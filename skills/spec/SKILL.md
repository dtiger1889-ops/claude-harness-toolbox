---
name: spec
description: Efficiently produce a spec into the current project AND drive its
  archive/promote closeout so it never just rots in place. Use when the user types /spec
  or says "spec this" / "write a spec for X" / "make a spec" / "close out this spec" /
  "archive this spec" / "promote this spec". Two modes - WRITE a new spec (lean for a
  mechanical change, full-reasoning for a decision reached through investigation), or
  CLOSE an existing one (archive to decisions/ OR promote into the deployed artifact).
  Every spec this skill writes ends with a mandatory Closeout section, and finishing a
  spec's work ALWAYS ends by firing that closeout - that step keeps getting dropped,
  which is the whole reason this tool exists. Terse, action-first, no capability
  narration. Not /breakdown (that is decomposition) and not /checkpoint (that is
  resume state).
---
A spec is a file that drives a decision or a change, then gets ARCHIVED or PROMOTED.
The failure this tool kills: specs get written and then left sitting forever. So the
closeout is not optional and not deferred - it fires every time the work is done.

Pick the mode from the user's words. Default WRITE unless they name an existing spec or
say close/archive/promote.

## MODE A - WRITE a new spec

No preamble. Produce the spec, write it, confirm. Do not explain at length first
(this is about CHAT preamble, not the spec body).

