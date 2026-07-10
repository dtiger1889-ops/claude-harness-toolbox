---
name: redteam
description: One focused adversarial pass on a claim, plan, or answer (the cheap middle gear between a single-shot answer and the ~7x-token /fanout). Use ONLY when the user types /redteam or says "push back on this" / "red-team this" / "stress-test this". Fires ONE adversarial pass that assumes the target is wrong and hunts the fatal flaw. Do NOT use for 5-way ideation (that is /fanout) or for convergent fact-checking with one obvious answer.
---

# redteam -- single-frame adversarial pass

Grounded in the maintainer's session-transcript crawl: the recurring friction is "the model
commits to one answer inline and the user has to push back." This skill front-runs that
push-back. It is ONE frame (adversarial), not five -- so it costs roughly 1x, far less
than /fanout.

## Step 1 -- get the target
The claim / plan / answer to attack, from an @-mention, a path, or the prior turn. If it is
ambiguous which claim to attack, ask -- once.

## Step 1.5 -- orient if the target is a project artifact (mandatory)
If the target is (or names) a file under a project folder -- a spec, plan, decision doc,
code file -- **read that project's `CHECKPOINT.md` to EOF first** (and its `CLAUDE.md` if
not already surfaced). The SessionStart receipt is a byte/line count, NOT the file; a
preview is not a read. Attacking a plan blind to project state manufactures flaws the
CHECKPOINT already resolved and misses the real constraints (deadlines, funding/sequencing
gates, what's been tried/rejected) that actually sink it. Fold those constraints into the
attack. Skip only when the target is genuinely project-free.

## Step 2 -- attack it. Assume it is wrong. Output:
1. **Strongest case it's wrong** -- the most likely fatal flaw, with the mechanism (not a
   vague "it might not scale" but how it actually breaks).
2. **Silent assumption** -- the load-bearing thing it takes for granted that, if false,
   sinks it.
3. **The decoy** -- if the obvious answer is a trap, name the real one.
4. **Cheapest disproof** -- the quickest concrete check (a command, a file read, a
   measurement) that would settle whether the fatal flaw is real, so the attack ends in
   evidence rather than a debate.
5. **Verdict** -- survives / needs revision / abandon, plus the single most important fix.

## Rules
- Do not hedge. Do not soften to be agreeable -- not-agreeing is the entire point.
- If after a genuine attempt the target actually holds, say so plainly and say why; do not
  manufacture a flaw to look useful.
- One pass (n=1). For 5-frame breadth, that is /fanout.
