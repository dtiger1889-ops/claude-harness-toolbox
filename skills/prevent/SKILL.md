---
name: prevent
description: Corrects a repeated or documented mistake and strengthens the failing workflow so the rule is encountered or enforced at decision time. Use for /prevent, "we've talked about this", "you should know this", "this is documented", or "why do you keep doing this" about previous work. Delivers a durable workflow change, not a promise.
---

# Prevent recurrence

1. **Correct the immediate mistake.** Identify the wrong action plainly and fix it within the authorized scope. Do not delay the correction for the prevention work.
2. **Find the existing knowledge.** Search relevant instructions, current state, decisions, archives, and targeted transcript excerpts. Cite the source. If it was never recorded, say so rather than inventing prior documentation.
3. **Diagnose the missed path.** Establish whether the rule was absent, misplaced, buried, in the wrong layer, skipped by this entry point, or read but unenforced. Separate proven causes from hypotheses.
4. **Change the narrowest reliable layer:**
   - Mechanical patterns: a tested hook, validator, or deny rule.
   - Local workflow constraints: a short colocated instruction.
   - Stable project behavior: project instructions.
   - Mutable state or pending implementation: the project's state or tracker.
   - Cross-project behavior: the shared instructions, only when every affected workflow needs it.
5. **Verify reach and behavior.** Check that the failing workflow actually loads or fires the change. For enforcement, test a violating case and a legitimate exception. Record any untested limitation.
6. **Report briefly:** correction applied; source and diagnosed gap; durable change and verification.

Preserve detailed records in their existing owner documents; add a short pointer rather than duplicating history. Follow the project's versioning, changelog, and size conventions. Use its designated durable store, not a new parallel memory system.

Do not create an unnecessary edit merely to claim prevention. If the existing rule is correct, address enforcement or the read path. For recurrence across entry points, strengthen the general failure family rather than adding a separate rule for each incident.

## Restricted runtimes

Use the connected filesystem and re-check its reachable roots if needed. A shell in a container does not imply access to the user's machine.

If local configuration or hooks cannot be edited or tested, write a concrete proposal in the owning project's existing tracker: exact destination, trigger, rule text, exceptions, and acceptance checks. Mark implementation pending. If no durable write is possible, give the proposal and state the access blocker; never claim it is installed.
