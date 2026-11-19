# rulebook_lean_gate.ps1 -- PreToolUse hook on Edit|Write|MultiEdit. Keeps history out of text that
# loads into every session (CLAUDE.md, SKILL.md, hook output); see docs/maintaining-the-harness.md.
# Blocks ONCE per session, per check and per edit content, then the re-issued identical call passes:
# - a CLAUDE.md edit adding more than 500 characters or backstory wording;
# - a SKILL.md edit adding backstory wording;
# - a CLAUDE.md or SKILL.md edit adding a credit (author-date parenthetical, lapse number, root CHECKPOINT
#   version); loaded rule text carries only a bare (-> vN) or (-> <path>) pointer;
# - a hook script (.ps1/.py/.sh under a hooks/ folder, not tests) whose added OUTPUT lines (text printed
#   into sessions) carry a date, a lapse number, a version tag, an author-date credit or backstory.
#   Lexical screen only: text built in a variable or here-string and printed later is not seen.
# - SKILL.md, skill-slices/*.md, skill-core.md and any path matching RLG_EXTRA_RULE_PATTERN get the
#   SKILL.md checks (backstory, credit) plus the checks below;
# - REFUSED every time (no pass on re-issue): an edit or new file that leaves a rule bullet (list item plus
#   wrapped lines) over 600 characters. The post-edit text is rebuilt (CRLF files included) and compared with
#   the old file as a multiset of bullets, so a new file, a copied long bullet and a changed bullet all count,
#   while an old long bullet left alone does not; an edit that does not grow the file is never refused;
# - blocks once: a double-quoted span of 8+ words, or a "<Name>, <date>: <quote>" pattern, that is new in the
#   resulting text (a span already in the old file is not new), unless its line carries the marker (exact wording);
# - blocks once: an edit to the workspace root CLAUDE.md whose resulting text ADDS a rule line naming exactly one
#   project folder (a folder under the root holding its own CLAUDE.md) or one domain. Off unless the root is set.
# Settings (environment variables, all optional):
#   RLG_WORKSPACE_ROOT (else HARNESS_WORKSPACE_ROOT): the folder whose CLAUDE.md is the workspace root.
#   RLG_ROOT_SKIP: comma-separated project folder names the root check ignores.
#   RLG_AUTHOR_NAMES: comma-separated names (e.g. your own) whose "(<Name>, <date>)" credits are caught.
#   RLG_EXTRA_RULE_PATTERN: a regex on the forward-slash file path for more rule files to check.
# Fails open on any internal error. Tests: rulebook_lean_gate_tests.ps1 beside this file.
$ErrorActionPreference = 'Stop'
try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $j = $raw | ConvertFrom-Json
    if (@('Edit', 'Write', 'MultiEdit') -notcontains [string]$j.tool_name) { exit 0 }
    $in = $j.tool_input
    $fp = [string]$in.file_path
    $name = [IO.Path]::GetFileName($fp)
    $norm = $fp -replace '\\', '/'
    $rootSetting = if ($env:RLG_WORKSPACE_ROOT) { $env:RLG_WORKSPACE_ROOT } else { [string]$env:HARNESS_WORKSPACE_ROOT }
    $rootDir = ($rootSetting -replace '\\', '/').TrimEnd('/')
    $isRulebook = $name -ieq 'CLAUDE.md'
    $isSkill = $name -ieq 'SKILL.md'
    $isSlice = ($norm -match '(?i)/skill-slices/[^/]+\.md$') -or ($name -ieq 'skill-core.md')
    $isExtra = $false
    if ($env:RLG_EXTRA_RULE_PATTERN) { $isExtra = $norm -match $env:RLG_EXTRA_RULE_PATTERN }
    $isInstr = $isSkill -or $isSlice -or ($isExtra -and -not $isRulebook)
    $isRoot = $rootDir -and ($norm -ieq "$rootDir/CLAUDE.md")
    $isHook = ($norm -match '(?i)/hooks/') -and ($name -match '(?i)\.(ps1|py|sh)$') -and ($name -notmatch '(?i)_tests?\.')
    if (-not ($isRulebook -or $isInstr -or $isHook)) { exit 0 }

    $oldText = ''
    if (Test-Path -LiteralPath $fp) { $oldText = [IO.File]::ReadAllText($fp) }
    $added = ''
    $growth = 0
    switch ([string]$j.tool_name) {
        'Edit' { $added = [string]$in.new_string; $growth = $added.Length - ([string]$in.old_string).Length }
        'MultiEdit' { foreach ($e in @($in.edits)) { $added += [string]$e.new_string + "`n"; $growth += ([string]$e.new_string).Length - ([string]$e.old_string).Length } }
        'Write' {
            $added = [string]$in.content
            $growth = $added.Length - $oldText.Length
            # For a full rewrite only judge text that is new relative to the old file.
            if ($oldText) { $oldSet = [Collections.Generic.HashSet[string]]::new([string[]]($oldText -split "`n")); $added = (($added -split "`n") | Where-Object { -not $oldSet.Contains($_) }) -join "`n" }
        }
    }
    $added = [string]$added

    # Post-edit text: what the file will contain. An LF old_string is retried as CRLF against a CRLF file.
    $newText = $oldText
    if ([string]$j.tool_name -eq 'Write') { $newText = [string]$in.content }
    elseif ($isRulebook -or $isInstr) {
        $edits = if ([string]$j.tool_name -eq 'Edit') { @($in) } else { @($in.edits) }
        foreach ($e in $edits) {
            $o = [string]$e.old_string; $n = [string]$e.new_string
            if ($o.Length -eq 0) { continue }
            if ($newText.IndexOf($o, [StringComparison]::Ordinal) -lt 0 -and $newText.Contains("`r`n")) {
                $o = $o -replace "(?<!`r)`n", "`r`n"; $n = $n -replace "(?<!`r)`n", "`r`n"
            }
            if ($e.replace_all -eq $true) { $newText = $newText.Replace($o, $n) }
            else { $ix = $newText.IndexOf($o, [StringComparison]::Ordinal); if ($ix -ge 0) { $newText = $newText.Substring(0, $ix) + $n + $newText.Substring($ix + $o.Length) } }
        }
    }
    function Get-Bullets([string]$text) {
        $res = @(); $cur = $null; $fence = $false
        foreach ($l in ($text -split "`r?`n")) {
            if ($l -match '^\s*```') { $fence = -not $fence; if ($cur) { $res += $cur }; $cur = $null; continue }
            if ($fence) { continue }
            if ($l -match '^\s*([-*+]|\d+[.)])\s+\S') { if ($cur) { $res += $cur }; $cur = $l }
            elseif ($cur -and $l -match '\S' -and $l -notmatch '^\s*(#|\|)') { $cur += "`n" + $l }
            else { if ($cur) { $res += $cur }; $cur = $null }
        }
        if ($cur) { $res += $cur }
        return $res
    }
    # Items of $newItems beyond what $oldItems already holds (multiset difference).
    function Get-NewItems($oldItems, $newItems) {
        $cnt = @{}
        foreach ($x in @($oldItems)) { if ($cnt.ContainsKey($x)) { $cnt[$x]++ } else { $cnt[$x] = 1 } }
        $out = @()
        foreach ($x in @($newItems)) { if ($cnt.ContainsKey($x) -and $cnt[$x] -gt 0) { $cnt[$x]-- } else { $out += $x } }
        return $out
    }

    $story = '(?i)\b(incident|burned|cost a turn|after a session|a session (once|kept)|was what kept|the old wording|lapse record|flagged \d+x|we (once|kept)|the original wording|caused the failure|sat \d+ minutes)\b'
    $months = 'January|February|March|April|May|June|July|August|September|October|November|December'
    $names = @('user', 'owner', 'model', 'Codex', 'Claude')
    if ($env:RLG_AUTHOR_NAMES) { $names += @($env:RLG_AUTHOR_NAMES -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ } | ForEach-Object { [regex]::Escape($_) }) }
    $who = ($names -join '|') + '|[A-Z][a-z]+ (decision|correction|instruction)'
    $credit = "(?i)(\(($who)[^)]{0,120}(\d{4}|$months)|\([^()]{0,120}\b(19|20)\d\d-\d\d-\d\d\b|\bn=\d+|\blapses? \d+|root CHECKPOINT v\d+)"
    $reasons = @(); $cats = @(); $hints = @{}
    function Add-Reason([string]$cat, [string]$text, [string]$hintText) { $script:reasons += $text; $script:cats += $cat; if ($hintText) { $script:hints[$cat] = $hintText } }
    if ($isRulebook) {
        if ($growth -gt 500) { Add-Reason 'size' "adds $growth characters" '' }
        if ($added -match $story) { Add-Reason 'story' "adds backstory wording ('$($Matches[0])')" '' }
    } elseif ($isInstr) {
        if ($added -match $story) { Add-Reason 'story' "adds backstory wording ('$($Matches[0])')" '' }
    }
    if (($isRulebook -or $isInstr) -and $added -match $credit) { Add-Reason 'credit' "adds a credit ('$($Matches[0])')" '' }

    if ($isRulebook -or $isInstr) {
        # Quoted span of 8+ words, or <Name>, <date>: "..." that is new in the resulting text; (exact wording) exempts its line.
        $qHint = ' Quotes: keep the quote in the changelog or lapse row the pointer names; a span the rule enforces word-for-word stays if its line carries the marker (exact wording).'
        $datedQuote = '\b[A-Z][A-Za-z]+,\s*(?=[^":\r\n]{0,30}(\d{4}|' + $months + '))[^":\r\n]{1,30}:\s*["“]'
        $oldBlocks = [Collections.Generic.HashSet[string]]::new([string[]]@($oldText -split "`r?`n\s*`r?`n"))
        $found = ''
        foreach ($blk in ($newText -split "`r?`n\s*`r?`n")) {
            if ($oldBlocks.Contains($blk)) { continue }
            $hits = @()
            foreach ($m in [regex]::Matches($blk, $datedQuote)) { $hits += , @($m.Index, $m.Length, $m.Value, 'dated quote') }
            foreach ($m in [regex]::Matches($blk, '["“]([^"“”]{1,800})["”]')) {
                if (@($m.Groups[1].Value -split '\s+' | Where-Object { $_ }).Count -ge 8) { $hits += , @($m.Index, $m.Length, $m.Groups[1].Value, 'span') }
            }
            foreach ($h in $hits) {
                if ($oldText.IndexOf([string]$h[2], [StringComparison]::Ordinal) -ge 0) { continue }
                $s1 = $blk.LastIndexOf("`n", [Math]::Max(0, [int]$h[0] - 1)) + 1
                $e1 = $blk.IndexOf("`n", [int]$h[0] + [int]$h[1] - 1); if ($e1 -lt 0) { $e1 = $blk.Length }
                if ($blk.Substring($s1, $e1 - $s1) -match '\(exact wording\)') { continue }
                $found = [string]$h[3]; break
            }
            if ($found) { break }
        }
        if ($found -eq 'dated quote') { Add-Reason 'quote' "adds a dated quote of someone's words" $qHint }
        elseif ($found) { Add-Reason 'quote' 'adds a quoted span of 8 or more words' $qHint }
    }
    if ($isRoot) {
        $skipNames = @()
        if ($env:RLG_ROOT_SKIP) { $skipNames = @($env:RLG_ROOT_SKIP -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
        # A project folder is a folder under the root that holds its own CLAUDE.md.
        $projNames = @(Get-ChildItem -LiteralPath $rootDir -Directory -ErrorAction SilentlyContinue |
            Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'CLAUDE.md') } |
            ForEach-Object { $_.Name } | Where-Object { $skipNames -notcontains $_ })
        # Common suffixes; the list is a screen, not a registry.
        $sfx = 'dev|com|org|io|net|ai|app|co|me|us|gov|edu'
        $domRx = "(?i)\b[a-z0-9-]+\.($sfx)\b"
        $addedLines = Get-NewItems @($oldText -split "`r?`n") @($newText -split "`r?`n")
        foreach ($ln in $addedLines) {
            if ($ln -notmatch '^\s*([-*+]|\d+[.)])\s+\S') { continue }
            # Drop pointers and backticked file paths; a backticked domain stays.
            $t = $ln -replace '\(->[^)]*\)', ''
            $t = [regex]::Replace($t, '`([^`]*)`', { param($m) $v = $m.Groups[1].Value; if ($v -match "(?i)^[^\s/]+\.($sfx)$") { $v } elseif ($v -match '\.[A-Za-z0-9]{1,5}$') { '' } else { $v } })
            $hitNames = @()
            foreach ($pn in $projNames) { if ($t -match ('(?i)(?<![A-Za-z0-9_-])' + [regex]::Escape($pn) + '(?![A-Za-z0-9_-])')) { $hitNames += $pn.ToLower() } }
            foreach ($m in [regex]::Matches($t, $domRx)) { $hitNames += $m.Value.ToLower() }
            $hitNames = @($hitNames | Select-Object -Unique)
            if ($hitNames.Count -eq 1) { Add-Reason 'root' "adds a rule line naming only '$($hitNames[0])'" ' Narrowest layer: name the colocated CLAUDE.md or project file this belongs in, or say why every session needs it.'; break }
        }
    }
    if ($isHook) {
        $outRx = '(?i)(Write-Output|Write-Host|WriteLine\(|\.Write\(|\becho\b|\bprint\(|additionalContext|systemMessage|permissionDecisionReason|"reason")'
        $provRx = "(?i)(\b20\d\d-\d\d-\d\d\b|\bn=\d+|\blapses? \d+|\bv\d{2,3}\b|\(($who)[^)]{0,80}(\d{4}|$months)|\bmeasured\b|\bdiagnosis\b)"
        # A bare (-> vN) or (-> <path>) pointer is the allowed form, so it is removed before matching.
        $printed = ((($added -split "`n") | Where-Object { $_ -notmatch '^\s*#' -and $_ -match $outRx }) -join "`n") -replace '\(->[^)]*\)', ''
        if ($printed -match $provRx) { Add-Reason 'hookout' "prints dates, evidence or provenance into the session ('$($Matches[0])')" '' }
        elseif ($printed -match $story) { Add-Reason 'hookout' "prints backstory into the session ('$($Matches[0])')" '' }
    }

    # Permanent refusal: a bullet the edit adds or changes that is over 600 characters, when the file grows.
    if (($isRulebook -or $isInstr) -and ($newText.Length - $oldText.Length) -gt 0) {
        $long = @(Get-NewItems @(Get-Bullets $oldText) @(Get-Bullets $newText) | Where-Object { $_.Length -gt 600 })
        if ($long.Count -gt 0) {
            [Console]::Error.WriteLine("RULEBOOK LEAN GATE: this $name edit leaves a rule bullet of $($long[0].Length) characters (limit 600). Rewrite the rule as short bullets: one trigger + directive per bullet, each under 600 characters, then re-issue. This is refused every time; re-issuing the same text does not pass.")
            exit 2
        }
    }
    if ($reasons.Count -eq 0) { exit 0 }

    # Once-flag per session, per check and per edit content.
    $sid = ([string]$j.session_id) -replace '[^A-Za-z0-9_-]', ''
    if (-not $sid) { $sid = 'nosession' }
    $dir = Join-Path ([IO.Path]::GetTempPath()) 'claude_rulebook_lean_gate'
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    $sha = [Security.Cryptography.SHA1]::Create()
    $pending = @(); $pendHint = ''
    for ($i = 0; $i -lt $reasons.Count; $i++) {
        $seed = $fp.ToLower() + '|' + $cats[$i] + '|' + $added
        $hash = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($seed)))) -replace '-', ''
        $flag = Join-Path $dir "$sid`_$hash.flag"
        if (Test-Path -LiteralPath $flag) { continue }
        Set-Content -LiteralPath $flag -Value (Get-Date -Format o)
        $pending += $reasons[$i]
        if ($hints.ContainsKey($cats[$i]) -and $pendHint -notlike "*$($hints[$cats[$i]])*") { $pendHint += $hints[$cats[$i]] }
    }
    if ($pending.Count -eq 0) { exit 0 }
    if ($isHook) {
        [Console]::Error.WriteLine("RULEBOOK LEAN GATE: this hook edit $($pending -join ' and '). Text a hook prints is the directive plus a file pointer only; dates, evidence, lapse numbers and credits go in the changelog or the pointed-to file. Fix, then re-issue; a re-issued call passes.")
    } else {
        [Console]::Error.WriteLine("RULEBOOK LEAN GATE: this $name edit $($pending -join ' and '). A rule is trigger + directive + exceptions, then at most a pointer (-> vN) or (-> <path>). Move credits, backstory and quotes into the changelog entry or lapse row the pointer names, then re-issue; a re-issued call passes.$pendHint")
    }
    exit 2
} catch { exit 0 }
