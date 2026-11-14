---
name: spec
description: Writes or reviews a change or decision spec with explicit tradeoffs and closeout criteria. Use for /spec, "spec this", "write a spec", review of a spec's open questions, or closing, archiving, and promoting a finished spec, including when its work is reported done and nobody said "close it". Runs a prior-art pass (shipped solutions, related projects, notes) before writing. Does not authorize implementation by itself.
---

# Spec

Two failures this skill prevents: a spec that sits forever after its work ships or dies, so the next session re-derives the decision; and a spec that leaves the user a question without what each answer costs them, which is homework handed back. Use those two as the rubric for cases the steps below do not cover.

Read the project's current state, instructions, existing spec, and relevant artifacts. Follow its naming and storage conventions. Otherwise use the existing outbound/ or specs/ folder, or create specs/. Write one topic per file. A skill you build always gets its own spec in the owning project's spec folder, written before or as it is built, never only a build brief inside a research note or the project state.

## Write or review

Choose depth by the work; unsure means decision spec:

- **Change spec:** a mechanical change with no contested reasoning. Concise problem, intended behavior, scope, implementation plan, and acceptance checks; padding it is noise.
- **Decision spec:** a conclusion reached through investigation. The reasoning is the deliverable, so include in full: the investigation chain in order with the numbers each step produced and the tool that produced them, the method that validates each measurement, every rejected approach with the data that rejected it, and the provenance of each design choice (measured, the user's call, or model default). Add a Trigger naming the dated real event and the specific defects, numbered checkable acceptance criteria with no vague adjectives, a scope fence, and, once executed, a "Divergences during execution" section at the top. Terse but empty is the failure here.

## Prior-art pass, before any design

A spec designed from the model's head rebuilds what already exists or repeats a failure someone already published. Run this before writing the design; it is never skipped, and a dry sweep is recorded as "nothing found" with its queries.

- **Reuse first.** If a sweep on this topic already exists (a dated prior-art note, the project state's research block, an interview or outside-view pass this session), cite it with its date and add only what it lacks.
- Name the problem without any approach, and the approach you already have in mind (the thing on trial).
- Search the web on three questions: which maintained library, tool or published skill already does this; what the largest platforms in the domain do (for agent tooling: Claude Code, Codex, Cursor and the big open-source frameworks); and how the best practitioners of this kind of work do it. An internal rule change still answers the second; the other two may read "not applicable: internal rule". A change spec takes one to three searches; a decision spec has no cap and keeps a long sweep in its own dated file, with the spec holding the verdict and a pointer.
- Open the page behind every fact you cite; a search snippet is never a source. A "nothing exists" verdict needs three or more distinct searches.
- Search the workspace: the state, decisions and specs of the two or three most plausible related projects, with a search that does not skip ignored files.
- Search the notes folders that hold reference material on the topic (one bounded lookup, one to three terms) and read the best hit, or write "no notes hits" / "notes unavailable".
- Write the result in the spec's `## Prior art` section, not chat. A verdict that kills or changes an approach the user already approved goes to them as the first decision, naming the line of the approved brief it contradicts.
- Skip it only when closing a spec or when the spec already has the section. Reviewing a spec that lacks one runs this pass first.

## Plan, attribution, cost

For later execution, put the plan right after Status, not at the bottom, because readers anchor on the top and skip the middle. Make it executable without re-deriving: exact files, relevant anchors or the existing pattern to mirror, configuration keys with defaults and how to disable or revert, the test to write, and the acceptance check. Acceptance includes a negative case (an input that must be refused or must fail) for each check the build adds. Prefer stable symbols or headings to unexplained line numbers.

Attribute choices accurately: user decisions, measurements, and model recommendations are different. A line written as the user's direction carries their literal words; specifics the model added to those words are labelled `(model reading)`; never harden a measured or model default into their sign-off. Do not quote every exchange. State risks, affected surfaces, and non-goals (one line of why per non-goal, so it is not re-argued). State cost as what the work touches (files, steps) plus its blast radius, never as a time estimate. Use an actual date and avoid invented shorthand. Too big for one spec: spec phase one and fence the rest under non-goals with the why.

## Decisions for the user

Each unresolved choice the user must make is a decision block (template below), and the same shape applies when reviewing a spec's open questions: a bare pick for a bare question is the failure.

- Two or three real options. An option with no real loss is the answer, not an option: state it and skip the block. Do not invent alternatives to make a block look balanced.
- Each option's **Lose** line names what breaks, what the user gives up, or what they keep maintaining, in their terms, not the model's.
- A **Gain** that claims an option fixes a failure names the issue, test or failure record it was checked against, or marks that claim unverified.
- The **Recommendation** names the one piece of evidence behind the pick (file and line, command output, URL, or the user's own words with their date) or says "no evidence beyond judgment", plus the one condition that would flip it. A confident reason with no source reads as a finding when it is a guess.
- An option taken from an outside page keeps that page's own word ("recommended", "optional") and link and says the user did not ask for it.
- An unknown the sweep could not settle becomes a decision block (if the choice is the user's) or an Assumptions item, never a silent guess. Every Assumptions item, in an `## Assumptions` section or a build brief's `Assumptions:` line, goes to the user in the same turn as an open decision in the project's tracker or state file naming the spec, because a guessed default left in a spec gets built on as if the user chose it. An item the user answers moves out of Assumptions into the decision it settles, with their words and date.

## File shape

Adapt sections to the task; omit empty sections except Closeout and Prior art.

```
# <Topic>
Status: proposed
Created: <date>
Owner / attribution: <who made decisions or recommendations>

## Execution plan
<when implementation is intended; negative case per check in its acceptance>

## Audit history
<one row per audit of this spec or the work it drives: date, auditor, scope, report location,
outcome (findings fixed / rejected with why / left open)>

## Problem and goal
## Scope and non-goals
## Prior art (searched <YYYY-MM-DD>: "<query 1>"; "<query 2>"; workspace and notes paths searched)
(reuse case: searched <YYYY-MM-DD>: see <path to the earlier sweep file>)
1. <what exists> -- <link or file:line> -- adopt / adapt / reject: <one line, the good and the bad>
Verdict: adopt / adapt / build new -- <why; building new names what was found and why it does not fit>
## Evidence and rejected approaches
<for investigated decisions>
## Design
## Decisions for the user (or "none")
### D1. <the question in plain words, one line>
<one or two lines of context a stranger needs>
**Option A -- <what it is>.**
- Gain: <what they get>
- Lose: <what breaks, what they give up, what they keep maintaining>
- Cost: <what it touches to build and to keep correct>
**Option B -- ...**
**Recommendation: <letter>.** Evidence: <one piece, or "no evidence beyond judgment">. Flip to <letter> if <condition>.
## Assumptions (each with its open decision in the tracker or state file)
## Acceptance checks
<observable success and a negative case per check>
## Closeout
- [ ] Verify the work or decision against the acceptance checks.
- [ ] Release any live artifact through the project's authorized release path.
- [ ] Move this spec to decisions/ or archive/, update Status, and retire the open pointer.
Until one release-or-archive box is checked, this spec is unfinished.
```

In the same turn, add or refresh a one-line pointer in the project's state or tracker naming the spec path, what it decides or builds, and what gates it (usually the user's go while proposed); a spec with no pointer is invisible to the next session. Report the path and status briefly. A spec request alone authorizes the document, not the build. Honor explicit existing implementation authorization; do not reset it merely because a spec is being written.

## Close or promote

Fire whenever a spec's work is reported done, even when nobody said "close it"; a done spec is never left open.

1. Verify completion against actual artifacts and acceptance checks; "done" is not taken on faith. Report unresolved work as open.
2. If a live change still needs release, use its authorized project release path. Do not infer permission for a new external action from "close the spec".
3. Move the completed spec to decisions/ or archive/ using a real file move, never write-new plus delete. Flip Status to `archived`, or `applied` then `archived` when promoted.
4. Retire the state/tracker pointer in the same turn. Confirm the outcome and new path.

If the runtime cannot move files, preserve the source and record the limitation. A copied destination with a surviving original is not a completed archive.

## Calibration

Under-use, the worse direction: a change ships with no spec after one was asked for; a finished spec stays in specs/ with its Closeout unchecked; a question for the user goes out as one line or as a pick with reasons attached; a spec with no Prior art section, or one citing only search snippets. Over-use: a change spec padded with investigation prose; a change spec's sweep grown into a research project; a decision block for a question with one answer. When in doubt, add the trade-offs and cut the narrative.
