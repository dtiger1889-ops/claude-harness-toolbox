---
name: log
description: Records reusable facts, corrections, decisions, and rule violations in the document or ledger that owns them. Use for /log, "log this", "capture this", "write that down", "don't lose this", or "log that lapse". Complements checkpoint, which owns project resume state; does not run on every answer.
---

# Log reusable findings

1. Extract the finding from the named passage or previous answer. Capture established facts and sources; do not re-research. If nothing is durable, report "nothing to log".
2. Classify and route:
   - Reference fact or mechanism: the owning living document.
   - Decision: its decision record or existing decisions convention.
   - Event or resume state: checkpoint or the project's changelog procedure.
   - Skipped required skill step: a skill-lapse ledger.
   - Broken general instruction: a rule-lapse ledger.
3. Read the target's structure. Correct erroneous text in place or add a dated entry. Name the evidence and author: user decision only for an explicit user choice, otherwise model finding or recommendation.
4. For a cross-project finding, record it at its owner and leave a concise pointer where needed. If no owner document exists, propose an appropriate home and obtain any permission required by the project's conventions.
5. Report what was written and its clickable path briefly.

Use the project's designated durable store. Do not create a parallel memory system or convert one-off feedback into a standing rule.

## Lapse ledgers

Use JSON Lines records with a Markdown twin for scope and Fix candidates. For a new ledger, copy [ledger-template.md](ledger-template.md) and create an empty JSONL beside it.

Resolve `<skill-dir>` to the directory containing this loaded SKILL.md, including plugin installations. The bundled `log_lapse.ps1` requires PowerShell. Append through it only; never edit or rebuild existing JSONL rows by hand.

General rule invocation, as one PowerShell command:

```powershell
& "<skill-dir>/log_lapse.ps1" -LogFile "<ledger>.jsonl" -Rule "<broken rule>" -Session "<context>" -Consequence "<cost>" -HowCaught "<how found>" -FixStatus "<correction; author and date>" -NotRepeat
```

Replace `-Rule` with `-Skill "<skill>" -Step "<skipped step>"` for a skill lapse.

Before appending, search earlier rows for the same failure family. Use `-RepeatOf <n>` instead of `-NotRepeat` for a confirmed repeat. Use `-NotRepeat` only after checking. With neither flag, the script may detect a possible repeat and exit 3 without appending; decide whether it is a repeat, then retry once with the appropriate flag. The fuzzy hint is a fallback, not a semantic duplicate check.

The script obtains model/effort from the current Claude Code transcript when available. Other runtimes pass `-Model` and `-Effort` as caller-reported values. For a lapse in another session, use `-ForeignSession -Model "<actual model>"` and available effort evidence so this session is not misattributed.

Record fixed lapses too. For a repeat, update the Markdown Fix candidates entry and one owning-project open item with a suggested family-level prevention change. Do not implement a new gate merely because the script prints PROMOTE.

If PowerShell or the ledger is unavailable, report the blocker and preserve a proposed record in an accessible owning document where authorized. Do not claim a ledger append succeeded.
