---
name: spec
description: Writes or reviews a change or decision spec with explicit tradeoffs and closeout criteria. Use for /spec, "spec this", "write a spec", review of a spec's open questions, or closing, archiving, and promoting a finished spec. Does not authorize implementation by itself.
---

# Spec

Read the project's current state, instructions, existing spec, and relevant artifacts. Follow its naming and storage conventions. Otherwise use the existing outbound/ or specs/ folder, or create specs/. Write one topic per file and link it from the project's state or tracker.

## Write or review

Choose depth by the work:

- **Change spec:** concise problem, intended behavior, scope, implementation plan, and acceptance checks.
- **Decision spec:** enough evidence to assess the recommendation without repeating the investigation: methods, measurements, rejected approaches, uncertainty, costs, and sources.

For later execution, put the plan near the top. Name exact files, relevant anchors or patterns, configuration defaults, disable/revert path, tests, and acceptance checks. Prefer stable symbols or headings to unexplained line numbers.

Attribute choices accurately: user decisions, measurements, and model recommendations are different. Preserve exact user wording only when it defines a requirement or decision; do not quote every exchange. State risks, affected surfaces, and non-goals. Use an actual date and avoid invented shorthand.

For each unresolved choice the user must make, include:

- The question and necessary context.
- Two or three real options, each with gains, losses, implementation cost, and maintenance cost.
- A recommendation, the one piece of evidence it rests on (file and line, command output, URL, or the user's own words with their date) or "no evidence beyond judgment", and the condition that would change it. A recommendation with a confident reason and no source reads as a finding when it is a guess.

Do not invent alternatives for a question with one answer. Support claims that an option fixes a failure with the relevant issue, test, or failure record; otherwise mark that claim unverified.

## File shape

Adapt sections to the task; omit empty sections except Closeout.

```
# <Topic>
Status: proposed
Created: <date>
Owner / attribution: <who made decisions or recommendations>

## Execution plan
<when implementation is intended>

## Problem and goal
## Scope and non-goals
## Evidence and rejected approaches
<for investigated decisions>
## Design
## Choices requiring the user's decision
<options, gains, losses, costs, recommendation, its evidence, reversal condition>
## Acceptance checks
<observable success and relevant negative cases>
## Closeout
- [ ] Verify the work or decision against the acceptance checks.
- [ ] Release any live artifact through the project's authorized release path.
- [ ] Move this spec to decisions/ or archive/, update Status, and retire the open pointer.
```

Report the path and status briefly. A spec request alone authorizes the document, not the build. Honor explicit existing implementation authorization; do not reset it merely because a spec is being written.

## Close or promote

1. Verify completion against actual artifacts and acceptance checks. Report unresolved work as open.
2. If a live change still needs release, use its authorized project release path. Do not infer permission for a new external action from "close the spec".
3. Move the completed spec to decisions/ or archive/ using a real file move. Record whether it was applied or is only a decision record.
4. Update the state/tracker pointer in the same turn. Confirm the outcome and new path.

If the runtime cannot move files, preserve the source and record the limitation. A copied destination with a surviving original is not a completed archive.
