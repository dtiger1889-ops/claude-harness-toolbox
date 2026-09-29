---
name: grill-me
description: Interview the user with batched, numbered questions BEFORE building anything new, then confirm a short Build spec in a file, then build. Use whenever a session KICKS OFF new work or FIRST IMPLEMENTS something -- "build / make / create / design / implement / set up / scaffold / spec / prototype X", a new project, milestone, skill, hook, app, dashboard, automation, document, deck, or plan -- even when the request looks detailed enough to start, and especially on one-line asks like "make me a dashboard". Also use when the user types /grill-me or says "grill me" / "interview me first". Do NOT use for continuing work that already has a Build spec or spec file, for bug fixes, edits to existing work, debugging, questions, explanations, reformatting, one-shot commands, or unattended sessions (scheduled tasks, claude -p, subagents) where nobody can answer.
---

# Grill Me

A build request carries a fraction of what the person asking has in mind. Building from
that fraction produces work that gets thrown away. A dozen well-aimed questions take a
couple of minutes and save the rebuild. That trade is the whole skill.

## Core rule

Before writing any code, file, design, spec, or deliverable for NEW work, interview the
user: 10-15 questions across 2-3 rounds. No "quick draft to react to" first. A draft
anchors the conversation, and the interview turns into approving whatever was guessed.

## Step 0 -- don't ask what the files already answer

Before round 1, read whatever already answers questions and strike those questions:
- the project's `CHECKPOINT.md` (Goal, Open threads, Key decisions) and `CLAUDE.md`;
- any notes, profile, or reference file those point at, when the build depends on the
  user's own preferences or history;
- the conversation so far and anything pasted or attached.

Asking something a file already answers tells the user you weren't paying attention, and
it burns a question slot. If everything is already answered, say so in one line and go
straight to the Build spec.

## Running the interview

**Rounds, not a wall.** 2-3 rounds of 4-6 questions. Round 1 covers fundamentals
(purpose, where it will be used, scope); later rounds drill into what the answers
revealed. You can't ask a good edge-case question until you know what the thing is for.
Number every question so the user can answer by number.

**Use the question tool, not prose.** Where the runtime has a structured question tool
(`AskUserQuestion` in Claude Code), every question goes through it: up to four per call,
two to four short options each. Open-ended questions (examples, names, what would make
them reject it) go through it too, with one or two plausible options plus the built-in
free-text answer. Don't mix: numbered prose questions sent in the same turn as a
question-tool call can fail to reach the user on some surfaces, and the session then
wrongly concludes they never answered. Plain numbered prose is the fallback only when no
question tool exists. On a phone or remote terminal, keep rounds to 4-5 questions.

**Cover the brief and the surface; don't re-ask them.** Two things belong in every Build
spec: the brief in the user's own words ("what does this look and feel like when it's
right?") and the surface it runs on (desktop, phone, a scheduled job, someone else's
machine), because the surface defines what "verified" means. If the request already states
them, quote them back as settled and use the slot on something else.

**Every question must be able to change the build.** Before asking, know what you'd do
differently for each plausible answer. If every answer leads to the same build, cut the
question. Four real questions beat six padded ones.

**Scale depth to stakes.** A one-evening script earns about 10 questions. Something every
future session inherits (a skill, a hook), or anything published, earns 15.

## What to ask about

Weight these by what's being built; never force all of them:

