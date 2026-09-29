---
name: log
description: Force a durable write of the last answer's reusable facts into the doc that already owns them, and file the session's own rule-breaking in an append-only lapse ledger. Use when the user types /log or says "log this" / "capture this" / "write that down" / "don't lose this" / "log that lapse" / "did you track your own mistake". Supplements /checkpoint, which owns resume-state; /log is for reusable knowledge below that threshold. Not for resume-state, and not on every answer.
---

# log -- force a durable write for findings that are not resume-state

The gap this fills: a session proves a fact, corrects a wrong claim, settles a small
decision, or pins down how something works. None of that is resume-state (Status / Open
threads / Next step), so `/checkpoint` has no reason to write it. It stays in scrollback and
is gone when the session ends, unless someone notices and files it by hand, and that
follow-through is exactly the step that silently fails.

This skill is the forcing function against that. It supplements `/checkpoint` and never
replaces it.

## When it runs
- **By hand:** the user invokes `/log`, or says the last answer produced something worth
  keeping.
- **As a backstop (optional):** a PostToolUse hook can make the model run this skill after a
  `/prove`, `/prevent`, `/fanout`, or `/outside` turn. Treat that as a consideration pass: if
  nothing durable came out, say "nothing to log" and stop. Never invent a finding to look
  useful.

## Step 1 -- pull the finding(s) from the last answer
Read the previous answer (or the block the user names). Keep only durable, reusable facts: a
proof and its source, a correction of an earlier claim, a decision and its reason, a
mechanism established. Capture what the conversation already established; do not
re-research. Nothing durable -> "nothing to log", stop.

## Step 2 -- classify each finding
- **Reference knowledge** (a fact or mechanism reusable across sessions) -> a living
  reference doc.
- **A decision** -> the doc where that decision is tracked, or a `decisions/` folder if it
  closes something.
- **A pure event** ("what happened") -> that is the changelog, which `/checkpoint` owns. Do
  not duplicate it. But if a reusable kernel inside the event would be buried once the
  changelog is archived, re-record that kernel in a reference doc.
- **A lapse** (this session broke a rule the user had already set up). First decide which
  kind, because the two go to different ledgers and get fixed differently:
  - **A skill's required step was skipped** -> `skill_lapses.jsonl`. Fix surface: a hard
    sub-step or a verifier inside that skill.
  - **A general conduct rule was broken** (a `CLAUDE.md` rule, no skill involved: jargon with
    no gloss, a cause reported without evidence, an offer made instead of doing the work) ->
    `rule_lapses.jsonl`. Fix surface: a `CLAUDE.md` tightening or a hook.

  Route by where the broken rule lives, not by which project the session is in. See
  "Filing a lapse" below for the procedure.

## Step 3 -- route to the doc that already owns it
1. **Owning project.** Which project owns the finding? It may not be the one the session is
   in (a phone fact that surfaced during PC troubleshooting belongs to the phone project).
2. **The specific doc.** Tell apart a living working doc, a closed record in `decisions/`,
   and an open spec in `specs/`. A live finding goes in the working doc; a finding that
   resolves a spec goes where that spec now lives. Read the target's structure before
   placing the entry.
3. **Cross-project.** Write to the owning project's doc, and leave a one-line pointer in the
   active project so the trail survives.
4. **No home yet.** If the finding opens a genuinely new area with no doc, do not force it
   into the wrong one. Stop, say a new doc is needed, and propose one. This is the one point
   where `/log` asks before writing.

## Step 4 -- write it
- Append a dated entry, or correct the existing text in place when the finding corrects it.
- **Format:** match the target doc's house style. Where it has none, use
  `YYYY-MM-DD -- <claim> -- <evidence or source> -- <author>`.
- **Provenance:** bump the doc's `Last updated` / version stamp and attribute the entry.
  `<user> decision -- <date>` only for the user's explicit call; otherwise
  `model finding -- <date>`.
- Any invented code or shorthand gets a plain-words gloss in the same sentence. These docs
  are read cold, weeks later, with no one to ask.

## Step 5 -- report (terse)
One line per finding: what was written, and where (clickable path), plus any cross-project
pointer or new-doc flag. No recap of the finding itself; it is on disk now.

