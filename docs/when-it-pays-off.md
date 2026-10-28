# When the harness pays off (and when it doesn't)

The harness is not a free win on every task. It was tested across 154 paired Claude Code
trials (two-sided Wilcoxon signed-rank on the paired differences), all on one pinned
model, `claude-sonnet-4-6`. The full experiment — report, raw per-trial data, and the
benchmark itself — is published at
[harness-benchmark-report](https://github.com/dtiger1889-ops/harness-benchmark-report).

## What was measured

| Task shape | Effect on cost | Why |
|---|---|---|
| Trivial, or the prompt already says where to look | **Harness costs more** (+14% to +31%) | The agent runs the startup ritual, finds no useful state, and pays for it. |
| Harness pre-built on one structured task | Costs a little more (+7%) | Orientation cost slightly exceeds its benefit. |
| Everything else, including exploratory multi-project tasks | Roughly neutral (−5% to +6%, not significant) | Some token savings (on one task, 13% fewer cached reads) are offset by more cache writes, so the bill stays flat. |

**Correction (2026-10-17).** Earlier versions of this page said the harness "wins big" on
exploratory tasks (−25% to −45%). That figure came from a counting error in the original
analysis, which counted most API calls two or three times; the benchmark report explains
it in full. No task got cheaper with the harness.

**What was not measured:** every trial was one fresh session. The harness exists to carry
state from one session to the next, and that was never tested.

## Practical rules that still hold

1. **Don't make the agent self-judge "am I oriented?" — let read-only work be free and let a
   gate enforce the rest.** Read-only operations never need orientation, so a genuinely
   pre-oriented prompt pays less ritual tax automatically. For state-changing actions,
   enforce "read CHECKPOINT first" structurally with the orientation gate, not with a
   prose instruction. The maintainer originally shipped a self-judged "skip the ritual if
   pre-oriented" rule; a 50-session audit found the model applied it unreliably (acted
   before reading state in roughly 1 of 5 actionable sessions), so the rule was replaced
   by the gate.
2. **Hierarchy reads less but costs the same.** A full per-project hierarchy read less than
   a single top-level file on exploratory tasks, but cost the same. Keep per-project files
   for clarity and resumability, not for savings.
3. **Stale CLAUDE.md is the actual production risk.** The benchmark used a frozen,
   accurate harness; in real use the danger is drift. Defend with the `Last updated:`
   line in each CHECKPOINT — it doubles as a "verified against reality" stamp.
4. **Don't pitch this as cheaper or faster.** In a single session it is at best
   cost-neutral and costs more on trivial tasks. Its case is continuity: picking up work
   in a later session without re-explaining it.
5. **The harness doesn't relieve context-window pressure.** There is no evidence in the
   benchmark that it delays compaction. If you hit compaction, that's a separate problem.

## Where it fits

Multi-project personal work that spans many sessions, where the question each time is
"what was done, what's open, and which project does the user mean?" That is the shape
the layout — projects as siblings under a single ledger — was designed for, and the part
the benchmark has not yet tested.
