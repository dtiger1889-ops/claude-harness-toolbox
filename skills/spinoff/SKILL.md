---
name: spinoff
description: Hand a side topic off to a NEW, separate Claude Code session, so the current session stays on topic and its context (and the cache reads every later turn pays for) stops growing. Use ONLY when the user types /spinoff or says "spin this off" / "hand this off to a new session" / "take this to its own session". Writes a short brief of just the side topic (never the whole chat), picks the project folder that owns it, starts a named background session there, and drops the topic here. Never fires on its own. Not /branch or /fork, which copy the whole conversation.
---

# spinoff -- move a side topic into its own session

The problem: you are working on X, a question about Y comes up, and three turns later the
session is about Y. Every later turn re-reads all of it. `/branch` and `/fork` don't help,
because they copy the whole conversation into the new session. This skill starts the new
session from a short brief instead, so both sessions stay small.

Copy this checklist into your response and tick it as you go:
- [ ] 1. Topic named (which thread of this chat is the side topic)
- [ ] 2. Folder picked
- [ ] 3. Brief written to a file
- [ ] 4. Session started (or the brief handed over)
- [ ] 5. One-line reply; topic dropped here

## 1. Name the side topic
The args name it, or it is the most recent detour away from this session's main work. If two
detours are equally plausible, ask once; otherwise do not ask.

## 2. Pick the folder that owns it
The project whose job covers the topic (permissions and settings questions -> the folder
where you keep your harness or config; a bug in another app -> that app's folder). No clear
owner -> this session's own folder. Say which folder you picked.

## 3. Write the brief (only the side topic)
If the `ListAgents` tool exists, run it once: its first line is this session's own name.
Write the brief to a scratch or temp folder as `spinoff-<UTC timestamp>-<slug>.md`:

```
Spinoff: <topic in at most 6 words>

Started by /spinoff from the session "<own name>" in <this folder>, so the user can work
this side topic without growing that session. Read the project's state files the usual way,
then pick up at "Open question".
Asked: <what the user asked, their words where they matter>
Known so far: <facts found, with file paths, commands, tool names, error text>
Decided: <anything settled, and who decided it>; or "nothing yet"
Open question: <the one thing to work on first>
Report back: <either "When settled, send '<own name>' a 1-3 line result with SendMessage,
because <what it changes there>" or "Nothing goes back to the original session.">
```

Keep it under ~300 words. Leave out the main topic; include everything the new session needs,
because it sees nothing else. Choose "Report back" only when the outcome changes what this
session is doing.

## 4. Start the session
- **Your setup has its own session launcher** (a terminal deck, a tmux script; your CLAUDE.md
  says so): use it, passing the brief as the first message.
- **Otherwise:** from the chosen folder, run
  `claude --bg --name "<folder>: Spinoff: <topic>" "$(cat <brief path>)"`.
  It prints a short id. The user opens the session with `claude attach <id>` or from
  `claude agents`. The folder must already be trusted (Claude Code refuses an untrusted one
  and says so).
- On a refusal or an error, do not retry: give the user the brief's path and its text, and
  say in one line why the session could not start.

## 5. Reply and drop it
One line: "Started **<name>** in <folder>; open it with `claude attach <id>`." Then go back
to the main topic. If the user brings the side topic back here, point to that session in one
line; continue it here only if they say to.

## Not this skill
Copying the whole conversation (`/branch`, `/fork`, `--fork-session`); a quick side question
that needs no back-and-forth (`/btw` answers those, though it still reads the whole chat);
offering a spinoff the user didn't ask for.
