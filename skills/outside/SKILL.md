---
name: outside
description: Checks prior art, related workspace projects, and relevant notes before choosing an approach. Use for /outside, "get an outside view", "check prior art", "are we reinventing the wheel", or "has anyone already built this". Runs one bounded reconnaissance pass without helper agents.
---

# Outside view

1. **Orient.** For project work, read current state and instructions to EOF. Extract relevant decisions and failed approaches before searching.
2. **Frame.** State the problem independently of the proposed solution and identify the current approach being assessed.
3. **Find shipped solutions.** Start with one to three targeted web searches. Check maintained libraries or components for build work, the relevant major platforms' approaches, and how the best practitioners of the deliverable do it (skilled people's methods, not only tools built for it), answered with a link or marked not found; within the search cap, fold that question into another search rather than drop it. Prefer primary documentation and working repositories. Expand only if a specific evidence gap prevents a useful conclusion.
4. **Check the workspace.** Search the two or three most plausible related projects' state, decisions, and specs. If ignore rules hide files, use explicit paths or an appropriate no-ignore search.
5. **Check notes.** Read a relevant note when the project points to it. Either way, run one bounded topic lookup (filenames and content, one to three topic terms) over the notes folders that hold reference material on this topic, such as saved resources, web clippings, and the matching project or area folder, because a saved workflow or clipping on this exact topic is the cheapest prior art there is. Read the best hit. This step is done only with a hit read, or with the lookup's no-hits or notes-unavailable result stated in the report; a project pointer, or the absence of one, is never coverage on its own. Stay on topic: no trawl of personal notes, no folders the topic does not touch.
6. **Report.** Lead with whether the current approach survives, changes, or should be replaced, and why. Present a few materially different options with inline source links or file locations, then one concrete next action. Adopt or adapt shipped work by default; explain evidence-based reasons for building from scratch.

If the request includes fixing a concrete defect, apply the supported fix within the authorized scope and report it. A research request alone does not authorize implementation.

Cite each finding and label gaps. Do not manufacture alternatives when the evidence supports the existing approach. Save a findings document only when project conventions or the user request call for one; table deeper research as the next action rather than starting an unrelated investigation.
