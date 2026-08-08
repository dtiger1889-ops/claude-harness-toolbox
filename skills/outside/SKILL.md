---
name: outside
description: Force the session out of its own head before committing to an approach -- one cheap reconnaissance pass over shipped solutions, the user's other projects, and the user's notes. Use when the user types /outside or says "get an outside view" / "check prior art" / "are we reinventing the wheel" / "has anyone already built this" / "look around before we build this". Sits between a single-shot answer and /redteam in cost - one pass, no subagents, 1-3 web searches. Do NOT use for multi-frame ideation (that is /fanout), attacking a finished answer (that is /redteam), or pre-build requirements interviewing.
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

## 0 -- orient
If in a project with a state/checkpoint file not fully read this session, read it to EOF
first. Its recorded decisions and failed approaches may already contain the answer -- or
be the tunnel itself.

## 1 -- name the tunnel
Two sentences, no more:
- The problem, restated stripped of any approach ("we need X", not "we need to build Y
  for X").
- The current in-head approach, named explicitly. This is the thing on trial.

## 2 -- shipped-solutions sweep
Web search for what already exists for this exact ask: GitHub repos, published
skills/MCP servers, community writeups, a library, a product someone already ships.
1-3 searches. Prefer free search tools over metered scraping services.

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
   with its strongest source (link or file:line). Max 5 items total. Adopt/adapt beats
   greenfield; recommending greenfield requires saying what WAS found and why it doesn't
   fit.
3. **One next action, last line.** Exactly one.

Source links go inline in the report; write a findings doc only if this feeds a real
milestone.

## Rules
- One pass, no subagents. A dry sweep is a RESULT ("nothing shipped does this") -- report
  it plainly, don't pad.
- If the sweeps confirm the current approach, say so and stop; do not manufacture
  alternatives to look useful.
- This is reconnaissance, not a research milestone. If it uncovers a rabbit hole worth
  real research, put THAT in the report as the one next action -- don't dive inline.