FIRST decide the spec's DEPTH - the two kinds of spec want opposite amounts of content:
- **CHANGE spec** - describes a mechanical change with no contested reasoning ("add a
  config flag", "rename X", "wire up Y"). Keep it LEAN; the line-budgets in step 2 apply.
  The change is obvious, so padding it is noise.
- **DECISION spec** - records a conclusion reached through INVESTIGATION (hypotheses
  tested, approaches rejected, measurements taken). The line-budgets DO NOT apply: the
  reasoning IS the deliverable. Include, in full -
    - **How you got here**: the investigation chain in order, each step with the numbers
      it produced and the tool/script that produced them.
    - **Methodology**: how each measurement was validated (so it can be re-run + trusted).
    - **Rejected approaches**: every approach tried and the data that killed it - the
      single highest-value content, because a future session cannot rebuild it.
    - **Provenance**: for each design choice, why that value/shape (measured? the user's
      call? model default?).
  A future session must be able to rebuild your reasoning WITHOUT re-running the work.
  Terse-but-empty is the failure mode here; sparse decision specs are the exact complaint
  this rule fixes. When unsure which kind, it's a DECISION spec.

Both kinds still obey: no chat preamble, no capability narration, mandatory Closeout.

If the spec will be BUILT (by a future session, a smaller model, or someone else):
- Put the **BUILD / EXECUTION plan near the TOP** (right after Status), NOT at the bottom.
  Models and humans skip the middle of long docs and anchor on the top + end, so a build
  plan buried at the bottom gets half-read. Everything below it is the supporting reasoning.
- Make it **executable without re-deriving**: exact files + line anchors, the existing
  pattern/function to mirror, the config keys + defaults (and how to disable), the test to
  write, and an acceptance check. Assume the implementer has NOT read the rest of the doc -
  inline the few facts they need. "Add a gate" is not a plan; "insert after engine.py:889,
  mirror the block at 696-709, key on (family, side)" is.

A DECISION spec also carries these:
- **Status line**: state + date + what shipped/decided + a pointer (commit hash once executed).
- **Trigger**: the dated, concrete real event that caused this, with the SPECIFIC defects
  numbered (the actual bug / loss / report), not an abstract problem statement.
- **Verbatim quotes at every decision point**: when the user made the call, quote their
  exact words ("Why they rejected B: '<quote>'"). Distinguish measured/model-default
  choices from the user's calls - never harden a model-suggested default into "their
  sign-off".
- **Numbered, checkable Acceptance criteria** - including the final "move this spec to
  decisions/" step. Each criterion independently checkable; include what must NOT happen
  (the negative case); no ambiguous adjectives ("fast", "clean", "robust") - state the
  concrete observable instead.
- **Estimated cost**: per-change size, total session estimate, and a blast-radius/risk note.
- **What this does NOT do**: the scope fence.
- **Post-execution**: a "Divergences during execution" section pinned at the TOP (drafted
  vs shipped vs why), so the file stays honest about what actually landed.

1. PLACE it. Write to the current project's spec folder, in this precedence:
   `outbound/` -> `specs/` -> else create `specs/`. Filename `<kebab-topic>.md`.
   Single file, no sibling templates.
2. WRITE this shape - cut any section that is empty for this spec EXCEPT Closeout. The
   (N-line) hints below are the CHANGE-spec budget; a DECISION spec ignores them, expands
   every section as needed, and ADDS sections for the investigation chain, methodology,
   and rejected approaches (per the depth rule above):
   ```
   # <Spec name>
   Status: proposed
   Created: <YYYY-MM-DD>

   ## Problem (1-3 lines - what is broken / missing)
   ## Goal (1-2 lines - what "done" means, concretely)
   ## Non-goals (what this deliberately does NOT do - the scope fence; one-line WHY per
   item, so the exclusion isn't re-litigated later)
   ## Decision / design (the actual content; bullets over prose)
   ## Open questions (or "none")

   ## Closeout - DO NOT DELETE, fires when this spec's work is executed
   This spec does not just sit in specs/. When the work is done, ONE of:
   - [ ] ARCHIVE: move this file to <project>/decisions/ (or archive/) - it is now a
     record of a made decision. Flip Status: archived.
   - [ ] PROMOTE: ship the change into the live artifact/repo, then archive this spec.
     Flip Status: applied then archived.
   Until one box is checked, this spec is UNFINISHED.
   ```
3. Real date (PowerShell: `[System.DateTime]::UtcNow.ToString('yyyy-MM-dd')`; bash:
   `date -u '+%Y-%m-%d'`).
4. Plain language, no invented codes. Keep `Failed approaches:` as a sub-bullet under
   Decision when relevant - it is the highest-value content a future session can't rebuild.
   For a DECISION spec this is not a one-liner: give each rejected approach its own
   reasoning + the measurement that killed it.
5. CONFIRM in one line: path written + Status. Then STOP. Do not start building unless
   the user says go.

## MODE B - CLOSE a spec (archive or promote) [the load-bearing half]

Fire this whenever a spec's work is reported done - and proactively when the user says a
spec is finished, even if they didn't say "close it." A done spec is never left open.

1. READ the spec. Confirm the work it describes is actually executed (check the
   files/repo it targets - do not take "done" on faith).
2. DECIDE archive vs promote:
   - PROMOTE if the spec produces a live change in a deployed artifact/repo - ship it
     first (the project's ship path), THEN archive.
   - ARCHIVE if the spec is a record of a decision with no separate live artifact.
3. MOVE the file with `Move-Item` (PowerShell) / `mv` - never Write-new + delete.
   Destination `<project>/decisions/` (create if absent) or `<project>/archive/`.
4. FLIP Status: in the moved file to `archived` (or `applied` then `archived` if promoted).
5. POINT: if the project's CHECKPOINT has an Open thread for this spec, mark it done /
   remove it in the same turn (do not leave a spoken "I'll update it later" promise).
6. CONFIRM in one line: archived-or-promoted + new path + what shipped.

## Rules
- The Closeout is mandatory in MODE A and unconditional in MODE B. Never write a spec
  without it; never leave a finished spec unarchived.
- Terse and action-first. No capability narration, no "I have access to...".
- Persist only the spec file (and its move). No scratch files.
- If a project/workspace CLAUDE.md names a different spec folder convention, it wins.
- If the ask is too big for one spec, spec PHASE 1 only and fence the later phases under
  Non-goals (with the why) or Open questions - do not write one sprawling spec.
