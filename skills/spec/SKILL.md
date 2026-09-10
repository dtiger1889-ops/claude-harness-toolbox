---
name: spec
description: >-
  Write a spec that drives a decision or a change into the current project's spec
  folder, or close a finished spec by archiving or promoting it, so no spec rots in
  place and no question left for the user arrives without its trade-offs. Use this skill
  whenever the user types /spec or says "spec this", "write a spec for X", "make a spec",
  "close out this spec", "archive this spec", "promote this spec", and ALSO when they ask
  to review, refine, or "answer the open questions" of an existing spec (a decision
  section is being produced either way, and it owes them the same shape), and ALSO when a
  spec's work is reported done even if nobody said "close it". Do NOT use for /breakdown
  (that is decomposition into a next action), /checkpoint (resume state), /grill-me
  (the interview that runs BEFORE a spec and feeds it), or a question about a topic
  where the user wants an answer in chat and no file.
---

# Spec

Two failures this skill exists to kill. First, specs get written and then sit forever:
the work ships or dies and the file never says which, so the next session re-derives the
decision. The Closeout block is the fix and it is never optional. Second, a spec that
leaves the user a question without laying out what each answer costs them is not a spec,
it is homework handed back. (Real report, on five open questions rewritten as five
picks-with-reasons: it "proposes no trade-offs for one option over another".) A decision
they cannot make from the file alone means the spec did not do its job. Use these two
failures as the rubric for every case the steps below do not cover.

## Core rule

A spec ends in a Closeout, and every question it leaves for the user is a decision block:
the options side by side, what each one gains them, what each one costs them, then a
recommendation and the one condition that flips it. Writing the spec never authorizes
building it.

## Mode A -- WRITE (default unless the user names an existing spec or says close / archive / promote)

No chat preamble and no capability narration; produce the file, then confirm in one line.

