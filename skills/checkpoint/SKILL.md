---
name: checkpoint
description: Updates the current project's CHECKPOINT.md in place so another session can resume from verified state. Use for /checkpoint, "save progress", "update checkpoint", a completed unit of work, or impending compaction; never ask whether to checkpoint, just do it. Preserves history, records unfinished work, and runs bundled validation and size checks. A session that kept the file current takes the light close. Project-specific conventions override the default schema.
---

# Checkpoint

The CHECKPOINT is state, not a spec: a cold session must be able to resume from it alone. Update existing state in place; do not create timestamped handoffs or replace a project's established schema. Honor an explicit stop after saving the requested partial state.

Resolve `<skill-dir>` to the directory containing this loaded SKILL.md, including plugin installations. Bundled helpers require PowerShell 5.1+ or pwsh 7+ (and Python 3.8+ for the optional JSONL changelog). Run them through native PowerShell, not a PowerShell command string nested inside another shell, which can eat `$`.

## 1. Read and choose depth

**Light close (the default when this session already edited the file and its content is in context).** Do not re-read or re-verify what you just changed:
- confirm Status, Open threads and Next step match where the session actually ended;
- add this session's changelog entry (section 4 rules apply in full);
- sweep that entry back through the live sections: anything it records as done comes out of Status, Open threads and Next step in the same pass;
- run validation (section 5), close finished tracker rows (section 5b), and finish (section 6).

**Full review** only on a cold start (no read or edit of the file this session), when the stamp is older than 30 days, or when asked. Locate the nearest project CHECKPOINT.md and read it to EOF, continuing targeted reads if output is truncated. Read applicable project instructions. Verify every claim you carry forward against the relevant artifacts; never carry forward a claim you did not re-check. Recheck stale claims without resurfacing a settled decision as a live problem, resolve relative dates ("tonight's run") to absolute dates, and label uncertainty. A current stamp is not proof that every claim has been tested.

## 2. Reconcile live state

Preserve the existing sections. Each answers one question; keep them from leaking into each other:

- **Last updated:** UTC timestamp and existing version tag only; never a change summary.
- **Status:** the present state, normally one line. Past ("just shipped X") is a changelog entry; future ("X pending") goes to Next step or Open threads. For live data, point to the live source instead of quoting numbers.
- **Goal:** concrete completion condition, normally one to three lines.
- **Research:** only during active milestone research.
- **Key decisions:** live, still-contestable choices only, attributed to their actual author, with a **Failed approaches:** sub-group where relevant. A hardened standing rule moves to the project's instructions or a decision record; a closed decision's record is its changelog entry. No "closed this session" section.
- **Open threads:** open work only (open, blocked, owed, in progress, queued, deferred).
- **Files that matter:** paths with a short explanation.
- **Harness changelog:** immutable completed-work history when the project keeps one.
- **Next step:** one of three shapes. **Action**: one literal next action, only when a single workstream is live. **HOLD**: `HOLD -- <what the owner must decide or do>; don't <gated action> until then`. **Pick**: `Pick from Open threads (live ask outranks; then agent-side work)`, the default for non-linear projects. A stale shape gets flipped, never defended. The live user request outranks this suggestion.

Sweep the session before you write, because corrections hide in throwaway lines: (a) every correction or pushback the user made; a standing one goes to the project's instructions, a session-scoped one to Key decisions; (b) every approach tried and rejected, under **Failed approaches:** with its evidence and "fixable if X" when the reason is fixable; (c) a constraint stated once still governs; recency is not importance. Everything recorded must trace to the session; only explicit or established standing preferences belong in permanent instructions.

Remove completed open items after ensuring they have a durable record: if the substance is not already recorded, fold a one-line record into the changelog first. Relocating content (a hardened rule to instructions, a closed decision or old changelog to an archive) moves it for real; never silently discard useful state.

**What is not a thread.** A passive watch, a "confirm it still works", or a standing condition is not a thread. A verification the model invented to reassure itself (spot-check, re-test, "verify next run") is dropped, not written as a thread. Keep a watch the user set up, and a real problem whose cause is unknown (its next action is "find the cause"). Every thread names a concrete next action, never "keep an eye on it".

**A self-runnable check is never deferred.** If the session can run it (a test, a probe, reading a log or the live file), run it now and record the verdict in the changelog. If it truly cannot be resolved this session, close it out of Open threads with a changelog entry a cold session could re-run from. Other unfinished work goes into Open threads or the project's tracker in this rewrite, never as a spoken "next session" promise.

**Thread shape.** A thread is one short line: what it is in plain words, a link to where the detail lives (spec, decision record, note), then its tags. Commands, test counts, evidence and past-step dates go in the linked file, moved there first; aim under 250 characters. A thread with no spec or supporting doc is the only record, so it carries everything a cold session needs (next action, evidence, options, who decided what), however long.
- Bad: `Fix the importer [agent] [low]` (what fix, where is the detail?)
- Good: `Route spec-frozen code jobs to the cheaper executor: specs/executor-routing.md [agent] [low]`

