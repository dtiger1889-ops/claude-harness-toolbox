# Design history

This is a historical record of the public patterns that informed the toolbox. The source
survey was performed on 2026-05-19 and last reviewed on 2026-06-23. It is preserved to
explain design choices, not to claim that the comparison is current or exhaustive.

## Public patterns reviewed

| Reference | Useful pattern | Boundary observed in the 2026-05 survey |
|---|---|---|
| [Anthropic: Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) | Progress record, machine-readable feature state, initializer/coder separation | Optimized for long-running greenfield builds rather than a mixed multi-project workspace |
| [willseltzer/claude-handoff](https://github.com/willseltzer/claude-handoff) | Explicit handoff sections, especially failed approaches and resume instructions | Manually invoked and scoped to one repository |
| [Anthropic: Using CLAUDE.md files](https://claude.com/blog/using-claude-md-files) | Hierarchical instruction files and concise project guidance | Describes the instruction layer rather than a full state, enforcement, and archive system |
| [claudelint CLAUDE.md size rule](https://claudelint.com/rules/claude-md/claude-md-size) | A concrete size warning | Flags growth without prescribing where overflow should go |
| Community harness-writing discussions | Harness quality can outweigh model swapping; context should be layered | Published approaches varied widely and were usually simpler than mature private setups |

The comparison was limited to published artifacts. It cannot establish that a pattern was
unique, and it should not be read as a survey of private production harnesses.

## Patterns adopted

### Record failed approaches

Failed approaches are unusually valuable resume state because successful work leaves an
artifact while failed exploration often leaves nothing. The toolbox keeps them under Key
decisions instead of adding another permanent top-level CHECKPOINT section.

### Use structured sidecars for fixed checklists

For a stable release gate or audit list, a small JSON sidecar can hold per-item state while
Markdown carries rationale. This is optional: use it only when the same fixed checklist
must survive several sessions and free-form rewriting would lose state.

### Layer instructions and state

Hierarchical `CLAUDE.md` files, explicit resume state, and progressive disclosure were
consistent with the public guidance and became the base of the toolbox.

## Patterns deliberately not adopted as universal defaults

- **Initializer/coder agent split:** useful for autonomous build loops, but unnecessary
  overhead for many research, documentation, and small maintenance sessions.
- **A startup end-to-end test for every project:** appropriate for build systems, not a
  universal ritual for projects without an executable product.
- **Separate top-level Current State, Code Context, and Setup Required sections:** these
  duplicate Status, project guidance, or dedicated context files and make CHECKPOINT less
  scannable.
- **An append-only progress log as the primary resume artifact:** the toolbox uses a
  bounded whiteboard plus a separate archive so current state stays cheap to load.

## Choices this toolbox added

These were the distinguishing choices in the 2026 survey. They are design decisions, not
claims of exclusivity:

- Numeric file budgets plus an explicit overflow path.
- A SessionStart receipt that reports file presence and size, then requires a real read,
  instead of dumping state through a silently truncated hook channel.
- A date-led changelog archive and a byte-faithful mover so history is moved rather than
  summarized or retyped.
- A rule against promises that exist only in chat: either do the work or record it in
  durable state.
- Root-cause verification before naming a cause, and action instead of capability
  narration when the work is available in-session.
- Transcript-grounded skill selection: build tools for friction found in real sessions.
- A block-once, fail-open orientation gate that leaves read-only work free but enforces a
  CHECKPOINT read before state-changing actions.
- A multi-project ledger that can be extracted from the root instruction file when it
  becomes lookup data.
- Dated state and staleness checks so an old checkpoint is not mistaken for current truth.

## Later evolution

By 2026-08-18, the installer itself had accumulated much of this rationale. That made a
machine parse design history before it could install files. The repo therefore split the
roles:

- `harness_me.txt` is the terse execution contract;
- `README.md` explains the product and evidence;
- `docs/maintaining-the-harness.md` owns the maintenance procedure;
- this file preserves the dated comparison and adoption record;
- the separate benchmark repository owns the experiment and raw measurements.

That split applies the toolbox's own rule: the right layer is more valuable than more
prose in an always-read file.

## Sources retained from the survey

- [Anthropic: Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
- [Anthropic: Using CLAUDE.md files](https://claude.com/blog/using-claude-md-files)
- [willseltzer/claude-handoff](https://github.com/willseltzer/claude-handoff)
- [Anthropic Claude Code issue 11455](https://github.com/anthropics/claude-code/issues/11455)
- [Virtual monorepo pattern](https://medium.com/devops-ai/the-virtual-monorepo-pattern-how-i-gave-claude-code-full-system-context-across-35-repos-43b310c97db8)
- [claudelint CLAUDE.md size rule](https://claudelint.com/rules/claude-md/claude-md-size)
- [Harness engineering guide](https://dev.to/shipwithaiio/the-complete-claude-code-harness-engineering-guide-5-layers-8-deep-dives-3d4j)
- [Harness engineering best practices](https://nyosegawa.com/en/posts/harness-engineering-best-practices-2026/)
