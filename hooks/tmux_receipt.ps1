# tmux_receipt.ps1 -- SessionStart hook: session-environment receipt.
#
# PROBLEM: a session launched from somewhere other than your desktop (SSH from a phone,
# inside tmux, any login shell with its own PATH) inherits that environment's quirks and
# cannot tell it did. The canonical failure on Windows: Claude Code launched inside
# tmux/MSYS2 inherits MSYS2's stripped PATH in BOTH the Bash and PowerShell tools, so
# node, git, gh, python etc. fail by bare name while being fully installed -- and every
# session re-derives the wrong conclusion ("not installed") from scratch.
#
# FIX: detect the environment and TELL the session, once, at start. Silent no-op on
# desktop launches. Pair with a root fix where possible (for MSYS2 the lever is
# MSYS2_PATH_TYPE=inherit in whatever launches the login shell -- it makes /etc/profile
# append the full Windows PATH instead of discarding it).
#
# ADAPT BEFORE USE:
#   1. The detection below is for tmux under MSYS2 on Windows. If your remote launch
#      path differs (plain SSH, WSL, a container), change the markers to whatever your
#      environment actually sets. Verify from a REAL remote session: print $env:TMUX,
#      $env:MSYSTEM, $env:SSH_CONNECTION, $env:Path and see what distinguishes it.
#   2. Point the FIX line at YOUR tools-index doc (a file listing full invocation paths
#      for the tools your PATH loses). Keep one; it turns every future "command not
#      found" from a re-diagnosis into a lookup.
try {
    $isRemote = $false
    if ($env:TMUX) { $isRemote = $true }
    if ($env:MSYSTEM) { $isRemote = $true }
    # PATH signature: MSYS dirs present while a dir you KNOW is on the desktop PATH is
    # missing. Swap 'nodejs' for any marker dir that fits your machine.
    if (($env:Path -like '*msys64*') -and ($env:Path -notlike '*nodejs*')) { $isRemote = $true }
    if ($isRemote) {
        Write-Output '=== REMOTE/TMUX SESSION RECEIPT ==='
        Write-Output 'This session was launched from tmux/MSYS2 (or SSH), NOT from the desktop.'
        Write-Output 'CONSEQUENCE: both shell tools inherit a stripped PATH. Tools like node, git, gh, python may FAIL by bare name while being fully installed. "Not on PATH" does NOT mean "not installed" -- never conclude a tool is missing from a bare-name failure.'
        Write-Output 'FIX: use full invocation paths, or prepend the real dirs to PATH per command. Full paths live in <YOUR-TOOLS-INDEX-DOC> -- Read it before working around any "missing" tool.'
        Write-Output 'Everything else (files, hooks, permissions, MCP) behaves identically to a desktop session.'
        Write-Output '=== end RECEIPT ==='
    }
} catch { }
