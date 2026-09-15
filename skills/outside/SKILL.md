---
name: outside
description: Force the session out of its own head before committing to an approach -- one cheap reconnaissance pass over shipped solutions, the user's other projects, and the user's notes. Use when the user types /outside or says "get an outside view" / "check prior art" / "are we reinventing the wheel" / "has anyone already built this". One pass, no subagents, 1-3 web searches.
---

# outside -- external grounding pass (prior art + workspace + notes)

The gap this fills: /breakdown decomposes, /fanout diverges internally, /redteam attacks --
none of them LOOK OUTSIDE the session. This one does. It forces "shipped solutions first":
adopt or adapt what exists is the default; building from scratch needs a stated reason.

Copy this checklist into your response and check items off as you complete them:
- [ ] 0. Oriented (project state file read, if in a project)
- [ ] 1. Tunnel named (problem restated + current in-head approach stated)
- [ ] 2. Shipped-solutions sweep (web)
- [ ] 3. Workspace sweep (sibling projects)
- [ ] 4. Notes check
- [ ] 5. Report (verdict first, one next action last)

## 0 -- orient (a hard step, not a reminder)
If in a project with a state/checkpoint file not fully read this session, read it to EOF
first. Its recorded decisions and failed approaches may already contain the answer -- or
be the tunnel itself.
**Before step 2 may run, quote back in your response:** the state file's status line
verbatim, and the headings of its recorded decisions (or "none"). A pass that cannot quote
them has not oriented and does not proceed to the web. Why this is a hard step: an
orientation hook only fires on world-changing tool calls, and /outside opens with
read-only work, so nothing else catches a pass that skips this; it was skipped twice in the
maintainer's lapse ledger and both times the answer was already in the state file.

## 1 -- name the tunnel
Two sentences, no more:
- The problem, restated stripped of any approach ("we need X", not "we need to build Y
  for X").
- The current in-head approach, named explicitly. This is the thing on trial.

## 2 -- shipped-solutions sweep
Web search for what already exists for this exact ask: GitHub repos, published
skills/MCP servers, community writeups, a library, a product someone already ships.
1-3 searches. Prefer free search tools over metered scraping services. One of the searches
is always the standing question "what do the LARGEST agent runtimes / platforms do for
this?" (Claude Code, Codex, OpenClaw, Cursor, the big open-source agent frameworks) -- a
sweep keyed only on the deliverable's own nouns missed the largest adjacent platform until
the user asked.

## 3 -- workspace sweep
Has a sibling project already solved this problem shape? Search the state files,
decision docs, and specs of the 2-3 most plausible sibling projects, not the whole tree.
Gotcha: if the workspace uses a deny-by-default .gitignore, ripgrep-backed search tools
silently skip most files -- use plain `grep -rin` instead.

## 4 -- notes check
If the user keeps a notes system (Obsidian vault, wiki) and the project points at a
relevant note, read that ONE note. Otherwise skip -- do not trawl the notes system.

## 5 -- report (this cap BINDS)
Order is fixed:
1. **Verdict line first:** current approach survives / dies / mutates -- plus the
   one-clause why.
2. **What exists:** 2-3 genuinely different ways to attack the problem, numbered, each
   with its strongest source (link or file:line). Max 5 items total (a cap on what the report SHOWS, never on how much the sweeps find or consider; adapted from ayghri/i-have-adhd rule 9, 2026-09-14). Adopt/adapt beats
   greenfield; recommending greenfield requires saying what WAS found and why it doesn't
   fit.
3. **One next action, last line.** Exactly one.

Source links go inline in the report; write a findings doc only if this feeds a real
milestone.

## Rules
- One pass, no subagents. A dry sweep is a RESULT ("nothing shipped does this") -- report
  it plainly, don't pad.
- Every finding names its source (a link or file:line). Not found means say "not found" --
  never fill the gap from memory. (Adopted 2026-09-15 from the AI Tools keepers review; /prove
  already enforces this after the fact, this makes it the rule up front.)
- If the sweeps confirm the current approach, say so and stop; do not manufacture
  alternatives to look useful.
- This is reconnaissance, not a research milestone. If it uncovers a rabbit hole worth
  real research, put THAT in the report as the one next action -- don't dive inline.

## Scope
Not multi-frame ideation (that is /fanout), not attacking a finished answer (that is /redteam), not pre-build requirements interviewing.
