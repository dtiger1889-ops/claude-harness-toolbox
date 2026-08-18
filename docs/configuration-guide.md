# Configuration guide

This is the optional human-facing configuration tour removed from `harness_me.txt`. It
explains choices that affect the harness without making an installing agent parse a
general settings lesson.

Last reviewed: 2026-08-18. Claude Code settings and interface labels change; the linked
official documentation is authoritative when it conflicts with this guide.

## Permission mode

Start in `default` mode when you want to approve impactful actions individually, or
`plan` mode when the session should investigate without editing. Use `acceptEdits` when
you are comfortable reviewing file changes after they happen while still approving other
tool categories.

Manage repeated decisions through `/permissions` and narrowly scoped `allow`, `ask`, and
`deny` rules. Deny takes precedence over ask, which takes precedence over allow. Treat
`bypassPermissions` as an isolated-container or disposable-VM mode, not a daily default.

See [Configure permissions](https://code.claude.com/docs/en/permissions) and
[Choose a permission mode](https://code.claude.com/docs/en/permission-modes).

## Put settings at the right scope

| Scope | Use in this toolbox |
|---|---|
| User `~/.claude/settings.json` | Hooks and preferences that must apply across workspaces |
| Shared project `.claude/settings.json` | Configuration intentionally distributed with one project |
| Local project `.claude/settings.local.json` | Machine- or user-specific project permissions and overrides |
| Managed settings | Organization-enforced policy that lower scopes cannot override |

The installer puts harness hooks at user scope because orientation and compaction behavior
must still fire when a session starts inside a project subfolder. Merge settings; never
replace an existing file. Hook command paths must be absolute, and every hook should be
tested in a fresh session after editing its registration.

See [Claude Code settings](https://code.claude.com/docs/en/configuration).

## Skills and project instructions

Use `CLAUDE.md` for concise always-on facts and rules. Use a skill for reusable knowledge
or a multi-step workflow that should load on demand. Install toolbox-wide skills under
`~/.claude/skills/<name>/`; keep project-specific skills with the project.

Skill names and descriptions can consume startup context even when the full skill body is
not loaded. Keep descriptions focused on when the skill should trigger, and disable skills
that do not belong in the current setup.

See [Extend Claude with skills](https://code.claude.com/docs/en/slash-commands).

## MCP servers

MCP supplies connections and tools; skills supply the instructions for using them. Enable
an MCP server only when its data or actions are useful to the work. Each enabled server's
tool definitions compete for context, so a large inactive connector set creates a tax even
before a tool runs.

Choose the narrowest appropriate scope, review authentication and write capabilities, and
remove or disable servers that are not being used.

See [Extend Claude Code](https://code.claude.com/docs/en/features-overview).

## Pick one durable-memory system

This toolbox treats `CLAUDE.md` plus `CHECKPOINT.md` as the authoritative durable store.
Current Claude Code versions also enable project-scoped auto memory by default. To follow
the toolbox's single-store design, turn auto memory off with `/memory` or set the Boolean
`autoMemoryEnabled` field to `false` at the applicable project settings scope.

Auto memory is a legitimate alternative, but maintaining the same facts in auto memory
and harness files creates two authorities that can drift. If you keep auto memory enabled,
use `/memory` to inspect what it saved and define which information belongs in each store.

See [How Claude remembers your project](https://code.claude.com/docs/en/memory).

## Compaction and resume state

Claude Code compacts automatically as context fills; `/compact` triggers it manually. The
toolbox's PreCompact hook reminds the session to update `CHECKPOINT.md` first so mutable
state survives as a readable artifact rather than only as a generated summary.

After compaction, project-root `CLAUDE.md` is re-injected from disk. Nested instruction
files reload when Claude reads a file in their subtree. CHECKPOINT remains the explicit
resume record: if a decision or open thread must survive, write it there before compaction.

See [Explore the context window](https://code.claude.com/docs/en/context-window).

## Check the context budget

Use `/context` to inspect what occupies the active window. Always-loaded instructions,
auto memory, MCP tool definitions, and skill descriptions all contribute before task files
and conversation history. Remove unused connectors and skills, and move lookup material
out of always-loaded files before changing compaction thresholds.

## Deliberately outside this guide

Theme and appearance have no harness effect. Click-by-click interface paths and model
rankings age quickly and do not belong in a durable toolbox document. Use the current
Claude Code interface and official model guidance for those choices.
