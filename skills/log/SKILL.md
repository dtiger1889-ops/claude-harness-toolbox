---
name: log
description: Records reusable facts, corrections, decisions, and rule violations in the document or ledger that owns them. Use for /log, "log this", "capture this", "write that down", "don't lose this", or "log that lapse". Complements checkpoint, which owns project resume state; does not run on every answer.
---

# Log reusable findings

A fact proved, a claim corrected or a small decision made mid-conversation is not resume state, so nothing else forces it to disk and it dies with the scrollback. This skill is that forcing step.

When the bundled `log_backstop` hook prompts a run after /prove, /prevent, /fanout, /outside or /dumb, treat it as a consideration pass: if nothing durable came out, report "nothing to log" and stop. Never manufacture a finding.

1. Extract the finding from the named passage or previous answer. Capture established facts and sources; do not re-research. If nothing is durable, report "nothing to log".
2. Classify and route:
   - Reference fact or mechanism: the owning living document.
   - Decision: its decision record or existing decisions convention.
   - Event or resume state: checkpoint or the project's changelog procedure. If the event holds a durable kernel that would be lost once the changelog is archived, record that kernel in a reference document too.
   - Skipped required skill step: a skill-lapse ledger.
   - Broken general instruction: a rule-lapse ledger.
3. Find the owner. The owning project may differ from the active one. A live finding goes in the ongoing working document; a finding that resolves a spec goes where that spec now lives (open or closed). Read the target's structure before placing the entry.
4. Write it. Correct erroneous text in place, or add a dated entry in the target's house style; with no house style, use `YYYY-MM-DD -- <claim> -- <evidence or source> -- <author>`. Author is a user decision only for an explicit user choice, otherwise model finding or recommendation. Update the document's last-updated or version stamp. Give any invented code or shorthand a plain-words gloss in the same sentence. A rule written from a user's correction quotes the user's exact words beside it and drops any clause that restricts more than they did.
5. For a cross-project finding, record it at its owner and leave a one-line pointer in the active project. If no owner document exists, stop, propose an appropriate home, and obtain any permission required by the project's conventions. This is the one point where the skill asks before writing.
6. Report one line per finding: what was written and its clickable path, plus any pointer left or new home proposed. Do not recap the finding.

Use the project's designated durable store. Do not create a parallel memory system or convert one-off feedback into a standing rule. Never write resume state or a changelog entry as the primary act (except the PROMOTE line below); hand resume state to checkpoint.

## Lapse ledgers

Route a lapse by the HOME of the ignored rule, not the active session's project: a skipped skill step goes to the skill-lapse ledger of the project that owns that skill (one ledger per project, with a Skill column); a broken general conduct rule goes to the rule-lapse ledger of the project that owns the shared instructions.

Use JSON Lines records with a Markdown twin for scope and Fix candidates. For a new ledger, copy [ledger-template.md](ledger-template.md) and create an empty JSONL beside it.

Resolve `<skill-dir>` to the directory containing this loaded SKILL.md, including plugin installations. The bundled `log_lapse.ps1` requires PowerShell. Append through it only; never read, edit or rebuild existing JSONL rows by hand.

Before appending, search earlier rows for the same failure family, for example:

```bash
python -c "import json,sys;[print(o['n'],o.get('rule') or o.get('step')) for o in map(json.loads,open(sys.argv[1],encoding='utf-8')) if o.get('n')]" "<ledger>.jsonl" | grep -i "<keyword>"
```

General rule invocation, as one PowerShell command:

```powershell
& "<skill-dir>/log_lapse.ps1" -LogFile "<ledger>.jsonl" -Rule "<broken rule>" -Session "<context>" -Consequence "<cost>" -HowCaught "<how found>" -FixStatus "<correction; author and date>" -NotRepeat
```

Replace `-Rule` with `-Skill "<skill>" -Step "<skipped step>"` for a skill lapse. Say in `-HowCaught` whether the model caught it or the user did; end `-FixStatus` with author and date.

Use `-RepeatOf <n>` instead of `-NotRepeat` for a confirmed repeat. Use `-NotRepeat` only after checking. With neither flag, the script may detect a possible repeat and exit 3 without appending; decide whether it is a repeat, then retry once with the appropriate flag. The fuzzy hint is a fallback, not a semantic duplicate check.

In Claude Code the script reads model and effort from the session transcript; do not pass your own model identity. Other runtimes pass `-Model` and `-Effort` as caller-reported values. For a lapse in another session (a recovered session, a subagent, another runtime), use `-ForeignSession -Model "<actual model>"` and available effort evidence so this session is not misattributed.

Record fixed lapses too. On a PROMOTE message (any `-RepeatOf` append), in the same run: update the Markdown twin's Fix candidates entry for the family, listing every n; and write or widen the ONE open-item line for that family in the owning project's state file. Edit only that line: search the file for the open-items heading and the family's line, read just those lines, and widen the existing line or insert a new one under the heading. The fix a repeat earns is a stronger version of the general rule family, never a rule shaped to one incident. Do not implement a new gate merely because the script prints PROMOTE.

If PowerShell or the ledger is unavailable, report the blocker and preserve a proposed record in an accessible owning document where authorized. Do not claim a ledger append succeeded.
