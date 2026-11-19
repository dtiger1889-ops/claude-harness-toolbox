# Tests for rulebook_lean_gate.ps1. Run: pwsh -NoProfile -File rulebook_lean_gate_tests.ps1 [-Hook <path>] [-HostExe powershell.exe]
param([string]$Hook = (Join-Path $PSScriptRoot 'rulebook_lean_gate.ps1'), [string]$HostExe = 'pwsh')
$ErrorActionPreference = 'Stop'
$pass = 0; $fail = 0
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("rlg_" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
$md = Join-Path $tmp 'CLAUDE.md'
Set-Content -LiteralPath $md -Value "# Rules`n- one rule"

# $envs: hashtable of environment variables for the hook process. A plain string is RLG_WORKSPACE_ROOT.
function Run($tool, $toolInput, $sid, $envs) {
    $payload = @{ tool_name = $tool; tool_input = $toolInput; session_id = $sid } | ConvertTo-Json -Depth 6 -Compress
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $HostExe; $psi.Arguments = "-NoProfile -File `"$Hook`""
    foreach ($k in 'RLG_WORKSPACE_ROOT', 'HARNESS_WORKSPACE_ROOT', 'RLG_ROOT_SKIP', 'RLG_AUTHOR_NAMES', 'RLG_EXTRA_RULE_PATTERN') { $psi.EnvironmentVariables.Remove($k) }
    if ($envs -is [string]) { $envs = @{ RLG_WORKSPACE_ROOT = $envs } }
    if ($envs) { foreach ($k in $envs.Keys) { $psi.EnvironmentVariables[$k] = [string]$envs[$k] } }
    $psi.RedirectStandardInput = $true; $psi.RedirectStandardError = $true; $psi.RedirectStandardOutput = $true; $psi.UseShellExecute = $false
    $pr = [Diagnostics.Process]::Start($psi)
    $pr.StandardInput.Write($payload); $pr.StandardInput.Close()
    $err = $pr.StandardError.ReadToEnd(); $pr.WaitForExit()
    return @{ code = $pr.ExitCode; err = $err }
}
function Check($name, $cond, $detail) { if ($cond) { $script:pass++; Write-Host "PASS  $name" } else { $script:fail++; Write-Host "FAIL  $name  $detail" } }
$s = "t" + [guid]::NewGuid().ToString('N').Substring(0, 8)

$r = Run 'Edit' @{ file_path = $md; old_string = '- one rule'; new_string = '- one rule (Incident: a session deleted the repo.)' } "$s-a"
Check '1 backstory wording blocks' ($r.code -eq 2 -and $r.err -match 'RULEBOOK LEAN GATE') "code=$($r.code)"
$r = Run 'Edit' @{ file_path = $md; old_string = '- one rule'; new_string = '- one rule (Incident: a session deleted the repo.)' } "$s-a"
Check '2 re-issue in the same session passes' ($r.code -eq 0) "code=$($r.code)"
$r = Run 'Edit' @{ file_path = $md; old_string = 'x'; new_string = ('y' * 600) } "$s-b"
Check '3 growth over 500 chars blocks' ($r.code -eq 2 -and $r.err -match 'adds 599 characters') "code=$($r.code) err=$($r.err)"
$r = Run 'Edit' @{ file_path = $md; old_string = '- one rule'; new_string = '- one rule, scoped to PowerShell (-> v127).' } "$s-c"
Check '4 short rule line with pointer passes' ($r.code -eq 0) "code=$($r.code)"
$r = Run 'Edit' @{ file_path = (Join-Path $tmp 'NOTES.md'); old_string = 'a'; new_string = 'Incident: ' + ('z' * 900) } "$s-d"
Check '5 non-CLAUDE.md files ignored' ($r.code -eq 0) "code=$($r.code)"
$r = Run 'Write' @{ file_path = $md; content = "# Rules`n- one rule`n- a second rule" } "$s-e"
Check '6 small full rewrite passes' ($r.code -eq 0) "code=$($r.code)"
$r = Run 'Write' @{ file_path = $md; content = "# Rules`n- one rule`n- new rule; the old wording said otherwise" } "$s-f"
Check '7 full rewrite adding backstory wording blocks' ($r.code -eq 2) "code=$($r.code)"
$r = Run 'MultiEdit' @{ file_path = $md; edits = @(@{ old_string = 'a'; new_string = 'b (burned an evening)' }) } "$s-g"
Check '8 MultiEdit backstory blocks' ($r.code -eq 2) "code=$($r.code)"
$r = Run 'Bash' @{ command = 'ls' } "$s-h"
Check '9 other tools ignored' ($r.code -eq 0) "code=$($r.code)"
$hd = Join-Path $tmp '.claude/hooks'; New-Item -ItemType Directory -Path $hd -Force | Out-Null
$hk = Join-Path $hd 'sample_hook.ps1'; Set-Content -LiteralPath $hk -Value "Write-Output 'x'"
$r = Run 'Edit' @{ file_path = $hk; old_string = "Write-Output 'x'"; new_string = "Write-Output 'Rule here (Alex /prevent, 2026-10-07; record: foo.md)'" } "$s-i"
Check '10 hook printing a dated credit blocks' ($r.code -eq 2 -and $r.err -match 'prints dates') "code=$($r.code) err=$($r.err)"
$r = Run 'Edit' @{ file_path = $hk; old_string = "Write-Output 'x'"; new_string = "Write-Output 'Use full paths: docs/tools-index.md.'" } "$s-j"
Check '11 hook printing directive + pointer passes' ($r.code -eq 0) "code=$($r.code)"
$r = Run 'Edit' @{ file_path = $hk; old_string = "Write-Output 'x'"; new_string = "# record 2026-10-07, lapse n=12`nWrite-Output 'ok'" } "$s-k"
Check '12 dated comment in a hook passes (not printed)' ($r.code -eq 0) "code=$($r.code)"
$r = Run 'Edit' @{ file_path = $hk; old_string = "Write-Output 'x'"; new_string = "Write-Output 'Read it first (lapses 40, 41).'" } "$s-za"
Check 'A1 hook printing a lapses citation blocks' ($r.code -eq 2) "code=$($r.code)"
$r = Run 'Edit' @{ file_path = $hk; old_string = "Write-Output 'x'"; new_string = "Write-Output 'Read it first (-> v176).'" } "$s-zb"
Check 'A2 hook printing a bare pointer passes' ($r.code -eq 0) "code=$($r.code)"
$r = Run 'Edit' @{ file_path = $md; old_string = '- one rule'; new_string = '- one rule (Alex decision, November 17)' } "$s-zc"
Check 'A3 CLAUDE.md month-name decision credit blocks' ($r.code -eq 2) "code=$($r.code)"
$r = Run 'Edit' @{ file_path = $md; old_string = '- one rule'; new_string = '- one rule (Alex, November 17)' } "$s-zd"
Check 'A4 a bare name credit passes when the name is not configured' ($r.code -eq 0) "code=$($r.code) err=$($r.err)"
$r = Run 'Edit' @{ file_path = $md; old_string = '- one rule'; new_string = '- one rule (Alex, November 17)' } "$s-ze" @{ RLG_AUTHOR_NAMES = 'Sam, Alex' }
Check 'A5 RLG_AUTHOR_NAMES makes a bare name credit block' ($r.code -eq 2 -and $r.err -match 'adds a credit') "code=$($r.code) err=$($r.err)"
$sk = Join-Path $tmp 'SKILL.md'; Set-Content -LiteralPath $sk -Value "# s"
$r = Run 'Edit' @{ file_path = $sk; old_string = '# s'; new_string = "# s`n- step (after a session lost it)" } "$s-l"
Check '13 SKILL.md backstory blocks' ($r.code -eq 2) "code=$($r.code)"
$r = Run 'Edit' @{ file_path = $sk; old_string = '# s'; new_string = ('# s' + ('q' * 900)) } "$s-m"
Check '14 SKILL.md growth alone passes' ($r.code -eq 0) "code=$($r.code)"
$r = Run 'Edit' @{ file_path = $md; old_string = '- one rule'; new_string = '- one rule (Alex, 2026-11-17; root CHECKPOINT v176)' } "$s-n"
Check '15 CLAUDE.md author-date credit blocks' ($r.code -eq 2 -and $r.err -match 'adds a credit') "code=$($r.code) err=$($r.err)"
$r = Run 'Edit' @{ file_path = $md; old_string = '- one rule'; new_string = '- one rule (Alex, 2026-11-17; root CHECKPOINT v176)' } "$s-n"
Check '16 re-issued credit edit passes' ($r.code -eq 0) "code=$($r.code)"
$r = Run 'Edit' @{ file_path = $md; old_string = '- one rule'; new_string = '- one rule (lapses n=12, 40)' } "$s-o"
Check '17 CLAUDE.md lapse number blocks' ($r.code -eq 2 -and $r.err -match "adds a credit \('n=12'\)") "code=$($r.code) err=$($r.err)"
$r = Run 'Edit' @{ file_path = $md; old_string = '- one rule'; new_string = '- one rule; see root CHECKPOINT v150' } "$s-p"
Check '18 CLAUDE.md root CHECKPOINT version blocks' ($r.code -eq 2 -and $r.err -match 'adds a credit') "code=$($r.code) err=$($r.err)"
$r = Run 'Edit' @{ file_path = $sk; old_string = '# s'; new_string = "# s`n- step (model wording -- 2026-10-29)" } "$s-q"
Check '19 SKILL.md author-date credit blocks' ($r.code -eq 2 -and $r.err -match 'adds a credit') "code=$($r.code) err=$($r.err)"
$r = Run 'Edit' @{ file_path = $md; old_string = '- one rule'; new_string = '- one rule (-> v176)' } "$s-r"
Check '20 CLAUDE.md bare (-> v176) pointer passes' ($r.code -eq 0) "code=$($r.code) err=$($r.err)"
$r = Run 'Edit' @{ file_path = $sk; old_string = '# s'; new_string = "# s`n- step (-> v134)" } "$s-s"
Check '21 SKILL.md bare (-> v134) pointer passes' ($r.code -eq 0) "code=$($r.code) err=$($r.err)"

# --- 600-character refusal (no pass on re-issue) ---
$longBullet = '- ' + ('w' * 650)
$r = Run 'Edit' @{ file_path = $md; old_string = '- one rule'; new_string = $longBullet } "$s-b1"
Check 'B1 650-char bullet refused' ($r.code -eq 2 -and $r.err -match 'limit 600') "code=$($r.code) err=$($r.err)"
$r = Run 'Edit' @{ file_path = $md; old_string = '- one rule'; new_string = $longBullet } "$s-b1"
Check 'B2 same long bullet refused again on re-issue' ($r.code -eq 2 -and $r.err -match 'limit 600') "code=$($r.code)"
$r = Run 'Edit' @{ file_path = $md; old_string = '- one rule'; new_string = ("- a`n  " + ('x' * 300) + "`n  " + ('y' * 300)) } "$s-b2"
Check 'B3 wrapped continuation lines count toward the bullet' ($r.code -eq 2 -and $r.err -match 'limit 600') "code=$($r.code)"
$r = Run 'Edit' @{ file_path = $md; old_string = '- one rule'; new_string = ('- ' + ('w' * 400)) } "$s-b3"
Check 'B4 400-char bullet passes' ($r.code -eq 0) "code=$($r.code) err=$($r.err)"
$r = Run 'Write' @{ file_path = $md; content = "# Rules`n- one rule`n$longBullet" } "$s-b4"
Check 'B5 Write leaving a long new bullet refused' ($r.code -eq 2 -and $r.err -match 'limit 600') "code=$($r.code)"
$ld = Join-Path $tmp 'long'; New-Item -ItemType Directory -Path $ld | Out-Null
$lmd = Join-Path $ld 'CLAUDE.md'; Set-Content -LiteralPath $lmd -Value ("# R`n- old long " + ('o' * 700) + "`n- short")
$r = Run 'Edit' @{ file_path = $lmd; old_string = '- short'; new_string = '- short, plus a small addition' } "$s-b5"
Check 'B6 untouched pre-existing long bullet is not blocked' ($r.code -eq 0) "code=$($r.code) err=$($r.err)"
$r = Run 'Edit' @{ file_path = $lmd; old_string = ('o' * 700); new_string = ('o' * 650) } "$s-b6"
Check 'B7 shrinking a long bullet passes' ($r.code -eq 0) "code=$($r.code) err=$($r.err)"
$r = Run 'Edit' @{ file_path = $lmd; old_string = ('o' * 700); new_string = ('o' * 750) } "$s-b7"
Check 'B8 growing a long bullet refused' ($r.code -eq 2) "code=$($r.code)"

# --- quoted-span check ---
$r = Run 'Edit' @{ file_path = $sk; old_string = '# s'; new_string = '# s' + "`n- say ""one two three four five six seven eight nine"" then stop" } "$s-q1"
Check 'C1 8+ word quoted span blocks' ($r.code -eq 2 -and $r.err -match 'quoted span') "code=$($r.code) err=$($r.err)"
$r = Run 'Edit' @{ file_path = $sk; old_string = '# s'; new_string = '# s' + "`n- say ""one two three four five six seven eight nine"" then stop" } "$s-q1"
Check 'C2 re-issued quoted span passes' ($r.code -eq 0) "code=$($r.code)"
$r = Run 'Edit' @{ file_path = $sk; old_string = '# s'; new_string = '# s' + "`n- say ""run it now"" then stop" } "$s-q2"
Check 'C3 short quote passes' ($r.code -eq 0) "code=$($r.code) err=$($r.err)"
$r = Run 'Edit' @{ file_path = $sk; old_string = '# s'; new_string = '# s' + "`n- print ""one two three four five six seven eight nine"" (exact wording)" } "$s-q3"
Check 'C4 quote with (exact wording) marker passes' ($r.code -eq 0) "code=$($r.code) err=$($r.err)"
$r = Run 'Edit' @{ file_path = $sk; old_string = '# s'; new_string = '# s' + "`n- Alex, 2026-11-17: ""stop"" is the rule" } "$s-q4"
Check 'C5 <Name>, <date>: " pattern blocks' ($r.code -eq 2 -and $r.err -match 'quote') "code=$($r.code) err=$($r.err)"
$r = Run 'Edit' @{ file_path = $sk; old_string = '# s'; new_string = '# s' + "`n- Note, then: ""stop"" is the rule" } "$s-q5"
Check 'C6 <Word>, text: " with no date passes' ($r.code -eq 0) "code=$($r.code) err=$($r.err)"

# --- widened file set ---
$sd = Join-Path $tmp 'notes/skill-slices'; New-Item -ItemType Directory -Path $sd -Force | Out-Null
$slice = Join-Path $sd 'inbox.md'; Set-Content -LiteralPath $slice -Value '# i'
$r = Run 'Edit' @{ file_path = $slice; old_string = '# i'; new_string = "# i`n- step (after a session lost it)" } "$s-w1"
Check 'D1 skill-slices/*.md backstory blocks' ($r.code -eq 2) "code=$($r.code) err=$($r.err)"
$core = Join-Path $tmp 'skill-core.md'; Set-Content -LiteralPath $core -Value '# c'
$r = Run 'Edit' @{ file_path = $core; old_string = '# c'; new_string = "# c`n- step (Alex, 2026-11-17)" } "$s-w2"
Check 'D2 skill-core.md credit blocks' ($r.code -eq 2) "code=$($r.code) err=$($r.err)"
$td = Join-Path $tmp 'rule-modules'; New-Item -ItemType Directory -Path $td | Out-Null
$vr = Join-Path $td 'write safety.md'; Set-Content -LiteralPath $vr -Value '# v'
$extra = @{ RLG_EXTRA_RULE_PATTERN = '(?i)/rule-modules/[^/]+\.md$' }
$r = Run 'Edit' @{ file_path = $vr; old_string = '# v'; new_string = "# v`n" + $longBullet } "$s-w3" $extra
Check 'D3 RLG_EXTRA_RULE_PATTERN file long bullet refused' ($r.code -eq 2 -and $r.err -match 'limit 600') "code=$($r.code) err=$($r.err)"
$r = Run 'Edit' @{ file_path = $vr; old_string = '# v'; new_string = "# v`n" + $longBullet } "$s-w3b"
Check 'D3b same file ignored without the pattern' ($r.code -eq 0) "code=$($r.code) err=$($r.err)"
$vo = Join-Path $tmp 'Other note.md'; Set-Content -LiteralPath $vo -Value '# v'
$r = Run 'Edit' @{ file_path = $vo; old_string = '# v'; new_string = "# v`n" + $longBullet + ' (after a session lost it)' } "$s-w4" $extra
Check 'D4 file outside the pattern ignored' ($r.code -eq 0) "code=$($r.code)"
$r = Run 'Edit' @{ file_path = $slice; old_string = '# i'; new_string = "# i`n- step (-> v134)" } "$s-w5"
Check 'D5 slice with bare pointer passes' ($r.code -eq 0) "code=$($r.code) err=$($r.err)"

# --- narrowest-layer question on the workspace root CLAUDE.md (read-only: the hook never writes) ---
$wr = Join-Path $tmp 'wsroot'; New-Item -ItemType Directory -Path $wr | Out-Null
foreach ($d in 'site_alpha', 'tool_beta', 'skipme') { New-Item -ItemType Directory -Path (Join-Path $wr $d) | Out-Null; Set-Content -LiteralPath (Join-Path $wr "$d/CLAUDE.md") -Value '# p' }
New-Item -ItemType Directory -Path (Join-Path $wr 'archive') | Out-Null
$root = Join-Path $wr 'CLAUDE.md'
Set-Content -LiteralPath $root -Value "# Root`n- Keep navigation smooth.`n- Another general rule.`n- say ""one two three four five six seven eight"" (Alex, 2026-11-17)"
$rootEnv = @{ RLG_WORKSPACE_ROOT = $wr; RLG_ROOT_SKIP = 'skipme' }
function RootAdd($new, $sid) { Run 'Edit' @{ file_path = $root; old_string = '- Another general rule.'; new_string = "- Another general rule.`n$new" } $sid $rootEnv }
$r = RootAdd '- Keep example.dev navigation smooth on every page.' "$s-n1"
Check 'E1 root rule naming one domain blocks' ($r.code -eq 2 -and $r.err -match 'colocated CLAUDE.md') "code=$($r.code) err=$($r.err)"
$r = RootAdd '- Keep example.dev navigation smooth on every page.' "$s-n1"
Check 'E2 re-issue passes' ($r.code -eq 0) "code=$($r.code)"
$r = RootAdd '- Never edit site_alpha pages without the build step.' "$s-n2"
Check 'E3 root rule naming one project folder blocks' ($r.code -eq 2 -and $r.err -match 'colocated CLAUDE.md') "code=$($r.code) err=$($r.err)"
$r = RootAdd '- Keep example.dev and site_alpha in sync.' "$s-n3"
Check 'E4 line naming two projects passes' ($r.code -eq 0) "code=$($r.code) err=$($r.err)"
$r = RootAdd '- Every session records state first (-> site_alpha/CHECKPOINT.md).' "$s-n4"
Check 'E5 project name only inside a pointer passes' ($r.code -eq 0) "code=$($r.code) err=$($r.err)"
$r = RootAdd '- Every session records state before it ends.' "$s-n5"
Check 'E6 general root rule passes' ($r.code -eq 0) "code=$($r.code) err=$($r.err)"
$r = Run 'Edit' @{ file_path = $md; old_string = '- one rule'; new_string = '- Keep example.dev navigation smooth.' } "$s-n6" $rootEnv
Check 'E7 same text in a non-root CLAUDE.md passes' ($r.code -eq 0) "code=$($r.code)"
$r = Run 'Edit' @{ file_path = $root; old_string = '- Another general rule.'; new_string = "- Another general rule.`n- Keep example.dev navigation smooth." } "$s-n7"
Check 'E8 no root setting: root check is off' ($r.code -eq 0) "code=$($r.code) err=$($r.err)"
$r = Run 'Edit' @{ file_path = $root; old_string = '- Another general rule.'; new_string = "- Another general rule.`n- Keep example.dev navigation smooth." } "$s-n8" @{ HARNESS_WORKSPACE_ROOT = $wr }
Check 'E9 HARNESS_WORKSPACE_ROOT is the fallback root setting' ($r.code -eq 2 -and $r.err -match 'colocated') "code=$($r.code) err=$($r.err)"
$r = RootAdd '- Use `example.dev` navigation smoothly.' "$s-f6a"
Check 'F6a backticked domain counts' ($r.code -eq 2 -and $r.err -match 'colocated') "code=$($r.code) err=$($r.err)"
$r = RootAdd '- Use Site_Alpha pages carefully.' "$s-f6b"
Check 'F6b project name matched case-insensitively' ($r.code -eq 2 -and $r.err -match 'colocated') "code=$($r.code) err=$($r.err)"
$r = RootAdd '- Keep example.ai navigation smooth.' "$s-f6c"
Check 'F6c .ai domain counts' ($r.code -eq 2 -and $r.err -match 'colocated') "code=$($r.code) err=$($r.err)"
$r = RootAdd '- Use skipme for hook work.' "$s-f6d"
Check 'F6d folder listed in RLG_ROOT_SKIP is skipped' ($r.code -eq 0) "code=$($r.code) err=$($r.err)"
$r = RootAdd '- Move old work to archive when done.' "$s-f6f"
Check 'F6f folder with no CLAUDE.md is not a project' ($r.code -eq 0) "code=$($r.code) err=$($r.err)"
$r = RootAdd '- See `notes/file.md` for detail.' "$s-f6e"
Check 'F6e backticked file path is not a domain' ($r.code -eq 0) "code=$($r.code) err=$($r.err)"
$r = Run 'Edit' @{ file_path = $root; old_string = 'Keep navigation'; new_string = 'Keep example.dev navigation' } "$s-f7" $rootEnv
Check 'F7 mid-line edit that makes a rule name one domain blocks' ($r.code -eq 2 -and $r.err -match 'colocated') "code=$($r.code) err=$($r.err)"
$r = Run 'Edit' @{ file_path = $root; old_string = '- Keep navigation smooth.'; new_string = '- Keep site_alpha smooth (Alex, 2026-11-17).' } "$s-f8" $rootEnv
Check 'F8a credit warning fires first' ($r.code -eq 2 -and $r.err -match 'adds a credit') "code=$($r.code) err=$($r.err)"
$r = Run 'Edit' @{ file_path = $root; old_string = '- Another general rule.'; new_string = "- Another general rule.`n- Keep tool_beta pages tidy." } "$s-f8" $rootEnv
Check 'F8b a different edit in the same session gets its own root warning' ($r.code -eq 2 -and $r.err -match 'colocated') "code=$($r.code) err=$($r.err)"
$r = Run 'Edit' @{ file_path = $root; old_string = '- Keep navigation smooth.'; new_string = '- Keep site_alpha smooth (Alex, 2026-11-17).' } "$s-f8" $rootEnv
Check 'F8c re-issue of the first edit passes' ($r.code -eq 0) "code=$($r.code) err=$($r.err)"
$ad = Join-Path $tmp 'a-b'; $bd = Join-Path $tmp 'a_b'; New-Item -ItemType Directory -Path $ad, $bd | Out-Null
$sa = Join-Path $ad 'SKILL.md'; $sb = Join-Path $bd 'SKILL.md'; Set-Content -LiteralPath $sa -Value '# s'; Set-Content -LiteralPath $sb -Value '# s'
$r = Run 'Edit' @{ file_path = $sa; old_string = '# s'; new_string = "# s`n- x (Incident: a)" } "$s-f8d"
$r2 = Run 'Edit' @{ file_path = $sb; old_string = '# s'; new_string = "# s`n- x (Incident: a)" } "$s-f8d"
Check 'F8d same-looking paths a-b and a_b do not share a flag' ($r.code -eq 2 -and $r2.code -eq 2) "codes=$($r.code),$($r2.code)"

# --- new files, copied bullets, CRLF, quotes across edits ---
$newSkill = Join-Path $tmp 'fresh/SKILL.md'
$r = Run 'Write' @{ file_path = $newSkill; content = "# n`n- " + ('x' * 601) } "$s-f1a"
Check 'F1a Write of a NEW SKILL.md with a long bullet refused' ($r.code -eq 2 -and $r.err -match 'limit 600') "code=$($r.code) err=$($r.err)"
$r = Run 'Write' @{ file_path = (Join-Path $tmp 'fresh/CLAUDE.md'); content = "# n`n- " + ('x' * 601) } "$s-f1b"
Check 'F1b Write of a NEW CLAUDE.md with a long bullet refused' ($r.code -eq 2 -and $r.err -match 'limit 600') "code=$($r.code) err=$($r.err)"
$dup = Join-Path $tmp 'dup/SKILL.md'; New-Item -ItemType Directory -Path (Split-Path $dup) | Out-Null
$lb = '- ' + ('d' * 603); Set-Content -LiteralPath $dup -Value "# s`n$lb"
$r = Run 'Write' @{ file_path = $dup; content = "# s`n$lb`n$lb" } "$s-f2a"
Check 'F2a copying an existing long bullet refused' ($r.code -eq 2 -and $r.err -match 'limit 600') "code=$($r.code) err=$($r.err)"
$r = Run 'Write' @{ file_path = $dup; content = "# s`n$lb`n- short" } "$s-f2b"
Check 'F2b keeping the one old long bullet passes' ($r.code -eq 0) "code=$($r.code) err=$($r.err)"
$crlf = Join-Path $tmp 'crlf/SKILL.md'; New-Item -ItemType Directory -Path (Split-Path $crlf) | Out-Null
[IO.File]::WriteAllText($crlf, "# s`r`n- " + ('x' * 601) + "`r`n- short`r`n")
$r = Run 'Edit' @{ file_path = $crlf; old_string = ('x' * 601) + "`n- short"; new_string = ('x' * 602) + "`n- short" } "$s-f3a"
Check 'F3a LF edit against a CRLF file still measures the long bullet' ($r.code -eq 2 -and $r.err -match 'limit 600') "code=$($r.code) err=$($r.err)"
$r = Run 'MultiEdit' @{ file_path = $md; edits = @(@{ old_string = '- one rule'; new_string = ('- ' + ('m' * 700)) }) } "$s-f3b"
Check 'F3b MultiEdit long bullet refused' ($r.code -eq 2 -and $r.err -match 'limit 600') "code=$($r.code) err=$($r.err)"
$qf = Join-Path $tmp 'q/SKILL.md'; New-Item -ItemType Directory -Path (Split-Path $qf) | Out-Null
Set-Content -LiteralPath $qf -Value "# s`n- say ""one two three four five six seven`n- keep ""alpha beta gamma delta epsilon zeta eta theta"" (Alex, 2026-11-17)"
$r = Run 'Edit' @{ file_path = $qf; old_string = 'five six seven' + "`n"; new_string = 'five six seven eight"' + "`n" } "$s-f4a"
Check 'F4a quote completed across an edit boundary blocks' ($r.code -eq 2 -and $r.err -match 'quoted span') "code=$($r.code) err=$($r.err)"
$r = Run 'MultiEdit' @{ file_path = $qf; edits = @(@{ old_string = '- say "one two three four five six seven'; new_string = '- say "one two three four five six seven eight' }, @{ old_string = "`n- keep"; new_string = "`n- nine"" then`n- keep" }) } "$s-f4b"
Check 'F4b MultiEdit assembling a quote blocks' ($r.code -eq 2 -and $r.err -match 'quoted span') "code=$($r.code) err=$($r.err)"
$wf = Join-Path $tmp 'q/slices/skill-core.md'; New-Item -ItemType Directory -Path (Split-Path $wf) | Out-Null
Set-Content -LiteralPath $wf -Value "# c`n- say ""one two three four`nfive six seven eight"" now`n"
$r = Run 'Edit' @{ file_path = $wf; old_string = '# c'; new_string = '# c2' } "$s-f4c"
Check 'F4c wrapped quote that already existed is not new' ($r.code -eq 0) "code=$($r.code) err=$($r.err)"
$r = Run 'Edit' @{ file_path = $wf; old_string = 'now'; new_string = "now`n- also ""a b c d`ne f g h"" ok" } "$s-f4d"
Check 'F4d new wrapped quote across two lines blocks' ($r.code -eq 2 -and $r.err -match 'quoted span') "code=$($r.code) err=$($r.err)"
$r = Run 'Edit' @{ file_path = $qf; old_string = '- keep "alpha beta gamma delta epsilon zeta eta theta" (Alex, 2026-11-17)'; new_string = '- keep "alpha beta gamma delta epsilon zeta eta theta"' } "$s-f5"
Check 'F5 stripping a credit from a line with an old quote passes' ($r.code -eq 0) "code=$($r.code) err=$($r.err)"

Remove-Item -LiteralPath $tmp -Recurse -Force
Write-Host "---- $pass passed, $fail failed"
if ($fail) { exit 1 }
