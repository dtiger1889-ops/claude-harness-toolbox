# tmux_receipt.ps1 -- SessionStart hook: prints a short receipt when the session was launched
# from tmux/MSYS2 over SSH (for example from a phone); silent no-op on desktop launches.
#
# Why: a session launched inside tmux/MSYS2 inherits a stripped PATH in both shell tools, so
# installed tools fail by bare name and the session wrongly concludes they are missing.
#
# ADAPT BEFORE USE:
#   1. Detection requires BOTH a tmux/MSYS2 marker AND an SSH marker; a single signal
#      false-positives on desktop sessions. If your remote launch path differs (plain SSH,
#      WSL, a container), change the markers to what that environment really sets; check by
#      printing $env:TMUX, $env:MSYSTEM and $env:SSH_CONNECTION from a real remote session.
#   2. Replace <YOUR-TOOLS-INDEX-DOC> with a file listing full paths for the tools your PATH loses.
#
# Printed text is directive + pointer only, because it re-enters context every session:
# no dates, evidence or history (see docs/maintaining-the-harness.md).
try {
    $hasTmuxMarker = [bool]($env:TMUX -or $env:MSYSTEM)
    $hasSshMarker = [bool]($env:SSH_CONNECTION -or $env:SSH_TTY -or $env:SSH_CLIENT)
    if ($hasTmuxMarker -and $hasSshMarker) {
        Write-Output 'TMUX SESSION: launched through tmux over SSH, not the desktop.'
        Write-Output '- Both shells have a stripped PATH: a bare-name failure does not mean a tool is missing. Use full paths: <YOUR-TOOLS-INDEX-DOC>.'
        Write-Output '- The user is not at this machine: send any file they must open through your client''s file-sending tool, never only a local path.'
        Write-Output '- Before a call that may ask for approval, say so in chat. Installs, settings edits, publishes, credential touches and metered services are raised with the user before the call.'
    }
} catch { }
