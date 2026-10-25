---
name: decisions
description: >-
  Builds the decision board for the current project: only the choices that are genuinely the
  user's to make right now, each with its options and, per option, why you'd pick it, what it
  costs and what it unblocks. Use when the user types /decisions or says "what do I need to
  decide", "show me my decisions", "decision board" or "what's waiting on me". Gathers candidates
  from the project's CHECKPOINT.md open threads (plus an optional folder of markdown task notes),
  classifies each with a fixed test, prints the verdicts, then shows the survivors as a board page
  whose picks the next run reads back, or as a numbered list in chat when no page host is
  available. An empty board is a correct result. Do NOT use for listing open work in general (that
  is the CHECKPOINT) or for a to-do list.
---

# decisions -- the decision board for one project

The hard part is the classifier, not the page: a board that carries non-decisions makes the user
whittle them off one at a time, and every fake decision teaches them to ignore the real ones.
Classify FIRST, show the reasoning, build only what passes.

Requires PowerShell 5.1+ or `pwsh` 7+ (collector) and Python 3 (renderer, validator). State lives
in the project's `.decisions/` folder: `board.json` (the last board), `board.html` (a preview),
`url.txt` (the hosted page, once one exists).

Copy this checklist into your reply and tick each line:
- [ ] 0 picks from the last board read and recorded
- [ ] 1 candidates collected
- [ ] 2 verdict table printed
- [ ] 3 decisions written
- [ ] 4 board validated, then shown (page or chat)
- [ ] 5 report

## 0 -- record the picks from the last board before anything else

Picks exist in one of two places: the hosted board's database (when `.decisions/url.txt` exists
and the session has the `ArtifactData` tool), or answers the user gave in chat to the last chat
board. For a hosted board, `ArtifactData` `list` the `picks` collection and the `receipts`
collection on that URL. Each pick is `{decision, option, note, at, rev, unpicked?}`.

- **Skip** a pick whose receipt has the same `rev` and `state: "applied"`: already recorded.
- **A pick:** on the CHECKPOINT Open-threads bullet the decision came from (its `sources` in
  `.decisions/board.json`), add `owner decision -- <YYYY-MM-DD>: <option label>` plus the note
  copied character for character, and drop the `[owner]` tag when the pick leaves only agent work.
  For a decision from a task note, prepend `<YYYY-MM-DD> -- you picked "<option label>" on <at>`
  (plus `: <note>`) to the note's `reply` field, newest first, joined with ` | `, keeping its YAML
  valid.
- **Note-only record** (`option` null): a question or comment on a decision not picked yet.
  Answer it in chat, carry the answer into that decision's `background` at the rebuild, leave the
  decision open. Exception: a note that states a choice outright ("drop it", "do B") is recorded
  as that choice, in the user's words.
- **Removed pick** (`unpicked` set, `option` null): strike the earlier `owner decision` line and
  mark the bullet undecided again. For a task note, prepend `<YYYY-MM-DD> -- you removed your pick
  "<old option label>" on <at>` to its `reply`: the collector reads that entry as reopening the
  question, so the next run puts it back on the board.
- After recording, `ArtifactData set` `receipts/<decision>` to `{rev, state: "applied", result:
  "<one line>", at: "<YYYY-MM-DD HH:MM UTC>"}`. Never write into a pick document; the page
  replaces it whole on every save.
- **A pick is recorded, never acted on in this run.** "Go build it" becomes an `[agent]` thread;
  build, apply or edit nothing the pick approves unless the user asks for it in chat, because a
  board press is a decision, not a work order, and the user is not watching this run.
- Tell the user what they picked and what that set in motion, one line each.

## 1 -- collect candidates (mechanical)

```
pwsh -NoProfile -File <this skill's folder>/collect_decisions.ps1 -ProjectDir <project folder>
```