## Filing a lapse

The ledgers are JSON Lines files (one JSON object per line), each with a Markdown twin of the
same name that holds the rules the ledger covers and a **Fix candidates** section. Keep both
in one place every session can find, for example a `lapses/` folder in your harness project,
and name that folder in your top-level `CLAUDE.md`. To start a ledger, copy
[`ledger-template.md`](ledger-template.md) to `<name>.md` and create an empty `<name>.jsonl`
beside it.

**Append with the script only.** Never open, edit, or rebuild the `.jsonl` by hand; the
script assigns `n` and the date itself:

```
pwsh -File ~/.claude/skills/log/log_lapse.ps1 -LogFile <full path>.jsonl \
  -Rule "<the rule that was broken>" -Session "<project, one-line context>" \
  -Consequence "<what it cost>" -HowCaught "<self-caught or user-caught, and how>" \
  -FixStatus "<what was done about it>. Author: model finding -- YYYY-MM-DD."
```

For `skill_lapses.jsonl`, pass `-Skill` and `-Step` instead of `-Rule`. The script also
stamps the write time and, under Claude Code, the model and reasoning effort read from the
session's own transcript, so the model never types its own identity. Another runtime passes
`-Model` / `-Effort`, which the record marks `caller-reported`. When filing a lapse that
happened in a different session (a recovered session, a subagent), add `-ForeignSession`
with `-Model`, so this session's transcript does not overwrite the real one.

**Log it even if the mistake is already fixed.** A silent fix is exactly the evaporation
this skill exists to stop.

**Check for a repeat before filing.** Search the ledger for an earlier row on the same rule:

```
python -c "import json;[print(o['n'],o.get('rule') or o.get('step')) for o in map(json.loads, open(r'<full path>.jsonl', encoding='utf-8')) if o.get('n')]" | grep -i "<keyword>"
```

Found one -> pass `-RepeatOf <n>`. Checked and it is new -> pass `-NotRepeat`. Pass
neither, and the script runs its own word-overlap match; on a likely hit it prints
`POSSIBLE REPEAT of n=<k>` and exits 3 **without appending**. Decide, then re-run once with
`-RepeatOf <k>` or `-NotRepeat`.

**On a repeat, strengthen the rule family, not the incident.** Any `-RepeatOf` append prints
a PROMOTE message. In the same run: (1) update the Fix candidates entry in the `.md` twin,
and (2) write one Open-threads line in the `CHECKPOINT.md` of the project that holds the
ledgers. The fix a repeat earns is a stronger version of the general rule it broke (one hook
or one rule per family of failure, such as "widened the scope without saying so"), never a
new rule shaped to this one incident. One narrow rule per repeat piles up fast and still
misses the next variation.

## Why it works this way
- **JSON Lines plus a script, not a Markdown table.** The ledgers started as Markdown
  tables; two sessions in a row appended rows out of order or retyped earlier rows. A script
  that only appends a line has no way to damage the history.
- **Model and effort are read, not reported.** A model asked to name itself can be wrong or
  stale; the session transcript records what actually ran.
- **The repeat check runs before the append.** A check after the append would mean a caller
  who agrees with the hint and re-runs files the same lapse twice.
- **The word-overlap threshold is low on purpose (0.15).** Calibrated against a real ledger:
  a 0.35 threshold caught none of seven known repeat pairs. Even at 0.15 the match only
  catches near-identical wording. The same mistake described in different words scores low
  at any threshold, so the search above is the real defense and the script's hint is only a
  backstop.
- **A repeat used to earn a new incident-specific gate.** That produced a stack of one-off
  rules, each shaped to one past mistake, while the next variation slipped past all of them.
  Strengthening the general rule is what the PROMOTE message asks for now.

## Rules
- Supplements `/checkpoint`. Never write resume-state or a changelog entry as the main act;
  if the finding is resume-state, hand it to `/checkpoint`. The one exception is the single
  Open-threads line a PROMOTE requires.
- Harness files only. No parallel memory store (no auto-memory files, no database).
- Capture, don't re-derive: work from what the conversation already established.
