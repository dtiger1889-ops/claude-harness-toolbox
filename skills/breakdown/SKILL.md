---
name: breakdown
description: Decomposes one tangled problem into a smallest next action and a compact plan. Use only for /breakdown, "break this down", "break it down", or "decompose this". For open-ended ideation use fanout; skip when the task is already one clear action.
---

# Breakdown

Run inline without agents. This is a planning request; execute only if the user also authorizes the work.

1. Read the supplied text or referenced artifact. For project work, read the project's current state and instructions to EOF before choosing an action. Ask once if the problem is too vague to decompose.
2. Respond with these five short blocks, with no preamble and no restating of the question:
   - **Goal:** what completion means. Identify any discrepancy with the stated goal as an interpretation, not a settled fact.
   - **Smallest next action:** one concrete, physical step that can be completed in one sitting ("open X and write the three field names", not "design the schema"). Then offer to do it now.
   - **Blocking decision:** the fork that unlocks the action, or "none, just start".
   - **Full plan:** a compact checklist under a one-line summary, marked to ignore until the next action is done.
   - **First trap:** the likeliest failure and its earliest observable signal.

Use plain language and one critical path; do not list parallel workstreams. Do not create a file unless requested or required by the project's state-recording conventions; if the result is worth keeping, offer to record it as the project's next step.
