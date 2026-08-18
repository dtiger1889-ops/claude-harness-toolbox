# Token efficiency

Every word Claude reads costs tokens, and tokens are money or rate-limit headroom. These
are the habits that keep sessions cheap without sacrificing quality. (Several are
enforced by the installed workspace rulebook; this file is the why.)

## Model selection: principles, not a grid

- **Match the tier to the task shape.** Genuinely mechanical transforms (reading a
  CHECKPOINT and stating the next step, filling a template, summarizing a listing) run
  fine on the smallest current tier. Planning, tradeoffs, and multi-step judgment want a
  mid tier. Long-horizon autonomous work, architectural decisions, and anything that
  ships to a reader deserve the top tier.
- **Never the smallest tier for real work** — small models are for mechanical
  transforms, not anything requiring judgment.
- **Don't hardcode a task→model grid.** Model ratings go stale with every release, and a
  rigid matrix amplifies over-routing. Keep the principles; re-derive assignments as
  models change. (This is also why no model names appear here.)

## Sub-agent routing

- **Cost gate first — the task NOUN is not the trigger, the TOKEN WEIGHT is.** A
  sub-agent pays a fixed context-rebuild overhead (tens of thousands of tokens: it
  starts cold, re-explores, over-verifies), so routing pays only when inline would cost
  more. A handful of commands runs INLINE even when the category ("run tests", "restart
  the server") sounds routable. Litmus: "would inline cost more than ~30–40k tokens?"
  No → inline. Real incident: a ~4-command process restart routed to a sub-agent burned
  67k tokens / 26 tool calls to fire stop+start.
- **Once a sub-agent is warranted: intelligence > taste > cost, cost as tie-breaker
  ONLY.** Mechanical/bulk execution → mid tier. Anything user-facing or that ships →
  taste tier (usually: stays inline on the big model). Under subscription billing,
  "cost" means usage-pool depletion, not $/token.
- **Optional second-provider rung:** a separate CLI coding agent can take spec-frozen,
  repo-local, pure-code work — implementation from a frozen spec, bug fixes with a known
  repro, test writing. It gets zero session context and none of your MCP tools, so
  anything context- or tool-dependent stays home, and the primary agent reviews its
  output. Value = a second usage-limit pool. Gate it on the CLI actually being installed
  (probe the PATH), not on intent.

## File and reading habits

- **Front-load resume-critical sections.** Order CHECKPOINT so Status / Open threads /
  Next step come first and the changelog last — if anything truncates, the load-bearing
  part survives.
- **Pointers, not quotes.** "See CHECKPOINT.md → Open threads" beats pasting content.
- **Trust the checkpoint.** Don't re-read files already summarized there.
- **One open thread at a time.** Splitting attention floods context and hurts both tasks.
- The file budgets themselves (CLAUDE.md ≤ 30 lines, CHECKPOINT ≤ 120 lines / ~30KB, the
  root-file character budget) live in
  [maintaining-the-harness.md](maintaining-the-harness.md).

## A note on speed claims

The harness saves tokens on exploratory work; it does not necessarily save wall-clock
time. See [when-it-pays-off.md](when-it-pays-off.md) for the measured boundary.