1. **Pick the depth first**, because the two kinds want opposite amounts of content.
   - CHANGE spec: a mechanical change with no contested reasoning ("add a config flag",
     "rename X", "wire up Y"). Keep it lean; the line budgets in the template apply. The
     change is obvious, so padding it is noise.
   - DECISION spec: a conclusion reached through investigation (hypotheses tested,
     approaches rejected, measurements taken). Budgets do not apply: the reasoning is the
     deliverable, because a future session cannot rebuild it without re-running the work.
     Include in full the investigation chain in order with the numbers each step produced
     and the tool that produced them; the methodology that validates each measurement; every
     rejected approach with the data that killed it (the reference depth is a spec that
     records a measured, rejected guard); and provenance for each design choice (measured,
     the user's call, or model default). Terse-but-empty is the failure here.
     Unsure which kind: DECISION.
2. **If the spec will be built** by a later session, a smaller model, or anyone else,
   put the BUILD / EXECUTION plan right after Status, not at the bottom: readers anchor on
   the top and the end and skip the middle. Make it executable without re-deriving: exact
   files and line anchors, the existing pattern to mirror, config keys with defaults and
   how to disable, the test to write, the acceptance check. "Add a gate" is not a plan;
   "insert after engine.py:889, mirror the block at 696-709, key on (family, side)" is.
3. **A DECISION spec also carries the house style**: a Status line with state, date,
   what shipped or was decided, and a pointer; a Trigger naming the dated real event and
   the specific numbered defects, not an abstract problem; verbatim quotes at every point
   the user decided something ("Why they rejected B: '<quote>'"), never hardening a
   measured or model default into their sign-off; numbered checkable acceptance criteria
   including the negative cases and the final "move to decisions/" step, with no
   ambiguous adjectives; an estimated cost with blast radius; a scope fence; and, once
   executed, a "Divergences during execution" section pinned at the top.
4. **Place it.** Current project's spec folder, precedence `outbound/` then `specs/`,
   else create `specs/`. Filename `<kebab-topic>.md`, single file, no sibling templates. A
   project or workspace CLAUDE.md that names another convention wins.
5. **Write the shape** under Output format. Cut any section that is empty except Closeout.
   Real date via `[System.DateTime]::UtcNow.ToString('yyyy-MM-dd')` (bash: `date -u +%F`).
   Plain language, no invented codes. `Failed approaches:` sits as a sub-bullet under
   Decision when relevant. Too big for one spec: spec phase 1 and fence the rest under
   Non-goals with the why.
6. **Write the decision blocks** for anything the user must choose, in the exact shape under
   Output format. Two or three options; an option with no real loss is not an option, it is
   the answer, so say that and skip the block. The Lose line names what breaks or what they
   give up or keep maintaining, in their terms, not the model's. The same shape applies
   when REVIEWING a spec's open questions: a review that answers a bare question with a
   bare pick has repeated the failure this skill exists to kill.
7. **Point at it** in the same turn: add or refresh a one-line Open-threads bullet in the
   project's CHECKPOINT.md naming the spec path, what it decides or builds, and what gates
   it (usually `[owner] [gates: build]` while proposed). A spec with no CHECKPOINT
   pointer is invisible to the next session, the exact rot this skill kills.
8. **Confirm in one line** (path and Status) and stop. Building waits for the user's go
   given AFTER they have seen the spec; a "yes" from before /spec was invoked is void, because
   invoking /spec resets authorization to review-first. (Real incident: "i asked you to spec,
   and you shipped it".)

## Mode B -- CLOSE (archive or promote)

Fire whenever a spec's work is reported done, including when the user says it is finished
without saying "close it". A done spec is never left open.

1. Read the spec and confirm the work is actually executed by checking the files or repo
   it targets; "done" is not taken on faith.
2. PROMOTE if the spec produces a live change in a deployed artifact or repo: ship it
   through the project's own release path, then archive. ARCHIVE if it is a record of a
   decision with no separate live artifact.
3. Move the file with `Move-Item` or `mv`, never write-new plus delete, to
   `<project>/decisions/` (create if absent) or `<project>/archive/`.
4. Flip `Status:` to `archived`, or `applied` then `archived` if promoted.
5. Retire the CHECKPOINT Open-threads bullet in the same turn; no spoken "later".
6. Confirm in one line: archived or promoted, new path, what shipped.

## Output format

```
# <Spec name>
Status: proposed
Created: <YYYY-MM-DD>

## Problem (1-3 lines: what is broken or missing)
## Goal (1-2 lines: what "done" means, concretely)
## Non-goals (the scope fence; one-line WHY per item so it is not re-litigated)
## Decision / design (the content; bullets over prose; `Failed approaches:` sub-bullet)
## Decisions the owner needs to make (or "none")
### D<n>. <the question in plain words, one line>
<one or two lines of context a stranger needs>
**Option A -- <what it is>.**
- Gain: <what they get>
- Lose: <what breaks, what they give up, what they keep maintaining>
- Cost: <size to build and to keep correct>
**Option B -- ...** (2-3 options)
**Recommendation: <letter>.** Flip to <letter> if <the one condition that changes it>.

## Closeout - DO NOT DELETE, fires when this spec's work is executed
This spec does not just sit in specs/. When the work is done, ONE of:
- [ ] ARCHIVE: move this file to <project>/decisions/ (or archive/) - it is now a
  record of a made decision. Flip Status: archived.
- [ ] PROMOTE: ship the change into the live artifact/repo, then archive this spec.
  Flip Status: applied then archived.
Until one box is checked, this spec is UNFINISHED.
```

A DECISION spec adds sections for the investigation chain, methodology, rejected
approaches, provenance, acceptance criteria, and cost (step 3), and puts the build plan
right after Status when one exists (step 2).

## Calibration

Under-use, the worse direction: a change ships with no spec after the user asked for one; a
finished spec stays in `specs/` with its Closeout unchecked; a question for the user goes
out as one line or as a pick with reasons attached. Over-use: a CHANGE spec padded with
investigation prose nobody needs; a decision block written for a question that has one
answer (state the answer instead); options invented to make a block look balanced. When
in doubt, add the trade-offs and cut the narrative.

## Example

The ask, mid-review of a spec: "see if you can come up with answers to the open
questions". The spec's question reads "Manifest advance trigger: checkpoint-finisher only,
or also a PostToolUse observed-Read bump?" The block that lets them decide:

```
### D1. When does a note stop counting as "unseen"?
A session gets told "3 new notes for this project." What clears those 3?
**Option A -- when you close the session with /checkpoint.**
- Gain: no new hook; about 10 lines in a script that already runs
- Lose: a session that never opened the note still clears it, because closing is not
  reading; the one session in four that never touches CHECKPOINT never clears the list
- Cost: one script edit, one session; collides with the pending close-time edit
**Option B -- when a session actually opens the note (a hook on every Read).**
- Gain: exact; works for read-only sessions
- Lose: a note nobody wants to read lists forever unless a dismiss command is run, and the
  model has to remember to run it; agents without hook support get only the command; one
  more hook on every Read in every project
- Cost: one ~20-line hook plus its wiring, one session
**Recommendation: B.** Flip to A-plus-B if the pilot shows the list never converges.
```

What the earlier, rejected version said instead: "Manifest advance: observed-Read hook +
explicit ack; finisher NOT used", followed by four lines of reasons. Same conclusion, no
way to weigh it.

## Runtime -- what changes in a cloud / sandboxed session with no local shell

The thinking steps (depth, build plan, decision blocks, Closeout) are pure reasoning and run
unchanged. Writing the spec file and the step 7 CHECKPOINT pointer goes through whatever
filesystem bridge the runtime gives you. If that bridge publishes an allowlist of reachable
folders, re-check it at the moment of need -- these allowlists commonly mutate mid-session;
list the project folder first and request access to the workspace root if it is not
connected, rather than guessing a path.
Step 5's `[System.DateTime]::UtcNow` will not run -- use the container's own clock
(`date -u +%F`). **Mode B's `Move-Item`/`mv` cannot run when the bridge writes but never
deletes**: write the file to `decisions/` (or `archive/`) with the flipped `Status:`, then
say plainly that the original is still in `specs/` and leave its removal as a one-line note
for a local session -- never report the spec as archived when both copies exist.
