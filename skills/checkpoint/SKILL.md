---
name: checkpoint
description: >-
  Rewrite the current project's CHECKPOINT.md in place to the harness schema. Use when
  the user types /checkpoint or says "checkpoint" / "save progress" / "update
  checkpoint", at the end of a logically complete task, or when context is about to
  compact. Overwrites in place, never a new or timestamped file (not a /handoff). Enforces
  the section shape, the 120-line / ~30KB caps (archives the oldest changelog on
  overflow), and the Last-updated bump; a project or workspace CLAUDE.md that states a
  different CHECKPOINT rule wins. NEVER ask the user whether to checkpoint; when in
  doubt, do it, because offering wastes a turn. Every logically complete unit of work
  earns a changelog entry in a project that keeps one, even research-only or "one-off"
  work. A session that kept CHECKPOINT.md current earns the LIGHT CLOSE (step 0), a
  changelog entry plus one finisher call, not a full re-verify.
---
The CHECKPOINT is STATE, not a spec, and it is overwritten in place. Make it reflect
reality so a cold session can resume from it alone.

Scripts in this folder require PowerShell 5.1+ (Windows PowerShell) or `pwsh` 7+ on
macOS/Linux. On a runtime with no PowerShell at all, see the Runtime section at the end.

0. LIGHT CLOSE -- the default when this session kept the file current. If THIS session
   already edited CHECKPOINT.md and its content is in context, do NOT re-read the file or
   re-verify the world you just changed: confirm the live sections (Status / Open threads /
   Next step) match where the session actually ended, prepend this session's changelog
   entry (step 3's changelog rules bind in full), then SWEEP that entry back through the
   live sections -- anything the entry you just wrote records as done/shipped comes OUT of
   Status, Open threads, and Next step in the same pass (a real drift case: Next step kept
   pointing at two items the same file's new entries recorded as done). Then run step 4.5
   (the claim check -- it runs on EVERY close, light ones included) and step 5.
   Run the FULL pass (steps 1-6) only when entering cold (no read or
   edit of the file this session), when `Last updated:` is >30 days old, or when the user
   asks for a full verify.
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
   project versions its CLAUDE.md) -> Next step (one declared shape: Action / HOLD / Pick).
   **Sweep THIS session before you write:** (a) every correction or pushback the user made
   ("shorter", "not that surface", "that was my decision, not yours") is a preference paid
   for once and must never be paid for again -- they hide in throwaway lines, so scan for
   them specifically; a standing one goes to the project CLAUDE.md, a session-scoped one to
   Key decisions. (b) every approach tried and rejected goes under Key decisions'
   **Failed approaches:** WITH the reason, and "fixable if X" when it was rejected for a
   fixable reason -- this is the only thing standing between the next session and
   re-exploring every dead path. (c) a constraint stated once in the session still governs
   everything; recency is not importance. Everything recorded must trace to the session --
   an invented detail in a CHECKPOINT is an invisible landmine, so mark real uncertainty as
   such.
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
   - `Next step` = ONE of three declared shapes (THIS list is canonical; a workspace CLAUDE.md
     should carry only the caps + a pointer here):
     **Action** (one literal next action -- only when a single workstream is live right now),
     **HOLD** (`HOLD -- <what the owner must decide/do>; don't <gated action> until then`), or
     **Pick** (`Pick from Open threads (live ask outranks; then agent-side [low] to a delegated
     worker, [high] inline; owner-gated items are the owner's)` -- the DEFAULT for non-linear
     projects). A stale shape gets FLIPPED (Action gone stale -> Pick), never defended. This
     section, not Status, owns "what's next."
   - **Every top-level Open-threads bullet ends with two tags, gate then complexity**, so a
     cold reader can dispatch the list without re-reading every bullet: `[owner]` when the
     very next action needs the user's hands or a decision they have explicitly been asked
     for (the bullet names the one thing they do), else `[agent]` (any model session). A
     decision an AGENT then executes (build X on their go, adopt a rule, trial Y or not) is
     `[gates: go] [agent]`, never `[owner]`; a passive watch, a "confirm it still works", or
     a standing condition is not a thread at all; then `[low]` when a smaller/cheaper model
     can finish the agent-side share from the bullet alone, else `[high]`. No middle value;
     under doubt the gate is `[agent]`, because a mis-gated `[owner]` item sits where no
     session acts on it. The list runs `[owner] [low]`, `[owner] [high]`, `[agent] [low]`,
     `[agent] [high]`; you do NOT sort it by hand -- the finisher (step 5) sorts tagged
     bullets into that order at every close, so your job is the tags. Bold sub-headers
     (`**Owner-gated**` / `**Agent-side**`) are optional and regenerated by the sort; the
     tags are not optional. `[blocked-by: X]` / `[gates: Y]` may sit before the pair;
     sub-bullets carry no tags.
   - When you MOVE content out of a section during a rewrite (hardened rule -> CLAUDE.md; closed
     decision / old changelog -> archive), relocate it for real -- never silently drop it. Changelog
     overflow uses the archiver in step 6(a); a closed-decision block with no other home gets a
     one-line changelog record (or an archive move) BEFORE it leaves the file.
   **Worked example -- a thread a stranger can act on without opening another file:**
   - Bad: `Wire the second-agent rung into the category-(a) path [agent] [low]`
   - Good: `Route spec-frozen code jobs to the second agent CLI -- add the call in run.ps1 [agent] [low]`
   - Why: the bad one needs a second document to decode, so a cold session skips it.
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
   threads must read like a to-do list (open / blocked / owed / in-progress / queued / deferred)
   -- never a graveyard of completed items.
   **A MODEL-INVENTED verification is NOT an Open thread.** If the only remaining "work" is a
   check the model thought up to confirm something is still true -- spot-confirm, re-test,
   "confirm X still works", "verify Y next run" -- DROP it, do NOT write it as a thread. The
   user comes back and re-asks if it is still a problem; that is the mechanism, not a standing
   nag in the file. This is doubly true when the model cannot even do the check itself (needs
   the user to eyeball, a future scheduled run, a notification receipt) -- writing "ask the
   user to confirm" is the exact clutter that makes Open threads unreadable. **The line is WHO
   asked:** a watch/measurement the USER explicitly set up (e.g. "watch whether the trim breaks
   routing over the next week", with a revert path they defined) IS a real thread and stays --
   never delete their watches to satisfy this rule. A real PROBLEM whose CAUSE is unknown IS an
   open thread -- its next action is "diagnose it". The exclusion is only a check with no
   evidence anything is wrong ("confirm the thing we have no reason to doubt still works").
   Everything else earns its place by naming a concrete NEXT ACTION someone will take -- build
   X, decide Y, register Z, find the cause of Z -- not "keep an eye on it."
   **EXISTING changelog entries are immutable history.** Never summarize, shorten, merge, or
   "tidy" ANY already-written entry -- prior-session OR ones YOU added earlier THIS SAME session.
   "It's only this session's entries" is NOT a license to merge/compress them (real incident: a
   session merged 3 detailed same-session entries into one, destroying detail under-cap, by
   reading "prior sessions" as a loophole). Not even when rewriting the whole file, and
   ESPECIALLY not while under the caps (rewriting under-cap history destroyed detail with no
   archive copy in a second real incident). The ONLY sanctioned operation on old entries is the
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
   **EXCEPTION -- a self-runnable check is NOT deferrable work and NEVER becomes an Open
   thread.** If a validation/verification is something a session CAN run -- a test, a probe,
   reading a log / transcript / API / the live file -- RUN it now and record the verdict in
   the changelog; do NOT park it for "a fresh session." If you genuinely can't resolve it
   this session, CLOSE it out of Open threads anyway and rely on a THOROUGH changelog entry
   (enough context that a cold session could re-run it) -- the user re-raises it if it's
   still broken. Reserve `[owner]` threads for truly owner-gated steps ONLY (auth/OAuth, a
   physical device in hand, a UI-only click); a "verify it works later" test is never one of
   those, and tagging a model-runnable check `[owner]` is the exact failure this kills.
4.5 CHECK THE FILE'S OWN CLAIMS -- BEFORE the finisher. Every path, file and pointer the
   rewrite states must exist: resolve each one and fix the pointer (or the claim around it)
   before going on. Reconcile the file's git claims (unpushed / uncommitted / "pushed") with
   what git actually reports, and re-examine any date older than 30 days and any owner-gated
   thread. Runs on EVERY close INCLUDING light closes -- one real four-defect close PRESENTED
   as a light close. This step exists because the original step 2 had no failure signal and
   was therefore reliably skipped; a close-time script that exits non-zero on a dead pointer,
   the way the cap check does, is the mechanical version and is worth building for your own
   layout. Whatever this step surfaces is addressed to YOU, never pasted to the user
   (step 7's relay rule applies).
5. STAMP + MEASURE IN ONE CALL. Run
   `finish-checkpoint.ps1 -Checkpoint <path>` from this folder
   -- it rewrites the `Last updated:` line with real UTC itself (preserving an existing
   bare `(vN)` tag), sorts tagged Open-threads bullets into the four-run order, and
   reports lines + bytes against both caps in the same output. Do
   NOT run UtcNow, Get-Content, or Get-Item as separate calls, and do NOT write the
   timestamp by hand -- the script replaces all three round-trips and you never
   transcribe a clock. If the project's CLAUDE.md version changed this session, edit the
   `(vN)` tag BEFORE calling (the script preserves whatever tag is there). The line is a
   TIMESTAMP, full stop -- NOT a pointer to what changed, NOT a prose summary, NOT a
   `[v47... v46...]` trail -- "what changed" is a changelog entry (step 3), and letting it
   leak back into this line is the #1 conformity drift. No per-response timestamps. The
   stamp doubles as the "verified against reality" stamp. Run it through a native
   PowerShell tool, never `powershell.exe -Command` inside a bash wrapper (the wrapper
   eats `$`).
   ONE call per file per close, when the file is FINAL -- never restamp after every
   intermediate edit (a real incident: a 28-call restamp treadmill on one file); the only
   sanctioned re-run is after step 6(b) compression. A close that touched MULTIPLE
   projects' CHECKPOINTs runs the finisher once for EACH file touched -- hand-stamping a
   sibling project's file by Edit instead of calling the script is the #1 observed
   violation (one batch close hand-stamped two sibling files date-only, and those two
   were exactly the files that shipped over their caps).
   AFTER THE SCRIPT RUNS, RE-READ BEFORE YOU EDIT. Every run rewrites the file on disk
   (the stamp; the over-cap path rewrites it twice more), which makes the read snapshot
   from your own earlier Edits stale -- the next Edit is then rejected with "File has been
   modified since read". That is not a bug to work around, it is the expected cost of
   letting a script own the timestamp. So: if you have ANY further edit to make to that
   file, `Read` it first. The script prints this reminder in its own output too.
   (Diagnosed from a real pair of closes: 6 rejected Edits, every one of them the first
   Edit after a finisher call.)
6. ENFORCE THE CAPS -- 120 lines AND ~30KB, PLUS the live-section budgets (the changelog is
   the record -- live sections are terse pointers, narrative lives in the changelog).
   Step 5's script printed all of it (exit 2 = over a
   cap OR SECTION BLOAT: Status > 1 line/~300 chars, Goal > 3 lines, Next step > 2
   lines/~350 chars; >700-char Open-threads bullets get a WARN); trust its output, no
   separate measurement pass. On SECTION BLOAT, compress the flagged section -- verify the
   cut content already exists in the changelog / a pointer target (move it there first if
   not), then re-run the finisher. (Manual
   re-measure, only if ever needed: lines = `(Get-Content $f).Count`, bytes =
   `(Get-Item $f).Length` via a native PowerShell tool -- NEVER `Measure-Object -Line`, it
   undercounts by the last line and disagrees with the Read tool + the archiver.)
   On overflow the finisher handles the archive ITSELF: it auto-archives the oldest
   Harness-changelog entries (keeping the newest 2 inline) to
   <project>/archive/harness_changelog.md through archive-changelog.ps1's byte-verbatim
   move, maintains the one-line `Older entries:` pointer, and re-reports the counts -- in
   the normal path you never pick line numbers and never call the mover yourself. If it
   still exits 2 after auto-archiving (or says nothing to auto-archive):
   (b) `Read` the file (the finisher just rewrote it -- see step 5), then compress Open
   threads + tighten the Last-updated line, then re-run the finisher once to restamp +
   confirm the new counts;
   (c) if still over, ASK before overflowing -- never ship an over-cap file silently.
   MANUAL mover (rare: bullet-format archives needing -PrependHeader "### YYYY-MM-DD -- ...",
   or a genuinely hand-picked range): call `archive-changelog.ps1`
   with -FromLine/-ToLine -AtTop, ONCE, for real -- no -DryRun pass (it fails closed on a
   bad range; a dry-run is wasted ceremony) -- then patch the pointer line yourself and
   re-run the finisher.
   For a fixed checklist with a stable item set, keep per-item done-state in a JSON sidecar
   <name>.json (booleans), prose in the markdown twin.
7. CONFIRM in one line: what changed + the new line count and byte size.
   **NOTHING the finisher printed goes into that line.** Its output is addressed to YOU,
   not to the user: the HOVERING/near-cap advisory, "re-Read before your next Edit", the
   auto-archive trace, "compress live sections", exit codes. They take no action on any of
   it -- the caps are this skill's housekeeping, not theirs. Relaying it reads as busywork
   and buries the one fact they asked for. A workspace CLAUDE.md should state this generally
   ("never relay tool/script output addressed to YOU"); it is repeated HERE because the
   violation happens at THIS step -- the last action of a long session, when CLAUDE.md is
   far back in context and this file is not. (Violated for real once: a close ended with the
   finisher's near-cap advisory quoted verbatim plus a five-section report, against a
   one-line cap.)

Archive standard the mover assumes (full rationale: harness_me.txt Section 8c):
per-project `archive/` folder; entry header date-led `### YYYY-MM-DD -- summary (vN)`,
newest at top; fixed archive header + one-line pointer, no running batch-log.

## Runtime -- what changes in a cloud / sandboxed session with no local shell

Steps 0-4 and 7 run unchanged once the file is reachable: read and edit CHECKPOINT.md through
whatever filesystem bridge the runtime gives you. If that bridge publishes an allowlist of
reachable folders, re-check it at the moment of need -- these allowlists commonly mutate
mid-session. Never guess a path; list the project folder first, and request access to the
workspace root if it is not connected. A file that reads truncated is usually the stale
sandbox view, not corruption -- re-read before writing.
**Steps 4.5, 5, and 6's auto-archive cannot run at all** when no PowerShell exists in the
sandbox. Instead: stamp `Last updated:` by hand in real UTC, hold the section shape and both
caps (120 lines / ~30KB) by eye, move any overflow changelog entries byte-verbatim by hand,
and write "finisher not run (no shell)" in this session's changelog entry.
