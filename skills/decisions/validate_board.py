"""Validate a decision-board data file against what board_template.html actually reads.

Why this exists: the template has no error handling. One wrong-shaped field throws inside
render() and the page paints nothing, with no clue on screen about why.

Usage:  python validate_board.py <path to board.json> [--collected <collector json>]
        (without --collected, <name>.collected.json beside the board file is read when it exists)
Exit 0 and prints "ok" when the file is safe to render; exit 1 with the reason otherwise.
"""
import json
import os
import re
import sys

OPTION_FIELDS = ("key", "label", "choose_if", "cost", "unblocks")
DECISION_FIELDS = ("id", "title", "background", "why_now", "sources", "options")
# A cold reader sees what each item is, what was asked and what was read before any verdict.
# Required and non-blank on every decision and every 'left' row.
CONTEXT_FIELDS = ("what", "ask", "read")
# A run of this many non-space characters (a link, a path) cannot wrap on a phone screen, so the
# card widens past the screen and clips it. Links belong in `sources`, which wrap.
UNBREAKABLE = re.compile(r"\S{30,}")

# A source counts as "the research it came from" if it is anything other than a pointer back at
# the CHECKPOINT line that listed the decision: a doc, spec or note in any folder layout, or a URL.
CHECKPOINT_POINTER = re.compile(r"(^|/)checkpoint\.md(:\d+)?$")

# A why_now or default_reason about the owner's time or schedule marks a scheduling item, which
# the skill's step 2 discard list keeps off the board. Phrases are about THEIR time only: a
# deadline or a clock on the thing ("the trial ends next week") is a real reason and must pass,
# so bare "next week", "time" and "your time" are deliberately absent.
TIME_ABOUT_OWNER = re.compile(
    r"\byour (?:own )?(?:schedule|calendar|availability|bandwidth|free time|spare time)\b"
    r"|\bwhen(?:ever)? you(?:'re| are) (?:free|available|ready|around)\b"
    r"|\bwhen(?:ever)? you (?:have|get|find) (?:the |some |a )?(?:time|minute|moment|chance|bandwidth|spare)\b"
    r"|\bwhen you get around to\b"
    r"|\b(?:free|spare) time\b"
    r"|\b(?:find|make) (?:the |some )?time\b"
    # "later this week" only when the clause is about the owner ("you'd look later this week"); a
    # deadline on the thing ("the vendor ends support later this week") passes.
    r"|\b(?:you|you'd|you'll|you're|your)\b[^.;,!?\n]{0,25}\blater this (?:week|month|weekend)\b"
    r"|\blater this (?:week|month|weekend)\b[^.;!?\n]{0,25}\b(?:you|you'd|you'll|you're|your)\b"
    r"|\bwhen to (?:do|spend|start|schedule|fit|get to)\b"
    r"|\bfit (?:it|this) in\b"
    r"|\b(?:choice|question|call|decision) about (?:your|their) (?:own )?time\b",
    re.IGNORECASE)


def fail(msg):
    print("INVALID: " + msg)
    sys.exit(1)


def has_grounded_source(sources):
    """True if at least one source's path is something other than the CHECKPOINT pointer."""
    for s in sources:
        path = str(s.get("path", "")).strip().lower().replace("\\", "/")
        if path and not CHECKPOINT_POINTER.search(path):
            return True
    return False


