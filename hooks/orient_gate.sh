#!/usr/bin/env bash
# ~/.claude/hooks/orient_gate.sh -- PreToolUse orientation gate (Mac/Linux).
# Mirrors orient_gate.ps1: blocks (exit 2) every world-changing action of a session until the
# NEAREST CHECKPOINT.md (at or above cwd) has been read this session. Read only counts when each
# Read call got a successful tool_result and the Reads' line ranges together cover the whole
# file, after the session's last /clear (a Read before a compaction still counts). Re-issuing a
# blocked call does not pass; set ORIENT_GATE_BLOCK_ONCE=1 for the older block-once behaviour.
# Fails OPEN on any error.
# NOTE: a port of the maintainer's Windows-tested PowerShell version; it has NOT been verified
# on macOS/Linux hardware. Test before relying on it (see harness_me.txt Section 6, checklist
# item 5). Requires jq; fails open if jq is missing.
raw="$(cat)"; [ -z "$raw" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0          # no jq -> fail open

field() { printf '%s' "$raw" | jq -r "$1" 2>/dev/null; }
tool="$(field '.tool_name // empty')"
cwd="$( field '.cwd // empty')"
tp="$(  field '.transcript_path // empty')"
sid="$( field '.session_id // empty')"

# Gate only world-changing / external tools; read-only tools pass straight through.
gated=0
case "$tool" in
  Write|Edit|MultiEdit|NotebookEdit|Bash|WebSearch|WebFetch) gated=1 ;;
  mcp__*)
    method="${tool##*__}"
    printf '%s' "$method" | grep -Eq '^(create|update|delete|add|send|set|fill|apply|save|submit|publish|archive|log|rebuild|respond|upload|insert|remove|patch|write|draft|move|copy)(_|$)' && gated=1 ;;
esac
[ "$gated" = 1 ] || exit 0

# Nearest CHECKPOINT.md at or above cwd (case-exact: a lower-case checkpoint.md is a note).
# None -> nothing to orient against -> never block.
dir="$cwd"; cp=""
while [ -n "$dir" ]; do
  if [ -f "$dir/CHECKPOINT.md" ] && ls -1A "$dir" 2>/dev/null | grep -qx 'CHECKPOINT.md'; then
    cp="$dir/CHECKPOINT.md"; break
  fi
  parent="$(dirname "$dir")"; [ "$parent" = "$dir" ] && break; dir="$parent"
done
[ -n "$cp" ] || exit 0

# Absolute, symlink-resolved form of a path whose folder exists ("" otherwise).
canon() { d="$(dirname -- "$1")"; b="$(basename -- "$1")"; (cd -- "$d" 2>/dev/null && printf '%s/%s' "$(pwd -P)" "$b"); }

oriented=0
if [ -n "$tp" ] && [ -f "$tp" ]; then
  want="$(canon "$cp")"
  # One "path<TAB>offset<TAB>limit" row per Read tool_use after the last /clear whose
  # tool_result exists and is not an error.
  reads="$(jq -R -s -r '
    [split("\n")[] | (try fromjson catch null)] as $rows
    | ([$rows | to_entries[]
        | select(.value != null and (.value | type) == "object" and .value.type == "user" and .value.isMeta != true
                 and ((.value.message.content | type) == "string")
                 and (.value.message.content | contains("<command-name>/clear</command-name>")))
        | .key] | if length == 0 then 0 else (last + 1) end) as $start
    | def blocks: if (type != "object") then []
                  elif .type == "tool_use" or .type == "tool_result" then [.]
                  elif ((.message.content? | type) == "array") then .message.content
                  else [] end;
      ([$rows[$start:][] | select(. != null) | blocks[]
        | select(type == "object" and .type == "tool_result")
        | {key: ((.tool_use_id // "") | tostring), value: (.is_error != true)}] | from_entries) as $ok
    | $rows[$start:][] | select(. != null) | blocks[]
    | select(type == "object" and .type == "tool_use" and .name == "Read")
    | select(($ok[(.id // "") | tostring] // false) == true)
    | [(.input.file_path // ""), ((.input.offset // 1) | tostring), ((.input.limit // "") | tostring)]
    | @tsv' "$tp" 2>/dev/null)"
  ranges=""
  while IFS="$(printf '\t')" read -r fp off lim; do
    [ -n "$fp" ] || continue
    case "$fp" in *[Cc][Hh][Ee][Cc][Kk][Pp][Oo][Ii][Nn][Tt].[Mm][Dd]) ;; *) continue ;; esac
    [ "$(canon "$fp")" = "$want" ] || continue
    case "$off" in ''|*[!0-9]*) off=1 ;; esac
    [ "$off" -lt 1 ] && off=1
    case "$lim" in ''|*[!0-9]*) lim=2000 ;; esac      # the Read tool's default is 2000 lines
    ranges="$ranges$off $((off + lim - 1))
"
  done <<EOF
$reads
EOF
  if [ -n "$ranges" ]; then
    total="$(awk 'END { print NR }' "$cp")"
    next=1                                            # first line not yet covered
    while read -r s e; do
      [ -n "$s" ] || continue
      [ "$s" -gt "$next" ] && break
      if [ "$e" -ge "$total" ]; then next=$((total + 1)); break; fi
      [ "$e" -ge "$next" ] && next=$((e + 1))
    done <<EOF
$(printf '%s' "$ranges" | sort -n -k1,1)
EOF
    [ "$next" -gt "$total" ] && oriented=1
  fi
fi
[ "$oriented" = 1 ] && exit 0

safe_sid="$(printf '%s' "$sid" | tr -c 'A-Za-z0-9_-' '_')"
flag="${TMPDIR:-/tmp}/orient_gate_${safe_sid}.flag"
if [ "${ORIENT_GATE_BLOCK_ONCE:-}" = 1 ]; then
  [ -f "$flag" ] && exit 0
  : > "$flag" 2>/dev/null
  echo "ORIENTATION GATE: this session has not read CHECKPOINT.md and you are about to run a world-changing action ($tool). FIRST Read the project's CHECKPOINT.md to EOF and follow its Open threads / Next step. If you have genuinely judged this a pre-oriented one-shot, just re-issue this exact call -- the gate fires only once per session." >&2
  exit 2
fi
# Record the blocked call's key (tool|target), as the PowerShell version does.
target="$(field '[.tool_input.file_path, .tool_input.notebook_path, .tool_input.command, .tool_input.url, .tool_input.query] | map(select(. != null and . != "")) | (.[0] // "")')"
printf '%s|%s' "$tool" "$target" | cut -c1-400 > "$flag" 2>/dev/null
echo "ORIENTATION GATE: this session has not read CHECKPOINT.md and you are about to run a world-changing action ($tool). FIRST Read the project's CHECKPOINT.md to EOF (every line, with as many offset/limit Reads as it takes) and follow its pointers (Open threads, Files that matter, Next step). There is no exemption and re-issuing does not pass: this gate blocks every such call until that Read." >&2
exit 2
