"""Wrapper tests for validate_board.py -- writes bad/good board JSON into a temp dir and runs the
validator against it exactly as the SKILL.md step 4 does (subprocess, same interpreter).
Usage: python validate_board_tests.py
"""
import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
VALIDATOR = os.path.join(HERE, "validate_board.py")

GOOD_OPTION_A = {"key": "a", "label": "Option A", "choose_if": "x", "cost": "y", "unblocks": "z"}
GOOD_OPTION_B = {"key": "b", "label": "Option B", "choose_if": "x2", "cost": "y2", "unblocks": "z2"}


def base_decision(**overrides):
    d = {
        "id": "test-decision",
        "title": "A fork the owner needs to pick?",
        "what": "The nightly job that copies board picks into the project notes.",
        "ask": "Task note reply: \"make picks land without me pressing anything\"",
        "read": "the job's script and its last run log",
        "background": ["Paragraph one.", "Paragraph two."],
        "why_now": "It gates the next step.",
        "sources": [{"label": "the research", "path": "research/some-finding-2026-09-22.md"}],
        "options": [GOOD_OPTION_A, GOOD_OPTION_B],
        "default": None,
        "default_reason": "This turns on the owner's taste.",
    }
    d.update(overrides)
    return d


def board_with(decision):
    return {"project": "example", "generated": "2026-09-22 00:00 UTC", "decisions": [decision], "left": []}


def run_validator(data, collected=None, explicit=False):
    tmpdir = tempfile.mkdtemp(prefix="validate_board_test_")
    path = os.path.join(tmpdir, "board.json")
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(data, fh)
    args = [sys.executable, VALIDATOR, path]
    if collected is not None:
        cpath = os.path.join(tmpdir, "elsewhere.json" if explicit else "board.collected.json")
        with open(cpath, "w", encoding="utf-8") as fh:
            json.dump(collected, fh)
        if explicit:
            args += ["--collected", cpath]
    proc = subprocess.run(args, capture_output=True, text=True)
    return proc.returncode, proc.stdout + proc.stderr


pass_count = 0
fail_count = 0


def check(name, ok, detail=""):
    global pass_count, fail_count
    if ok:
        pass_count += 1
        print("PASS  " + name)
    else:
        fail_count += 1
        print("FAIL  " + name + "  " + detail)


# 1. Good board: exits 0, prints ok
code, out = run_validator(board_with(base_decision()))
check("1 good board exits 0", code == 0, "code=%d out=%s" % (code, out))
check("1b good board prints ok", out.strip().startswith("ok:"), out)

# 2. Missing background entirely -> exit 1, names the decision id
bad = base_decision()
del bad["background"]
code, out = run_validator(board_with(bad))
check("2 missing background exits 1", code == 1, "code=%d" % code)
check("2b names decision id", "test-decision" in out, out)

# 3. Empty background list -> exit 1, names the decision id
bad = base_decision(background=[])
code, out = run_validator(board_with(bad))
check("3 empty background exits 1", code == 1, "code=%d" % code)
check("3b names decision id", "test-decision" in out, out)

# 4. sources present but none point at research/specs/docs/note -> exit 1, names the decision id
bad = base_decision(sources=[{"label": "the checkpoint line", "path": "CHECKPOINT.md:14"}])
code, out = run_validator(board_with(bad))
check("4 ungrounded sources exits 1", code == 1, "code=%d out=%s" % (code, out))
check("4b names decision id", "test-decision" in out, out)
check("4c message explains the requirement", "research" in out.lower(), out)

# 5. sources missing entirely -> exit 1
bad = base_decision()
del bad["sources"]
code, out = run_validator(board_with(bad))
check("5 missing sources exits 1", code == 1, "code=%d" % code)

# 6. a 'specs/' path source is accepted
ok_specs = base_decision(sources=[{"label": "the spec", "path": "specs/some-spec.md"}])
code, out = run_validator(board_with(ok_specs))
check("6 specs/ path passes", code == 0, "code=%d out=%s" % (code, out))

# 7. a notes-app clip path is accepted
ok_clip = base_decision(sources=[{"label": "the clip", "path": "Notes/Clippings/thing.md"}])
code, out = run_validator(board_with(ok_clip))
check("7 clip path passes", code == 0, "code=%d out=%s" % (code, out))

