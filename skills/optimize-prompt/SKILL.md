---
name: optimize-prompt
description: One deliberate rewrite pass that applies Anthropic's current prompt-engineering best practices to an existing draft prompt (SKILL.md, scheduled-task prompt, API/system prompt, one-off task prompt). Use when the user types /optimize-prompt or says "optimize this prompt" / "improve this prompt" / "tune this prompt" / "apply prompt best practices to X". Input is a pasted prompt, @-mentioned file, or a pointer to where the prompt lives. Outputs the rewritten prompt + a what-changed rationale to chat — NEVER auto-overwrites the source. "--check" diagnoses without rewriting. NOT a from-scratch prompt generator (that is a normal conversation) and NOT an eval/judge loop (those degrade past iteration 2-3).
---

# optimize-prompt -- one-pass prompt rewrite

Grounded in platform.claude.com prompting best-practices + prompting-tools (the Console
prompt improver's 4-step transform) + the model-specific pages (Fable 5, Sonnet 5, Opus 4.8);
community: arxiv 2601.22025 (generic rewrites measured net-negative), Decagon GEPA production
notes (length caps = regularization), DreamHost 25-technique test (emphasis devices dead;
XML/few-shot/ordering alive). When maintaining this skill, re-verify against the LIVE docs,
not memory.

## Step 1 -- target + context
- Get the draft: pasted text, @-mentioned file, or a described location (find it, Read to EOF).
- If context is absent AND material, ask ONCE, one message: target surface (Claude Code
  SKILL / API system prompt / scheduled-task prompt / chat one-off) and latency-vs-accuracy
  preference. Defaults: accuracy; Claude 4.6+/Fable-era models.
- `--check` flag → run Step 2 only, report the defect list, stop. No rewrite.
- **SKILL.md detection:** if the target is a Claude Code SKILL.md, additionally apply the
  skill-authoring conventions: description in third person carrying the WHEN-triggers
  (discovery lives in YAML, execution in the body); body is a procedure to run, not
  reference prose; <250 lines; multi-step must-not-skip flows get a copy-this checklist;
  deterministic steps → scripts. Descriptions for auto-trigger skills should be slightly
  "pushy" -- enumerate the concrete phrasings and contexts that should trigger, including
  implicit ones (undertriggering is the documented failure mode) -- but NEVER loosen an
  explicitly gated skill's "use ONLY when" fence into auto-trigger language.

## Step 2 -- diagnose (no rewriting yet)
Classify each chunk of the draft (role, instructions, context/data, examples, output spec),
then list concrete defects against the Step 3 checklist. Name each defect + where it is.

## Step 3 -- rewrite
**Preserve task-specific constraints verbatim.** Generic rewrites that smooth away task
specifics lose more than they gain (arxiv 2601.22025: −10% extraction, −13% RAG compliance).
When unsure whether a constraint is task-specific or accidental, keep it and flag it.

Checklist:
- **Structure:** one-sentence role if missing; wrap distinct content types in XML tags
  (`<instructions>`, `<context>`, `<examples>`, `<input>`); variable parts →
  `{{template_variables}}`; long data ABOVE instructions/query (20k+ context: query-at-end
  is worth up to ~30%); multi-doc inputs → nested `<documents><document index>` shape.
- **Instructions:** negative constraints → positive equivalents ("write flowing prose" not
  "no markdown"); add the WHY to rules so the model generalizes; vague scope → explicit
  ("every section, not just the first"); strip MUST/CRITICAL/ALL-CAPS emphasis (4.5+ models
  overtrigger on it); explicit output-format spec; imperative verbs for tool actions.
- **Examples:** wrap in `<example>` tags; flag if <3 or >5; ensure at least one edge case;
  reasoning tasks get a `<thinking>` block inside examples; flag examples written for older
  model generations as stale.
- **Reasoning:** complex tasks get numbered analysis steps + a self-check line ("before
  finishing, verify against <criteria>"); prefer "consider/evaluate" over "think" when
  extended thinking is off.
- **Model-currency sweep (4.6+/Fable):** remove assistant prefills (400 error now);
  `budget_tokens` → adaptive thinking + `effort`; remove "reproduce your reasoning in the
  response" asks (Fable refusal trigger); dial back anti-laziness/over-prescriptive language
  carried from 3.x-era prompts — newer models DEGRADE under it, so cutting old instructions
  is often the optimization.
- **Anti-bloat regulator:** compress examples aggressively, instructions barely (asymmetric
  compression); if the rewrite exceeds 1.5x the input length, cut before delivering.

## Step 4 -- report
Output to chat:
1. The optimized prompt in a fenced block.
2. Bulleted "what changed and why" — each bullet names the rule applied.
3. Deliberate non-changes ("kept your negative constraint because it carries a why").
If the source is a file and the user asks for a file, write a SIBLING `<name>.optimized.md`.
Never overwrite the source; the user applies it.

## Never (failed approaches, pre-encoded)
- No eval loops, golden sets, or LLM-as-judge iteration — judges carry systematic biases
  and loops degrade past iteration 2-3. One pass, human reviews.
- No generic "helpful assistant" framing added to task prompts (measured net-negative).
- No multi-candidate tournaments / token-burning fan-out.
- No blank-page generation from a vague wish — require a draft or a concrete task description.
