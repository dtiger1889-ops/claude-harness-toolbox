---
name: necromancy
description: Recover a Claude Code session that died before a CHECKPOINT was written
  (crash, outage, closed window, compact loss). Use when the user types /necromancy or
  says "resurrect that session" / "recover the dead session" / "what was I doing in
  the session that crashed" / "the session died before checkpointing". Reads the local
  ~/.claude/projects JSONL session store via a deterministic PowerShell digest script
  (no model cost on the raw transcript), extracts anchors (ask, user decisions, final
  state, files written, commands, commits, errors), and synthesizes a resume summary.
  NOT for gracefully-closed work -- if CHECKPOINT.md reflects the session, just read
  it. Pattern adapted from ryanthedev/herderp's session-necromancy (regex anchors,
  newest-first ranking, everything capped), without the wrapper tooling.
---
Recover state from a dead session's on-disk transcript. The script does the heavy
lifting deterministically; you NEVER Read raw session JSONL into context (files run
to multiple MB -- the digest exists precisely to avoid that).

Script: `~/.claude/skills/necromancy/necromancy.ps1` (run via the PowerShell tool;
Windows-first, like the rest of this toolbox's scripts).

1. LIST. Run with the project folder the user means (default: the folder they're
   asking about, usually cwd):
   `& "$env:USERPROFILE\.claude\skills\necromancy\necromancy.ps1" -Project <path>`
   Output: newest-first sessions with title, first ask, size, and checkpoint state
   ("NO CHECKPOINT WRITE" or "N assistant msgs after last write").

2. PICK the dead session. The newest file is almost always the CURRENT live session
   -- skip it. A dead candidate is: NO CHECKPOINT WRITE, or many assistant messages
   after the last checkpoint write, matching the timeframe/topic the user describes.
   If ambiguous, show them the list lines and ask which one.

3. DIGEST. `... necromancy.ps1 -Project <path> -Session <uuid-prefix>`
   Sections: FIRST ASK, USER MESSAGES (their decisions -- the gold), FINAL ASSISTANT
   STATE, FILES WRITTEN/READ, COMMANDS, GIT/COMMITS, VERSIONS, TESTS, ERRORS.

4. SYNTHESIZE a resume summary FROM THE DIGEST ONLY: what was asked, what got
   decided, what was completed vs in flight when it died, and the literal next
   action. Verify claims about file state against the ACTUAL files (a dead session's
   last words may describe work it never flushed) before asserting anything as done.

5. OFFER TO PERSIST. If the project has a CHECKPOINT.md that predates the dead
   session, the natural close is updating it (the /checkpoint skill) so the
   recovered state has a durable home. Do it when the user confirms resuming.

Gotchas:
- Slug mapping is `[^A-Za-z0-9] -> '-'` on the project path; the script falls back
  case-insensitively (Windows store dirs vary in case; same inode either way).
- Digest caps per category (precision over recall). If a needed detail is missing,
  re-run digest, then at worst grep the single session file for a specific string
  (`grep -o` a narrow pattern) -- still never full-Read it.
- Anchor extraction is regex-only and can misfire; treat ERRORS/COMMITS lines as
  leads, not verified facts.