# 8. 'docs/' and 'reference/' path sources are accepted
ok_docs = base_decision(sources=[{"label": "the doc", "path": "myproject/docs/some-research.md"}])
code, out = run_validator(board_with(ok_docs))
check("8 docs/ path passes", code == 0, "code=%d out=%s" % (code, out))
ok_ref = base_decision(sources=[{"label": "the reference", "path": "myproject/reference/thing.md"}])
code, out = run_validator(board_with(ok_ref))
check("9 reference/ path passes", code == 0, "code=%d out=%s" % (code, out))
ok_url = base_decision(sources=[{"label": "the vendor page", "path": "https://example.com/pricing"}])
code, out = run_validator(board_with(ok_url))
check("9b URL source passes", code == 0, "code=%d out=%s" % (code, out))

# 10. option count bounds are 2 to 8
def n_options(n):
    return [dict(GOOD_OPTION_A, key="k%d" % i, label="Option %d" % i) for i in range(n)]


code, out = run_validator(board_with(base_decision(options=n_options(1))))
check("10 one option rejected", code == 1 and "2 to 8" in out, "code=%d out=%s" % (code, out))
code, out = run_validator(board_with(base_decision(options=n_options(9))))
check("10b nine options rejected", code == 1 and "found 9" in out, "code=%d out=%s" % (code, out))
code, out = run_validator(board_with(base_decision(options=n_options(8))))
check("10c eight options accepted", code == 0, "code=%d out=%s" % (code, out))

# 11. a why_now or default_reason about the owner's time or schedule fails
TIME_REASONS = [
    ("why_now", "This is a choice about your time."),
    ("why_now", "Pick it when you have time."),
    ("why_now", "It fits your schedule this month."),
    ("why_now", "Whenever you're free, it can start."),
    ("why_now", "You said you'd look later this week."),
    ("why_now", "Worth a look when you get a chance."),
    ("default_reason", "No evidence; it turns on when you are free to test it."),
    ("default_reason", "Depends on whether you can find time for the calls."),
    ("default_reason", "It is about when to spend the evening on it."),
    ("why_now", "Your plan was to look at it later this month."),
    ("why_now", "Later this weekend, when you are back, pick one."),
]
for i, (field, text) in enumerate(TIME_REASONS):
    code, out = run_validator(board_with(base_decision(**{field: text})))
    check("11.%d %s %r fails" % (i, field, text), code == 1 and "time or schedule" in out and field in out,
          "code=%d out=%s" % (code, out))

# 12. a real deadline or a time word that is not about the owner's time passes
OK_REASONS = [
    ("why_now", "The free trial ends next week, so the pick decides whether we pay."),
    ("why_now", "Load time doubled after the last change."),
    ("why_now", "It gates the next step."),
    ("why_now", "The map of where you spend your time cannot move until the radar is in place."),
    ("default_reason", "Option A halves the time to first result (bench.md:12)."),
    ("default_reason", "No evidence beyond judgment."),
    ("why_now", "The vendor ends support later this week, so choose a replacement now."),
    ("why_now", "The old API shuts off later this month."),
    ("default_reason", "The venue closes bookings later this weekend (venue email, 2026-10-17)."),
]
for i, (field, text) in enumerate(OK_REASONS):
    code, out = run_validator(board_with(base_decision(**{field: text})))
    check("12.%d %s %r passes" % (i, field, text), code == 0, "code=%d out=%s" % (code, out))

# 13. decisions or left as an object (not a list) fails: the template calls .filter/.map on them
code, out = run_validator({"project": "demo", "generated": "x", "decisions": {}, "left": []})
check("13 decisions as object fails", code == 1 and "LIST" in out, "code=%d out=%s" % (code, out))
code, out = run_validator({"project": "demo", "generated": "x", "decisions": [], "left": {}})
check("13b left as object fails", code == 1 and "LIST" in out, "code=%d out=%s" % (code, out))

# 14. two decisions with the same id fail: they would share one saved pick
dup = board_with(base_decision())
dup["decisions"].append(base_decision(title="Another fork?"))
code, out = run_validator(dup)
check("14 duplicate decision ids fail", code == 1 and "unique" in out, "code=%d out=%s" % (code, out))

# 15. a doc in any folder layout is grounded; Windows separators work; a CHECKPOINT pointer alone is not
for i, p in enumerate(["design.md", "C:\\work\\demo\\docs\\plan.md", "notes/pricing call.txt"]):
    code, out = run_validator(board_with(base_decision(sources=[{"label": "doc", "path": p},
                                                                {"label": "thread", "path": "CHECKPOINT.md:20"}])))
    check("15.%d %r passes" % (i, p), code == 0, "code=%d out=%s" % (code, out))
