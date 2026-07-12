#!/usr/bin/env python3
"""
fructa duplicate + dead file audit
Run from repo root:  python3 tools/dupe_audit.py

  A. Byte-identical files
  B. Same basename in two directories (shadow models: lib/models vs lib/data/models)
  C. Files never imported by any other file and never a route target (dead code)
  D. Class names declared in more than one file (import ambiguity)
"""
import hashlib
import os
import re
import sys
from collections import defaultdict

ROOT = os.getcwd()
LIB = os.path.join(ROOT, "lib")
ENTRY = {"main.dart", "firebase_options.dart"}

IMPORT = re.compile(r"""^\s*(?:import|export|part)\s+['"]([^'"]+)['"]""", re.M)
CLASS = re.compile(r"^(?:abstract\s+|sealed\s+|final\s+|base\s+)*class\s+(\w+)", re.M)


def dart_files():
    for base, dirs, files in os.walk(LIB):
        dirs[:] = [d for d in dirs if d not in (".dart_tool", "build")]
        for f in files:
            if f.endswith(".dart"):
                yield os.path.join(base, f)


def rel(p):
    return os.path.relpath(p, ROOT)


def main():
    if not os.path.isdir(LIB):
        sys.exit("run me from the repo root (no ./lib found)")

    files = sorted(dart_files())
    src = {}
    for p in files:
        with open(p, encoding="utf-8", errors="replace") as fh:
            src[p] = fh.read()

    # A. byte-identical
    by_hash = defaultdict(list)
    for p in files:
        by_hash[hashlib.sha256(src[p].encode()).hexdigest()].append(rel(p))
    identical = [v for v in by_hash.values() if len(v) > 1]

    # B. same basename, different dir
    by_name = defaultdict(list)
    for p in files:
        by_name[os.path.basename(p)].append(rel(p))
    shadows = {k: v for k, v in by_name.items() if len(v) > 1}

    # C. imported-by graph
    imported = set()
    for p in files:
        here = os.path.dirname(p)
        for spec in IMPORT.findall(src[p]):
            if spec.startswith("package:fructa/"):
                imported.add(os.path.normpath(
                    os.path.join(LIB, spec.split("package:fructa/", 1)[1])))
            elif not spec.startswith(("dart:", "package:")):
                imported.add(os.path.normpath(os.path.join(here, spec)))
    orphans = [rel(p) for p in files
               if p not in imported and os.path.basename(p) not in ENTRY]

    # D. duplicate class names
    by_class = defaultdict(list)
    for p in files:
        for c in CLASS.findall(src[p]):
            if not c.startswith("_"):
                by_class[c].append(rel(p))
    clash = {k: v for k, v in by_class.items() if len(set(v)) > 1}

    def block(title, rows):
        print("\n== %s ==" % title)
        if not rows:
            print("  none")
        for r in rows:
            print("  " + r)

    block("A. byte-identical files", ["  |  ".join(g) for g in identical])
    block("B. same basename in >1 dir",
          ["%-26s %s" % (k, "  |  ".join(v)) for k, v in sorted(shadows.items())])
    block("C. never imported (dead unless a route/entrypoint)", sorted(orphans))
    block("D. class declared in >1 file",
          ["%-26s %s" % (k, "  |  ".join(sorted(set(v))))
           for k, v in sorted(clash.items())])


if __name__ == "__main__":
    main()
