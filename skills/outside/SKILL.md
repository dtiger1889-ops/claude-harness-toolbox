---
name: outside
description: Checks prior art, related workspace projects, and relevant notes before choosing an approach. Use for /outside, "get an outside view", "check prior art", "are we reinventing the wheel", or "has anyone already built this". Runs one bounded reconnaissance pass without helper agents.
---

# Outside view

Copy this checklist into your response and check items off as you go:
- [ ] 1. Oriented (state quoted, or "not in a project")
- [ ] 2. Problem framed, current approach named
- [ ] 3. Shipped-solutions sweep
- [ ] 4. Workspace sweep
- [ ] 5. Notes lookup (hit read, or no-hits stated)
- [ ] 6. Report (verdict first, one next action last)

1. **Orient.** For project work, read current state and instructions to EOF. Extract relevant decisions and failed approaches before searching; they may already hold the answer, or be the tunnel itself. Before any web search, quote the state file's status line verbatim and the headings of its key decisions (or "none"); a pass that cannot quote them has not oriented and does not proceed. This is a hard step because the pass opens with read-only work, so nothing else catches a skipped orientation.
2. **Frame.** In two sentences, state the problem independently of the proposed solution ("we need X", not "we need to build Y for X") and name the current approach being assessed.
3. **Find shipped solutions.** Start with one to three targeted web searches. Check maintained libraries or components for build work, the relevant major platforms' approaches, and how the best practitioners of the deliverable do it (skilled people's methods, not only tools built for it), answered with a link or marked not found; within the search cap, fold that question into another search rather than drop it. Prefer primary documentation and working repositories. Expand only if a specific evidence gap prevents a useful conclusion. If you keep a ledger of tools and projects you have evaluated, read it when the ask touches agent tooling and add any notable new find that passes your own admission bar, judged per find.
4. **Check the workspace.** Search the two or three most plausible related projects' state, decisions, and specs. If ignore rules hide files, use explicit paths or an appropriate no-ignore search.
5. **Check notes.** Read a relevant note when the project points to it. Either way, run one bounded topic lookup (filenames and content, one to three topic terms) over the notes folders that hold reference material on this topic, such as saved resources, web clippings, any index of repositories you keep local copies of, and the matching project or area folder, because a saved workflow or clipping on this exact topic is the cheapest prior art there is. Read the best hit. This step is done only with a hit read, or with the lookup's no-hits or notes-unavailable result stated in the report; a project pointer, or the absence of one, is never coverage on its own. Stay on topic: no trawl of personal notes, no folders the topic does not touch.
6. **Report.** Lead with one line: whether the current approach survives, changes, or should be replaced, and why. Then two or three materially different options with inline source links or file locations, at most five items in all (a cap on what the report shows, not on what the sweeps consider). End with exactly one concrete next action. Adopt or adapt shipped work by default; recommending a build from scratch says what was found and why it does not fit.

If the request includes fixing a concrete defect in the user's own artifact, apply the supported fix within the authorized scope in the same turn and report what changed; if it cannot be run, say why. A research request alone does not authorize implementation.

The spec skill carries a condensed copy of steps 2-5 as its prior-art pass; change the two together.

Cite each finding and label gaps: "not found" is a result, never filled from memory, and a dry sweep is reported plainly. Do not manufacture alternatives when the evidence supports the existing approach; say so and stop. Save a findings document only when project conventions or the user request call for one; table deeper research as the next action rather than starting an unrelated investigation.
