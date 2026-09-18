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

## 2026-09-18: from a routing rule to routing hooks

This section records why the toolbox gained four delegation hooks, in order, so the
reasoning can be checked rather than trusted.

### The rule as prose (2026-07-09 to 2026-09-16)

The workspace had a written model-routing rule since 2026-07-09: a cost gate (hand work to
a sub-agent when inline work would exceed roughly 30-40k tokens), Sonnet for mechanical
bulk, the taste tier for anything that ships, never Haiku for real work. It was adapted
from a public cost/intelligence/taste matrix after an adversarial pass rejected the
verbatim grid (subscription billing makes token price the wrong currency; model names churn;
a per-task matrix invites over-routing). Two later additions came from a review of two
community sub-agent setups: every spawn names its model (2026-09-16), and delegated work
that ships is checked against the original brief, by a fresh reviewer agent once three or
more tasks are in flight.

Two mechanical aids were built after the rule failed twice: a PostToolUse counter that
prints one reminder past 600 inline code lines (2026-09-02), and a prompt-time reminder
that fires when a prompt hands over a list of three or more items plus a go-word
(2026-09-14, after the counter missed a four-item spec-frozen batch done through many small
edits). Anthropic had declined a built-in pre-spawn policy hook
([issue 55144](https://github.com/anthropics/claude-code/issues/55144)), so both stayed
local and advisory.

### The audit (2026-09-18)

The owner asked whether the top-tier model had been applying the ladder. The check read the
session transcripts themselves rather than the lapse ledger, because the ledger records what
someone noticed, and the sharpest finding had never been noticed. Across 130 sessions of the
top-tier model (55 in the first seventeen days of September):

- It delegated when told: 228 spawns since 09-01, model naming compliant after the rule.
- It did not delegate by default: ten owner prompts in fifteen days were needed to start or
  restart delegation, and three sessions that opened with an orchestrate instruction still
  drifted back to typing code within the same session.
- The two aids had not reached it: the line counter fired in three sessions ever and was
  followed by 954 more inline lines in one of them; the prompt-time reminder had fired zero
  times in a top-tier session. Both were blind to shell heredoc writes, which the runtime's
  own auto-mode reminder pushes the model toward.
- The never-Haiku rule leaked through a side door: all ten Haiku sub-agent runs on disk were
  spawns of the built-in documentation-lookup agent with no model named. That agent pins
  Haiku in its own definition, which outranks the environment variable that would otherwise
  force a model, so only a per-call `model` can override it
  ([sub-agents docs](https://code.claude.com/docs/en/sub-agents)). Two of those ten runs
  produced the month's two false "not possible" capability claims the owner had to correct.

### What the outside pass changed

Before designing, a shipped-solutions sweep asked what already existed. Findings that
shaped the build: a PreToolUse hook can match the `Agent` tool and read its input, but
cannot rewrite the spawn's model because `updatedInput` is ignored for that tool
([issue 44412](https://github.com/anthropics/claude-code/issues/44412)), so the gate blocks
and says rather than fixes; hook input carries `agent_id` only inside a sub-agent
([hooks reference](https://code.claude.com/docs/en/hooks)), which is what lets a write-block
distinguish the orchestrating session from its workers; a published dotfiles repo re-injects
a one-line delegation policy on every prompt because "a rule seen thousands of tokens
earlier loses" at the first tool call ([dotclaude PR 379](https://github.com/Jerry0022/dotclaude/pull/379));
and the nearest packaged orchestrator ([pilotfish](https://github.com/Nanako0129/pilotfish))
is prompt-only, keeps main-session coding, and uses Haiku for scouting. Nothing shipped
blocks the main session from writing code once it has said it is orchestrating.

### The decisions

The owner was interviewed on twelve forks before anything was written. The picks:

- A hard block, every time, on any spawn with no model or with Haiku. The escape is to
  name the model, which is the rule.
- An orchestrator mode, per session: on by phrase ("orchestrate", "delegate the rest",
  "act as an orchestrator") or a `/orchestrate` skill, off by phrase ("go inline", "stop
  orchestrating"). While on, the main session may write docs and the checkpoint only; any
  code write, including a shell heredoc, is refused with a one-line redirect to spawn a
  named-model worker. Workers are exempt by construction.
- The mode also turns on by itself after 150 cumulative inline code lines, because the
  owner's stated feel was "I never have to say orchestrate again" while the rejection
  criteria were a false block on a small edit and slower sessions; a threshold lets small
  fixes stay inline and stops a build before it is deep.
- One short delegation line on every real prompt, replacing the list-detecting reminder
  that never fired where it mattered.
- Repair the line counter: find why it stayed silent in the two largest inline sessions
  and count shell writes.

### What was rejected and why

- Widening the list-detector's trigger (recognise a spec path plus "go"): another proxy on
  the same fading-rule problem; the shipped answer is re-injection, not a smarter trigger.
- Rewriting the model from the hook: not possible for the `Agent` tool (issue 44412).
- A budget or usage-window model of delegation (dotclaude PR 382): a different question
  (how much to spend) from the one being fixed (whether the rule is applied at all).
- Enforcement in runtimes without hooks: the rule stays prose there.

The four hooks, their wrapper tests and the dated provenance of every ladder rule live in the
companion [Agent Ladder](https://github.com/dtiger1889-ops/agent-ladder) repository
(`hooks/`, `tests/`, `HISTORY.md`); the private build record, with the transcript counts above
and their scan scripts, stays in the owner's workspace.

## Sources retained from the survey

- [Anthropic: Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
- [Anthropic: Using CLAUDE.md files](https://claude.com/blog/using-claude-md-files)
- [willseltzer/claude-handoff](https://github.com/willseltzer/claude-handoff)
- [Anthropic Claude Code issue 11455](https://github.com/anthropics/claude-code/issues/11455)
- [Virtual monorepo pattern](https://medium.com/devops-ai/the-virtual-monorepo-pattern-how-i-gave-claude-code-full-system-context-across-35-repos-43b310c97db8)
- [claudelint CLAUDE.md size rule](https://claudelint.com/rules/claude-md/claude-md-size)
- [Harness engineering guide](https://dev.to/shipwithaiio/the-complete-claude-code-harness-engineering-guide-5-layers-8-deep-dives-3d4j)
- [Harness engineering best practices](https://nyosegawa.com/en/posts/harness-engineering-best-practices-2026/)
