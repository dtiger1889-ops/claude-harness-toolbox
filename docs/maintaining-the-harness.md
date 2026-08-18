# Maintaining the harness

This is the human-facing maintenance guide. It is intentionally separate from
`harness_me.txt`, which is an installation contract read by a machine.

The central maintenance rule is simple: put information in the narrowest layer that is
guaranteed to be read or fired when it matters. Do not make every session pay for
explanations, history, or procedures it does not need.

## What belongs where

| Artifact | Owns | Move content out when |
|---|---|---|
| Workspace `CLAUDE.md` | Stable workspace-wide rules and pointers | A list becomes lookup data, a procedure gains several steps, or a rule applies only to one project |
| Project `CLAUDE.md` | Stable project purpose, key paths, working rules, and gotchas | Mutable status appears or the file exceeds the toolbox's 30-line target |
| `CHECKPOINT.md` | Current status, decisions, open threads, and resume state | History crowds out current state or the file approaches 120 lines / 30 KB |
| Hook | Deterministic behavior tied to a session or tool event | The behavior requires judgment rather than a mechanical condition |
| Skill | A reusable multi-step procedure | The content is reference material rather than a procedure |
| On-demand document | Ledgers, routing tables, rationale, research, and history | A fact must be known in every session rather than followed through a pointer |

These are toolbox defaults, not platform laws. Keep a tighter budget when the file is
mostly optional context. Relax one only after measuring that the extra material improves
the sessions that always load it.

## Diet an always-loaded rulebook in two passes

Run a diet when the platform reports a size warning, the rulebook consumes a material
share of context, sessions repeatedly read irrelevant instructions, or two parts of the
harness claim authority over the same behavior.

### Pass 1: compress in place

1. Preserve the full pre-edit text in a recoverable history location.
2. Reduce each rule to: trigger, directive, pointer.
3. Move incident narratives and lengthy rationale to on-demand documents.
4. Keep the rule's enforcement and exception boundaries; those are usually the valuable
   parts.

In the maintenance pass that produced this method, compression removed 28% of the
always-loaded file without dropping a rule.

### Pass 2: extract by layer

When compression is not enough:

1. Move project ledgers and routing tables to an on-demand index.
2. Move multi-step procedures to the skill that executes them.
3. Move rules tied to a recognizable tool event into a hook.
4. Move design explanations and comparison history into `docs/`.
5. Leave one pointer at the original load point when a session must know where to look.
6. Delete duplicate authority. A procedure should not be independently maintained in a
   rulebook and a skill.

The measured extraction behind this repo reduced one root rulebook from 239 lines / 40.6
KB to 146 lines / 22.3 KB and roughly halved its reported memory footprint. At that time,
Claude Code warned on memory files at roughly 40,000 characters or 5% of the selected
model's context window. Treat platform thresholds as version-sensitive; the important
measure is the context charged to every turn.

## Sweep contradictory imperatives

Compression does not catch rules that are individually clear but collectively
incompatible. Audit every `always`, `never`, `must`, and `required` statement:

1. Group rules by the event they govern.
2. Mark pairs that can demand different actions from the same event.
3. Replace each pair with one precedence rule that names the condition separating the
   behaviors.
4. Verify hooks and skills implement the same precedence.

A contradiction left in two always-loaded rules becomes an execution-time coin flip.

## Keep CHECKPOINT a whiteboard

`CHECKPOINT.md` is mutable state, not an append-only journal. Rewrite it in place. When it
approaches either toolbox cap:

1. Move the oldest changelog entries to `archive/harness_changelog.md` without retyping
   them.
2. Remove closed work from Open threads after its durable result is recorded elsewhere.
3. Compress dense bullets while retaining decisions, blockers, evidence, and exact resume
   points.
4. Re-run both line and byte checks; either cap can fail independently.

The checkpoint skill and archive helper in this repository encode that procedure.

## Ground new skills in your own transcripts

Claude Code keeps full session transcripts under `~/.claude/projects/`. Before building
a skill suite, have Claude crawl your real sessions for friction phrases and bucket them
by candidate tool — then build only for friction that proves out. The maintainer's
631-session crawl inverted the expected priorities: the anticipated friction ("I'm
overwhelmed, simplify") came back near-empty, while the dominant, repeated friction was
laziness/punting — stopping at "can't determine" with the data in reach, or narrating
capability instead of acting. One planned tool was demoted and another survived only as
a terser reframe of itself. Pair this with the promote-failing-rules principle: a rule
you have re-written three times and still watched fail is the textbook case for a skill
or a hook.

## Outside-audit the rulebook

Use a fresh agent context periodically. A different model or vendor can help, but the
important property is that the auditor did not author the current rulebook and must
inspect the live artifacts.

Give the auditor the always-loaded files, installed hooks, installed skills, load paths,
and current platform documentation. Ask it to report:

- contradictory imperatives;
- procedures maintained in more than one place;
- prose already enforced by a hook;
- content stored at a broader layer than its audience requires;
- stale platform claims or broken pointers.

Treat the report as evidence to verify, not instructions to apply blindly:

1. Corroborate every finding against live files and actual load paths.
2. Implement high-confidence findings.
3. Hold findings the auditor cannot justify, with the missing context recorded.
4. Track each finding as `DONE` or `HELD`, including evidence and rationale.
5. Test a fresh session: no size warning, lower context footprint, correct orientation,
   working hooks, and no broken pointers.

An outside auditor can spot duplication while still missing why one session type only
loads the root file. Verification is what separates a useful audit from a rewrite by
someone with less context.
