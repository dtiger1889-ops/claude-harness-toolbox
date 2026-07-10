---
name: breakdown
description: Convergent, action-first problem decomposition (the terse twin of /fanout). Use ONLY when the user types /breakdown or says "break this down" / "break it down" / "decompose this". Takes ONE tangled or ambiguous problem and returns the single smallest next ACTION plus a collapsed full plan. Terse, no hand-holding, no capability narration. Do NOT use for open-ended ideation with many valid answers (that is /fanout), and do NOT use when the task is already one clear action.
---

# breakdown -- convergent, action-first decomposition

The convergent complement to /fanout. /fanout opens a problem up (many valid answers);
/breakdown closes one down (one tangle -> one next step). Single-shot, no sub-agents,
~1x cost. Grounded in the maintainer's session-transcript crawl: the loudest friction was
"stop explaining, just do it," so this skill is ACTION-FIRST and minimal-prose by design.
If your output reads like a gentle walk-through, it is wrong -- cut it.

## Step 1 -- get the tangle
Accept the problem from an @-mention, a path, or pasted text. If it is genuinely vague,
ask for one or two sentences -- once. Read any referenced file to EOF before decomposing.
If the tangle is (or names) a project artifact, ALSO read that project's `CHECKPOINT.md`
to EOF first (receipt/preview is not a read) -- the "real goal" and the "blocking decision"
depend on live project state (deadlines, sequencing gates, what's already decided), and a
decomposition blind to it points at the wrong next action. Skip only if genuinely project-free.

## Step 2 -- output exactly these five blocks, tersely, in order
No preamble. No "I have access to...". Do not restate the question back at length.

1. **Real goal** (one sentence). What "done" actually means. If the stated goal differs
   from the real one, say so in one line.
2. **Smallest next action** (one concrete, physical step doable in one sitting -- e.g.
   "open X and write the three field names," not "design the schema"). Then OFFER to just
   do it now. Do not explain at length first.
3. **The one blocking decision** -- the single fork that unlocks the most, or
   "none -- just start."
4. **Full plan (collapsed)** -- the complete checklist under a one-line summary, explicitly
   de-emphasized: "ignore until step 2 is done."
5. **First trap** -- the single most likely failure mode and its earliest signal.

## Rules
- One thread on the critical path. Do not list parallel workstreams.
- Plain language, no invented codes (translate any filing tags to people-words).
- Do NOT start the work until the user picks. /breakdown plans; it does not execute.
- Persist nothing by default. If worth keeping, offer to write it into the project's
  CHECKPOINT "Next step" line.
