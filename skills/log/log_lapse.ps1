# log_lapse.ps1 -- append ONE lapse record to a .jsonl lapse ledger.
# The model never opens the ledger: it passes fields, this script builds the line and appends.
# n is auto-assigned (last record's n + 1). -Date defaults to today (UTC).
#
# Every record also gets:
#   utc        -- 'yyyy-MM-dd HH:mm UTC' write time from this script's clock
#   model      -- model id read from this Claude Code session's transcript
#                 (~/.claude/projects/**/<CLAUDE_CODE_SESSION_ID>.jsonl, last assistant line)
#   effort     -- reasoning effort read from the same line
#   provenance -- "transcript:<session-id>" when read from the transcript; "caller-reported"
#                 when -Model/-Effort were used (another runtime, or -ForeignSession);
#                 "unavailable" when neither worked.
#
# -ForeignSession  The lapse happened in a different session than the one filing it. Skips
#                  the transcript read and trusts -Model/-Effort. Requires -Model.
# -RepeatOf <n>    Earlier row(s) this lapse repeats (12, or 12,46). Stamps `repeat_of` on the
#                  record and prints a PROMOTE message after appending.
# -NotRepeat       The caller checked and this is new; skips the similarity check.
# Similarity check (runs only when neither flag is passed): word-set overlap (Jaccard) between
#   this record's rule/step text and every earlier row's. At or above -Threshold (default 0.15)
#   it prints "POSSIBLE REPEAT of n=<k>" and EXITS 3 WITHOUT APPENDING; the caller re-runs
#   once with -RepeatOf or -NotRepeat. Lexical only: the same mistake in different words
#   scores low, so searching the ledger before filing is still required.
#
# Fields by ledger: rule_lapses.jsonl takes -Session -Rule; skill_lapses.jsonl takes
# -Skill -Step. All ledgers require -Consequence -HowCaught -FixStatus.
#
# Example:
#   pwsh -File log_lapse.ps1 -LogFile "<dir>/rule_lapses.jsonl" -Session "<project>" `
#     -Rule "<rule>" -Consequence "<cost>" -HowCaught "<how>" -FixStatus "<fix>. Author: model finding -- YYYY-MM-DD."

param(
    [Parameter(Mandatory = $true)][string]$LogFile,
    [string]$Date,
    [string]$Session,
    [string]$Skill,
    [string]$Rule,
    [string]$Step,
    [Parameter(Mandatory = $true)][string]$Consequence,
    [Parameter(Mandatory = $true)][string]$HowCaught,
    [Parameter(Mandatory = $true)][string]$FixStatus,
    # Fallbacks for non-Claude-Code runtimes (Codex/Cowork) where no transcript is findable.
    # Ignored when the transcript harvest succeeds -- the harvested value always wins.
    [string]$Model,
    [string]$Effort,
    # The lapse was witnessed in a DIFFERENT session than the one filing it (a recovered/
    # necromancy session, a subagent, a Cowork run). Skips the transcript harvest below
    # entirely (it would otherwise stamp THIS session's model/effort, not the offending
    # one) and trusts -Model/-Effort as given. Requires -Model.
    [switch]$ForeignSession,
    # n values of earlier rows this lapse repeats. Skips the fuzzy-match check, stamps
    # `repeat_of` on the record, and prints the PROMOTE block after appending.
    [string[]]$RepeatOf,   # accepts 12 or 12,46 or '12 46'; normalized below (see the -File note)
    # Caller has checked and confirmed this is NOT a repeat of anything earlier -- silences
    # the fuzzy-match hint (which would otherwise gate the append behind exit 3).
    [switch]$NotRepeat,
    # Jaccard similarity threshold for the repeat hint; the log SKILL.md says why it is this low.
    [double]$Threshold = 0.15
)

$ErrorActionPreference = 'Stop'

