import re, sys, os

import os as _os
_HERE = _os.path.dirname(_os.path.abspath(__file__))
_REPO = _os.path.abspath(_os.path.join(_HERE, "..", "..", ".."))
_PATCHES = _os.environ.get("AMP_XMLPATCHES") or _os.path.join(
    _REPO, "amp", "src", "main", "resources", "xmlpatches")
BASE = _PATCHES


def statements(path):
    xml = open(path, encoding="utf-8").read()
    out = []
    for m in re.finditer(r'<lang delimiter="(.*?)"[^>]*>(.*?)</lang>', xml, re.DOTALL):
        delim, body = m.group(1), m.group(2)
        body = body.strip()
        was_cdata = body.startswith("<![CDATA[")
        if body.startswith("<![CDATA["):
            body = body[len("<![CDATA["):]
        if body.endswith("]]>"):
            body = body[: -len("]]>")]
        body = re.sub(r"<!--.*?-->", "", body, flags=re.DOTALL)
        # outside CDATA the SQL is XML-escaped; put it back
        if not was_cdata:
            body = (body.replace('&lt;', '<').replace('&gt;', '>')
                        .replace('&quot;', '\"').replace('&apos;', "'")
                        .replace('&amp;', '&'))
        out.extend(s.strip() for s in body.split(delim) if s.strip())
    return out


def func_stmts(path, names):
    """Return only CREATE FUNCTION statements for the named functions."""
    found = {}
    for s in statements(path):
        m = re.match(
            r"CREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION\s+(?:public\.)?([a-zA-Z_][a-zA-Z0-9_]*)\s*\(",
            s, re.IGNORECASE)
        if m and m.group(1).lower() in names:
            found[m.group(1).lower()] = s
    return found


# function name -> the patch that defines it.
# getlocationidbyimplloc / getlocationname / getparentsectorid / getsectorname /
# getprogramsettingid are deliberately absent: no patch in the tree defines
# them (they only ever arrive inside a country dump), so they are hand-written
# in sql/30-location-functions.sql and sql/31-view-functions.sql instead.
WANTED = [
    ("getlocationdepth",       "2.z12.00/AMP-21453-define-location-nicache-tables.xml"),
    ("dimension_updated_proc", "2.z12.04/AMP-23377-ni-schema-triggers.xml"),
    ("getsectordepth",         "2.z10.01/AMP-18143-define-sector-cache-tables.xml"),
    ("getsectorlevel",         "2.z10.01/AMP-18143-define-sector-cache-tables.xml"),
    ("getprogramdepth",        "2.8.11/AMP-17863-enable-recreate-views-and-create-cache-table-programs.xml"),
    ("getprogramlevel",        "2.8.11/AMP-17863-enable-recreate-views-and-create-cache-table-programs.xml"),
]

by_file = {}
for fn, rel in WANTED:
    by_file.setdefault(rel, set()).add(fn)

chunks = []
missing = []
for rel, names in by_file.items():
    path = os.path.join(BASE, rel)
    found = func_stmts(path, names)
    for n in sorted(names):
        if n in found:
            chunks.append("-- %s  (from %s)\n%s;" % (n, rel, found[n]))
        else:
            missing.append((n, rel))

dst = sys.argv[1]
open(dst, "w", encoding="utf-8", newline="\n").write("\n\n".join(chunks) + "\n")
print("extracted %d function definitions" % len(chunks))
if missing:
    print("MISSING:")
    for n, rel in missing:
        print("  %s in %s" % (n, rel))
