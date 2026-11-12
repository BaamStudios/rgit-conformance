#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Inventory of `test-tool` subcommands used by the conformance scripts.

Scans test scripts (never git's C helper sources) for `test-tool` calls and
writes TEST-TOOL.md: every subcommand with usage count, class and owner issue.

Scripts are looked up in the imported `t/` directory first and in the upstream
git `t/` directory (--upstream or $UPSTREAM_T) second.

  test-tool/inventory.py --write --upstream ../rgit/upstream/git/t
  test-tool/inventory.py --check [--upstream DIR]

--write replaces the generated section of TEST-TOOL.md; without it the
section is printed.

--check fails when an imported script (t/t*.sh) or a listed script uses a
subcommand that has no class in test-tool/classes.tsv, and, when the upstream
directory is available, when TEST-TOOL.md is not up to date.
"""

import argparse
import collections
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

# Functions from test-lib-functions.sh that wrap a test-tool call.
WRAPPERS = {
    "packetize": "pkt-line pack",
    "packetize_raw": "pkt-line pack-raw-stdin",
    "depacketize": "pkt-line unpack",
    "test_file_size": "path-utils file-size",
    "test_readlink": "path-utils readlink",
    "test_bool_env": "env-helper",
    "test_set_magic_mtime": "chmtime",
    "test_is_magic_mtime": "chmtime",
    "test_trailing_hash": "hexdump",
}

# Subcommands whose second word selects an action worth tracking separately.
ACTION_WORD = {"path-utils": 1, "date": 1, "pkt-line": 1, "ref-store": 2,
               "config": 1, "trace2": 1, "run-command": 1, "bitmap": 1,
               "read-midx": 1, "env-helper": 0, "serve-v2": 0,
               "submodule": 1, "bundle-uri": 1, "simple-ipc": 1,
               "chmtime": 0, "progress": 0, "json-writer": 0}

CALL = re.compile(r"(?<![\w/.$-])test-tool((?:\s+(?:-C\s+\S+|--no-chdir|>>?\S+))*)\s+(\S+)(.*)")
SOURCE = re.compile(r"^\s*\.\s+\"?\$?\{?TEST_DIRECTORY\}?\"?/(lib-[\w-]+\.sh)")


def read_lines(path):
    """Code lines with continuations joined and comment lines removed."""
    out, buf = [], ""
    with open(path, encoding="utf-8", errors="replace") as f:
        for raw in f:
            line = raw.rstrip("\n")
            if line.lstrip().startswith("#"):
                continue
            if line.endswith("\\"):
                buf += line[:-1] + " "
                continue
            out.append(buf + line)
            buf = ""
    if buf:
        out.append(buf)
    return out


def clean(tok):
    return tok.strip("'\"`();|&")


ALIAS = re.compile(r"^\s*(\w+)=[\"'](test-tool\s[^\"']*)[\"']\s*$")


def expand_aliases(lines):
    """Replace $RUN with "test-tool ref-store main" etc. after RUN="test-tool ..."."""
    aliases, out = {}, []
    for line in lines:
        m = ALIAS.match(line)
        if m:
            aliases[m.group(1)] = m.group(2)
            continue
        for name, body in aliases.items():
            line = re.sub(r"\$\{?" + name + r"\b\}?", body, line)
        out.append(line)
    return out


def calls(path, known):
    """Yield (key, unknown) for every test-tool call in a file."""
    for line in expand_aliases(read_lines(path)):
        for m in CALL.finditer(line):
            sub = clean(m.group(2))
            rest = m.group(3).split()
            if sub.startswith("$"):
                # test-tool $test_hash_algo / $(test_oid algo): sha1 or sha256
                yield "sha1/sha256 (via $algo)", False
                continue
            if sub not in known:
                continue  # prose, e.g. "test-tool (from ...)"
            key = sub
            idx = ACTION_WORD.get(sub)
            if idx is not None and idx > 0 and len(rest) >= idx:
                act = clean(rest[idx - 1])
                if sub == "date" and act.startswith("show:"):
                    act = "show:<format>"
                if re.fullmatch(r"[\w:<>-]+", act) and not act.startswith("-"):
                    key = f"{sub} {act}"
            yield key, False


def wrapper_calls(path):
    for line in read_lines(path):
        for fn, key in WRAPPERS.items():
            n = len(re.findall(rf"(?<![\w-]){fn}(?![\w-])", line))
            for _ in range(n):
                yield key


def sourced_libs(path, tdirs, seen=None):
    seen = set() if seen is None else seen
    for line in read_lines(path):
        m = SOURCE.match(line)
        if m and m.group(1) not in seen:
            seen.add(m.group(1))
            lp = find(m.group(1), tdirs)
            if lp:
                sourced_libs(lp, tdirs, seen)
    return seen


def find(name, tdirs):
    for d in tdirs:
        p = os.path.join(d, name)
        if os.path.isfile(p):
            return p
    return None


def load_tsv(path):
    rows = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            if line.startswith("#") or not line.strip():
                continue
            rows.append(line.rstrip("\n").split("\t"))
    return rows


def base(key):
    return key.split(" ")[0]


def classify(key, classes):
    """Most specific entry wins: 'ref-store main' before 'ref-store'."""
    parts = key.split(" ")
    for i in range(len(parts), 0, -1):
        k = " ".join(parts[:i])
        if k in classes:
            return classes[k]
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--upstream", default=os.environ.get("UPSTREAM_T"))
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--write", action="store_true", help="update TEST-TOOL.md in place")
    args = ap.parse_args()

    known = {l.strip() for l in open(os.path.join(HERE, "known-subcommands.txt"))
             if l.strip() and not l.startswith("#")}
    classes = {r[0]: r[1:] for r in load_tsv(os.path.join(HERE, "classes.tsv"))}
    listed = load_tsv(os.path.join(HERE, "scripts.tsv"))

    imported_dir = os.path.join(ROOT, "t")
    tdirs = [imported_dir] + ([args.upstream] if args.upstream else [])
    imported = sorted(f for f in os.listdir(imported_dir)
                      if re.fullmatch(r"t\d{4}-.*\.sh", f)) if os.path.isdir(imported_dir) else []

    owners = collections.defaultdict(set)  # script -> {(milestone, issue)}
    for m, n, s in listed:
        owners[s].add((m, n))
    for s in imported:
        owners.setdefault(s, set())

    missing = [s for s in owners if not find(s, tdirs)]
    if missing and not args.upstream:
        if args.check:
            missing_set = set(missing)
            owners = {s: o for s, o in owners.items() if s not in missing_set}
        else:
            sys.exit("upstream t/ directory needed (--upstream or UPSTREAM_T)")
    elif missing:
        sys.exit("scripts not found: " + " ".join(sorted(missing)))

    per_script = {}
    lib_users = collections.defaultdict(set)
    for s in sorted(owners):
        p = find(s, tdirs)
        cnt = collections.Counter(k for k, _ in calls(p, known))
        cnt.update(wrapper_calls(p))
        per_script[s] = cnt
        _libs_cache[s] = sourced_libs(p, tdirs)
        for lib in _libs_cache[s]:
            lib_users[lib].add(s)

    per_lib = {}
    for lib in sorted(lib_users):
        p = find(lib, tdirs)
        cnt = collections.Counter(k for k, _ in calls(p, known))
        cnt.update(wrapper_calls(p))
        if cnt:
            per_lib[lib] = cnt

    framework = {}
    for f in ("test-lib.sh", "test-lib-functions.sh"):
        p = find(f, tdirs)
        if p:
            framework[f] = collections.Counter(k for k, _ in calls(p, known))

    unclassified = set()
    for cnt in list(per_script.values()) + list(per_lib.values()):
        for k in cnt:
            if classify(k, classes) is None:
                unclassified.add(k)

    if args.check:
        bad = sorted(unclassified)
        if bad:
            print("unclassified test-tool subcommands (add them to test-tool/classes.tsv):",
                  file=sys.stderr)
            for k in bad:
                users = sorted(s for s, c in per_script.items() if k in c)
                print(f"  {k}: {' '.join(users)}", file=sys.stderr)
            return 1
        if args.upstream:
            have = open(DOC, encoding="utf-8").read()
            want = splice(have, render(per_script, per_lib, framework, owners, classes))
            if want != have:
                print("TEST-TOOL.md is out of date; regenerate it with "
                      "test-tool/inventory.py --write --upstream DIR", file=sys.stderr)
                return 1
        return 0

    section = render(per_script, per_lib, framework, owners, classes)
    if args.write:
        have = open(DOC, encoding="utf-8").read() if os.path.exists(DOC) else ""
        with open(DOC, "w", encoding="utf-8") as f:
            f.write(splice(have, section))
    else:
        sys.stdout.write(section)
    return 0


BEGIN = "<!-- BEGIN GENERATED INVENTORY -->"
END = "<!-- END GENERATED INVENTORY -->"
DOC = os.path.join(ROOT, "TEST-TOOL.md")


def splice(doc, section):
    """Replace the generated section of TEST-TOOL.md (or append it)."""
    if BEGIN in doc and END in doc:
        a = doc.index(BEGIN)
        b = doc.index(END) + len(END) + 1
        return doc[:a] + section + doc[b:]
    return doc + ("\n" if doc and not doc.endswith("\n") else "") + section


def render(per_script, per_lib, framework, owners, classes):
    out = []
    w = out.append
    w(BEGIN + "\n")
    w("<!-- Generated by test-tool/inventory.py --write. Do not edit by hand. -->\n\n")
    w("## Inventory\n\n")
    w("Scripts scanned: the upstream scripts named in open rgit M1/M2 issues\n"
      "(`test-tool/scripts.tsv`) plus the imported scripts in `t/`. Counts are\n"
      "call sites in the script text (a helper function called in a loop counts\n"
      "once), including calls through the wrapper functions of\n"
      "`test-lib-functions.sh` (`packetize`, `test_file_size`, ...) and through\n"
      "variables such as `RUN=\"test-tool ref-store main\"`. Calls inside sourced\n"
      "`lib-*.sh` files are listed separately. Class and owner come from\n"
      "`test-tool/classes.tsv`.\n\n")
    total = collections.Counter()
    scripts_of = collections.defaultdict(set)
    ms_of = collections.defaultdict(set)
    for s, cnt in per_script.items():
        for k, n in cnt.items():
            total[k] += n
            scripts_of[k].add(s)
            for m, _ in owners.get(s, ()):
                ms_of[k].add(m)
    libs_of = collections.defaultdict(set)
    for lib, cnt in per_lib.items():
        for k in cnt:
            libs_of[k].add(lib)
            total[k] += 0  # list subcommands used only by libraries

    w("### By subcommand\n\n")
    w("| Subcommand | Calls | Scripts | Also in | Milestones | Class | Owner | Note |\n")
    w("|---|---:|---:|---|---|---|---|---|\n")
    for k in sorted(total, key=lambda k: (base(k), -total[k], k)):
        cl = classify(k, classes) or ["?", "", "unclassified"]
        cl = cl + [""] * (3 - len(cl))
        ms = ", ".join(sorted(ms_of[k])) or "-"
        libs = ", ".join(sorted(libs_of[k])) or "-"
        w(f"| `{k}` | {total[k]} | {len(scripts_of[k])} | {libs} | {ms} | {cl[0]} | {cl[1]} | {cl[2]} |\n")
    w("\n")

    w("### Class C call sites per milestone\n\n")
    for m in ("M1", "M2"):
        cc = collections.Counter()
        for s, cnt in per_script.items():
            if any(mm == m for mm, _ in owners.get(s, ())):
                for k, n in cnt.items():
                    if (classify(k, classes) or ["?"])[0] == "C":
                        cc[k] += n
        items = ", ".join(f"`{k}` {n}" for k, n in sorted(cc.items(), key=lambda x: (-x[1], x[0])))
        w(f"- **{m}**: {items or 'none'}\n")
    w("\n")

    w("### By script\n\n")
    w("| Script | Issues | Subcommands (calls) |\n|---|---|---|\n")
    for s in sorted(per_script):
        iss = ", ".join(f"{m} #{n}" for m, n in sorted(owners.get(s, ()), key=lambda x: (x[0], int(x[1]))))
        cnt = per_script[s]
        subs = ", ".join(f"`{k}` {n}" for k, n in sorted(cnt.items())) or "-"
        w(f"| {s} | {iss or 'imported'} | {subs} |\n")
    w("\n")

    w("### Sourced libraries\n\n")
    w("| Library | Used by | Subcommands (calls) |\n|---|---:|---|\n")
    for lib, cnt in sorted(per_lib.items()):
        subs = ", ".join(f"`{k}` {n}" for k, n in sorted(cnt.items()))
        users = sum(1 for s in per_script if lib in _libs_cache.get(s, ()))
        w(f"| {lib} | {users} | {subs} |\n")
    w("\n")

    w("### Framework\n\n")
    w("Always loaded, so these run in every script.\n\n")
    for f, cnt in framework.items():
        subs = ", ".join(f"`{k}` {n}" for k, n in sorted(cnt.items())) or "-"
        w(f"- `{f}`: {subs}\n")
    w(END + "\n")
    return "".join(out)


_libs_cache = {}

if __name__ == "__main__":
    sys.exit(main())
