---
name: grill-me
description: Interviews the user before new work, then records an agreed build brief. Use for /grill-me, "interview me first", or the first build of a new project, milestone, app, skill, hook, automation, dashboard, document, plan, or design, even when the request looks detailed enough to start. Skip fixes, edits, debugging, explanations, one-shot commands, work with an existing spec or build brief, and unattended sessions.
---

# Interview before building

Most build requests fail in specification, not execution: the user holds the full picture and the request carries a fraction of it. A few good questions are cheaper than a rebuild. Do not produce a "quick draft" first; a premature draft anchors the conversation and turns the interview into a formality.

## 1. Read first

Read the project's current state, instructions, relevant references, supplied material, and conversation. Treat answered questions as settled and strike them; asking what a file already answers signals you were not listening. If the brief is complete, say so in one line and go straight to recording it.

When the ask points at something the user said, asked, or decided before ("as I said", "we covered this", "I asked for"), search their own past messages before asking again; those words often live only in an old session transcript. Claude Code keeps each session as a JSON Lines file under `~/.claude/projects/<project>/`. Search the user-role lines of recent files for two to four topic keywords from the ask (30 days by default, or the time the ask names; widen to a year once if nothing turns up), and drop subagent rows, pasted blocks, and system or tool text before matching. A hit in words the user typed is the answer: quote it with its date and do not strengthen it. A hit that reads like a pasted brief, a report, or another model's prose is not the user's own words; keep looking. If the search finds nothing, say so ("I searched your past messages for <keywords> and found nothing") and then ask. Where the transcripts are not reachable (a cloud or web session), say that instead.

Before the first round, run the spec skill's prior-art pass (its searches, not the write-up) so the questions start from what already exists, and keep the findings in the conversation; the spec written afterward reuses them instead of searching again.

## 2. Ask only questions that change the result

Use short, numbered rounds, never every question at once. Round one establishes fundamentals; later rounds drill into what the answers revealed. Scale the number of questions to the unresolved choices and the stakes (a throwaway script earns fewer than a skill or hook every future session inherits, or anything shipped publicly), never to a fixed quota. Before asking, know what you would do differently for each plausible answer; if every answer leads to the same build, cut the question. Never pad a round to look thorough.

Round one must cover the brief in the user's own words ("what does this look and feel like when it's right?") and the surface it runs on (desk, phone, a web chat, a scheduled task, someone else's machine), because both go in the build brief and the surface defines what "verified" means. When the request already states them, quote them back as settled and spend the slot elsewhere; asking for a brief the user just wrote reads as a made-up question.

Use the runtime's structured question tool when it has one, for closed and open questions alike: give an open question one or two plausible options plus free text. Do not send a round as prose in the same turn as a question-tool call, because the prose may never reach the user's screen; plain numbered questions are the fallback only for a runtime with no question tool. When several answers can all be true at once, such as what would make the user send the result back, make the question multi-select rather than single choice, so no real answer has to be dropped. Keep rounds especially short on a phone.

Consider, as relevant:

- Purpose: what triggered this now and what success looks like in the user's words.
- Required behavior and explicit non-goals.
- Platform, integrations, data source, format, and volume; a real example the user can paste.
- Budget, deadline, usage limits, and where the work lives.
- Failure handling and how uncertainty reaches the user.
- Taste references and rejection criteria; the other half: who or what, other than the user or the model, shows the result is good (an outside judge).
- Maintenance, ownership, and delegation preferences.

For inputs the build did not create (documents, exports, pasted text), ask whether to produce partial output with flags (fail open) or stop (fail closed), and how flags reach the user. If nobody can answer, default to flagged partial output for drafting, formatting and triage; stop before uncertain sends, payments, deletions, publication, or overwrites. Record the assumption.

## 3. Respect the user's direction

If the user says to just build it, compress rather than skip: ask the three questions whose answers would most change the outcome and say you will proceed on stated assumptions. If they decline even those, build and list the assumptions at the top of the deliverable so wrong guesses are visible and cheap to correct.

Never re-interview the same work: when the project state, a spec, or the tracker already holds a build brief or a `Grilled:` line for it, follow-ups get at most one or two clarifying questions. New work inside an old project is new work.

For unattended work (scheduled runs, headless runs, helper agents), skip the interview, write the brief from the provided instructions and project evidence, put the assumptions at the top of the deliverable and in an open item in the project state, and preserve any explicit approval boundaries.

## 4. Record the build brief

```
## Build spec
- Brief (the user's words, verbatim): "..."
- Goal: <concrete completion condition>
- Surface / users: <where it runs and for whom>
- User's explicit requirements: <each in their words or their pick, quoted, with date and where
  they said it: "<words>" (user, YYYY-MM-DD, grill Q3)>
- Model proposals: <each item the model designed, tagged (model)>
- Out of scope: <excluded work>
- Constraints: <platform, location, cost, deadline, delegation>
- Failure behavior: <fail open or fail closed; what gets flagged, and where>
- Taste references: <if relevant>
- Outside judge: <who or what, other than the user or the model, shows it is good; or "none named">
- Assumptions: <anything still guessed; each also goes to the user as an open decision in the tracker or state file>
- Approval scope: <the user's exact words on this brief and what they cover: whole brief, a bounded part, or "not approved">
- Grilled: YYYY-MM-DD, N questions, <surface>
```

Attribution, for the brief and for every design doc or rule written from it, because a model line recorded as the user's gets built on as their decision:
- A line goes under the user's requirements only with their literal words beside it. Specifics the model added (a place, a mechanism, a scope they never named) come after them, labelled `(model reading)`.
- A blanket "yes, build it" goes in Approval scope, never as a tag on model-designed items; approval is not authorship of each line.
- A scoped instruction ("skip it in this folder") is recorded with its scope, not as a standing decision about the thing.
- A reply counts as the user's decision only when the turn before put that decision to them; agreeing with a fact is not a decision, and a hold, pause, skip or cancel credited to them needs their own action words (hold, wait, skip, stop, don't).
- With no source in reach for a line crediting the user, write `evidence unavailable` on it or move it to Model proposals.

Show the brief, get an explicit yes, then write it where the next session will read it: work big enough for its own spec, and every new skill, goes at the top of a new spec file (via the spec skill); smaller work goes into the project's state file under its goal or open item. The `Grilled:` line is what stops a re-grill. The brief is the contract: if a later ask contradicts it, point at the line and confirm the change rather than silently drifting. Do not treat silence as agreement, or invalidate authorization the user already gave. Build only within that scope.

## What counts as new work

Grill for apps, sites, tools, skills, hooks, non-trivial scripts, dashboards, automations, scheduled tasks, documents, decks, plans, specs, data designs, and a new project or milestone. Skip one-line answers, explanations, edits to existing work, debugging, format conversions, resuming interrupted work, checkpointing, and work whose spec already exists; grilling someone who asked to rename a variable destroys trust in the skill.

An optional grill hook is provided in the toolbox; consult the repository's Hooks documentation before installing it. Its reminder is not a substitute for reviewing the actual brief.

Credit: adapted from [Matt Pocock's grill-me](https://github.com/mattpocock/skills), MIT, and Ruben Hassid's batched-interview adaptation.
