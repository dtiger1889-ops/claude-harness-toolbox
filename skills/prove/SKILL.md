---
name: prove
description: The user suspects something in your last response was made up, or contradicts
  documented knowledge you didn't read -- and you must VERIFY it with sources, not re-assert
  it. Use when the user types /prove or says "prove it" / "prove that" / "did you make that
  up" / "source?" / "where did you get that" about your previous response. Extract every
  factual claim from the last few sentences you sent, look each one up (project files and
  harness docs first, then web search if needed), and report per-claim verdicts with
  citations -- confirming, correcting, or admitting unverifiable. Never defend a claim
  from memory.
---

# prove -- you asserted something; now back it with sources

The premise is FIXED: at least one factual claim in your last response is suspected of being
fabricated, misremembered, or contradicting documented knowledge you didn't read. Do NOT
re-assert it, defend it, or say "I'm confident that..." -- confidence from memory is the
exact thing being called out. Repeating the claim more firmly is failure. Every claim gets
looked up or downgraded.

## Step 1 -- extract the claims
List the factual assertions in the last few sentences of your previous response (or the
passage the user points at). A claim is anything checkable: a number, date, version, name,
file path, config behavior, API detail, "X works like Y", "the docs say", "you decided Z".
Opinions and hedged speculation that was *labeled* as speculation are out of scope.
Keep the list short and plain -- quote each claim in readable English, not shorthand.
Order the list by risk -- most load-bearing claims first, and treat classic red-flag features
as raising suspicion (suspiciously round numbers, rates at exactly 0%/100%, a figure that
perfectly confirms what you wanted to be true) -- so if the turn gets cut short, the
highest-risk claims are already verified.

## Step 2 -- verify each claim, in this order
For EACH claim, walk the ladder until you hit a real source; do not skip rungs because you
"already know":

1. **Local documented knowledge first.** If the claim is about the user's projects, machine,
   harness, or past decisions, the truth lives in files: the relevant project's `CLAUDE.md`,
   `CHECKPOINT.md`, specs, archives. Read them. (If your workspace `.gitignore` hides
   project files from the ripgrep-backed Grep tool, search with plain `grep -rin` instead.)
   A claim that contradicts these files is WRONG until the file is shown to be stale.
2. **The actual artifact.** If the claim is about code, config, a file's contents, or tool
   behavior, read the file or run the harmless command that demonstrates it. Output beats
   recollection.
3. **Web search.** If the claim is about the outside world (library versions, API behavior,
   product facts, dates, prices), search for an authoritative source. Prefer official docs
   over blog posts. If a reference agent or skill covers the topic, use it instead of memory.
4. **No source found** -> the claim is UNVERIFIED. Say so plainly. Do not promote "I couldn't
   find a contradiction" to "confirmed".

## Step 3 -- report verdicts, one line each
For each claim, one of exactly three verdicts, with the source named:
- **Confirmed** -- quote or cite the source (file path:line, URL, command output).
- **Wrong** -- state the correct fact, cite the source, and say what you got wrong. No
  softening ("technically", "depending on interpretation") unless the source itself hedges.
- **Unverified** -- you could not find a source either way; the claim should be treated as
  unreliable and you retract it as an assertion.

Then, if any verdict was Wrong or Unverified, restate the corrected version of the original
answer in one tight paragraph -- the fixed RESULT, not a meditation on the error. If the
wrong claim changed a recommendation or action you took, flag that explicitly.

## Rules
- Memory (training data OR persistent auto-memory) is never a verdict source. Memory can
  point you at where to look; the file you then read is the source.
- Don't punt with "hard to verify" while rungs remain unclimbed.
- Plain English throughout -- claims and verdicts readable on a phone, no invented codes.
- If verification requires something genuinely unavailable (paywalled source, offline-only
  data), say exactly what's missing and mark Unverified -- one tight sentence, not a shrug.
