#!/usr/bin/env python3
"""changelog_jsonl.py -- the JSONL-mode changelog tool for the /checkpoint skill.

An optional history store for projects whose changelog outgrows the CHECKPOINT. A project
is in JSONL mode iff `changelog.jsonl` sits beside its CHECKPOINT.md; to opt in, run
`convert` once. The file is UTF-8, one JSON object per line, OLDEST FIRST, append-only: no line is
ever edited, reordered or deleted. CHECKPOINT.md keeps exactly the newest entry
inline plus one pointer line; that entry is also the file's last line.

Record fields (entries): date, title, author, body, heading, origin.
  heading = the original `### ...` line, byte-verbatim (rendering uses this)
  body    = everything after the heading line up to the next entry, byte-verbatim
            (trailing blank lines included, so separators round-trip exactly)
  date / title / author are derived conveniences for grep and scripts.
The archive's non-entry header becomes one {"kind": "preamble", ...} record.

Subcommands (Python 3.8+, standard library only):
  convert  --checkpoint CP --archive ARC --out JSONL
           One-time conversion. Refuses if JSONL exists. Writes, then runs the
           byte-identical round-trip check; on a failed check the new file is
           moved aside to JSONL.failed and nothing else changes. Never edits CP/ARC.
  check    --jsonl J [--checkpoint CP] [--archive ARC]
           Round-trip check: rendered archive-origin records == ARC bytes, and
           rendered checkpoint-origin records == CP's inline entry bytes.
  inline   --checkpoint CP --jsonl J
           Make CP's `## Harness changelog` hold exactly the last JSONL record plus
           the pointer line. Refuses unless every inline entry is already in J.
  append   --jsonl J --entry-file F|- [--checkpoint CP] [--lock-timeout S]
           Close step in JSONL mode: append one entry (file lock, JSON validated,
           refuses a heading/date+title equal to the last line), then, with
           --checkpoint, swap the inline entry for the new one. Nothing else changes.
  render   [--jsonl J] [--grep PAT] [--since YYYY-MM-DD] [--last N] [--archive-file]
           Markdown, newest first. --archive-file reproduces the old archive file.

Exit codes: 0 ok, 1 refused / check failed (each reason printed), 2 usage error.
"""
import argparse
import json
import os
import re
import sys
import time

POINTER = ("Older entries: changelog.jsonl (append-only, oldest first; search with grep, "
           "render with the checkpoint skill's changelog_jsonl.py render).")
SECTION_RE = re.compile(r"^## Harness changelog")
DATE_RE = re.compile(r"\d{4}-\d{2}-\d{2}")
AUTHOR_RE = re.compile(r"\(([^()\n]*(?:--|\u2014|\u2013)\s*\d{4}-\d{2}-\d{2})\)\.?\s*\Z")
FIELDS = ("date", "title", "author", "body", "heading", "origin")


class Refused(Exception):
    pass


# ---------------------------------------------------------------- text helpers
def read_text(path):
    """Return (text with LF newlines, newline convention). Refuses mixed newlines."""
    raw = open(path, "rb").read()
    if raw.startswith(b"\xef\xbb\xbf"):
        raise Refused(f"{path} starts with a UTF-8 BOM; byte-exact handling is not supported")
    text = raw.decode("utf-8")
    crlf = text.count("\r\n")
    lf = text.count("\n")
    if crlf and crlf != lf:
        raise Refused(f"{path} mixes CRLF and LF newlines; cannot round-trip it byte-exactly")
    return (text.replace("\r\n", "\n"), "\r\n" if crlf else "\n")


def write_text(path, text, nl):
    data = (text.replace("\n", "\r\n") if nl == "\r\n" else text).encode("utf-8")
    for delay in (0, 0.5, 1, 2, 4, 8):          # sync clients, antivirus and indexers hold files briefly
        if delay:
            time.sleep(delay)
        try:
            with open(path, "wb") as f:
                f.write(data)
            return
        except PermissionError:
            last = sys.exc_info()[1]
    raise Refused(f"could not write {path} after retrying a locked file: {last}")


def split_keep(text):
    """Lines WITH their trailing '\n' (only '\n' splits; no str.splitlines surprises)."""
    return re.findall(r"[^\n]*\n|[^\n]+\Z", text)


