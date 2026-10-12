---
name: necromancy
description: Recovers a Claude Code session that ended before its checkpoint was saved, using a deterministic digest of the local session store. Use for /necromancy, "recover the dead session", "resurrect that session", or a crash before checkpointing. Does not recover other agents' stores, editor autosaves, or git artifacts.
---

# Recover a dead session

Use the bundled `necromancy.ps1` with PowerShell. Resolve `<skill-dir>` to the directory containing this loaded SKILL.md, including plugin installs. The script reads the current user's `~/.claude/projects` store; it needs access to the actual host store, not an unrelated sandbox home.

1. **List** candidates for the requested project, defaulting to the project under discussion:

   ```powershell
   & "<skill-dir>/necromancy.ps1" -Project "<project path>"
   ```

2. **Select** by topic, timeframe, and checkpoint state. The newest transcript may be the current live session; do not select it merely for being newest. Ask if multiple candidates fit.
3. **Digest** the selected session:

   ```powershell
   & "<skill-dir>/necromancy.ps1" -Project "<project path>" -Session "<UUID prefix>"
   ```

4. **Synthesize** from the digest: request, user decisions, completed work, interrupted work, and next action. Verify completion claims against current artifacts; transcript statements alone do not prove writes or releases completed.
5. **Persist** recovered state through checkpoint when the user authorizes resuming or recording it. If the checkpoint already reflects the session, use it rather than repeating recovery.

Do not load a full raw JSONL transcript into model context. The digest caps each category and uses regex anchors; errors and commits are leads. If required detail is omitted, search only the selected transcript for specific anchors. Report uncertainty instead of reconstructing missing events.

Project slugs replace non-alphanumeric path characters with hyphens; the script also checks case variants. A missing store or unsupported runtime is a limitation, not evidence that the session never existed.

Credit: digest pattern adapted from [herderp](https://github.com/ryanthedev/herderp).
