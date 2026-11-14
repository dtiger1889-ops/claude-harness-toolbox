---
name: prove
description: Verifies disputed factual claims in a previous response against actual sources. Use for /prove, "prove it", "did you make that up", "source?", or "where did you get that" about an earlier assertion. Reports confirmed, wrong, or unverified claims with citations and corrects the answer.
---

# Prove the claims

1. Extract checkable assertions from the passage the user disputes: numbers, dates, names, paths, decisions, behavior, and source attributions. Keep labeled opinions or speculation separate. Order the list by risk, most load-bearing first, and rank red-flag features higher (suspiciously round numbers, rates of exactly 0% or 100%, a figure that neatly confirms what the answer wanted), so a cut-short turn has already checked the riskiest claims.
2. Verify each claim using the source appropriate to it:
   - **User/project facts:** current instructions, state, decisions, and relevant records.
   - **Artifact or behavior:** inspect the file, configuration, logs, or run a harmless demonstration.
   - **External facts:** current authoritative sources, preferably official documentation or primary evidence. When a documentation tool or reference skill in the session covers the topic, use it rather than memory.
3. Resolve contradictory sources rather than treating either as automatically correct. Check dates and the actual artifact where possible. Memory may locate evidence but cannot confirm a claim.
4. Report one concise verdict per claim:
   - **Confirmed:** cite supporting evidence.
   - **Wrong:** give the correct fact and cite its source.
   - **Unverified:** name the missing evidence and withdraw the unsupported assertion.
5. If any claim changed, restate the corrected answer briefly. Flag any recommendation or action affected by the error.

Do not treat absence of contradiction as confirmation, repeat a claim more confidently, or stop while an available source remains unchecked. Preserve qualifications in the evidence. Use plain language and accessible citations.