code, out = run_validator(board_with(base_decision(sources=[{"label": "thread", "path": "C:\\work\\demo\\CHECKPOINT.md:3"}])))
check("15b Windows CHECKPOINT pointer alone fails", code == 1 and "research" in out, "code=%d out=%s" % (code, out))

# 16. every decision says what it is, the ask and what was read, before any verdict
for field in ("what", "ask", "read"):
    bad = base_decision()
    del bad[field]
    code, out = run_validator(board_with(bad))
    check("16 decision missing %r fails" % field, code == 1 and field in out and "test-decision" in out,
          "code=%d out=%s" % (code, out))
code, out = run_validator(board_with(base_decision(what="   ")))
check("16d blank what fails", code == 1 and "what" in out, "code=%d out=%s" % (code, out))

# 17. every left row carries the same three, beside its verdict
GOOD_LEFT = {"title": "Rename the log folder", "verdict": "not: mechanical",
             "what": "The folder the job writes to.", "ask": "Thread: \"tidy the log names\"",
             "read": "the CHECKPOINT thread"}
for field in ("what", "ask", "read"):
    row = dict(GOOD_LEFT)
    del row[field]
    data = board_with(base_decision())
    data["left"] = [row]
    code, out = run_validator(data)
    check("17 left row missing %r fails" % field, code == 1 and field in out and "Rename the log folder" in out,
          "code=%d out=%s" % (code, out))
data = board_with(base_decision())
data["left"] = [GOOD_LEFT]
code, out = run_validator(data)
check("17d complete left row passes", code == 0, "code=%d out=%s" % (code, out))

# 18. options this session already offered the user stay on the board
data = board_with(base_decision())
data["offered"] = [{"topic": "how to record the server crash", "decision": "test-decision"}]
code, out = run_validator(data)
check("18 offered topic on the board passes", code == 0, "code=%d out=%s" % (code, out))
data = board_with(base_decision())
data["left"] = [dict(GOOD_LEFT, id="crash-logging")]
data["offered"] = [{"topic": "how to record the server crash", "decision": "crash-logging"}]
code, out = run_validator(data)
check("18b offered topic moved to left fails", code == 1 and "offered" in out and "crash" in out,
      "code=%d out=%s" % (code, out))
data = board_with(base_decision())
data["offered"] = [{"topic": "jump feel"}]
code, out = run_validator(data)
check("18c offered entry without a decision id fails", code == 1 and "offered" in out, "code=%d out=%s" % (code, out))

# 19. every offer the collector found must be carried, not only the ones the board declares
COLLECTED = {"project": "example", "candidates": [], "warnings": [],
             "offered": [{"at": "2026-10-26T06:01:00Z", "kind": "text", "text": "Option A -- event log ..."}]}
code, out = run_validator(board_with(base_decision()), COLLECTED)
check("19 collected offer missing from the board fails", code == 1 and "2026-10-26T06:01:00Z" in out,
      "code=%d out=%s" % (code, out))
data = board_with(base_decision())
data["offered"] = [{"topic": "crash logging", "decision": "test-decision", "at": "2026-10-26T06:01:00Z"}]
code, out = run_validator(data, COLLECTED)
check("19b collected offer carried by a decision passes", code == 0, "code=%d out=%s" % (code, out))
code, out = run_validator(board_with(base_decision()), COLLECTED, explicit=True)
check("19c --collected path is read too", code == 1 and "2026-10-26T06:01:00Z" in out, "code=%d out=%s" % (code, out))
code, out = run_validator(board_with(base_decision()), {"offered": []})
check("19d no collected offers passes", code == 0, "code=%d out=%s" % (code, out))

# 20. a link or path in body text cannot wrap on a phone; the same link in sources passes
LONG = "https://example.com/a/very/long/path/that/does/not/wrap"
code, out = run_validator(board_with(base_decision(background=["See " + LONG + " for detail."])))
check("20 link in background fails", code == 1 and "unbreakable" in out, "code=%d out=%s" % (code, out))
code, out = run_validator(board_with(base_decision(options=[dict(GOOD_OPTION_A, cost=LONG), GOOD_OPTION_B])))
check("20b link in an option fails", code == 1 and "unbreakable" in out, "code=%d out=%s" % (code, out))
code, out = run_validator(board_with(base_decision(sources=[{"label": "the page", "path": LONG}])))
check("20c same link in sources passes", code == 0, "code=%d out=%s" % (code, out))

print("---- %d passed, %d failed ----" % (pass_count, fail_count))
sys.exit(1 if fail_count else 0)
