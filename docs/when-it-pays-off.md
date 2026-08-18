# When the harness pays off (and when it doesn't)

The harness is not a free win on every task. It was tested across 154 paired Claude Code
trials (paired Wilcoxon, p < 0.05 unless noted), and the result is conditional: it pays
off on some task shapes and adds tax on others. Knowing the regime boundary is the
difference between deploying it well and over-applying it. The full experiment — report,
raw per-trial data, and the benchmark itself — is published at
[harness-benchmark-report](https://github.com/dtiger1889-ops/harness-benchmark-report).

## Three regimes, measured

| Task shape | Effect | Why |
|---|---|---|
| Trivial or pre-oriented prompt (the prompt names the file/path) | **Harness HURTS** (+35% to +136% output tokens, +64% to +80% cache reads) | Claude runs the startup ritual, finds no useful state, and burns tokens narrating it. |
| Structured single-project tasks | Neutral | Orientation cost ≈ orientation benefit. |
| Exploratory multi-project tasks (Claude must pick which folders matter) | **Harness WINS BIG** (−25% to −45% on read-side metrics) | Per-project CLAUDE.md lets Claude classify folders without reading them. Compounds into less exploratory chatter. |

## Practical rules that fall out of this

1. **Don't make Claude self-judge "am I oriented?" — let read-only work be free and let a
   gate enforce the rest.** Read-only operations never need orientation, so a genuinely
   pre-oriented prompt pays zero ritual tax automatically. For state-changing actions,
   enforce "read CHECKPOINT first" structurally with the orientation gate, not with a
   prose instruction. The maintainer originally shipped a self-judged "skip the ritual if
   pre-oriented" rule; a 50-session audit found the model applied it unreliably (acted
   before reading state in roughly 1 of 5 actionable sessions), so the rule was replaced
   by the gate.
2. **Hierarchy isn't ceremony.** Per-project CLAUDE.md files added another ~22% output
   savings, ~8% cache-read savings, and ~20% fewer logical turns on top of a
   top-level-only harness for exploratory tasks. Keep them even when they feel small.
3. **Stale CLAUDE.md is the actual production risk.** The benchmark used a frozen,
   accurate harness; in real use the danger is drift. Defend with the `Last updated:`
   line in each CHECKPOINT — it doubles as a "verified against reality" stamp.
4. **Don't pitch this as "always faster."** Wall-clock didn't track tokens: exploratory
   tasks saved 25–45% on output while costing up to +14% on duration (reading CLAUDE.md
   adds latency even when it saves downstream work). Tokens cost money; wall-clock costs
   patience. Two different axes.
5. **The harness doesn't relieve context-window pressure.** Peak context was unaffected
   across all 154 trials. It compresses what Claude *seeks out*, not what Claude needs
   in flight. If you hit compaction, that's a separate problem the harness won't solve.

## The clearest winning regime

Multi-project personal work where the question is "which of these projects does the user
mean?" That is exactly the shape the layout — projects as siblings under a single
ledger — was designed for.
