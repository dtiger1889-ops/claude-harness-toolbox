---
name: fanout
description: Explicit-invoke divergent-ideation booster (a 5-frame fanout run natively via the Agent tool). Use ONLY when the user types /fanout or says "run a fanout" / "fanout this" / "give me frames on X". Runs 5 parallel cognitive-frame ideation agents + a critic pass on an OPEN-ENDED problem with many valid answers (design, API surface, naming, strategy, hypothesis generation, "give me a few ways to..."). Do NOT use for CONVERGENT work -- root-cause debugging, "why did X break", verifying a fix, anything with one checkable answer -- single-shot is better and cheaper there. Costs ~7x the tokens of a single-shot answer for a small breadth/trap-coverage gain, so it is gated, never automatic.
---

# Fanout -- selective divergent-ideation pass

Empirical basis: the maintainer's two-phase eval. The fanout gives a small but
consistent edge on divergent design tasks and **nothing** on convergent root-cause
work. It is worth ~7x tokens only when the task is open AND high-stakes. This skill
exists so that lift is available on demand without ever firing on routine work.

## Step 0 -- gate before running (mandatory)

Check the task against the selector. Both must be true:

1. **Open-ended?** Multiple valid answers ("design / name / approach / hypotheses
   for X"). If the task is "why did X break", "did the fix work", "what's the root
   cause", or anything with one checkable answer -> this is CONVERGENT. Tell the user
   single-shot is the better tool here, and ask whether to proceed anyway before
   running. Do not silently run on convergent tasks.
2. **High-stakes enough for ~7x tokens?** A load-bearing rule / API shape / name /
   strategy, not a throwaway. If it looks low-stakes, say so and confirm.

If the gate is ambiguous, state your read and ask. Once it passes, proceed.

## Step 1 -- get the problem

Accept the problem statement from: an @-mentioned file, a file path, or pasted
text in the user's message. If only a vague topic is given, ask for one or two
sentences of problem framing first -- the frames need something concrete.

## Step 1.5 -- ORIENT if the target is a project artifact (mandatory)

A `/fanout <file path>` looks pre-oriented, but it is NOT: the frames reason off
the artifact alone and will confidently contradict the project's live state if you
don't feed it to them. Before Step 2, if the problem is (or names) a file under a
project folder -- a spec, decision doc, CHECKPOINT thread, code file -- **read that
project's `CHECKPOINT.md` to EOF first** (and its `CLAUDE.md` if the hook didn't
surface it). The SessionStart receipt is a byte/line count, NOT the file -- a
preview is not a read. Then extract the load-bearing constraints (deadlines,
funding/sequencing gates, standing decisions, what's already been tried/rejected,
hard numbers) and paste them verbatim into EVERY frame prompt AND the critic's, the
same way the artifact text is. A frame given the artifact but not the project state
is a documented failure (a real fanout on a cost spec surfaced "premature, do it
after break-even" framing that the project's CHECKPOINT directly contradicted).
Skip this step ONLY when the problem is genuinely project-free (a pasted abstract
question, a naming/API-shape exercise with no living state behind it).

## Step 2 -- DIVERGENCE (5 parallel Agent calls, one message)

Fire 5 `general-purpose` agents IN PARALLEL (single message, 5 tool calls). Give
each the same problem and ONE distinct vantage. Each agent's instruction:
"Analyze ONLY from your assigned vantage. Generate 4-6 DISTINCT approaches/ideas;
for each, name the failure modes (traps) it carries and state the mechanism. Be
specific, name mechanisms, do not hedge, do not rank, do not evaluate your own
ideas. Keep it tight (this feeds a critic pass)." Return the output directly (no
file writes unless the user asked to save).

The 5 vantages (verbatim):

1. **ARCHITECTURE / SYSTEMS** -- think in state machines, data flows, and where
   information gets transformed or lost; what the system does at the layer below
   the visible behavior; how it breaks under concurrency, failure, or scale.
2. **ADVERSARIAL / DEVIL'S-ADVOCATE** -- assume every option has a fatal flaw and
   find it; what does each silently assume; what would be true if the obvious
   answer is a decoy.
3. **FIRST-PRINCIPLES** -- strip to the underlying mechanism, rebuild from real
   constraints, distrust convention; what is actually required vs merely customary.
4. **PRACTITIONER / OPERATOR** -- you have run this in production and been paged by
   it at 3am; care about field failures, edge cases, operational toil,
   observability, the gap between the design and the on-call reality.
5. **GENERALIST OUTSIDER** -- no domain context; what makes intuitive sense;
   distrust jargon that hides circular reasoning; the obvious-in-hindsight trap the
   experts inside might miss.

## Step 3 -- CRITIC (1 Agent call)

Once all 5 return, fire ONE `general-purpose` agent with all 5 outputs + the
problem. Instruction: "1) SCORE each approach on novelty/viability/fit (0-10).
2) CLUSTER across frames by underlying strategy; note where 2+ frames converged
(that convergence is signal). 3) TRAP UNION: the deduped union of distinct,
mechanistically-stated traps across all 5 frames, each with its mechanism.
4) DEEPEN TOP 3: sharper version, mechanism, traps to avoid, the riskiest
assumption it rests on + the cheapest way to test that assumption before committing,
and one concrete first step. Output sections: ## Scored, ## Clusters, ## Trap union, ## Top 3 deepened,
## Synthesis (4-6 sentences: strongest direction + the traps that most threaten
it)."

## Step 4 -- present

Show the user the critic's **## Top 3 deepened**, **## Trap union**, and
**## Synthesis** in chat. Summarize the convergence (which directions multiple
frames independently reached). Do NOT dump all 5 raw frame outputs unless asked.

By default persist nothing (leftover scratch files are their own mess). If the
user wants the full record, offer to save the critic output + frames to a path
they name.

## Notes

- Native Agent tool only -- do NOT shell out to a nested `claude -p` for the
  frames (nested CLI launches are unreliable under permission/safety layers;
  the Agent tool is the supported path).
- This is one-shot per invocation (n=1). If the user wants a variance check, they
  can invoke /fanout again -- but the small effect size rarely justifies it.
- Never auto-trigger. Only the explicit surface forms in the description.