1. **Purpose**: why now, what problem it solves, what success looks like in their words.
2. **Surface and audience**: where it runs; just them or others; how technical the users are.
3. **Scope**: must-haves, nice-to-haves, and what's explicitly out.
4. **Constraints**: deadline, budget or usage limits, stack, platform, integrations, where it lives.
5. **Content and data**: where data comes from, formats, volume, a real example they can paste.
6. **Edge cases and failure**: unusual inputs, error states, what "wrong" looks like.
   When the build handles input it didn't create (documents, emails, exports, pasted
   text), ask directly: should it **fail open** (always produce output and flag what it
   couldn't handle) or **fail closed** (stop when something is unexpected)? And how do
   flags reach them? If nobody can answer, default to fail open for drafting, formatting,
   and triage, and fail closed for anything that sends, pays, deletes, publishes, or
   overwrites, and record that under Assumptions.
7. **Taste**: examples they like or hate; tone; look.
8. **Lifecycle**: one-off or maintained, and by whom.
9. **Delegation**: which parts can go to a cheaper model or helper agent.
10. **Rejection criteria**: what would make them send it back. Often the most revealing question.

## Pushback

If the user says "just build it", the interview serves them, it doesn't gatekeep. Compress
instead of skipping: ask the 3 questions whose answers would most change the result, then
proceed on stated assumptions. If they decline those too, build now and list your
assumptions at the top of the deliverable so a wrong guess is visible and cheap to fix.

**Never re-grill the same work.** If the project's `CHECKPOINT.md` or a spec file already
holds a Build spec or a `Grilled:` line for this work, follow-ups get 1-2 clarifying
questions at most. New work inside an old project is new work: grill it.

**Unattended sessions** (scheduled tasks, `claude -p`, subagents): nobody can answer. Skip
the interview, write the Build spec from what's known, and put the assumptions at the top
of the deliverable and in the project's `CHECKPOINT.md`.

## After the interview: the spec goes in a file

Chat scrolls away and the next session never sees it. Condense the answers into this block:

```
## Build spec
- Brief (user's words, verbatim): "..."
- Goal: [one sentence]
- Surface / users: [where it runs and who uses it]
- Must have: [list]
- Out of scope: [list]
- Constraints: [list, including where it lives and any cost limits]
- Failure behavior: [fail open or fail closed; what gets flagged, and where]
- Taste references: [what it should and shouldn't feel like]
- Assumptions: [anything still guessed]
- Grilled: YYYY-MM-DD, N questions, [surface]
```

Show it, get an explicit yes, then write it where the next session will read it:
- work big enough for its own spec: the top of a new `specs/<name>.md`;
- smaller work: the project's `CHECKPOINT.md`, under Goal or the relevant open thread.

The `Grilled:` line is what stops a later session from re-interviewing. The spec is the
contract: if a later request contradicts it, point at the line and confirm the change
instead of drifting.

## What counts as new work

Grill for: apps, sites, tools, skills, hooks, scripts over ~20 lines, dashboards,
automations, scheduled tasks, documents, decks, plans, specs, database designs, a new
project or milestone.

Skip for: one-line answers, explanations, edits to existing work, debugging, questions,
format conversions, resuming work, checkpointing, and anything whose spec already exists.
Interviewing someone who asked to rename a variable destroys their trust in the skill.

## Example

**User:** "Build me a habit tracker."

**Round 1** (question tool):
1. In a sentence or two, what does this look and feel like when it's right?
2. Where will you use it: desktop, phone, both?
3. Just you, or other people too?
4. Web app, script, or part of something you already run?
5. What's failing about how you track habits now?

**Round 2** (shaped by "desktop + phone, just me, part of my existing dashboard, streaks keep breaking"):
6. When a streak breaks: reset to zero, or allow grace days?
7. Daily only, or weekly / x-times-per-week too?
8. The one screen you'll look at daily: today's checklist or streak history?
9. Reminders pushed to you, or check in when you remember?
10. A check-in arrives malformed or for a habit that no longer exists: log and flag it (fail open), or reject it (fail closed)?
11. Anything you've tried and disliked?

Then the Build spec (into `CHECKPOINT.md`), then the build.

## Enforcement (optional)

A skill description is advice the model can skip. The toolbox's `hooks/grill_gate.ps1`
makes it stick: a prompt that reads like a build kickoff gets a reminder, and if the
session then tries to write a file before asking any questions, that first write is
blocked once. See the README's Hooks table.

## Credit

The idea is Matt Pocock's `grill-me` ([mattpocock/skills](https://github.com/mattpocock/skills), MIT).
This version grew from Ruben Hassid's adaptation of it (the 10-15 questions in batched
rounds), rewritten here with the read-first step, question-tool delivery, the fail
open/closed question, the Build spec written to a file, and the hook that enforces it.
