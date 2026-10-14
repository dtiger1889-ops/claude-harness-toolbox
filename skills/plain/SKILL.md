---
name: plain
description: >-
  Re-expresses a dense response in plain English while preserving its substance. Use for
  /plain, "say that in plain English", "de-jargon this", "unpack that", or "explain that
  like a normal person". Targets the previous assistant message unless the user supplies
  another passage. Picture mode, only when asked (/plain show, or "show me" about an
  answer), re-explains with the smallest plain-text picture - pseudocode, a call tree, a
  component or file tree, or a diff of a tree.
---

# Plain English

1. Identify the target passage; ask only if the target is ambiguous.
2. Look up unfamiliar project codes, tags, acronyms, and phase names in their source files. Do not guess. If a meaning is unavailable, say that explicitly.
3. Re-express all the substantive content in ordinary sentences. Expand compressed clauses and define unavoidable technical terms at first use.
4. Use short paragraphs or a clear list. Preserve qualifications, uncertainty, and actionable details; add no new analysis or next steps.

Example with fictional terminology:
- Dense: "The F027 gate blocks the B13 rung until the file hashes reconcile."
- Plain: "A check prevents the next build step until the two copies of the file match. They currently differ."

Use enough space to explain the meaning; brevity must not erase it.

## Picture mode (only when asked)

Runs only on `/plain show` or when the user says "show me" about an answer; otherwise the output stays prose. Adapted from the show-me skill in [humanlayer/skills](https://github.com/humanlayer/skills) (MIT).

1. Resolve every code first (step 2 above). Labels inside a picture are words too; a tree node named `F027` fails the same way a sentence does.
2. Pick the smallest picture that makes the point, usually one, rarely two:
   - steps or logic: pseudocode in plain words, numbered or indented
   - what runs what, in order: an indented call tree
   - how parts or files are arranged and who owns what: a shallow component or file tree
   - what changes: a `diff` block of the tree or list (`-` removed, `+` added) when the shape already exists; show the whole thing when most of it is new
3. Put one or two plain sentences before each picture saying what it shows. Keep only the parts that answer the point.
4. Use plain monospace text in a fenced block: ASCII only (`|--`, `` `-- ``, indentation), lines under about 60 characters so a phone terminal does not wrap them.
5. No Mermaid in a terminal or phone session, because it prints as raw text there. Do not write an HTML file or open a viewer. If plain text cannot carry the point (a screen layout, a dense comparison), say so and offer a rendered diagram instead.
6. Everything above still holds: what the picture cannot hold goes in plain sentences under it, so no substance is lost and no new shorthand or analysis comes in.