def dumps(rec):
    s = json.dumps(rec, ensure_ascii=False, separators=(",", ":"))
    # U+2028/9 are legal in JSON but some line readers split on them; escape to stay one line.
    return s.replace("\u2028", "\\u2028").replace("\u2029", "\\u2029")


# ---------------------------------------------------------------- record model
def make_record(heading, body, origin):
    m = DATE_RE.search(heading)
    date = m.group(0) if m else ""
    if m:
        title = heading[m.end():]
        title = re.sub(r"^\s*(?:--|\u2014|\u2013)\s*", "", title).strip()
    else:
        title = re.sub(r"^###\s*", "", heading).strip()
    am = AUTHOR_RE.search(body.rstrip())
    author = am.group(1).strip() if am else ""
    return {"date": date, "title": title, "author": author, "body": body,
            "heading": heading, "origin": origin}


def entry_text(rec):
    return rec["heading"] + "\n" + rec["body"]


def norm_body(b):
    return re.sub(r"\s+\Z", "", b.replace("\r\n", "\n"))


def same_entry(a, b):
    return a["heading"] == b["heading"] and norm_body(a["body"]) == norm_body(b["body"])


def parse_entries(lines):
    """lines: list of keepends lines that are entirely entry region. -> list of (heading, body)."""
    out = []
    for ln in lines:
        if ln.startswith("### "):
            out.append([ln.rstrip("\n"), ""])
        elif out:
            out[-1][1] += ln
        elif ln.strip():
            raise Refused(f"text before the first entry in the entry region: {ln[:80]!r}")
    return [tuple(e) for e in out]


def checkpoint_layout(text):
    """Split a CHECKPOINT into (before, lead, entry_lines, pointer_idx_info...).

    Returns dict with keys: lines, s (section heading idx), e (section end, exclusive),
    f (first entry idx or None), r (entry region end, exclusive), p (pointer idx or None).
    """
    lines = split_keep(text)
    s = next((i for i, l in enumerate(lines) if SECTION_RE.match(l)), None)
    if s is None:
        raise Refused("no '## Harness changelog' section in the CHECKPOINT")
    e = next((i for i in range(s + 1, len(lines)) if lines[i].startswith("## ")), len(lines))
    p = next((i for i in range(s + 1, e) if lines[i].startswith("Older entries")), None)
    f = next((i for i in range(s + 1, e) if lines[i].startswith("### ")), None)
    if f is None:
        r = None
    elif p is not None and p > f:
        r = p
    else:
        r = e
    return {"lines": lines, "s": s, "e": e, "f": f, "r": r, "p": p}


def inline_entries(text):
    L = checkpoint_layout(text)
    if L["f"] is None:
        return L, []
    return L, parse_entries(L["lines"][L["f"]:L["r"]])


def load_jsonl(path):
    """-> list of records. Refuses on any unparsable line or a missing final newline."""
    raw = open(path, "rb").read()
    # git core.autocrlf=true checks the file out with CRLF on Windows; read either.
    text = raw.decode("utf-8").replace("\r\n", "\n")
    if text and not text.endswith("\n"):
        raise Refused(f"{path} does not end with a newline (a partial write?); fix by hand before appending")
    recs = []
    for n, line in enumerate(text.split("\n")[:-1] if text else [], 1):
        if not line.strip():
            raise Refused(f"{path} line {n} is blank; the file must be one JSON object per line")
        try:
            rec = json.loads(line)
        except ValueError as ex:
            raise Refused(f"{path} line {n} is not valid JSON: {ex}")
        if not isinstance(rec, dict):
            raise Refused(f"{path} line {n} is not a JSON object")
        if rec.get("kind") != "preamble":
            missing = [k for k in FIELDS if k not in rec]
            if missing:
                raise Refused(f"{path} line {n} lacks field(s) {missing}")
        recs.append(rec)
    return recs


def entries_only(recs):
    return [r for r in recs if r.get("kind") != "preamble"]


# ---------------------------------------------------------------- render
def render_archive_file(recs):
    pre = "".join(r["text"] for r in recs if r.get("kind") == "preamble" and r.get("origin") == "archive")
    ents = [r for r in entries_only(recs) if r["origin"] == "archive"]
    return pre + "".join(entry_text(r) for r in reversed(ents))


