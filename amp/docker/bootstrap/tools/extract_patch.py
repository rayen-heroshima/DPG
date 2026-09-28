"""Emit the SQL of one or more xmlpatch files as a plain script.

Usage: extract_patch.py <out.sql> <patch-path-relative-to-xmlpatches> ...

Paths are resolved against the repo's xmlpatches directory (override with
AMP_XMLPATCHES). Statements are split on the patch's own delimiter, XML entities
are decoded when the body is not CDATA, and inline XML comments are stripped —
several patches put a <!-- ... --> in the middle of their SQL.
"""
import html
import os
import re
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_REPO = os.path.abspath(os.path.join(_HERE, "..", "..", ".."))
_PATCHES = os.environ.get("AMP_XMLPATCHES") or os.path.join(
    _REPO, "amp", "src", "main", "resources", "xmlpatches")


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


def main():
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    dst, rels = sys.argv[1], sys.argv[2:]
    chunks, total = [], 0
    for rel in rels:
        path = os.path.join(_PATCHES, rel)
        if not os.path.exists(path):
            raise SystemExit("no such patch: %s" % path)
        stmts = statements(path)
        chunks.append("-- ==== %s ====" % rel)
        for s in stmts:
            # one transaction per statement so a failure cannot poison the rest
            chunks.append("BEGIN;\n%s;\nCOMMIT;" % s)
        total += len(stmts)
    open(dst, "w", encoding="utf-8", newline="\n").write("\n".join(chunks) + "\n")
    print("patches: %d   statements: %d" % (len(rels), total))


if __name__ == "__main__":
    main()
