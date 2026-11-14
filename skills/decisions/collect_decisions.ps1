# collect_decisions.ps1 -- gather decision-board candidates for one project.
# Never classifies: the decisions skill's step 2 does that. Emits ONE JSON object on stdout,
# UTF-8 without BOM. Requires PowerShell 5.1+ or pwsh 7+.
#
# Usage:
#   collect_decisions.ps1 [-ProjectDir <path>] [-Checkpoint <path>] [-NotesDir <path>]
#       [-Transcript <session .jsonl> | -SessionId <id>] [-ProjectsDir <dir>] [-Out <file>]
#
#   -ProjectDir  the project folder (default: the current directory). Its leaf name is the slug.
#   -Checkpoint  default <ProjectDir>/CHECKPOINT.md
#   -NotesDir    optional folder of markdown task notes with YAML frontmatter (any notes app or
#                tracker that writes .md files). Default: $env:DECISIONS_NOTES_DIR; unset = skipped.
#   -Transcript  THIS session's transcript (.jsonl). Without it, <ProjectsDir>/*/<SessionId>.jsonl,
#                where SessionId defaults to $env:CLAUDE_CODE_SESSION_ID and ProjectsDir to
#                ~/.claude/projects. Never "the newest file": concurrent sessions share a folder.
#                No transcript found = a warning and an empty offered[].
#   -Out         also write the JSON to this file (UTF-8, no BOM); validate_board.py reads it as
#                <board name>.collected.json beside the board file.
#
# Output shape:
#   { project, generated_utc, candidates: [...], offered: [...], sources_scanned: {checkpoint, notes}, warnings: [...] }
#
# offered: choices this session already put to the user, so step 1b carries them onto the board
# instead of re-judging them. One entry {at, kind, text} per main-thread assistant row that holds
# an AskUserQuestion call (kind "question": each question plus its option labels) or text with two
# or more option lines ("Option A", "(a)", "a)") (kind "text": the first 800 characters).
# Sidechain (sub-agent) rows are skipped.
#
# Candidate kinds:
#   thread -- top-level bullets under the CHECKPOINT's "## Open threads" section; owner is "owner"
#             when the bullet carries an [owner] tag, else "agent".
#   note   -- *.md files in NotesDir whose frontmatter `project:` matches the slug and whose
#             `done:` is not true. answered: true + answered_line when the `reply` field already
#             holds a dated decision entry (see Get-AnsweredEntry).
#
# Exit 0 on success (including "nothing found"); exit 1 on a bad parameter. Never throws.

param(
    [string]$ProjectDir,
    [string]$Checkpoint,
    [string]$NotesDir,
    [string]$Transcript,
    [string]$SessionId,
    [string]$ProjectsDir,
    [string]$Out
)

$ErrorActionPreference = 'Stop'

function Write-JsonAndExit {
    param([string]$Json, [int]$Code)
    try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch {}
    Write-Output $Json
    exit $Code
}

if ([string]::IsNullOrWhiteSpace($ProjectDir)) { $ProjectDir = (Get-Location).Path }
if (-not (Test-Path -LiteralPath $ProjectDir -PathType Container)) {
    [Console]::Error.WriteLine("ERROR: -ProjectDir not found: $ProjectDir")
    exit 1
}
$ProjectDir = (Resolve-Path -LiteralPath $ProjectDir).Path -replace '\\', '/'
$slug = Split-Path -Leaf $ProjectDir

if ([string]::IsNullOrWhiteSpace($Checkpoint)) { $Checkpoint = "$ProjectDir/CHECKPOINT.md" }
if ([string]::IsNullOrWhiteSpace($NotesDir)) { $NotesDir = $env:DECISIONS_NOTES_DIR }

$warnings = New-Object System.Collections.Generic.List[string]
$candidates = New-Object System.Collections.Generic.List[object]

# --- helpers -----------------------------------------------------------------

function Strip-Tags {
    param([string]$Text)
    $t = $Text -replace '^\s*-\s*', ''
    $t = [regex]::Replace($t, '\[[^\[\]]*\]', '')
    $t = [regex]::Replace($t, '\s{2,}', ' ')
    return $t.Trim()
}

