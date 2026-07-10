---
name: plain
description: Re-explain a dense, jargon-loaded, or code-stuffed response in plain, generous
  English. Use when the user types /plain or says "say that in plain english" / "english
  please" / "de-jargon this" / "unpack that" / "explain that like a normal person".
  Targets the PREVIOUS assistant message by default, or a pasted/@-mentioned block.
  Expands every invented code/tag/acronym into people-words by LOOKING IT UP (never
  guessing), keeps ALL the substance, and introduces NO new shorthand. This is the
  on-demand enforcement of a standing plain-language rule.
---

# plain -- translate a dense/jargon response into plain English

The standing rule this enforces: plain, verbose English in chat, no self-invented codes.
It keeps getting violated -- responses come back stuffed with filing codes (`F027`, `B13`,
`PTT`, a `def_hash`...), unexpanded acronyms, and compressed noun-stacks that are a wall
to read. This skill is the fix: take that response and SAY IT AGAIN in plain,
conversational, generous English.

This is the ANTI-terse skill -- the opposite of /breakdown. Length is fine; losing meaning
is not.

## What to translate
Default target: the immediately previous assistant message. If the user pasted text or
@-mentioned a file/block, translate that instead. If it is ambiguous which, ask once.

## How to do it
1. **RESOLVE every code, tag, and acronym to its real meaning -- do NOT guess.** When a
   filing code / phase name / gate name / hash appears, look it up in the project files
   (e.g. `findings.md`, `CHECKPOINT.md`, the relevant spec) and state what it actually IS
   in people-words. If you genuinely cannot find what a code refers to, say
   "I couldn't find what `X` refers to" -- never bluff a meaning.
2. **Re-express, don't summarize.** Keep ALL the substance. This is a translation, not a
   trimmed recap; dropping detail to be shorter is the failure mode.
3. **Unpack** compressed noun-stacks and nested clauses into short, ordinary sentences.
4. **Introduce NO new shorthand** -- no codes, no project jargon. If a technical term is
   genuinely unavoidable, define it inline the first time you use it.
5. **Structure for reading** -- short paragraphs or a plain list, not a block.

## Rules
- Plain, generous English. Verbose is correct here; terse is wrong.
- Never invent a meaning for a code you couldn't resolve.
- Don't add new analysis, opinions, or next steps -- just make the existing content legible.
  If the user wants more, they'll ask.
