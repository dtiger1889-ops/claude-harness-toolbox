---
name: fanout
description: Runs five parallel ideation agents with distinct perspectives, then a critic, for an open-ended problem. Use only for /fanout, "run a fanout", "fanout this", or "give me frames on X". Intended for design, naming, strategy, and hypotheses with multiple valid answers; unsuitable for routine verification or debugging with one checkable answer. Uses substantially more model calls than a single review.
---

# Fanout

## 1. Select and ground the problem

Confirm that the problem has multiple valid answers and that breadth warrants six helper calls. For a clearly convergent or low-value task, explain the mismatch and ask whether to run this method anyway. Do not re-confirm when the user has already accepted that tradeoff.

Accept text or a referenced artifact. Ask once if only an unframed topic is supplied. For project work, read the artifact, current state, and instructions to EOF. Supply the same problem and relevant constraints to every frame and to the critic: settled decisions, deadlines, dependencies, measurements, and rejected approaches.

Use the runtime's native agent tools. If unavailable, report that limitation; do not silently substitute nested CLI calls. Respect the host's concurrency and model-routing limits; run frames in batches if necessary.

## 2. Generate perspectives

Launch five independent agents, each with one perspective:

1. **Architecture:** state, data flow, concurrency, failure, and scale.
2. **Adversarial:** critical assumptions, failure mechanisms, and misleading obvious answers.
3. **First principles:** necessary constraints versus conventions.
4. **Operator:** practical use, edge cases, maintenance, recovery, and observability.
5. **Outsider:** intuitive alternatives and jargon that hides weak reasoning.

Each prompt: "Analyze only from your assigned perspective. Generate distinct approaches and explain each approach's failure mechanisms. Do not rank your own ideas. Be concise and distinguish known constraints from assumptions." Aim for four to six useful ideas per frame; do not pad to reach a count. Return results without file writes unless requested.

## 3. Critique

Give one critic the problem, constraints, and all frame outputs. Ask it to:

- Assess novelty, viability, and fit, with reasons; treat any numeric ratings as judgments, not measurements.
- Cluster equivalent approaches and identify independent convergence.
- Combine distinct failure mechanisms without duplication.
- Develop the strongest three directions: mechanism, traps, riskiest assumption, cheapest test, and first concrete step.
- Recommend a direction and identify the uncertainty that could change it.
- Spread: name each frame's single highest-rated idea in one line, labelled "chance another AI gives this: N%", ordered high to low so the lowest comes last.

## 4. Present and record

Present the critic's spread first (the five one-line ideas with their percentages, lowest last), so an idea only one frame reached is not buried under the converged ones; then the strongest directions, distinct traps, and recommendation. Explain meaningful convergence; do not dump every raw output.

Keep raw frame output ephemeral unless the user requests it. Consider durable conclusions through log: save reusable findings in their existing owner document, or report "nothing to log". Run once per invocation; a second fanout needs a new request.
