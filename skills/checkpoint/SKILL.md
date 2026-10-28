---
name: checkpoint
description: Updates the current project's CHECKPOINT.md in place so another session can resume from verified state. Use for /checkpoint, "save progress", "update checkpoint", a completed unit of work, or impending compaction. Preserves history, records unfinished work, and runs bundled validation and size checks. Project-specific conventions override the default schema.
---

# Checkpoint

Update existing state in place; do not create timestamped handoffs or replace a project's established schema. Honor an explicit stop after saving the requested partial state.

Resolve `<skill-dir>` to the directory containing this loaded SKILL.md, including plugin installations. Bundled helpers require PowerShell 5.1+ or pwsh 7+. Run them through native PowerShell.

## 1. Read and choose depth

Locate the nearest project CHECKPOINT.md and read it to EOF, continuing targeted reads if output is truncated. Read applicable project instructions.

Use a light close when this session already read and kept the file current: reconcile the live sections, add the completed unit's changelog record where the project keeps one, then validate and finish. Use a full review on a cold start, when the stamp is older than 30 days, or when requested. A light close still runs validation.

Verify claims you carry forward against the relevant artifacts. Recheck stale claims, resolve relative dates to absolute dates, and label uncertainty. A current stamp is not proof that every claim has been tested.

## 2. Reconcile live state

Preserve the existing sections. Default project schema:

- **Last updated:** UTC timestamp and existing version tag only.
- **Status:** present state, normally one line; for live data, point to the live source.
- **Goal:** concrete completion condition, normally one to three lines.
- **Research:** only during active milestone research.
- **Key decisions:** choices still relevant to current work, attributed to their actual author. Point to durable decision records for settled detail.
- **Open threads:** actual unfinished actions, dependencies, or user-requested watches.
- **Files that matter:** paths with a short explanation.
- **Harness changelog:** immutable completed-work history when the project keeps one.
- **Next step:** one action, an explicit hold, or a pointer to choose from open work. The live user request outranks this suggestion.

Sweep the session for decisions, constraints, corrections, rejected approaches, and unfinished work. Record rejected approaches with their evidence and any condition for revisiting them. Keep session-specific feedback scoped to this work; only explicit or established standing preferences belong in permanent instructions.

Remove completed open items after ensuring they have a durable record. Relocate content to its real owner before removing it; never silently discard useful state.

An unresolved known defect remains open even when it cannot be checked now. Run checks within the current authorized scope when feasible. Do not invent future reassurance checks or watches with no evidence of a problem; retain watches the user explicitly requested.

## 3. Tag actionable threads

For the default tagged schema, end each top-level open bullet with:

- `[owner] [low]` or `[owner] [high]` when the next step needs the user's hands or an explicit decision.
- `[agent] [low]` or `[agent] [high]` for agent work.

Use low when an executor can act from the bullet alone, high when substantial analysis or judgment remains. Spell out the action in plain words. Optional `[gates: go]` or `[blocked-by: dependency]` tags precede the final pair. Sub-bullets need no tags.

The finisher sorts owner-low, owner-high, agent-low, agent-high. Model selection still follows the host's policy; these tags are planning hints.

## 4. Preserve history

Every completed unit gets an entry in the project's existing changelog, including research-only work. Default inline entries are newest-first `### YYYY-MM-DD -- summary (vN)` blocks under Harness changelog. If the project uses a different history store or append helper, follow it.

Existing entries are immutable, including entries added earlier this session. Use surgical edits; carry old history byte-identically. Only correct a factual error when needed and record that correction in the new entry. Do not summarize or merge history to fit a cap.

Archive old entries only for overflow, using the bundled byte-preserving mover. Keep live sections concise and history in its proper section.

## 5. Validate before finishing

```powershell
& "<skill-dir>/verify_checkpoint_claims.ps1" -Checkpoint "<checkpoint path>"
```

Exit 2 blocks completion for dead paths or undispositioned stale dated threads. Fix errors and rerun. Reconcile advisory prompts about state, attribution, tags, jargon, and verification claims; do not relay internal diagnostics as the user-facing report.

For a dated thread older than 30 days, verify and prune if resolved, or add `[kept YYYY-MM-DD: specific reason]`. A kept date must be within 30 days; its reason must be at least 12 characters and not reused for another bullet. An undated owner thread is advisory.

Configuration:
- `HARNESS_WORKSPACE_ROOT` overrides the default parent directory used for cross-project paths.
- `HARNESS_NOTES_ROOT` supplies the notes root when required.
- `HARNESS_OWNER_TAG` names your own owner tag (for example `Sam` makes `[Sam]` count like `[owner]`).
- `staleness: advisory` in the project's `.checkpoint-verify-ignore` changes stale-date errors to prompts; dead paths still fail.

These checks detect structural claims and date patterns, not semantic correctness. Read and assess the evidence yourself.

## 6. Finish and enforce limits

```powershell
& "<skill-dir>/finish-checkpoint.ps1" -Checkpoint "<checkpoint path>"
```

Run once when each touched checkpoint is final. The helper stamps actual UTC, preserves the existing bare version tag, sorts threads, and measures limits. Update a changed version tag before running.

Default limits are 120 lines and 30 KB. Section guidance: Status one line/about 300 characters, Goal three lines, Next step two lines/about 350 characters. Open bullets over 700 characters get warnings. Section budgets are advisory unless `<!-- checkpoint-budgets: strict -->` appears in the first five lines.

On overflow, the finisher archives oldest changelog entries byte-verbatim to `archive/harness_changelog.md`, keeps the newest two inline, and maintains an Older entries pointer. If it still exits 2, re-read the modified file, relocate live detail to its owner, tighten live sections, and rerun. Report a remaining blocker; do not claim successful completion.

Re-read before any edit after a helper run because it changed the file on disk. For rare manual archive ranges, use the bundled `archive-changelog.ps1` with `-Checkpoint`, `-Archive`, `-FromLine`, `-ToLine`, and `-AtTop`; read its parameter help before choosing a range. Verify the pointer afterward. Never use model regeneration for the move.

## 7. Report

Confirm the state saved and its path briefly. Include material open work or validation limitations; omit housekeeping output.

## Restricted runtimes

Use a connected filesystem, checking reachable roots when necessary. Do not assume a container shell reaches the user's disk.

Without PowerShell, reconcile state manually, use a real UTC clock, measure line and byte counts with available tools, and preserve history exactly. Record "helpers not run" and the missing validation in the new entry. If a byte-preserving archive move is unavailable, leave history intact and record the overflow blocker rather than approximate the move or claim success.
