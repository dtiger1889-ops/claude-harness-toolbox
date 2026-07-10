#!/usr/bin/env bash
# ~/.claude/hooks/orient_gate.sh — PreToolUse orientation gate (Mac/Linux).
# Mirrors orient_gate.ps1: blocks (exit 2) the FIRST world-changing action of a session
# until CHECKPOINT.md has been read this session, then allows (block-once). Fails OPEN.
# NOTE: faithful port of the maintainer's live, Windows-tested PowerShell version; it has
# NOT been verified on macOS/Linux hardware. Test before relying on it (see harness_me.txt
# Section 6, checklist item 5). Requires jq; fails open if jq is missing.
raw="$(cat)"; [ -z "$raw" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0          # no jq -> fail open

tool="$(printf '%s' "$raw" | jq -r '.tool_name // empty')"
cwd="$( printf '%s' "$raw" | jq -r '.cwd // empty')"
tp="$(  printf '%s' "$raw" | jq -r '.transcript_path // empty')"
sid="$( printf '%s' "$raw" | jq -r '.session_id // empty')"

# Gate only world-changing / external tools; read-only tools pass straight through.
gated=0
case "$tool" in
  Write|Edit|MultiEdit|NotebookEdit|Bash|WebSearch|WebFetch) gated=1 ;;
  mcp__*)
    method="${tool##*__}"
    printf '%s' "$method" | grep -Eq '^(create|update|delete|add|send|set|fill|apply|save|submit|publish|archive|log|rebuild|respond|upload|insert|remove|patch|write|draft|move|copy)(_|$)' && gated=1 ;;
esac
[ "$gated" = 1 ] || exit 0

# No CHECKPOINT.md at or above cwd -> nothing to orient against -> never block.
dir="$cwd"; has_cp=0
while [ -n "$dir" ]; do
  [ -f "$dir/CHECKPOINT.md" ] && { has_cp=1; break; }
  parent="$(dirname "$dir")"; [ "$parent" = "$dir" ] && break; dir="$parent"
done
[ "$has_cp" = 1 ] || exit 0

# Already read a CHECKPOINT.md this session?
if [ -n "$tp" ] && [ -f "$tp" ]; then
  grep -Eq '"name":[[:space:]]*"Read".*CHECKPOINT\.md' "$tp" && exit 0
fi

# Block-once: per-session sentinel in the temp dir.
safe_sid="$(printf '%s' "$sid" | tr -c 'A-Za-z0-9_-' '_')"
flag="${TMPDIR:-/tmp}/orient_gate_${safe_sid}.flag"
[ -f "$flag" ] && exit 0
: > "$flag" 2>/dev/null

echo "ORIENTATION GATE: this session has not read CHECKPOINT.md and you are about to run a world-changing action ($tool). FIRST Read the project's CHECKPOINT.md to EOF and follow its Open threads / Next step. If you have genuinely judged this a pre-oriented one-shot, just re-issue this exact call -- the gate fires only once per session." >&2
exit 2
