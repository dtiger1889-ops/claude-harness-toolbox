@echo off
REM Template for the Windows codex.cmd shim. install_codex_native.ps1 replaces the
REM two placeholders with your Python interpreter and the full path of codex_native.py
REM and writes the result into your shim folder as codex.cmd.
REM Desktop calls run Codex directly; SSH/session-0 headless calls use the desktop bridge.
"@PYTHON@" "@BRIDGE@" %*
exit /b %errorlevel%
