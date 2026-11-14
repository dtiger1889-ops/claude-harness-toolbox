---
name: dumb
description: >-
  Corrects an immediately previous response or action that the user says was wrong, incomplete,
  lazy, or missed the point. Use for /dumb and corrections such as "that was dumb", "fix it",
  "stop being lazy", "that's not done", or "you skipped" directed at the previous work, and also
  on the early laziness signals: "why am I still seeing this", "why didn't you", "you said you
  did", "did you actually", "just do it". Delivers the correction and records reusable lessons.
---

# Correct the previous work

1. Re-read the user's actual request and identify the concrete failure in one line. Investigate disputed facts; do not defend the previous answer or invent a failure to agree. It is usually one of these:
   - **Punted:** said "can't tell" or "would need more" when the answer or data was in reach.
   - **Explained instead of did:** described or asked permission when the goal was clear.
   - **Missed the ask:** answered a different question, or a near-miss of the user's literal words.
   - **Unreadable:** a dense, jargon-heavy answer or decision point.
   - **Half done:** did part and left the tedious remainder.
   - **Didn't read first:** answered from assumption instead of the file or source.
   - **Over-cautious:** deferred or asked again with enough in hand to act.
2. Complete the correction within the authorized scope. Read sources or artifacts first when needed. Give the corrected result, not a plan to fix it.
3. If the intended correction remains unclear after reviewing the context, ask one focused question and continue any independent work.
4. Record reusable findings: run the log skill once after the fix (the bundled `log_backstop` hook prompts for this). It stops at "nothing to log" when nothing durable came out; a repeat of an already-logged lapse is filed with `-RepeatOf`. Separate an incident from a standing preference: do not turn a one-off correction into a new permanent rule without evidence of that intent. Never end the turn with the correction only in scrollback.

Keep the reply short: show the corrected output with minimal narration. If prevention requires changing a workflow, use prevent; if the issue is disputed claims, use prove.
