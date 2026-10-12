---
name: redteam
description: Runs one adversarial review of a claim, plan, or answer. Use only for /redteam, "push back on this", "red-team this", or "stress-test this". Identifies failure mechanisms and the cheapest way to test them. For broader ideation use fanout; for source verification use prove.
---

# Red-team review

1. Identify the target from the supplied passage, file, or previous answer. Ask once if ambiguous.
2. Read a referenced artifact and its project's current state and instructions to EOF. Include existing decisions and constraints in the review.
3. Attempt to disprove the target. Report:
   - **Strongest objection:** the most consequential plausible failure, with its mechanism and evidence.
   - **Critical assumption:** what must hold for the target to work.
   - **Alternative explanation:** if supported; omit rather than invent a decoy.
   - **Cheapest disproof:** a concrete check that could settle the objection.
   - **Verdict:** survives, needs revision, or abandon, with the most important fix.
4. If the target is a file this session wrote and the fix is within the authorized scope, apply it and report the change. Otherwise deliver the review without editing someone else's artifact.

Run one pass. Be direct, distinguish evidence from hypotheses, and say when the target survives. Do not manufacture flaws or claim an unrun check proves the verdict.
