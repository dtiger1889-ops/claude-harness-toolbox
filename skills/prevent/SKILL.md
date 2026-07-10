---
name: prevent
description: You just did something documented knowledge says not to do -- a rule, prior
  decision, or known gotcha existed in a file, but it wasn't in your read path, so you
  repeated the mistake. Use when the user types /prevent or says "we've talked about this"
  / "you should know this" / "this is documented" / "why do you keep doing this" about
  your previous action. Fix the immediate mistake, find the documented knowledge that
  should have stopped you, diagnose why it wasn't read, then MOVE or copy that knowledge
  to where the failing workflow will actually read it next time (colocated CLAUDE.md,
  hook/deny rule). The harness change is the deliverable, not the apology. Not /dumb
  (fix only, no harness change) and not /prove (verify claims, not prevent repeats).
---

# prevent -- the mistake was preventable; make it impossible to repeat

The premise is FIXED: you did something the user and a past session already established you
shouldn't do, OR something a documented rule forbids. The knowledge exists somewhere; you
didn't hit it. This is a HARNESS BUG, not a one-off slip -- "I'll remember next time" is
the failure mode this skill exists to kill. The deliverable is a durable change to the
files future sessions read, so the same mistake becomes structurally hard to make.

## Step 1 -- fix the immediate mistake
Same discipline as /dumb: name the wrong action in one line, no defending, then actually
correct it now (undo the bad instruction, redo the operation the right way, retract the
wrong advice). Don't let the harness work below stall the fix.

## Step 2 -- find the knowledge that should have stopped you
Search for where this was already established. Grep across the workspace (if your workspace
`.gitignore` hides project files from the ripgrep-backed Grep tool, use plain `grep -rin`),
check the relevant project's CHECKPOINT.md and CLAUDE.md, archived specs, and past session
transcripts if needed. Quote the documented fact verbatim with its file path. If it
genuinely was never written down, say so -- Step 4 then writes it for the first time
instead of moving it.

## Step 3 -- diagnose WHY it wasn't read (pick one, say it plainly)
- **Wrong location** -- the fact lives in a file this workflow never opens (e.g. a
  deployment rule sitting in one project's CHECKPOINT, while the editing session only
  ever opens the deployed artifact's folder). Most common.
- **Buried** -- the file WAS read, but the fact was one line in a wall of other state.
- **Wrong layer** -- a stable rule stored as mutable state (CHECKPOINT) instead of in
  CLAUDE.md, or a mechanical rule stored as prose instead of a hook/deny entry.
- **Not surfaced at decision time** -- the rule is fine but the action happened on a
  pre-oriented prompt / subagent / automated path that skips the file.
- **Never documented** -- first occurrence was talked about but never landed in a file.
The diagnosis determines the fix; don't skip it and just paste the fact somewhere.

## Step 4 -- move the knowledge into the path of the work
Place (or duplicate-with-pointer) the fact where the FAILING workflow cannot miss it.
Choose the strongest applicable rung:

1. **Mechanical enforcement** -- if the mistake is a command pattern, a hook or
   settings.json deny rule beats any prose.
2. **Colocated doc** -- a `CLAUDE.md` (or top-of-file comment / README line) sitting IN
   the directory where the work happens, stating the rule in its first lines. Example:
   a deployed-artifact folder whose colocated CLAUDE.md opens with "edit the deployed
   copy and toggle the extension -- NEVER reinstall the installer package."
3. **Project CLAUDE.md** (stable rule) or **CHECKPOINT.md open thread / Key decision**
   (mutable state) of the project the workflow starts from -- respecting the 30-line and
   120-line caps.

If your setup treats the harness files as the ONLY durable memory (this harness does --
see harness_me.txt on auto-memory), a fix that lands only in an auto-memory file is a
FAILED /prevent: put it in the files future sessions actually read. If you do use
auto-memory as your durable store, it counts as a rung -- but pick one store and commit.

If the fact already lives somewhere legitimate, don't delete it -- leave the detailed
version where it is and put the short load-bearing line + pointer in the new location.
Follow the harness conventions while doing this: move files with mv/Move-Item (not
Write+delete), version-stamp bumps + changelog entries when a CLAUDE.md changes, line caps.

## Step 5 -- report, short
Three lines: (1) what you did wrong and the fix applied, (2) where the knowledge was
hiding and why it missed you, (3) where it now lives and why that location is in the
read path of the next session that attempts this action. No promises about future
behavior -- the file IS the promise.

## Rules
- A spoken "noted, won't do it again" without a file edit is a FAILED invocation of this
  skill. Something durable must change on disk every time /prevent fires.
- Don't over-correct into bloat: one tight rule line in the right place beats a paragraph
  in three places. Respect the CLAUDE.md 30-line cap; spill detail into a pointed-to file.
- If the right placement is genuinely ambiguous (two plausible homes), pick the one
  closest to where the bad action physically happens and note the alternative in one line
  -- don't ask unless both placements would require restructuring.
- If the same rule has now been violated twice from DIFFERENT entry points, that's the
  signal to escalate a rung (prose -> colocated doc -> hook/deny).
