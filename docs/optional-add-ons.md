# Optional add-ons

Concept sketches that pair well with the harness but are not part of the default
install. Each is a shape, not an implementation — ask Claude to flesh one out for your
own machine when a need matches.

## A "rants" / musings folder

A capture-first space for unstructured thinking that doesn't belong in any project's
CHECKPOINT. Useful for dictating half-formed thoughts without committing them to a
project's actionable scope.

- A dedicated `rants/` folder as a sibling of project folders, with its own CLAUDE.md
  that sets a different working mode.
- **Two paired files per topic:** a verbatim file (the user's words, untouched) and a
  summary file (cleaned, lightly structured). Verbatim is the source of truth; if they
  disagree, verbatim wins.
- **Filenames are short slugs** (~15–25 characters, no date prefix; dates live inside
  the files) so the folder stays scannable.
- **Similar topics merge, new topics spawn pairs.** A fresh musing that sounds like an
  existing one gets confirmed with the user, appended to the verbatim file under a dated
  divider, and the summary refreshed. Optional hybrid files may synthesize across rants,
  referencing their sources by filename.
- **Default behavior in this folder is capture, not critique.** Transcribe and lightly
  clean; don't argue with the take, "balance" it, or summarize it back. Sparring is a
  separate mode the user triggers explicitly.

Why it's worth having: it keeps unstructured thinking out of project CHECKPOINTs, and
keeps Claude from reflexively turning every musing into an action item. Some thoughts
are just thoughts.

## A Cowork sibling (for users of Anthropic's Cowork app)

If you also use Cowork (Anthropic's scheduled-task / async workspace app), give it its
own `Cowork/` folder as a **sibling** of your project folders.

- `~/Claude/Cowork/` is the Cowork workspace root — select that folder in Cowork's
  picker.
- `Cowork/CLAUDE.md` is Cowork-scoped and short, like any other CLAUDE.md.
- `Cowork/Scheduled/` holds per-task subfolders, each with the `SKILL.md` Cowork runs.
- `Cowork/.claude/settings.local.json` holds Cowork session permissions, separate from
  project-level settings.
- `*.skill` plugin archives live in `Cowork/`, not in any project folder.

**Why a sibling, not a subfolder of a project:** both apps look for a `CLAUDE.md` at
their working directory; nested, they fight over the same file. **Why not the workspace
root itself:** installed at the umbrella root, Cowork-scoped settings bleed into every
project session and vice versa.

**A drift to watch for:** cloud-sync clients sometimes resurrect old folder skeletons
from their snapshots after you reconfigure sync targets. If empty `Scheduled/` or
`.claude/` folders reappear at the workspace root after the move, those are sync
ghosts — safe to delete.
