"""Concatenate the SQL of every general/views patch into one script.

The patcher runs these alphabetically and aborts on the first failure, but the
views depend on each other, so order alone never satisfies them. Running the
whole set repeatedly converges instead: each pass creates whatever now has its
dependencies, and later passes pick up the rest.
"""
import html
import os
import re
import sys

import os as _os
_HERE = _os.path.dirname(_os.path.abspath(__file__))
_REPO = _os.path.abspath(_os.path.join(_HERE, "..", "..", ".."))
_PATCHES = _os.environ.get("AMP_XMLPATCHES") or _os.path.join(
    _REPO, "amp", "src", "main", "resources", "xmlpatches")
VIEWS = _os.path.join(_PATCHES, "general", "views")


def statements(path):
    xml = open(path, encoding="utf-8", errors="replace").read()
    out = []
    for m in re.finditer(r'<lang delimiter="(.*?)"[^>]*>(.*?)</lang>', xml, re.DOTALL):
        delim, body = m.group(1), m.group(2)
        body = body.strip()
        was_cdata = body.startswith("<![CDATA[")
        if was_cdata:
            body = body[len("<![CDATA["):]
        if body.endswith("]]>"):
            body = body[: -len("]]>")]
        body = re.sub(r"<!--.*?-->", "", body, flags=re.DOTALL)
        if not was_cdata:
            body = html.unescape(body)
        for s in body.split(delim):
            s = s.strip().rstrip(";").strip()
            if s:
                out.append(s)
    return out


files = sorted(f for f in os.listdir(VIEWS) if f.lower().endswith(".xml"))
chunks, n = [], 0
for f in files:
    stmts = statements(os.path.join(VIEWS, f))
    if not stmts:
        continue
    chunks.append("-- ==== %s ====" % f)
    for s in stmts:
        # each statement in its own transaction so one failure cannot poison the rest
        chunks.append("BEGIN;\n%s;\nCOMMIT;" % s)
        n += 1

open(sys.argv[1], "w", encoding="utf-8", newline="\n").write("\n".join(chunks) + "\n")
print("patches: %d   statements: %d" % (len(files), n))