if ($LogFile -notmatch '\.jsonl$') { throw "LogFile must be a .jsonl file, got: $LogFile" }
if (-not (Test-Path $LogFile)) { throw "LogFile not found: $LogFile (start a ledger by copying ledger-template.md to <name>.md and creating an empty <name>.jsonl beside it)" }
if ($ForeignSession -and -not $Model) { throw "-ForeignSession requires -Model (the session that actually made the lapse)" }
# -File callers hand every argument over as a STRING, and PowerShell binding '36,15' to [int[]]
# yields the single number 3615 (the comma reads as a thousands separator).
# So the parameter is [string[]] and is split here on commas / whitespace into ints.
if ($RepeatOf) {
    $RepeatOf = @($RepeatOf | ForEach-Object { "$_" -split '[,\s]+' } | Where-Object { $_ -ne '' } | ForEach-Object {
        if ($_ -notmatch '^\d+$') { throw "-RepeatOf value '$_' is not a whole number" }
        [int]$_
    })
}
if ($RepeatOf -and $NotRepeat) { throw "pass either -RepeatOf or -NotRepeat, not both -- they answer the same question oppositely" }
if (-not $Date) { $Date = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd') }
$utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm UTC')

# --- harvest model + effort from this session's transcript JSONL (verifiable, not self-reported)
$harvestModel = $null; $harvestEffort = $null; $provenance = 'unavailable'
if ($ForeignSession) {
    # Trust the caller outright -- do NOT harvest, or this session's own transcript would
    # silently override the foreign session's real model/effort.
    $harvestModel = $Model; $harvestEffort = $Effort; $provenance = 'caller-reported'
} else {
    $sid = $env:CLAUDE_CODE_SESSION_ID
    if ($sid) {
        $transcript = Get-ChildItem "$env:USERPROFILE\.claude\projects" -Recurse -Filter "$sid.jsonl" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($transcript) {
            # last assistant line carries message.model + top-level effort
            $lastAsst = $null
            foreach ($tl in [System.IO.File]::ReadLines($transcript.FullName)) {
                if ($tl -match '"type":"assistant"' -and $tl -match '"model"') { $lastAsst = $tl }
            }
            if ($lastAsst) {
                try {
                    $ao = $lastAsst | ConvertFrom-Json
                    $harvestModel  = $ao.message.model
                    $harvestEffort = $ao.effort
                    if ($harvestModel) { $provenance = "transcript:$sid" }
                } catch {}
            }
        }
    }
    if (-not $harvestModel -and $Model) {
        $harvestModel = $Model; $harvestEffort = $Effort; $provenance = 'caller-reported'
    }
}

# --- read every existing non-blank record once: needed for next-n, -RepeatOf validation,
# and the fuzzy-match hint.
$existingRecords = @()
foreach ($line in [System.IO.File]::ReadLines($LogFile)) {
    if ($line.Trim().Length -gt 0) {
        try { $existingRecords += ($line | ConvertFrom-Json) } catch {}
    }
}

# next n = last non-blank record's n + 1 (blank/trailing lines tolerated)
$n = 1
if ($existingRecords.Count -gt 0) {
    $n = [int]$existingRecords[-1].n + 1
}

# -RepeatOf: every value must name a real earlier row
if ($RepeatOf) {
    $existingNs = @($existingRecords | ForEach-Object { [int]$_.n })
    foreach ($v in $RepeatOf) {
        if ($existingNs -notcontains $v) {
            throw "-RepeatOf $v does not match any existing n in $LogFile (existing n range: 1..$($existingNs | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum))"
        }
    }
}

# --- fuzzy-match hint (only when the caller hasn't already answered the question)
$stopWords = [System.Collections.Generic.HashSet[string]]::new()
foreach ($w in @('the','a','an','of','to','and','or','in','on','is','it','not','before','after',
                 'with','for','that','this','you','your','be','as','by','at','from')) {
    [void]$stopWords.Add($w)
}

function Get-TokenSet {
    param([string]$Text)
    $set = [System.Collections.Generic.HashSet[string]]::new()
    if (-not $Text) { return $set }
    $t = $Text.ToLower() -replace '[^a-z0-9\s]', ' '
    foreach ($tok in ($t -split '\s+')) {
        if ($tok -and -not $stopWords.Contains($tok)) { [void]$set.Add($tok) }
    }
    # Force the HashSet itself onto the pipeline as ONE object -- a bare "return $set" lets
    # PowerShell enumerate the set's members individually (collapsing to a scalar string when
    # the set has exactly one token, or a plain object[] otherwise), so the caller never gets
    # back an actual HashSet. The unary comma prevents that flattening.
    return ,$set
}

function Get-JaccardScore {
    param($SetA, $SetB)
    if ($SetA.Count -eq 0 -and $SetB.Count -eq 0) { return 0.0 }
    $inter = [System.Collections.Generic.HashSet[string]]::new($SetA)
    $inter.IntersectWith($SetB)
    $union = [System.Collections.Generic.HashSet[string]]::new($SetA)
    $union.UnionWith($SetB)
    if ($union.Count -eq 0) { return 0.0 }
    return [double]$inter.Count / [double]$union.Count
}

$textFieldName = if ($Rule) { 'rule' } elseif ($Step) { 'step' } else { $null }
$newText = if ($Rule) { $Rule } elseif ($Step) { $Step } else { $null }

if (-not $RepeatOf -and -not $NotRepeat -and $textFieldName -and $newText) {
    $newTokens = Get-TokenSet -Text $newText
    $bestScore = 0.0
    $bestN = $null
    $bestText = $null
    foreach ($rec0 in $existingRecords) {
        $priorText = $rec0.$textFieldName
        if (-not $priorText) { continue }
        $priorTokens = Get-TokenSet -Text $priorText
        $score = Get-JaccardScore -SetA $newTokens -SetB $priorTokens
        if ($score -gt $bestScore) {
            $bestScore = $score
            $bestN = $rec0.n
            $bestText = $priorText
        }
    }
    if ($bestN -ne $null -and $bestScore -ge $Threshold) {
        $snippet = $bestText
        if ($snippet.Length -gt 90) { $snippet = $snippet.Substring(0, 90) }
        $scoreStr = [math]::Round($bestScore, 2)
        Write-Output "POSSIBLE REPEAT of n=$bestN ($scoreStr): '$snippet'. If it is the same rule, re-run with -RepeatOf $bestN (or pass -NotRepeat to silence)."
        exit 3
    }
}

# ordered record; only include the identity fields that were passed
$rec = [ordered]@{ n = $n; date = $Date; utc = $utc; model = $harvestModel; effort = $harvestEffort; provenance = $provenance }
if ($Session) { $rec.session = $Session }
if ($Skill)   { $rec.skill = $Skill }
if ($Rule)    { $rec.rule = $Rule }
if ($Step)    { $rec.step = $Step }
if ($RepeatOf) { $rec.repeat_of = [int[]]@($RepeatOf) }
$rec.consequence = $Consequence
$rec.how_caught  = $HowCaught
$rec.fix_status  = $FixStatus

$json = $rec | ConvertTo-Json -Compress -Depth 3

# append as a complete line; guard against a missing trailing newline
$raw = [System.IO.File]::ReadAllText($LogFile)
$prefix = ''
if ($raw.Length -gt 0 -and -not $raw.EndsWith("`n")) { $prefix = "`n" }
[System.IO.File]::AppendAllText($LogFile, "$prefix$json`n", [System.Text.UTF8Encoding]::new($false))

Write-Output "appended lapse n=$n to $LogFile (model=$harvestModel effort=$harvestEffort provenance=$provenance)"

if ($RepeatOf) {
    $allNs = @($RepeatOf) + @($n)
    $totalCount = $allNs.Count
    $nList = ($allNs | ForEach-Object { $_.ToString() }) -join ','
    $mdTwin = $LogFile -replace '\.jsonl$', '.md'
    $ckpt = Join-Path (Split-Path -Parent (Split-Path -Parent (Resolve-Path $LogFile).Path)) 'CHECKPOINT.md'
    Write-Output "PROMOTE: this rule now has $totalCount rows (n=$nList). A repeat earns a stronger GENERAL rule for its family (one hook or rule per family of failure), never a new rule shaped to this one incident. In THIS run: (1) add or update the family's Fix candidates entry in $mdTwin, listing every n in it; (2) write ONE Open-threads line in the CHECKPOINT.md of the project that holds this ledger (likely $ckpt): '- Strengthen <rule family, 8 words max>: <one-line design>.' The line closes when that fix ships and the rows' fix_status says so."
}
