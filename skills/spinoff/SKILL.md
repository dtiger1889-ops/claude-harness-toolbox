---
name: spinoff
description: >-
  Starts a separate session for a side topic from a short brief rather than copying the whole
  conversation, so this session stays on topic and its context stops growing. Use only for
  /spinoff, a message that starts with "spinoff", "spin-off" or "spin off" without the slash,
  "spin this off", "hand this off to a new session", or "take this to its own session". Does not
  trigger automatically. Not a conversation fork or branch (those copy the whole chat), not a
  sub-agent, not a checkpoint.
---

# Spin off a side topic

A fork keeps the whole conversation, so it saves nothing; the new session must start from a short
brief, and it acts on every line of that brief as an instruction.

1. **Name the side topic** from the request or the most recent detour. Ask once only if two topics
   fit equally.
2. **Pick the owning project** whose scope covers it; use the current project if no clearer owner
   exists. Pick without asking and state the destination.
3. **Refuse a vague ask.** If the user's words do not say what the deliverable is and this chat
   does not either, ask once and launch only on the answer: a session told to work out what they
   meant invents its own instructions. Never write a first action that asks the new session to
   guess or interpret.
4. **Write the brief** in a scratch location as `spinoff-<UTC timestamp>-<slug>.md`:

   ```
   <topic in at most 6 words>

   Start at "First action".
   Asked: <the user's ask, in their own nouns>
   Known so far: <what this chat established: referents, facts found, paths, commands, error text>
   Decided: <settled choices and their authors, or "nothing yet">
   First action: <the part of the ask to work on first; it never drops a source or deliverable the Asked line names, so a two-source ask keeps both here>
   Out of scope: <what the ask or this chat ruled out; "nothing named" when neither did>
   Done when: <the result that finishes the ask, in the user's nouns>
   ```

   - **Asked and First action carry the ask and nothing else.** Never map it onto a skill or
     procedure the user did not name, and add no task they did not ask for (no verify, audit or
     cleanup). Recognize a skill they name without its slash; a word that only sounds like a
     skill is not a request for it; when unsure, pass their words through as-is.
   - **A line written from a correction** quotes the user's exact words beside it and cuts every
     clause that restricts more than they did.
   - **Known so far comes only from this chat.** Never fill it from the target project's files;
     the new session reads its own state, and a paraphrase arrives as a false fact. Resolve every
     "that", "this" or "it" in the ask to its referent first; write "not in this chat" only after
     searching the chat.
   - **Keep the brief file under 1,000 characters**, because a longer one can lose its start in
     the new window. A pasted post, long excerpt or list of facts goes in its own scratch file,
     named with a one-line gloss on the first Known-so-far line.
   - **A brief for more than one folder** carries only facts true in every one of them; a
     folder-specific fact gets that folder its own brief.
   - Write a reason only when it rules out an action the new session would otherwise take; never
     explain why this session handed the topic off.
5. **Start the session** with the host's documented session-creation tool or configured launcher.
   On Claude Code with background sessions supported, run from the chosen project:

   ```powershell
   claude --bg --name "<project>: <topic>" (Get-Content -Raw "<brief path>")
   ```

   - Fill the folder and brief path into the command literally; never route them through the
     skill's argument placeholders, which the host may substitute with words from the request.
   - When the user names a model or effort ("opus high"), pass it as the launcher's model and
     effort options.
   - **Launch only, no topic** ("start a session in docs, no prompt"): skip the brief and launch
     with no message.
   - **A folder whose instructions say sessions start with a slash command** (a reader or
     companion skill, say): begin the message with that command, then the user's words, because a
     short greeting does not make the new session load it on its own.
   - Check the installed CLI's support before use. Do not change workspace trust, permission
     mode, or active sessions to make it launch.
6. **Check the brief arrived** before saying it started: the new session's transcript (for Claude
   Code, the newest `.jsonl` under `~/.claude/projects/<that folder>/`) holds a user message with
   the brief's first line. A window or title alone does not prove it, because a stuck session
   still draws one. If it is missing, run the same launch once more. Never type, paste or press
   Enter into the stuck window; name it in the reply so the user can close it.
7. **Reply and drop it.** One line naming the session (`<project>: <topic>`, from the brief's first
   line, no "Spinoff" prefix), its ID, and where it is (for Claude Code: `claude attach <id>`).
   Then return to the main task.
8. **If the launch fails** (refusal, block, non-zero exit), do not retry: give the brief path and
   the failure reason in one line. Never claim a session started.

Only include a report-back instruction when the outcome changes what this session is doing and the
user has authorized messaging the destination and any return message. A new-session request does
not authorize sending to unrelated sessions. If messaging is unsupported, leave the brief as the
handoff artifact.

If the user brings the topic back here, point them to that session in one line; continue it here
only if they say to.

## Not this skill
Full-conversation copies (branch, fork), offering a spinoff unasked, side questions that need no
back-and-forth.