def render_checkpoint_entries(recs):
    ents = [r for r in entries_only(recs) if r["origin"] == "checkpoint"]
    return "".join(entry_text(r) for r in reversed(ents))


def checkpoint_entry_bytes(text):
    L = checkpoint_layout(text)
    if L["f"] is None:
        return ""
    return "".join(L["lines"][L["f"]:L["r"]])


# ---------------------------------------------------------------- commands
def cmd_check(a, quiet=False):
    recs = load_jsonl(a.jsonl)
    ok = True
    msgs = [f"[changelog-jsonl] {a.jsonl}: {len(recs)} lines parse "
            f"({len(entries_only(recs))} entries, {len(recs) - len(entries_only(recs))} preamble)"]
    if a.archive:
        src, nl = read_text(a.archive)
        got = render_archive_file(recs)
        same = got == src
        n = sum(1 for r in entries_only(recs) if r["origin"] == "archive")
        msgs.append(f"  archive round-trip: {'BYTE-IDENTICAL' if same else 'MISMATCH'} "
                    f"({n} entries + preamble, {len(src.encode('utf-8'))} bytes, newline {nl!r})")
        if not same:
            ok = False
            msgs.append("  first difference at char " + str(_first_diff(got, src)))
    if a.checkpoint:
        src_full, nl = read_text(a.checkpoint)
        src = checkpoint_entry_bytes(src_full)
        got = render_checkpoint_entries(recs)
        same = got == src
        n = sum(1 for r in entries_only(recs) if r["origin"] == "checkpoint")
        msgs.append(f"  checkpoint round-trip: {'BYTE-IDENTICAL' if same else 'MISMATCH'} "
                    f"({n} entries, {len(src.encode('utf-8'))} bytes of inline entries)")
        if not same:
            ok = False
            msgs.append("  first difference at char " + str(_first_diff(got, src)))
    if not quiet:
        print("\n".join(msgs))
    return 0 if ok else 1, msgs


def _first_diff(a, b):
    for i, (x, y) in enumerate(zip(a, b)):
        if x != y:
            return i
    return min(len(a), len(b))


def cmd_convert(a):
    if os.path.exists(a.out):
        raise Refused(f"{a.out} already exists; the file is append-only and is never regenerated")
    arc_text, _ = read_text(a.archive)
    cp_text, _ = read_text(a.checkpoint)
    arc_lines = split_keep(arc_text)
    first = next((i for i, l in enumerate(arc_lines) if l.startswith("### ")), len(arc_lines))
    preamble = "".join(arc_lines[:first])
    arc_entries = parse_entries(arc_lines[first:])
    _, cp_entries = inline_entries(cp_text)
    recs = []
    if preamble:
        recs.append({"kind": "preamble", "origin": "archive", "text": preamble})
    recs += [make_record(h, b, "archive") for h, b in reversed(arc_entries)]
    recs += [make_record(h, b, "checkpoint") for h, b in reversed(cp_entries)]
    data = "".join(dumps(r) + "\n" for r in recs).encode("utf-8")
    with open(a.out, "xb") as f:
        f.write(data)
    print(f"[changelog-jsonl] wrote {a.out}: {len(recs)} lines = {len(arc_entries)} archive entries + "
          f"{len(cp_entries)} CHECKPOINT entries + {1 if preamble else 0} preamble")
    code, _ = cmd_check(argparse.Namespace(jsonl=a.out, archive=a.archive, checkpoint=a.checkpoint))
    if code != 0:
        os.replace(a.out, a.out + ".failed")
        raise Refused(f"round-trip check FAILED; moved the output to {a.out}.failed; nothing else changed")
    return 0


