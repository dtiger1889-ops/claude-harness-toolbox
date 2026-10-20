---
name: new-project
description: >-
  Scaffolds a new project folder from the harness templates and -- the
  load-bearing half -- registers it everywhere it must appear (the project
  ledger, any container index, its backup lane). Use when the user says
  "/new-project", "new project", "set up a project for X", or promotes an
  outgrown scratch folder to a project of its own. Do NOT use for adding a
  subfolder inside an existing project, or for work in a project that already
  has its CLAUDE.md and CHECKPOINT.md.
---

# /new-project -- scaffold + register a project

Scaffolding tends to get done; registration tends to get skipped, and a project no
index names is invisible to every later session. Never end this skill with the folder
scaffolded but unlisted. Conventions live in the workspace-level `CLAUDE.md`; the
skeletons are this repo's `templates/`, copied wherever you keep them.

## Step 0 -- the three questions (ask only what the conversation hasn't answered)

1. **Name** -- short kebab/snake slug; folder name = project name. Name it for what it
   DOES, not for the model that built it, so the name survives a change of agent.
2. **Location** -- top-level project, or an occupant of a container folder (one for
   experiments, one for small apps)? Default: experiments and one-offs start in the
   experiments container and get promoted later; anything with a standing goal goes
   top-level.
3. **Backup lane** (required -- every folder needs one):
   - **Synced folder** -- if it lands under a folder a sync service covers, say so.
     A two-way sync copies deletions too, so it is coverage, not a backup.
   - **Private git repo** -- only when the user asks for git; see Step 1b. A public
     repo needs the user's explicit per-repo decision and their publish review, never
     a `--public` flag by default. Inside an existing repo, the parent repo IS the
     lane: verify the new folder is not gitignored.

## Step 1 -- scaffold from the templates (never freehand)

```
templates/CLAUDE.md.template      -> <proj>/CLAUDE.md
templates/CHECKPOINT.md.template  -> <proj>/CHECKPOINT.md
templates/gitignore.template      -> <proj>/.gitignore   (new repo only)
```

Fill every `[bracketed placeholder]`. CLAUDE.md stays <= 30 lines with a line-2
version stamp (`<!-- v1 -- YYYY-MM-DD -->`). CHECKPOINT.md gets `Last updated:` from
the real clock in UTC (run a command, never guess) and the sections Status / Goal /
Key decisions / Open threads / Files that matter / Next step / Harness changelog.
A private repo's `.gitignore` covers only secrets, personal data and machine junk,
never a working file (CHECKPOINT, CLAUDE.md, specs, docs), because a resumed session
needs them.

### Step 1b -- create a private repo only after the project files are complete

- Inspect the folder first for nested `.git` directories, secrets or personal data,
  generated output, databases, archives and large files; write `.gitignore` first.
  Stop if a repo already exists there and diagnose it instead of initializing over it.
- `git init -b main`. If the folder sits inside a sync service, keep the git metadata
  outside it (`--separate-git-dir <path outside the synced tree>`), because a sync
  client rewriting a live `.git` folder corrupts it.
- Stage only after every placeholder is filled; inspect the staged tree and its largest
  files before committing. Create the remote **private**, add `origin`, push `main`.
- Check every command's result; never suppress a failure and print success after it.

## Step 2 -- register (do ALL that apply)

- **Top-level project** -> a row in the project ledger (the one file listing every
  project, with a one-line purpose) and a note in the workspace CHECKPOINT changelog.
- **Container occupant** -> the container's `CLAUDE.md` contents list AND its
  `CHECKPOINT.md` Status line, same turn.
- **Either way** -> name the backup lane in the project's CLAUDE.md or the container's
  conventions, so a later audit doesn't have to re-derive it.
- **New private repo** -> every list that tracks repos (backup script, repo monitor,
  public/private registry), same turn.

## Step 3 -- research-first opening

The project's first working turn writes a `## Research` block in its CHECKPOINT
(prior art, constraints, open questions, sources) before any implementation. Shipped
solutions first: GitHub, published skills, community writeups; default to
adopt/adapt with a citation. Building from scratch needs a stated reason.

## Step 4 -- verify before closing

Copy this checklist into the reply and tick each item:

```
- [ ] CLAUDE.md <= 30 lines, CHECKPOINT.md <= 120 lines (counted, not estimated)
- [ ] every index from Step 2 re-read and shows the new name
- [ ] backup lane real: inside a synced tree, repo pushed, or parent repo covers it un-ignored
- [ ] new private repo: branch main, remote private and pushed, on every repo list
- [ ] "registered in: ..." reported to the user
```

## Promotion variant (container -> top-level)

Same skill, reversed entry: move the folder up (a real move, never copy + delete), add
the ledger row, remove it from the container's contents list and Status, note the move
in both changelogs, and pick a new backup lane the same turn if leaving a git repo's
tree took the old one away.
