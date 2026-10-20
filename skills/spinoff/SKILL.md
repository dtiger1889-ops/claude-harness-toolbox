---
name: spinoff
description: Starts a separate session for a side topic from a short brief rather than copying the whole conversation. Use only for /spinoff, "spin this off", "hand this off to a new session", or "take this to its own session". Does not trigger automatically or replace a conversation fork.
---

# Spin off a side topic

1. Identify the side topic from the request or current detour. Ask once only if multiple topics fit.
2. Choose the existing project whose scope owns it; use the current project if no clearer owner exists. State the destination.
3. Write a short brief in a scratch location as `spinoff-<UTC timestamp>-<slug>.md`:

   ```
   Topic: <side topic>
   Request: <what the user asked>
   Read first: <project instructions and current state>
   Known: <evidence, relevant paths, commands, and errors>
   Decided: <settled choices and their authors, or none>
   First action / question: <the actual user request's next step; it never drops a source or deliverable the Request line names, so a two-source ask keeps both here>
   Boundaries: <scope and pending approvals>
   ```

   Include only the side topic and what the new session needs to work independently. Do not replace an action request with an abstract question. Keep the brief concise without omitting necessary evidence.
4. Use the host's documented session-creation tool or configured launcher. On Claude Code with background sessions supported, run from the chosen project:

   ```powershell
   claude --bg --name "<project>: <topic>" (Get-Content -Raw "<brief path>")
   ```

   Check the installed CLI's support before use. Do not change workspace trust, permission mode, or active sessions to make it launch.
5. Confirm the actual session name and ID returned by the launcher, then return to the main task. For Claude Code, the user can attach with `claude attach <id>`.
6. If launch fails, give the brief path and failure reason. Do not claim a session started or run a retry ladder.

Only include a report-back instruction when the user has authorized messaging the destination and any return message. A new-session request does not authorize sending to unrelated sessions. If messaging is unsupported, leave the brief as the handoff artifact.

If the user brings the topic back here, respect that direction; do not force them into the other session.