Add `-NotesDir <folder>` (or set `DECISIONS_NOTES_DIR`) to include markdown task notes whose
frontmatter carries `project: <folder name>`; it is optional, and without it the CHECKPOINT is the
only source. Output is JSON: `candidates[]` of kind `thread` (Open-threads bullets, with tags and
`owner`: `owner` when tagged `[owner]`) and `note` (not-done task notes, with `answered` +
`answered_line` when the note's `reply` already holds a dated decision). The collector never
classifies. If it warns the CHECKPOINT is missing, say so and continue with what it found.

A candidate already decided is not a candidate: one whose bullet carries an `owner decision`
line, a note with `answered: true`, or one a step-0 pick just settled goes in `left` with verdict
`already decided: <their answer, in their words> (<date>)`.

## 2 -- classify every candidate (the load-bearing step)

A candidate is a DECISION only if ALL three hold:
1. a genuine fork: materially different options with different outcomes;
2. it needs the USER's judgment (taste, strategy, product intent, risk appetite): a session
   cannot settle it with a recommendation and just do it.
   **A technical fork is never theirs** (implementation route, tool, library, architecture).
   Research until the evidence settles it, then decide and record it as a model decision. The
   "risk appetite" label does not rescue a technical fork: if a genuine value trade-off survives
   the research, the board carries only that trade-off, worded with no technical terms ("accept a
   small, unreported account-ban risk for a faster in-game panel?").
3. it is live now: not parked behind a precondition whose answer is already obvious.

**A carried decision gets no pass.** Every decision on the last board (`.decisions/board.json`)
goes through this test, the ownership check and the discard list again, from its own words and
sources; having been on a board is no evidence it is a decision. Never copy one forward.

Then the ownership check, because a choice that is not an answer to their ask is not theirs to
make. A candidate must pass all three, or it is not a decision: answer it or drop it.
- a. It answers the device, scope or thing the user named, not a neighbour or substitute of it.
- b. It raises no purchase or spend (new hardware, a subscription, an account) they never raised.
- c. It is not already settled by a dated decision of theirs in the CHECKPOINT, a note's
  `reply`, or a board pick.

Discard, naming the reason, anything that is:
- the project's normal improve-loop ("fold in what makes it better"): that is the job, not a choice;
- already decided or obvious from the user's stated intent (a stale "idea to explore" thread does
  not reopen it);
- scheduling, opportunity cost, token budget ("when do I spend the time on this obviously-fine thing");
- verification or execution ("prove it works", "run the staged step", "click deploy");
- mechanical, one right answer, a session can just do it;
- deferred behind an obvious precondition (a network that needs users who do not exist yet);
- a life to-do tracked under a project (a bill, a call, a purchase): it belongs in a to-do list.
  The board is for forks that GATE AGENT WORK in the project;
- finding users, testers or an audience: never on a board, not even in `left`, because when the
  user goes looking for people is their own call.

Signals, none sufficient alone: an `[owner]` thread whose text is "run X / paste Y / click Z" is
execution; a `[gates: go]` thread is a decision only if the go is a real fork (build A vs B vs not
at all), not a rubber stamp on obvious work. A spec or thread existing is not evidence the user
wants the thing.

Print the verdict table BEFORE building: candidate, verdict (decision / not: <category>), one-line
reason. The user vetoes in chat; remove the struck ones and continue. If nothing passes, say
"nothing needs deciding right now: <the one-line shape of what is open instead>", still write the
empty board when a hosted page exists (so the page is honest), otherwise stop. Never manufacture
a decision to fill the page.

## 3 -- write each surviving decision plainly

For each decision, in plain words a stranger could act on:
- `id`: a short unique slug, stable across rebuilds (the page saves picks under it).
- `title`: the fork as a question, under 100 chars, no field names or project shorthand.
- `background`: **a LIST of 2-4 paragraph strings** (the template calls `.map` on it, so a single
  string renders a blank page): what the thing is, where it came from, what was found, what the
  options are about. A title plus options without this is not a decision.
- `why_now`: one sentence.
- `sources`: a list of `{label, path}`, always including the research, spec, doc or URL the
  decision came from, and the CHECKPOINT line or task note that listed it.
- 2-8 `options`, each with `key` (a short unique slug: the page saves it as the pick and matches
  `default` against it), `label`, `choose_if`, `cost`, `unblocks` (concrete, no workflow jargon).
- `default` + `default_reason`: a suggested pick only with a one-sentence reason saying why that
  option beats the others, naming one piece of evidence (file:line, command output, URL, or a
  dated quote of the user), or saying "no evidence beyond judgment". `default` is a `key`, never a
  label. If the honest answer turns on their taste, risk appetite or a fact only they have, set
  `default: null` and say so in `default_reason`. Never suggest by habit or because it is the
  status quo. **`null` is never the answer when the user's recorded intent or the research points
  at an option**: recommend it and name that intent or evidence.
- Collect the discards as `left[]` (`title`, `verdict`) so the board shows what was left off and
  why (outreach items excepted, per step 2).

## 4 -- validate, then show the board

Write `<project>/.decisions/board.json` as `{project, generated, decisions, left}` (`generated` =
`YYYY-MM-DD HH:MM UTC`; `project` = the folder name). Then:

```
python <this skill's folder>/validate_board.py <project>/.decisions/board.json
python <this skill's folder>/render_board.py <project>/.decisions/board.json
```

Show the board only on the validator's `ok`: the template has no error handling, so one
wrong-shaped field gives a blank page. The validator also fails a `why_now` or `default_reason`
about the user's time or schedule; that is step 2's scheduling discard, so drop the decision
rather than reword the reason.

Pick the route by what this session has:

**Hosted page** (the session has the `Artifact` and `ArtifactData` tools):
- **Rebuild by database write, not by republish**, because republishing a page that declares the
  `db` capability asks the user for consent again. When `.decisions/url.txt` exists:
  re-run step 0 on any pick saved since it last ran, then `ArtifactData set`, collection
  `board`, doc `current`, from the validated `board.json`. The open page updates live.
- First board for the project: publish `.decisions/board.publish.html` (it carries no data, since
  the data holds local paths a hosted page should not; it fills from `board/current`) with
  `capabilities: {db: {}}`, `icon: "scale"`, a one-sentence description; save the returned URL to
  `.decisions/url.txt`; then write `board/current` as above. Open the page once and confirm the
  decisions are on it: a green validator is not a rendered board.
- The board is private by default; never share it on the user's behalf.

**Chat board** (no page host): print each decision as a numbered block: the title, the
background, then the options lettered with `choose if / costs / unblocks`, and the suggested pick
with its reason. Ask the user to answer as "1B, 2A: <note>". When they answer, record each pick
per step 0's rules (no receipt step). `board.html` from the renderer is a read-only preview that
opens in any browser.

## 5 -- report (this cap binds)

At most six lines: where the board is (URL, or "above"), how many decisions are on it, the one-line
list of their titles, what was left off (count; the fuller table is on the board), and any pick
from step 0 that was recorded. Nothing about the classifier's mechanics, the template or the
state files.

## Rules

- Classify before building; never build then whittle.
- One project at a time: the folder the session is in. Ask which project only if that folder has
  no CHECKPOINT.md and the user named none.
- Same page per project, fresh data each run: never a second hosted board for the same project.
- Tests: `python validate_board_tests.py` beside this file.
