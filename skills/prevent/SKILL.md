---
name: prevent
description: You just did something documented knowledge says not to do -- the rule
  existed in a file, but it wasn't in your read path. Use when the user types /prevent or
  says "we've talked about this" / "you should know this" / "this is documented" /
  "why do you keep doing this" about your previous action. Fix the mistake, find the
  knowledge, move it into the failing workflow's read path (colocated CLAUDE.md,
  hook/deny rule). The harness change is the deliverable.
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
   the directory where the work happens, stating the rule in its first lines. Example
   from the canonical case: a deployed-extension folder whose colocated CLAUDE.md opens
   with "installed extensions run from the extracted folder -- sync edits there and
   toggle the extension; the installer package is first-install convenience only, NEVER
   tell the user to reinstall it."
3. **Project CLAUDE.md** (stable rule) or **CHECKPOINT.md open thread / Key decision**
   (mutable state) of the project the workflow starts from -- respecting the 30-line and
   120-line caps; if it's cross-project runtime behavior, a catch-all meta-project is the
   right home.

If your setup treats the harness files as the ONLY durable memory (this harness does --
see harness_me.txt on auto-memory), a fix that lands only in an auto-memory file is a
FAILED /prevent: put it in the files future sessions actually read. That includes rules
about how to treat the user rather than an artifact -- those go in CLAUDE.md
(workspace-level for cross-project behavior). If you do use auto-memory as your durable
store, it counts as a rung -- but pick one store and commit.

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

## Scope
Not /dumb (fix only, no harness change) and not /prove (verify claims, not prevent repeats).

## Runtime -- what changes in a cloud / sandboxed session with no local shell

Steps 1, 3, and 5 are reasoning and run unchanged. Step 2's `grep -rin` searches the
container, not the user's machine: search the workspace through whatever filesystem bridge
the runtime gives you. If that bridge publishes an allowlist of reachable folders, re-check
it at the moment of need -- these allowlists commonly mutate mid-session; request access to
the workspace root if it is not connected rather than guessing a path. Step 4 rungs 2 and 3
(a colocated CLAUDE.md, a project CLAUDE.md or CHECKPOINT entry) write fine over a connected
folder.
**Step 4 rung 1 -- the hook / settings.json deny rule -- cannot run at all** when the agent's
own config directory is outside what the bridge can reach. Instead, deliver a written proposal
for a local session: the exact hook or deny-rule text, the file it goes in, and the trigger it
fires on, landed in the owning project's CHECKPOINT Open threads as `[owner] [low]` in the same
turn. A proposal that lands only in chat is a FAILED /prevent, same as a spoken promise.
