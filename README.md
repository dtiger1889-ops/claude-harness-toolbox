# Claude Code Harness Toolbox

A tested, empirically-grounded "harness" for [Claude Code](https://claude.com/claude-code):
a small set of files, hooks, and custom skills that give Claude durable memory across
sessions, structural orientation discipline, and on-demand self-correction tools.

**The core problem:** Claude's context window is finite and resets between sessions.
Without a harness, every session starts from scratch, re-reading the same files, with no
reliable way to know what was done, what's open, or where to pick up. This toolbox is the
storage layer: `CLAUDE.md` for stable facts, `CHECKPOINT.md` for compressed mutable state,
hooks that surface and enforce them, and a suite of skills that encode the conventions so
you never re-explain them.

## Quick start

Flip over to the "</> Code" tab in Claude Desktop (or open a fresh Claude Code session),
set the permission mode to Manual or Accept edits for your security, set the model to
Sonnet or Opus, and paste:

> Read this repository and tell me if it will help improve my Claude workspace:
> https://github.com/dtiger1889-ops/claude-harness-toolbox

Claude will ask for your permission to fetch and read this page before it tries to
download anything. When you're ready to install, [`harness_me.txt`](harness_me.txt) is the
machine-oriented installer Claude follows. It collects the workspace, OS, pace, and
selected components once; then it executes an explicit preflight → install → verify →
rollback-record contract. Design rationale stays here in the README and in the benchmark,
with configuration, maintenance, and historical guidance under [`docs/`](docs/), so an
installing session does not pay to parse them.

Then, optionally:

- **Skills**: copy any folder from [`skills/`](skills/) into `~/.claude/skills/<name>/`.
  Each becomes a `/slash` command in every project.
- **Hooks**: copy the scripts from [`hooks/`](hooks/) into `~/.claude/hooks/` and merge
  the matching `settings-*.example.json` block into your **user-level**
  `~/.claude/settings.json`. (User-level is load-bearing: workspace-level hooks silently
  never fire for sessions opened inside project subfolders.)
- **Templates**: [`templates/`](templates/) holds the skeletons for bootstrapping new
  projects (`CLAUDE.md`, `CHECKPOINT.md`, and a baseline `.gitignore`).

## What's inside

`harness_me.txt` — the machine-oriented installer described in Quick start above.

### Skills (`skills/<name>/`)

Copy any folder into `~/.claude/skills/<name>/`. Each becomes a `/slash` command in every project.

| Skill | What it is |
|---|---|
| `checkpoint` | `/checkpoint`: rewrites CHECKPOINT.md in place to the schema, enforces the 120-line/~30KB caps, and archives overflow via `archive-changelog.ps1`, a byte-faithful mover script (the model picks which lines to evict; the script moves bytes the model never retypes). |
| `prevent` | `/prevent`: when a documented rule got violated because it wasn't in Claude's read path: fix the slip, find the knowledge, diagnose why it missed, and move it to where the failing workflow will actually read it. If you build only one skill, build this one. |
| `outside` | `/outside`: one cheap external-grounding pass before committing to an approach: shipped-solutions sweep, sibling-project sweep, notes check; verdict-first report with exactly one next action. The "did someone already build this?" gear the rest of the suite lacks. |
| `prove` | `/prove`: extracts every factual claim from the last response and verifies each against files first, then the web; per-claim Confirmed / Wrong / Unverified with citations. |
| `redteam` | `/redteam`: one adversarial pass that assumes the target is wrong and hunts the fatal flaw. The cheap middle gear between a single-shot answer and `/fanout`. |
| `dumb` | `/dumb`: "that was wrong or lazy, fix it." Fires on wrongness and on laziness (punting, offering instead of doing, half-answers). Forbids defending the previous response, forces a one-line honest diagnosis plus the actual fix. |
| `fanout` | `/fanout`: 5 parallel cognitive-frame ideation agents + a critic pass, for open-ended problems only. ~7x tokens, explicitly gated, never automatic. |
| `breakdown` | `/breakdown`: convergent, action-first decomposition: real goal, smallest next action, the one blocking decision, collapsed plan, first trap. |
| `plain` | `/plain`: re-explains a dense/jargon response in plain generous English, resolving every invented code by looking it up (never guessing). |
| `spec` | `/spec`: writes lean specs with a mandatory Closeout section and forces the archive/promote step when the work ships, so dead specs stop piling up looking live. |
| `necromancy` | `/necromancy`: recovers a session that died before CHECKPOINT.md was written: a deterministic PowerShell script digests the on-disk session JSONL (anchors: first ask, user decisions, files written, commands, commits, errors) so the model never reads multi-MB raw transcripts. Pattern adapted from [ryanthedev/herderp](https://github.com/ryanthedev/herderp)'s session-necromancy. |

### Hooks (`hooks/`)

Copy the scripts into `~/.claude/hooks/` and merge the matching `settings-*.example.json` block into your **user-level** `~/.claude/settings.json`.

| Hook | What it is |
|---|---|
| `orient_gate.ps1` / `.sh` | PreToolUse **orientation gate**: blocks the first state-changing tool call of a session until CHECKPOINT.md has been read, then gets out of the way (block-once, fail-open; read-only tools are never gated). |
| `guard.ps1` | PreToolUse **mechanical guard**: blocks tool input that would literally break parsing (Windows-specific: non-ASCII into PowerShell, backslash paths into MSYS bash) plus `grep --no-ignore`, a ripgrep-only flag that makes GNU grep exit 2 printing nothing, so a scan that never ran is indistinguishable from a clean one. Worth having if any gate of yours is a grep. Adapt to your own breakages; never block style. |
| `deny_backstop.ps1` | PreToolUse **security backstop**: scans the complete Bash/PowerShell command, including command substitution and loop bodies, and blocks a narrow set of catastrophic operations. It includes broad name/pattern/pipeline process kills, requiring an explicit PID instead. Review and adapt its patterns before enabling it. |
| `tmux_receipt.ps1` | SessionStart **environment receipt** (optional): detects a tmux/SSH-launched session (stripped PATH, different world than the desktop) and tells the session so, once, at start, so it stops re-deriving "tool not installed" conclusions from bare-name failures. Silent no-op on desktop launches; adapt detection + message to your own remote launch path. |
| `settings-*.example.json` | The SessionStart receipt + PreCompact reminder + PreToolUse hooks, wired for Windows and Mac/Linux. The Windows example also wires the optional security backstop. |

### Docs (`docs/`)

| Doc | What it is |
|---|---|
| `configuration-guide.md` | The optional configuration tour: permission and settings scope, hooks, skills, MCP, memory choice, compaction, and context-budget checks. Cosmetic settings and model rankings are deliberately excluded. |
| `maintaining-the-harness.md` | The human maintenance procedure that was deliberately removed from the installer: file budgets, the two-pass rulebook diet, contradiction checks, and outside-audit workflow. |
| `design-history.md` | A dated record of the public patterns reviewed, what this toolbox adopted or declined, and the choices it added. It is design history, not a current market survey. |
| `when-it-pays-off.md` | The measured regime boundary in practical form: the three task-shape regimes, five rules of thumb that fall out of them, and the clearest winning regime. Read before installing if you're unsure the harness fits your work. |
| `token-efficiency.md` | Operating habits that keep sessions cheap: model-tier principles (deliberately no model names), the sub-agent cost gate, and file/reading habits like front-loading resume-critical sections. |
| `optional-add-ons.md` | Concept sketches beyond the default install: a capture-first rants/musings folder and a Cowork sibling workspace layout. |

### Templates (`templates/`)

Per-project `CLAUDE.md` / `CHECKPOINT.md` skeletons and a baseline `.gitignore`.

## Why trust any of this

The design choices are measured, not vibes:

- **154 paired Claude Code trials** (paired Wilcoxon, p < 0.05) mapped the regime
  boundary: the harness *hurts* on trivial or pre-oriented prompts (+35% to +136% output
  tokens, +64% to +80% cache reads), is neutral on structured single-project tasks, and
  wins clearly on exploratory multi-project work (−25% to −45% on read-side metrics).
  Every trial ran on a single pinned model, `claude-sonnet-4-6` (run in early-to-mid
  2026, predating the Claude 5 family) — these numbers describe that model's behavior,
  not a claim about any other model. The whole experiment is published at
  [**harness-benchmark-report**](https://github.com/dtiger1889-ops/harness-benchmark-report):
  the report, the raw per-trial data, and the benchmark itself, so you can check any
  number here or run a harness variant of your own against the same baselines.
- **A 50-session audit** found the model self-classifies "am I already oriented?"
  unreliably (~1 in 5 actionable sessions acted before reading state). That killed the
  original prose rule and produced the orientation gate: read-only work is free
  automatically, and the action boundary is enforced by a hook instead of judgment.
- **A 631-session transcript crawl** chose the skill list. Claude Code keeps a transcript
  of every session on disk, so before building any skills, a script searched 631 of the
  maintainer's real sessions for every place the model got told it was doing something
  wrong. The guess going in was that the most common complaint would be "this is too
  complicated, simplify it." That complaint barely appears in the record. The one that
  appears constantly is laziness: the model answering "can't determine" when the data to
  decide was already loaded, or describing what it could do instead of doing it. Those are
  the failures the skills above go after. Crawl your own transcripts before you copy the
  list; the problem you keep hitting may not be the one you'd guess.

Two limits fell out of the same measurements, and they're worth knowing before you
install rather than after. The harness buys tokens, not time. Exploratory tasks ran up to
14% *slower* even while spending 25–45% fewer output tokens, because reading `CLAUDE.md`
costs latency up front to save work later. And it does nothing for context-window
pressure: no trial ever came close to filling a window, so there is no evidence here that
a harness delays compaction. If what you want is a session that *feels* faster, or relief
from hitting the context limit, this is the wrong tool for it.

## Design principles (the short version)

1. **Harness beats model.** Fix session failures by improving the files, not by retrying.
2. **Receipt, not dump.** Hooks print a byte/line receipt and make Claude Read the file.
   Large hook output truncates silently to a ~2KB preview that looks complete.
3. **Enforce structurally what prose can't.** A notice the model can ignore isn't enough;
   a block-once, fail-open gate at the action boundary is.
4. **Overwrite in place, never append.** CHECKPOINT is a whiteboard, not a log. It has hard
   caps and a byte-faithful archive path for the one section that *is* a log.
5. **Promote failing rules into tools.** A rule you've re-written three times and still
   violated is the textbook case for a skill or a hook.
6. **Build for friction you can prove.** Crawl your own transcripts first.
7. **Right layer beats more prose.** A fix goes in the narrowest layer guaranteed to be
   read or fired at the failure point: a hook for tool-event patterns, a skill for
   procedures, an on-demand index for lookup data (project ledgers, routing tables).
   The always-loaded file is only for rules every session needs, and it has a real
   budget: Claude Code warns at ~40k characters, and everything under that ceiling
   taxes every turn.

The setup choices are explained in [`docs/configuration-guide.md`](docs/configuration-guide.md),
the operational version of principle 7 is in
[`docs/maintaining-the-harness.md`](docs/maintaining-the-harness.md), and the dated comparison
that informed the toolbox is preserved in [`docs/design-history.md`](docs/design-history.md).
The practical reading of the benchmark numbers above is
[`docs/when-it-pays-off.md`](docs/when-it-pays-off.md); day-to-day operating habits are
[`docs/token-efficiency.md`](docs/token-efficiency.md).

## Platform note

Windows-first: the PowerShell hooks are the maintainer's live, tested reference. Bash
ports are provided for Mac/Linux but have **not** been verified on that hardware. Run the
first-session checklist (`harness_me.txt` Section 6) before relying on them.

## License

[MIT](LICENSE).
