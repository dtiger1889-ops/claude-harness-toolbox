---
name: grill-me
description: Interviews the user before new work, then records an agreed build brief. Use for /grill-me, "interview me first", or the first build of a new project, milestone, app, skill, automation, document, or design. Skip fixes, edits, explanations, one-shot commands, work with an existing spec, and unattended sessions.
---

# Interview before building

## 1. Read first

Read the project's current state, instructions, relevant references, supplied material, and conversation. Treat answered questions as settled. If the brief is complete, proceed directly to recording it.

Clarify requirements before producing a deliverable that would anchor the user to an unsupported guess.

## 2. Ask only questions that change the result

Use short, numbered rounds. Start with purpose, audience, surface, scope, and success criteria; follow up on uncertainties revealed by the answers. Scale the number of questions to the unresolved choices and consequences, rather than a fixed quota.

Use a structured question tool when available and suitable, within its actual limits. Use free text when options would force an answer; plain numbered questions are the fallback. Avoid mixing delivery methods within a round.

Consider, as relevant:

- Required behavior and explicit non-goals.
- Platform, integrations, data source, format, and volume.
- Budget, deadline, usage limits, and where the work lives.
- Failure handling and how uncertainty reaches the user.
- Taste references and rejection criteria.
- Maintenance, ownership, and delegation preferences.

For unrecognized inputs, clarify whether to produce partial output with flags or stop. If nobody can answer, default to flagged partial output for drafting and triage; stop before uncertain sends, payments, deletions, publication, or overwrites. Record the assumption.

Do not ask what the files already answer. If every plausible answer produces the same build, omit the question.

## 3. Respect the user's direction

If the user says to proceed, use the existing authorization and record consequential assumptions. Ask only for information essential to safe or correct execution. Never re-interview an agreed spec; resolve material new choices only.

For unattended work, use the provided brief and project evidence, list assumptions, and preserve any explicit approval boundaries.

## 4. Record the build brief

Use the project's existing spec or state convention:

```
## Build spec
- Brief: <the user's intent; exact wording where it matters>
- Goal: <concrete completion condition>
- Surface / users: <where it runs and for whom>
- Must have: <required behavior>
- Out of scope: <excluded work>
- Constraints: <platform, location, cost, deadline>
- Failure behavior: <partial output or stop; how flags are delivered>
- Taste references: <if relevant>
- Assumptions: <unresolved interpretations>
- Agreed: <date and source of agreement; or proposed>
```

Show the concrete brief for review when approval is still required. Do not treat silence as agreement, or invalidate authorization the user already gave. Build only within that scope.

An optional grill hook is provided in the toolbox; consult the repository's Hooks documentation before installing it. Its reminder is not a substitute for reviewing the actual brief.

Credit: adapted from [Matt Pocock's grill-me](https://github.com/mattpocock/skills), MIT, and Ruben Hassid's batched-interview adaptation.
