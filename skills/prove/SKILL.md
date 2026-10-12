---
name: prove
description: Verifies disputed factual claims in a previous response against actual sources. Use for /prove, "prove it", "did you make that up", "source?", or "where did you get that" about an earlier assertion. Reports confirmed, wrong, or unverified claims with citations and corrects the answer.
---

# Prove the claims

1. Extract checkable assertions from the passage the user disputes: numbers, dates, names, paths, decisions, behavior, and source attributions. Prioritize consequential claims. Keep labeled opinions or speculation separate.
2. Verify each claim using the source appropriate to it:
   - **User/project facts:** current instructions, state, decisions, and relevant records.
   - **Artifact or behavior:** inspect the file, configuration, logs, or run a harmless demonstration.
   - **External facts:** current authoritative sources, preferably official documentation or primary evidence.
3. Resolve contradictory sources rather than treating either as automatically correct. Check dates and the actual artifact where possible. Memory may locate evidence but cannot confirm a claim.
4. Report one concise verdict per claim:
   - **Confirmed:** cite supporting evidence.
   - **Wrong:** give the correct fact and cite its source.
   - **Unverified:** name the missing evidence and withdraw the unsupported assertion.
5. If any claim changed, restate the corrected answer briefly. Flag any recommendation or action affected by the error.

Do not treat absence of contradiction as confirmation, repeat a claim more confidently, or stop while an available source remains unchecked. Preserve qualifications in the evidence. Use plain language and accessible citations.