function Get-BracketTags {
    param([string]$Text)
    $tags = New-Object System.Collections.Generic.List[string]
    foreach ($m in [regex]::Matches($Text, '\[([^\[\]]+)\]')) {
        $tags.Add($m.Groups[1].Value.Trim())
    }
    return $tags.ToArray()
}

function Unquote-Value {
    param([string]$Value)
    $v = $Value.Trim()
    if ($v.Length -ge 2 -and $v.StartsWith('"') -and $v.EndsWith('"')) {
        return $v.Substring(1, $v.Length - 2)
    }
    if ($v.Length -ge 2 -and $v.StartsWith("'") -and $v.EndsWith("'")) {
        return $v.Substring(1, $v.Length - 2)
    }
    return $v
}

# Line-by-line frontmatter parser -- never a YAML library. Handles:
#   key: value            (scalar, quoted or bare)
#   key:                   (followed by an indented block list)
#     - "item"
#     - item
function Parse-Frontmatter {
    param([string[]]$Lines)

    $fm = [ordered]@{}
    $bodyStartIdx = 0

    if ($Lines.Length -eq 0 -or $Lines[0].Trim() -ne '---') {
        return @{ fm = $fm; bodyStartIdx = 0 }
    }

    $i = 1
    $currentKey = $null
    $closed = $false
    while ($i -lt $Lines.Length) {
        $ln = $Lines[$i]
        if ($ln.Trim() -eq '---') {
            $bodyStartIdx = $i + 1
            $closed = $true
            break
        }
        if ($ln -match '^([A-Za-z_][A-Za-z0-9_]*):\s?(.*)$') {
            $key = $Matches[1]
            $val = $Matches[2]
            if ([string]::IsNullOrWhiteSpace($val)) {
                $fm[$key] = $null
                $currentKey = $key
            } else {
                $fm[$key] = Unquote-Value $val
                $currentKey = $null
            }
        } elseif ($ln -match '^\s{2,}-\s?(.*)$' -and $null -ne $currentKey) {
            $item = Unquote-Value $Matches[1]
            if ($null -eq $fm[$currentKey] -or -not ($fm[$currentKey] -is [System.Collections.Generic.List[string]])) {
                $fm[$currentKey] = New-Object System.Collections.Generic.List[string]
            }
            $fm[$currentKey].Add($item)
        }
        $i++
    }
    if (-not $closed) { $bodyStartIdx = $Lines.Length }

    $keys = @($fm.Keys)
    foreach ($k in $keys) {
        if ($fm[$k] -is [System.Collections.Generic.List[string]]) {
            $fm[$k] = $fm[$k].ToArray()
        }
    }
    return @{ fm = $fm; bodyStartIdx = $bodyStartIdx }
}

function FM-Get {
    param($Fm, [string]$Key)
    if ($Fm.Contains($Key)) { return $Fm[$Key] }
    return $null
}

