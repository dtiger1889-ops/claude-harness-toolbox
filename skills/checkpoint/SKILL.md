---
name: checkpoint
description: Rewrite the current project's CHECKPOINT.md in place to the harness
  schema. Use when the user types /checkpoint or says "checkpoint" / "save progress" /
  "update checkpoint", and at the end of a logically complete task or when context is
  about to compact. Overwrites in place -- never creates a new or timestamped file (this
  is NOT a /handoff). Enforces the section shape, the 120-line / ~30KB caps (archive
  oldest changelog on overflow), and the Last-updated bump. If a project/workspace
  CLAUDE.md states a CHECKPOINT rule that differs from these steps, CLAUDE.md wins.
  NEVER ask the user whether to checkpoint -- when in doubt, just do it. It is never a
  bad time to checkpoint; offering instead of doing wastes a turn. A logically complete
  unit of work always earns a changelog entry in a project that keeps one, even when it
  changed no live state or produced only research or reference output -- "it was a
  one-off" is never a reason to skip.
---
The CHECKPOINT is STATE, not a spec, and it is overwritten in place. Make it reflect
reality so a cold session can resume from it alone.

1. LOCATE + READ. Find the current project's CHECKPOINT.md (nearest one up the tree from
   cwd) and read it to EOF. If the Read shows a truncation / partial-view notice, re-Read
   with offset+limit until complete. Note the existing section structure -- you PRESERVE
   it, you do not stamp a template over it. (A workspace-root CHECKPOINT may be a
   changelog-style file with its own shape; don't force it into the project schema.)
2. VERIFY AGAINST REALITY. Re-confirm what the file claims is still true -- check the
   files/paths/threads it references before restating them. Correct anything stale; do not
   carry forward a claim you didn't re-check. Treat entries older than 30 days as
   suspect-until-verified, and never resurface a stale decision as a live problem. While
   rewriting, convert relative time references ("tonight's run", "next Thursday", "this
   week") to absolute dates -- a cold session weeks later cannot resolve them.
3. REWRITE IN PLACE. Never append, never a new or timestamped file. Canonical sections
   (preserve any the file already uses; don't invent ad-hoc ones): `Last updated:` line ->
   Status (1) -> Goal (1-3) -> Research (only during an active milestone research phase) ->
   Key decisions (with a **Failed approaches:** sub-bullet group where relevant) ->
   Open threads -> Files that matter (path + 1-line why) -> Harness changelog (only if the
   project versions its CLAUDE.md) -> Next step (1).
   **Section roles -- each answers ONE question; the drift to fight is them leaking into
   each other (separate by TENSE and by STABILITY):**
   - `Last updated:` = a TIMESTAMP (present-tense stamp), NOT a change summary -- see step 5.
   - `Status` (1 line) = the PRESENT state only. Strip anything past ("just shipped X" -> it is
     already a changelog entry) and anything future ("X pending / next" -> move to Next step or
     Open threads). For live-data projects (bot/dashboard) point Status at the live source, never
     quote numbers that go stale.
   - `Key decisions` = LIVE, still-contestable choices only. If a bullet has hardened into a
     standing rule, it belongs in the project's CLAUDE.md or a `decisions/` doc -- move it out,
     don't duplicate it here. If a decision is closed/done, its record is its changelog entry --
     prune it; never keep a `## Closed this session` graveyard. Litmus: still contestable AND only here?
   - `Next step` (1 line) = the single literal next action. This section, not Status, owns "what's next."
   - When you MOVE content out of a section during a rewrite (hardened rule -> CLAUDE.md; closed
     decision / old changelog -> archive), relocate it for real -- never silently drop it. Changelog
     overflow uses the archiver in step 6(a); a closed-decision block with no other home gets a
     one-line changelog record (or an archive move) BEFORE it leaves the file.
   **A completed unit of work always earns a changelog entry** (in a project that keeps a
   changelog): record what was DONE even when no live section (Status / Open threads / Next
   step) changed and the only output was research or reference material. The changelog answers
   "what happened here", not "what is still live" -- so "it was a one-off, nothing to log" is
   never a valid skip, and judging an entry "not worth it" is the exact rationalization to avoid.
   **This session's changelog goes in ONE place:** if the project keeps a `## Harness
   changelog`, add this session's summary as a NEW dated `### YYYY-MM-DD -- summary (vN)`
   block at the TOP of that section (newest-first; the section sits at the END of the file).
   NEVER put the session narrative in the `Last updated:` line, the Status line, or the top
   of the file -- that is the exact mistake to avoid.
   **Open threads holds only OPEN work.** Remove every item marked done / shipped / resolved /
   closed / complete -- its durable record is its changelog entry and/or its pointer (the spec
   / results / experiments file it links). If a done item's substance is NOT already in the
   changelog or a pointer, fold a one-line record into the changelog FIRST, then drop it. Open
   threads must read like a to-do list (open / blocked / owed / in-progress / queued / deferred
   / watch) -- never a graveyard of completed items.
   **EXISTING changelog entries are immutable history.** Never summarize, shorten, merge, or
   "tidy" ANY already-written entry -- prior-session OR ones YOU added earlier THIS SAME session.
   "It's only this session's entries" is NOT a license to merge/compress them (real incident:
   a session merged 3 detailed same-session entries into one, destroying detail while UNDER the
   caps, by reading "prior sessions" as a loophole). Not even when rewriting the whole file, and
   ESPECIALLY not while under the caps. The ONLY sanctioned operation on old entries is the
   byte-verbatim archive move in step 6(a), and only ON OVERFLOW. You may edit an existing entry
   solely to fix a factual error (e.g. a wrong date), stating so in this session's new entry --
   a date fix is NOT cover for also rewording/merging the entry.
   **Mechanically: do not pass old entries through the model.** "Rewrite in place" means
   restructure the LIVE sections (Status/Goal/threads/files) and PREPEND the new changelog
   entry; the existing changelog body is carried over byte-identical. Prefer surgical Edit
   calls over a full-file Write whenever the changelog section is nontrivial -- full-file
   regeneration is exactly where a model "tidies" history without noticing.
4. DEFER WORK INTO THE FILE. Any unfinished work goes into Open threads (or the project's
   tracker) in THIS rewrite -- never as a spoken "I'll do it next session" promise.
5. BUMP Last-updated WITH REAL UTC. Get the real current time first (PowerShell:
   [System.DateTime]::UtcNow.ToString('yyyy-MM-dd HH:mm UTC'); bash: date -u
   '+%Y-%m-%d %H:%M UTC'). The line is a TIMESTAMP, full stop -- the date (add HH:mm UTC
   when you have it), plus an OPTIONAL bare `(vN)` tag if the project versions its
   CLAUDE.md. NOT a pointer to what changed, NOT a prose summary, NOT a `[v47... v46...]`
   trail -- "what changed" is a changelog entry (step 3), and letting it leak back into
   this line is the #1 conformity drift. No per-response timestamps. The bump doubles as
   the "verified against reality" stamp.
6. ENFORCE THE CAPS before finishing -- 120 lines AND ~30KB. Measure with real primitives
   (PowerShell: lines = `(Get-Content $f).Count`, bytes = `(Get-Item $f).Length` -- run via
   a native PowerShell tool, not powershell.exe inside a bash wrapper, which eats `$`;
   bash: `wc -l -c $f`). Do NOT use PowerShell `Measure-Object -Line` (it counts newline
   terminators, undercounts by the last line, and disagrees with the Read tool + the
   archiver). On overflow, in order:
   (a) move the oldest Harness-changelog entries (keep newest 1-2 inline) to
   <project>/archive/harness_changelog.md by calling
   ~/.claude/skills/checkpoint/archive-changelog.ps1 -- it does the byte-verbatim cut/paste.
   You pick only the cut lines (FromLine/ToLine from the CHECKPOINT you just rewrote) and
   pass -AtTop; the script locates the newest-at-top insertion point itself (right after the
   header, before the first entry). Do NOT Read the archive to find where its header ends --
   that lookup is the script's job now; -AtTop handles every header shape (date-led,
   bullet-format, extra prose). It moves bytes it never loads into context, creates the
   archive with the canonical header if absent, and fails CLOSED on a bad range.
   Call it ONCE, for real -- do NOT run a -DryRun pass first. It fails closed on a bad
   range so there is nothing to pre-validate; a dry-run is just wasted ceremony.
   If the archive groups each moved batch under a date header (bullet-format archives), pass
   -PrependHeader "### YYYY-MM-DD -- ..." so the script places it in the SAME move; date-led
   projects skip it (entries carry their own headers). Then patch only the one-line CHECKPOINT
   pointer + (if the archive was just created) its <project> header line.
   (b) if still over, compress Open threads + tighten the Last-updated line;
   (c) if still over, ASK before overflowing -- never ship an over-cap file silently.
   For a fixed checklist with a stable item set, keep per-item done-state in a JSON sidecar
   <name>.json (booleans), prose in the markdown twin.
7. CONFIRM in one line: what changed + the new line count and byte size.

Archive standard the mover assumes (full rationale: harness_me.txt Section 8c):
per-project `archive/` folder; entry header date-led `### YYYY-MM-DD -- summary (vN)`,
newest at top; fixed archive header + one-line pointer, no running batch-log.