def rewrite_inline(cp_text, new_rec):
    """Return CP text whose changelog section holds exactly new_rec + the pointer line."""
    L = checkpoint_layout(cp_text)
    lines, s, e, f, r, p = L["lines"], L["s"], L["e"], L["f"], L["r"], L["p"]
    body = new_rec["body"]
    if not body.endswith("\n"):
        body += "\n"
    block = [new_rec["heading"] + "\n", body]
    if f is None:
        # No entries yet: put the entry right after the section heading (+ any lead blank lines).
        ins = s + 1
        while ins < e and ins != p and not lines[ins].strip():
            ins += 1
        out = lines[:ins] + block + lines[ins:]
        f_new, r_new = ins, ins + len(block)
        lines, e = out, e + len(block)
        if p is not None and p >= ins:
            p += len(block)
    else:
        out = lines[:f] + block + lines[r:]
        delta = len(block) - (r - f)
        if p is not None and p >= r:
            p += delta
        e += delta
        lines = out
        f_new, r_new = f, f + len(block)
    if p is not None:
        lines[p] = POINTER + "\n"
    else:
        # No pointer yet: put it right after the new entry (whose body ends in a blank
        # line), and keep a blank line before a following `## ` section.
        add = [POINTER + "\n"]
        if r_new < len(lines) and lines[r_new].startswith("## "):
            add.append("\n")
        lines = lines[:r_new] + add + lines[r_new:]
    return "".join(lines)


def _check_inline_covered(cp_text, recs, also_ok=None):
    _, ents = inline_entries(cp_text)
    allr = entries_only(recs)
    for h, b in ents:
        cand = {"heading": h, "body": b}
        if also_ok is not None and same_entry(cand, also_ok):
            continue
        if not any(same_entry(cand, r) for r in allr):
            raise Refused(f"inline entry is not in changelog.jsonl, refusing to drop it: {h[:100]}")
    return ents


def cmd_inline(a):
    recs = load_jsonl(a.jsonl)
    ents = entries_only(recs)
    if not ents:
        raise Refused(f"{a.jsonl} has no entries")
    cp_text, nl = read_text(a.checkpoint)
    _check_inline_covered(cp_text, recs)
    new = rewrite_inline(cp_text, ents[-1])
    if new == cp_text:
        print("[changelog-jsonl] CHECKPOINT already holds exactly the newest entry + pointer; nothing written")
        return 0
    write_text(a.checkpoint, new, nl)
    print(f"[changelog-jsonl] CHECKPOINT changelog section now holds the newest entry + pointer: {ents[-1]['heading'][:100]}")
    return 0