def main(path, collected_path=None):
    if collected_path is None:
        sibling = os.path.splitext(path)[0] + ".collected.json"
        collected_path = sibling if os.path.exists(sibling) else None
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)

    for field in ("project", "generated", "decisions"):
        if field not in data:
            fail("top level is missing '%s'" % field)
    # The template calls .filter/.map on both, so an object or string here blanks the page.
    if not isinstance(data["decisions"], list):
        fail("'decisions' must be a LIST, got %s" % type(data["decisions"]).__name__)
    if not isinstance(data.get("left", []), list):
        fail("'left' must be a LIST, got %s" % type(data["left"]).__name__)

    seen_ids = set()
    for d in data["decisions"]:
        where = d.get("id", "<a decision with no id>")
        for field in DECISION_FIELDS:
            if field not in d:
                fail("%s is missing '%s'" % (where, field))
        # The page saves each pick under picks/<id>, so two decisions sharing an id share one pick.
        if d["id"] in seen_ids:
            fail("%s: decision ids must be unique (the page saves picks under the id)" % where)
        seen_ids.add(d["id"])
        for field in CONTEXT_FIELDS:
            if not str(d.get(field) or "").strip():
                fail("%s is missing '%s' (what it is / the ask in the user's or the source's own "
                     "words / what was read): a cold reader needs all three before the options"
                     % (where, field))
        texts = [d.get(k) for k in ("title", "what", "ask", "read", "why_now", "default_reason")]
        if isinstance(d.get("background"), list):
            texts += d["background"]
        for o in d.get("options") or []:
            texts += [o.get(k) for k in ("label", "choose_if", "cost", "unblocks")]
        for t in texts:
            for tok in UNBREAKABLE.findall(str(t or "")):
                fail("%s has an unbreakable run of text (%s) outside sources: it cannot wrap on a "
                     "phone and gets cut off; move the link or path into sources" % (where, tok[:60]))
        if not isinstance(d["background"], list) or not d["background"]:
            fail("%s: background must be a non-empty LIST of paragraph strings "
                 "(the template renders one <p> per item)" % where)
        if any(not isinstance(p, str) for p in d["background"]):
            fail("%s: every background item must be a string" % where)
        for s in d["sources"]:
            if "label" not in s or "path" not in s:
                fail("%s: every source needs a label and a path" % where)
        if not has_grounded_source(d["sources"]):
            fail("%s: sources needs at least one entry pointing at the research, spec, doc, "
                 "note or URL it came from -- a pointer back at the CHECKPOINT line alone is "
                 "not background" % where)
        if not 2 <= len(d["options"]) <= 8:
            fail("%s: needs 2 to 8 options, found %d" % (where, len(d["options"])))
        keys = []
        for o in d["options"]:
            for field in OPTION_FIELDS:
                if not o.get(field):
                    fail("%s: an option is missing '%s' (the page saves 'key' as the pick)"
                         % (where, field))
            keys.append(o["key"])
        if len(set(keys)) != len(keys):
            fail("%s: option keys must be unique, got %s" % (where, keys))
        default = d.get("default")
        if default is not None and default not in keys:
            fail("%s: default must name an option key, got %r (keys: %s)"
                 % (where, default, keys))
        if default is None and not d.get("default_reason"):
            fail("%s: default is null, so default_reason must say why there is no "
                 "suggested pick" % where)
        for field in ("why_now", "default_reason"):
            m = TIME_ABOUT_OWNER.search(str(d.get(field) or ""))
            if m:
                fail("%s: %s is about the owner's time or schedule (%r). When they spend their "
                     "time is their call, not a board decision (decisions skill step 2, "
                     "scheduling discard): move it to 'left' or drop it, do not reword the reason"
                     % (where, field, m.group(0)))

    for l in data.get("left", []):
        if "title" not in l or "verdict" not in l:
            fail("every 'left' row needs a title and a verdict")
        for field in CONTEXT_FIELDS:
            if not str(l.get(field) or "").strip():
                fail("left row %r is missing '%s': a verdict needs what the item is, the ask and what "
                     "was read beside it" % (l["title"], field))

    # Choices this session already put to the user stay on the board as they were told them
    # (skill step 1b). Each offered entry names the decision id that carries it; an id that is
    # missing or sits in 'left' fails.
    ids = set(d["id"] for d in data["decisions"])
    for o in data.get("offered", []):
        if not o.get("topic") or not o.get("decision"):
            fail("every 'offered' entry needs a topic and the decision id that carries it")
        if o["decision"] not in ids:
            fail("offered topic %r (decision %r) is not on the board: options already put to the "
                 "user this session go on the board as they were told them, never into 'left'"
                 % (o["topic"], o["decision"]))

    # The board's own 'offered' list is checked against what the collector found in the session
    # transcript (collect_decisions.ps1 -Out <name>.collected.json beside the board file, or
    # --collected <path>): every collected offer needs a board 'offered' entry with the same 'at'.
    if collected_path and os.path.exists(collected_path):
        with open(collected_path, encoding="utf-8-sig") as fh:
            collected = json.load(fh)
        carried = set(str(o.get("at")) for o in data.get("offered", []))
        for c in collected.get("offered") or []:
            if str(c.get("at")) not in carried:
                fail("the session offered the user a choice at %s (%s) that no board decision "
                     "carries: add it to 'decisions' and list it in 'offered' with that 'at'"
                     % (c.get("at"), str(c.get("text", ""))[:80]))

    print("ok: %d decision(s), %d left off" % (len(data["decisions"]), len(data.get("left", []))))


if __name__ == "__main__":
    argv = sys.argv[1:]
    if len(argv) == 3 and argv[1] == "--collected":
        main(argv[0], argv[2])
    elif len(argv) == 1:
        main(argv[0])
    else:
        fail("usage: python validate_board.py <path to board.json> [--collected <collector json>]")
