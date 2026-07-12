#!/usr/bin/env python3
"""
fructa i18n audit
Run from repo root:  python3 tools/i18n_audit.py

Emits tools/i18n_report.md with:
  A. Hardcoded user-facing strings per file (the work list)
  B. Keys referenced in code but missing from en.json (runtime blanks)
  C. Keys in en.json referenced nowhere (dead weight)
  D. Duplicate values in en.json (consolidation candidates)
  E. Locale parity: keys present in en.json but missing in every other lang file
"""
import json
import os
import re
import sys
from collections import defaultdict

ROOT = os.getcwd()
LIB = os.path.join(ROOT, "lib")
LANG = os.path.join(ROOT, "assets", "lang")
OUT = os.path.join(ROOT, "tools", "i18n_report.md")

# ---------------------------------------------------------------- widgets that
# take user-facing copy. A string literal in one of these positions is a finding.
POSITIONAL = [
    r"\bText\(\s*",
    r"\bSelectableText\(\s*",
    r"\bTooltip\(\s*message:\s*",
    r"\bDisclaimer\(\s*",
    r"\b_toast\(\s*\w+\s*,\s*",
]
NAMED = [
    "label", "labelText", "hintText", "helperText", "errorText", "title",
    "subtitle", "sub", "sub2", "note", "foot", "footer", "tooltip", "message",
    "semanticLabel", "placeholder", "confirmText", "cancelText", "buttonText",
    "caption", "heading", "body", "kicker", "cta", "desc", "valueText",
    "trailing", "prefixText", "suffixText", "counterText",
]

# ---------------------------------------------------------------- exclusions.
# Not user-facing: identifiers, asset paths, keys, formats, single glyphs.
SKIP_LINE = re.compile(
    r"(^\s*//|^\s*///|"
    r"\bdebugPrint\(|\bprint\(|\bassert\(|"
    r"\bKey\(|\bValueKey\(|\bGlobalKey\(|"
    r"\bnamed:|\brouteName|\bfontFamily:|\bpackage:)"
)
# a line may mix a translated call with a raw literal. Blank out the translated
# call so the raw literal on the same line is still caught.
PAT_TCALL = re.compile(r"\b(?:context\.)?(?:t|tr)\(\s*['\"][a-zA-Z0-9_.]+['\"]")
SKIP_VALUE = re.compile(
    r"^\s*$"                       # empty / whitespace
    r"|^[\W\d_]{1,3}$"             # glyphs, punctuation, tiny numerics
    r"|^assets/"                   # asset path
    r"|^https?://"                 # url
    r"|^[a-z][a-zA-Z0-9]*$"        # bare camelCase identifier
    r"|^[a-z0-9_]+(\.[a-z0-9_]+)+$"  # dotted i18n key or slug
    r"|^[#%\$]"                    # format token
    r"|^[A-Z]{2,5}$"               # KES, USD, NSE, AUM
)

STR = r"'((?:[^'\\]|\\.)*)'|\"((?:[^\"\\]|\\.)*)\""
PAT_POS = re.compile("(?:" + "|".join(POSITIONAL) + r")(?:" + STR + ")")
PAT_NAMED = re.compile(r"\b(" + "|".join(NAMED) + r")\s*:\s*(?:" + STR + ")")
PAT_KEYREF = re.compile(r"\bt\(\s*['\"]([a-zA-Z0-9_.]+)['\"]")


def literal(m, groups):
    for g in groups:
        if m.group(g) is not None:
            return m.group(g)
    return ""


def dart_files():
    for base, dirs, files in os.walk(LIB):
        dirs[:] = [d for d in dirs if d not in (".dart_tool", "build")]
        for f in files:
            if f.endswith(".dart") and not f.endswith(".g.dart") \
                    and not f.endswith(".freezed.dart"):
                yield os.path.join(base, f)


def rel(p):
    return os.path.relpath(p, ROOT)


def main():
    if not os.path.isdir(LIB):
        sys.exit("run me from the repo root (no ./lib found)")

    findings = defaultdict(list)   # file -> [(line, kind, text)]
    refs = set()                   # i18n keys used in code

    for path in dart_files():
        with open(path, encoding="utf-8") as fh:
            for n, line in enumerate(fh, 1):
                for m in PAT_KEYREF.finditer(line):
                    refs.add(m.group(1))
                if SKIP_LINE.search(line):
                    continue
                line = PAT_TCALL.sub("t(", line)
                for m in PAT_POS.finditer(line):
                    v = literal(m, (1, 2))
                    if not SKIP_VALUE.match(v):
                        findings[rel(path)].append((n, "widget", v))
                for m in PAT_NAMED.finditer(line):
                    v = literal(m, (2, 3))
                    if not SKIP_VALUE.match(v):
                        findings[rel(path)].append((n, m.group(1), v))

    langs = {}
    if os.path.isdir(LANG):
        for f in sorted(os.listdir(LANG)):
            if f.endswith(".json"):
                with open(os.path.join(LANG, f), encoding="utf-8") as fh:
                    try:
                        langs[f[:-5]] = json.load(fh)
                    except json.JSONDecodeError as e:
                        langs[f[:-5]] = {}
                        print("INVALID JSON: %s -> %s" % (f, e))

    en = langs.get("en", {})
    missing = sorted(k for k in refs if k not in en)
    unused = sorted(k for k in en if k not in refs)

    dupes = defaultdict(list)
    for k, v in en.items():
        if isinstance(v, str):
            dupes[v.strip().lower()].append(k)
    dupes = {v: ks for v, ks in dupes.items() if len(ks) > 1}

    total = sum(len(v) for v in findings.values())
    L = []
    L.append("# fructa i18n audit\n")
    L.append("Hardcoded strings: **%d** across **%d** files."
             % (total, len(findings)))
    L.append("en.json keys: **%d** · referenced in code: **%d**\n"
             % (len(en), len(refs)))

    L.append("## A. Hardcoded user-facing strings\n")
    for f in sorted(findings, key=lambda x: -len(findings[x])):
        L.append("### %s  (%d)" % (f, len(findings[f])))
        L.append("```")
        for n, kind, v in findings[f]:
            L.append("%5d  %-14s %s" % (n, kind, v))
        L.append("```")

    L.append("\n## B. Keys used in code, absent from en.json (renders blank)\n")
    L.append("```\n" + ("\n".join(missing) if missing else "none") + "\n```")

    L.append("\n## C. Keys in en.json referenced nowhere\n")
    L.append("```\n" + ("\n".join(unused) if unused else "none") + "\n```")

    L.append("\n## D. Duplicate values in en.json\n")
    L.append("```")
    for v, ks in sorted(dupes.items()):
        L.append("%-34s %s" % (repr(v[:32]), ", ".join(ks)))
    L.append("```")

    L.append("\n## E. Locale parity\n")
    L.append("```")
    for name, data in langs.items():
        if name == "en":
            continue
        gap = [k for k in en if k not in data]
        L.append("%-6s %d/%d keys · missing %d" %
                 (name, len(data), len(en), len(gap)))
    L.append("```")

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write("\n".join(L) + "\n")
    print("wrote %s" % rel(OUT))
    print("hardcoded=%d missing=%d unused=%d dupevalues=%d"
          % (total, len(missing), len(unused), len(dupes)))


if __name__ == "__main__":
    main()