class Lock:
    def __init__(self, target, timeout, stale=600):
        self.path = target + ".lock"
        self.timeout, self.stale, self.fd = timeout, stale, None

    def __enter__(self):
        deadline = time.time() + self.timeout
        while True:
            try:
                self.fd = os.open(self.path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
                os.write(self.fd, f"{os.getpid()} {time.strftime('%Y-%m-%d %H:%M:%S')}\n".encode())
                return self
            except FileExistsError:
                try:
                    age = time.time() - os.path.getmtime(self.path)
                except OSError:
                    continue
                if age > self.stale:
                    print(f"[changelog-jsonl] taking over a stale lock ({int(age)} s old): {self.path}")
                    try:
                        os.remove(self.path)
                    except OSError:
                        pass
                    continue
                if time.time() >= deadline:
                    raise Refused(f"another close holds the lock {self.path} (waited {self.timeout} s); "
                                  "re-run when it finishes -- nothing written")
                time.sleep(0.25)

    def __exit__(self, *exc):
        if self.fd is not None:
            os.close(self.fd)
            try:
                os.remove(self.path)
            except OSError:
                pass


def read_entry(path):
    raw = sys.stdin.buffer.read() if path == "-" else open(path, "rb").read()
    text = raw.decode("utf-8-sig").replace("\r\n", "\n").lstrip("\n")
    lines = split_keep(text)
    if not lines or not lines[0].startswith("### "):
        raise Refused("the entry must start with a '### YYYY-MM-DD -- title' heading line")
    heading = lines[0].rstrip("\n").rstrip()
    if not DATE_RE.search(heading):
        raise Refused(f"the heading carries no YYYY-MM-DD date: {heading}")
    for ln in lines[1:]:
        if ln.startswith("### ") or ln.startswith("## ") or ln.startswith("Older entries"):
            raise Refused(f"the entry body contains a line that would break the section: {ln.strip()[:80]}")
    body = norm_body("".join(lines[1:]))
    if not body.strip():
        raise Refused("the entry has no body")
    return make_record(heading, body + "\n\n", "checkpoint")


def cmd_append(a):
    rec = read_entry(a.entry_file)
    line = dumps(rec)
    if json.loads(line) != rec:
        raise Refused("the serialized entry does not parse back to itself")
    with Lock(a.jsonl, a.lock_timeout):
        recs = load_jsonl(a.jsonl) if os.path.exists(a.jsonl) else []
        ents = entries_only(recs)
        if ents:
            last = ents[-1]
            if last["heading"] == rec["heading"] or (last["date"], last["title"]) == (rec["date"], rec["title"]):
                raise Refused(f"the last line already has this heading/date+title: {last['heading'][:100]} -- "
                              "nothing appended (give the new entry its own title)")
        cp_text = nl = None
        if a.checkpoint:
            cp_text, nl = read_text(a.checkpoint)
            _check_inline_covered(cp_text, recs, also_ok=rec)
        size = os.path.getsize(a.jsonl) if os.path.exists(a.jsonl) else 0
        eol = "\n"
        if size:
            with open(a.jsonl, "rb") as f:
                f.seek(max(0, size - 2))
                if f.read() == b"\r\n":
                    eol = "\r\n"          # keep the file's own newline (no mixed endings)
        with open(a.jsonl, "ab") as f:
            f.write((line + eol).encode("utf-8"))
            f.flush()
            os.fsync(f.fileno())
        after = load_jsonl(a.jsonl)
        if len(after) != len(recs) + 1 or after[-1] != rec:
            raise Refused(f"post-append validation failed; inspect {a.jsonl} from byte {size}")
        print(f"[changelog-jsonl] appended line {len(after)} to {a.jsonl}: {rec['heading'][:100]}")
        if a.checkpoint:
            new = rewrite_inline(cp_text, rec)
            write_text(a.checkpoint, new, nl)
            print(f"[changelog-jsonl] swapped the inline entry in {a.checkpoint} (nothing else changed). "
                  "Re-Read the CHECKPOINT before your next Edit.")
    return 0


def cmd_render(a):
    recs = load_jsonl(a.jsonl)
    if a.archive_file:
        out = render_archive_file(recs)
    else:
        ents = entries_only(recs)
        if a.since:
            ents = [r for r in ents if r["date"] >= a.since]
        if a.grep:
            rx = re.compile(a.grep, re.I)
            ents = [r for r in ents if rx.search(r["heading"]) or rx.search(r["body"])]
        if a.last:
            ents = ents[-a.last:]
        parts = []
        for r in reversed(ents):
            t = entry_text(r)
            if not t.endswith("\n\n"):
                t = t.rstrip("\n") + "\n\n"
            parts.append(t)
        out = "".join(parts)
    sys.stdout.buffer.write(out.encode("utf-8"))
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("convert"); p.add_argument("--checkpoint", required=True)
    p.add_argument("--archive", required=True); p.add_argument("--out", required=True)
    p = sub.add_parser("check"); p.add_argument("--jsonl", required=True)
    p.add_argument("--checkpoint"); p.add_argument("--archive")
    p = sub.add_parser("inline"); p.add_argument("--checkpoint", required=True); p.add_argument("--jsonl", required=True)
    p = sub.add_parser("append"); p.add_argument("--jsonl", required=True)
    p.add_argument("--entry-file", required=True); p.add_argument("--checkpoint")
    p.add_argument("--lock-timeout", type=float, default=30)
    p = sub.add_parser("render"); p.add_argument("--jsonl", default="changelog.jsonl")
    p.add_argument("--grep"); p.add_argument("--since"); p.add_argument("--last", type=int)
    p.add_argument("--archive-file", action="store_true")
    a = ap.parse_args(argv)
    try:
        if a.cmd == "check":
            return cmd_check(a)[0]
        return {"convert": cmd_convert, "inline": cmd_inline, "append": cmd_append, "render": cmd_render}[a.cmd](a)
    except Refused as ex:
        print(f"[changelog-jsonl] REFUSED: {ex}")
        return 1
    except FileNotFoundError as ex:
        print(f"[changelog-jsonl] REFUSED: file not found: {ex.filename}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