# A note's `reply` is dated entries, newest first, joined with " | ". An entry that opens
# "<YYYY-MM-DD>[ (qualifier)] -- " followed by "decision", "owner decision" or "you picked"
# records an answer the owner already gave. Returns the newest such entry, or $null.
# A note-only record ("your note on ...") is a question, not an answer, and does not match.
function Get-AnsweredEntry {
    param([string]$Reply)
    if ([string]::IsNullOrWhiteSpace($Reply)) { return $null }
    $pattern = '^\s*\d{4}-\d{2}-\d{2}(\s*\([^)]*\))?\s*(--|—|–)\s*(owner decision\b|decision\b|you picked\b)'
    # Entries are newest first: a removed pick met before any answer means the question is open again.
    $removed = '^\s*\d{4}-\d{2}-\d{2}(\s*\([^)]*\))?\s*(--|—|–)\s*you removed your pick\b'
    foreach ($entry in ($Reply -split '\s\|\s')) {
        if ([regex]::IsMatch($entry, $removed, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) { return $null }
        if ([regex]::IsMatch($entry, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
            return $entry.Trim()
        }
    }
    return $null
}

# --- (a) Open threads from CHECKPOINT -----------------------------------------

$checkpointResolved = $null
if (Test-Path -LiteralPath $Checkpoint -PathType Leaf) {
    $checkpointResolved = (Resolve-Path -LiteralPath $Checkpoint).Path -replace '\\', '/'
    $lines = @(Get-Content -LiteralPath $Checkpoint -Encoding UTF8)

    $inThreads = $false
    $itemLines = New-Object System.Collections.Generic.List[string]
    $itemStartLine = 0
    $threadCount = 0

    function Flush-ThreadItem {
        param([System.Collections.Generic.List[string]]$Buf, [int]$StartLine)
        if ($Buf.Count -eq 0) { return }
        $script:threadCount++
        $headLine = $Buf[0]
        $fullText = ($Buf -join ' ').Trim()
        $title = Strip-Tags $headLine
        if ($title.Length -gt 90) { $title = $title.Substring(0, 90) }
        $tags = Get-BracketTags $fullText
        $owner = 'agent'
        foreach ($t in $tags) { if ($t -ieq 'owner') { $owner = 'owner'; break } }
        $cand = [ordered]@{
            kind  = 'thread'
            id    = "thread-$script:threadCount"
            title = $title
            text  = $fullText
            tags  = @($tags)
            owner = $owner
            file  = $script:checkpointResolved
            line  = $StartLine
        }
        $script:candidates.Add($cand)
    }

    $lineNo = 0
    foreach ($ln in $lines) {
        $lineNo++
        if ($ln -match '^##\s') {
            if ($itemLines.Count -gt 0) { Flush-ThreadItem $itemLines $itemStartLine; $itemLines = New-Object System.Collections.Generic.List[string] }
            $inThreads = ($ln -match '^##\s+Open threads')
            continue
        }
        if (-not $inThreads) { continue }
        if ($ln -match '^-\s') {
            if ($itemLines.Count -gt 0) { Flush-ThreadItem $itemLines $itemStartLine; $itemLines = New-Object System.Collections.Generic.List[string] }
            $itemLines.Add($ln)
            $itemStartLine = $lineNo
            continue
        }
        if ($itemLines.Count -eq 0) { continue }
        if ($ln.Trim().Length -eq 0) {
            Flush-ThreadItem $itemLines $itemStartLine
            $itemLines = New-Object System.Collections.Generic.List[string]
            continue
        }
        $itemLines.Add($ln)
    }
    if ($itemLines.Count -gt 0) { Flush-ThreadItem $itemLines $itemStartLine }
} else {
    $warnings.Add("CHECKPOINT not found at $Checkpoint -- thread candidates empty")
}

# --- (b) optional task notes ----------------------------------------------------

$notesScanned = 0
if (-not [string]::IsNullOrWhiteSpace($NotesDir)) {
    if (Test-Path -LiteralPath $NotesDir -PathType Container) {
        $noteFiles = @(Get-ChildItem -LiteralPath $NotesDir -Filter '*.md' -File -ErrorAction SilentlyContinue)
        $notesScanned = $noteFiles.Count
        foreach ($f in $noteFiles) {
            try {
                $noteLines = @(Get-Content -LiteralPath $f.FullName -Encoding UTF8)
            } catch {
                $warnings.Add("could not read note: $($f.FullName)")
                continue
            }
            $parsed = Parse-Frontmatter $noteLines
            $fm = $parsed.fm
            if ($fm.Count -eq 0) { continue }

            $fmProject = FM-Get $fm 'project'
            if ($null -eq $fmProject -or -not ([string]$fmProject -ieq $slug)) { continue }

            $doneRaw = FM-Get $fm 'done'
            if ($null -ne $doneRaw -and [string]$doneRaw -eq 'true') { continue }

            $bodyStart = $parsed.bodyStartIdx
            $bodyText = ''
            if ($bodyStart -lt $noteLines.Length) {
                $bodyText = ($noteLines[$bodyStart..($noteLines.Length - 1)] -join "`n").Trim()
            }
            if ($bodyText.Length -gt 1200) { $bodyText = $bodyText.Substring(0, 1200) }

            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
            $title = [string](FM-Get $fm 'summary')
            if ([string]::IsNullOrWhiteSpace($title)) { $title = [string](FM-Get $fm 'title') }
            if ([string]::IsNullOrWhiteSpace($title)) { $title = $baseName }
            $replyVal = [string](FM-Get $fm 'reply')
            $answeredEntry = Get-AnsweredEntry $replyVal

            $cand = [ordered]@{
                kind          = 'note'
                id            = "note-$baseName"
                title         = $title
                text          = $bodyText
                status        = [string](FM-Get $fm 'status')
                reply         = $replyVal
                source        = [string](FM-Get $fm 'source')
                file          = ($f.FullName -replace '\\', '/')
                answered      = ($null -ne $answeredEntry)
                answered_line = $answeredEntry
            }
            $candidates.Add($cand)
        }
    } else {
        $warnings.Add("NotesDir not found at $NotesDir -- note candidates empty")
    }
}

# --- (c) options this session already offered the user --------------------------

$offered = New-Object System.Collections.Generic.List[object]
if ([string]::IsNullOrWhiteSpace($Transcript)) {
    if ([string]::IsNullOrWhiteSpace($SessionId)) { $SessionId = $env:CLAUDE_CODE_SESSION_ID }
    if (-not [string]::IsNullOrWhiteSpace($SessionId)) {
        if ([string]::IsNullOrWhiteSpace($ProjectsDir)) { $ProjectsDir = Join-Path (Join-Path $HOME '.claude') 'projects' }
        $hit = @(Get-ChildItem -LiteralPath $ProjectsDir -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName "$($SessionId.Trim()).jsonl" } |
            Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1)
        if ($hit.Count -gt 0) { $Transcript = $hit[0] }
        else { $warnings.Add("no transcript named $SessionId.jsonl under $ProjectsDir -- offered empty") }
    } else {
        $warnings.Add("no -Transcript or session id -- offered empty")
    }
}
if (-not [string]::IsNullOrWhiteSpace($Transcript)) {
    if (Test-Path -LiteralPath $Transcript -PathType Leaf) {
        $optLine = '(?im)^\s*(\*\*)?(option\s+[A-H1-8]\b|\(?[a-h]\)\s)'
        foreach ($raw in [System.IO.File]::ReadAllLines($Transcript, (New-Object System.Text.UTF8Encoding($false)))) {
            if ($raw.IndexOf('"assistant"') -lt 0) { continue }
            try { $row = $raw | ConvertFrom-Json } catch { continue }
            if ($row.type -ne 'assistant' -or $row.isSidechain) { continue }
            # Read the timestamp from the raw line: pwsh 7's ConvertFrom-Json turns it into a
            # local DateTime, which would no longer match the validator's 'at' comparison.
            $tsm = [regex]::Match($raw, '"timestamp"\s*:\s*"([^"]+)"', [System.Text.RegularExpressions.RegexOptions]::RightToLeft)
            $ts = if ($tsm.Success) { $tsm.Groups[1].Value } else { [string]$row.timestamp }
            foreach ($c in @($row.message.content)) {
                if ($c.type -eq 'tool_use' -and $c.name -eq 'AskUserQuestion') {
                    $parts = @()
                    foreach ($q in @($c.input.questions)) {
                        $labels = @($q.options | ForEach-Object { $_.label }) -join ' / '
                        $parts += "$($q.question) [$labels]"
                    }
                    $offered.Add([ordered]@{ at = $ts; kind = 'question'; text = ($parts -join ' | ') })
                } elseif ($c.type -eq 'text' -and $c.text) {
                    if ([regex]::Matches([string]$c.text, $optLine).Count -ge 2) {
                        $t = [string]$c.text
                        if ($t.Length -gt 800) { $t = $t.Substring(0, 800) }
                        $offered.Add([ordered]@{ at = $ts; kind = 'text'; text = $t })
                    }
                }
            }
        }
    } else {
        $warnings.Add("transcript not found at $Transcript -- offered empty")
    }
}

# --- assemble output -----------------------------------------------------------

$result = [ordered]@{
    project         = $slug
    generated_utc   = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    candidates      = @($candidates.ToArray())
    offered         = @($offered.ToArray())
    sources_scanned = [ordered]@{
        checkpoint = $checkpointResolved
        notes      = $notesScanned
    }
    warnings = @($warnings.ToArray())
}

$json = $result | ConvertTo-Json -Depth 10
if (-not [string]::IsNullOrWhiteSpace($Out)) {
    try { [System.IO.File]::WriteAllText($Out, $json, (New-Object System.Text.UTF8Encoding($false))) }
    catch { [Console]::Error.WriteLine("WARNING: could not write -Out file ${Out}: $($_.Exception.Message)") }
}
Write-JsonAndExit -Json $json -Code 0