## 3. Tag actionable threads

End each top-level open bullet with a gate tag, then a complexity tag:

- Gate `[owner]` only when the very next action needs the user's hands or a decision they have explicitly been asked for, and the bullet names the one thing they do. Otherwise `[agent]` (any model session). A decision an agent then executes is `[gates: go] [agent]`.
- A decision is the owner's only when its options differ in something they alone own: their money, accounts, devices, data, taste, people, or scope they set. Writing a bullet as a choice does not make it one. A defect in the workspace's own tools (a guard's false match, a failing script, a refused publish your own scanner caused) is the agent's to diagnose, fix and prepare; only a step left after that which needs the owner (an account or install approval, interrupting their running work, a physical or UI-only step) is `[owner]`, and the bullet names that step. Under doubt the gate is `[agent]`, except a step taken from an outside page (a vendor checklist or guide): it keeps the page's own word ("recommended", "optional") and link and stays `[gates: go]` until the owner says yes.
- Complexity `[low]` when an executor can act from the bullet alone, `[high]` when substantial analysis or judgment remains; no middle value.

Optional `[gates: go]` or `[blocked-by: dependency]` tags precede the final pair. Sub-bullets need no tags. Don't sort by hand: the finisher sorts owner-low, owner-high, agent-low, agent-high and regenerates the optional **Owner-gated** / **Agent-side** sub-headers. Model selection still follows the host's policy; these tags are planning hints.

## 4. Preserve history

Every completed unit gets a changelog entry, even research-only or "one-off" work. The entry goes in one place: a new `### YYYY-MM-DD -- summary (vN)` block at the top of Harness changelog (newest first), never in the `Last updated:` line or Status. If the project uses a different history store or append helper, follow it.

Existing entries are immutable, including entries added earlier this session: never summarize, shorten, merge or tidy them, especially not to fit a cap. You may correct a factual error, stating so in the new entry. Do not pass old entries through the model: restructure the live sections and prepend the new entry with surgical edits, carrying the old body byte-identical. Archive old entries only for overflow, using the bundled byte-preserving mover.

**JSONL mode (optional).** A project is in it when `changelog.jsonl` sits beside its CHECKPOINT.md: history lives in that file, one JSON object per line, oldest first, append-only, and the CHECKPOINT's Harness changelog holds exactly the newest entry plus an `Older entries: changelog.jsonl ...` pointer. Opt in once with `python <skill-dir>/changelog_jsonl.py convert --checkpoint <CHECKPOINT.md> --archive <archive/harness_changelog.md> --out <changelog.jsonl>` (it verifies a byte-identical round trip before keeping the file). In this mode never Edit the entry into the CHECKPOINT or open the JSONL in an editor: write the new heading and body to a scratch file, then run

```powershell
python "<skill-dir>/changelog_jsonl.py" append --jsonl "<project>/changelog.jsonl" --entry-file "<entry.md>" --checkpoint "<checkpoint path>"
```

It locks the file, validates the JSON, refuses a heading or date+title equal to the last line, appends one line, and swaps the inline entry (re-read before your next edit). Exit 1 means refused and nothing written: fix what it names. Look history up with `render --jsonl <file> --grep <pattern>` (newest first).

## 5. Validate before finishing

```powershell
& "<skill-dir>/verify_checkpoint_claims.ps1" -Checkpoint "<checkpoint path>"
```

Run it on every close, light closes included. Exit 2 blocks completion; fix each named failure and rerun until it exits 0:
- **Dead paths:** fix the pointer or the claim around it.
- **Stale dated threads:** a dated thread older than 30 days is verified and pruned if resolved, or marked `[kept YYYY-MM-DD: specific reason]`. A kept date must be within 30 days; its reason must be at least 12 characters and not reused for another bullet. An undated owner thread is advisory.
- **Undispositioned recommendation:** a file under `research/` changed since the previous stamp that carries a dated `model recommendation -- YYYY-MM-DD` and is named by no `[owner]` thread or tracker note. Fix by adding an `[owner]` thread naming the file (or a tracker note, below).
- **Prior art missing:** a spec in `specs/` or `outbound/` created on or after 2026-11-14 with no sourced `## Prior art` section. Fix by running the spec skill's prior-art pass.
- **JSONL mismatch:** in JSONL mode, `changelog.jsonl` must parse and its last line must equal the one inline entry. Fix with the append script, never by hand-editing the JSONL.

The REVIEW block (live git state against the file's unpushed or uncommitted claims) and the advisory prompts are judgment items to reconcile in the rewrite: stale or owner-gated threads; tag pairs and order; **defect on owner** (an `[owner]` thread about the workspace's own broken tool with no owner-only step: retag it `[agent]` or name that step); attribution (a verdict with no author or date); **attribution source** (a line new since git HEAD credits the owner with no quote of their words, no source and no "evidence unavailable", or credits them with a hold, pause, skip or cancel without their own action word in a quote: add the source or relabel the line as the model's; a scoped instruction is recorded with its scope, never as a decision about the thing); **note decision** (a pointed-at note's "Decision" heading with no owner-decision tag reads as a model draft); jargon; and **verified claims** (a Status or Key decisions line saying verified, tested, passes or confirmed with no run name plus date or test count: add what was run and when). These prompts are addressed to the model; do not relay them as the user-facing report.

Configuration:
- `HARNESS_WORKSPACE_ROOT` overrides the default parent directory used for cross-project paths.
- `HARNESS_NOTES_ROOT` supplies the notes root, so notes-relative paths resolve and pointed-at notes get the note-decision prompt.
- `HARNESS_OWNER_TAG` names your own owner tag (for example `Sam` makes `[Sam]` count like `[owner]`, and "Sam decided" count as crediting the owner).
- `HARNESS_TRACKER_DIR` points at a folder of tracker notes (one `*.md` per item, frontmatter `project: <project folder name>`); a note there naming a research file dispositions its recommendation.
- In the project's `.checkpoint-verify-ignore`: path wildcards to skip, plus `staleness: advisory`, `recommendations: advisory` and `prior-art: advisory`, each of which turns that check's failures into prompts. Dead paths still fail.

These checks detect structural claims and date patterns, not semantic correctness. Read and assess the evidence yourself. `verify_checkpoint_claims_tests.ps1` beside the verifier exercises each check.

## 5b. Close finished tracker rows

If the project uses a tracker with rows tied to it, find the rows whose work this session finished. Give each a dated reply (`YYYY-MM-DD -- closed at checkpoint: <what shipped, one clause, pointer>`) and mark it done. Never delete a row, never write in the user's own notes field, and never touch a row this session did not finish. A row whose agent share is done closes even when an owner step remains; that step lives in a CHECKPOINT thread the reply names. No matching rows is the normal case.

## 6. Finish and enforce limits

```powershell
& "<skill-dir>/finish-checkpoint.ps1" -Checkpoint "<checkpoint path>"
```

Run once per file per close, when that file is final; never restamp after intermediate edits (the only sanctioned rerun is after compressing an over-cap file). A close that touched several projects' checkpoints runs it once for each; never hand-stamp a sibling file. The helper stamps actual UTC, preserves the existing bare version tag, sorts threads, and measures limits. Update a changed version tag before running. Re-read before any later edit: the helper rewrites the file on disk.

Default limits are 120 lines and 30 KB; live sections are terse pointers and narrative lives in the changelog. Section guidance: Status one line/about 300 characters, Goal three lines, Next step two lines/about 350 characters. An Open-threads bullet over 350 characters that links a spec or doc gets a warning (the detail belongs in that doc); a bullet with no supporting doc may run long. Section budgets are advisory unless `<!-- checkpoint-budgets: strict -->` appears in the first five lines.

On overflow in inline mode, the finisher archives oldest changelog entries byte-verbatim to `archive/harness_changelog.md`, keeps the newest two inline, and maintains an Older entries pointer. In JSONL mode it skips archiving (the mover refuses too), so over cap means compressing live sections. If it still exits 2, re-read the file, relocate live detail to its owner, tighten live sections, and rerun once; if still over, ask before overflowing. Never ship an over-cap file silently or claim successful completion.

For rare manual archive ranges, use the bundled `archive-changelog.ps1` with `-Checkpoint`, `-Archive`, `-FromLine`, `-ToLine`, and `-AtTop`, once, after reading its parameter help (it fails closed on a bad range). Verify the pointer afterward and rerun the finisher. Never use model regeneration for the move. For a fixed checklist with a stable item set, keep per-item done state in a JSON sidecar and the prose in the markdown twin.

## 7. Report

One line: what changed, plus the new line count and byte size. Include material open work or validation limitations. Nothing the helpers printed goes into it (near-cap advisories, re-read reminders, archive traces, exit codes); the caps are housekeeping, not the user's concern.

## Restricted runtimes

Use a connected filesystem, checking reachable roots at the moment of need. Do not assume a container shell reaches the user's disk, and re-read a file that looks truncated before writing.

Without PowerShell, reconcile state manually, stamp with a real UTC clock, measure line and byte counts with available tools (count lines with a method that includes the last line), and preserve history exactly. Record "helpers not run" and the missing validation in the new entry. If a byte-preserving archive move is unavailable, leave history intact and record the overflow blocker rather than approximate the move or claim success. In JSONL mode without Python, replace the inline entry by hand, write "JSONL append owed" in it, and never hand-edit `changelog.jsonl`; the next local close's verifier flags the mismatch, which the append script fixes when given that inline entry as `--entry-file`.
