"""Collect every amp_global_settings INSERT that AMP's patch tree performs.

Those patches each carry an entryInTableMissing guard, so replaying just their
INSERTs (guarded the same way) is how a fresh database gets the settings a real
install accumulated over its upgrade history.
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
BASE = _PATCHES


def sql_of(path):
    xml = open(path, encoding="utf-8", errors="replace").read()
    chunks = []
    for m in re.finditer(r'<lang delimiter="(.*?)"[^>]*>(.*?)</lang>', xml, re.DOTALL):
        body = m.group(2).strip()
        was_cdata = body.startswith("<![CDATA[")
        if was_cdata:
            body = body[len("<![CDATA["):]
        if body.endswith("]]>"):
            body = body[: -len("]]>")]
        body = re.sub(r"<!--.*?-->", "", body, flags=re.DOTALL)
        if not was_cdata:
            body = html.unescape(body)
        chunks.append(body)
    return "\n".join(chunks)


# insert into amp_global_settings(<cols>) values (<vals>)
INS = re.compile(
    r"insert\s+into\s+amp_global_settings\s*\(([^)]*)\)\s*values\s*\((.*?)\)\s*(?:;|$)",
    re.IGNORECASE | re.DOTALL)


def split_vals(s):
    out, cur, depth, quote = [], "", 0, False
    i = 0
    while i < len(s):
        c = s[i]
        if quote:
            if c == "'":
                if i + 1 < len(s) and s[i + 1] == "'":
                    cur += "''"
                    i += 2
                    continue
                quote = False
            cur += c
        elif c == "'":
            quote = True
            cur += c
        elif c == "(":
            depth += 1
            cur += c
        elif c == ")":
            depth -= 1
            cur += c
        elif c == "," and depth == 0:
            out.append(cur.strip())
            cur = ""
        else:
            cur += c
        i += 1
    if cur.strip():
        out.append(cur.strip())
    return out


settings = {}
for dirpath, _d, files in os.walk(BASE):
    for f in sorted(files):
        if not f.lower().endswith(".xml"):
            continue
        try:
            sql = sql_of(os.path.join(dirpath, f))
        except Exception:
            continue
        for m in INS.finditer(sql):
            cols = [c.strip().lower() for c in m.group(1).split(",")]
            vals = split_vals(m.group(2))
            if len(cols) != len(vals):
                continue
            row = dict(zip(cols, vals))
            name = row.get("settingsname")
            if not name or not name.startswith("'"):
                continue
            # later patches win: they represent the newer default
            settings[name] = row

out = ["-- Global settings harvested from AMP's own patch tree (%d settings).\n"
       "-- Each is guarded exactly as the source patches guard them, so this is\n"
       "-- safe to re-run and never overwrites a value already present.\n" % len(settings)]
for name in sorted(settings):
    r = settings[name]
    val = r.get("settingsvalue", "NULL")
    possible = r.get("possiblevalues", "NULL")
    desc = r.get("description", name)
    section = r.get("section", "'general'")
    for k in ("settingsvalue", "possiblevalues", "description", "section"):
        if r.get(k, "").lower().startswith("nextval"):
            pass
    out.append(
        "INSERT INTO amp_global_settings (id, settingsname, settingsvalue, possiblevalues, description, section, internal)\n"
        "SELECT nextval('amp_global_settings_seq'), %s, %s, %s, %s, %s, false\n"
        "WHERE NOT EXISTS (SELECT 1 FROM amp_global_settings WHERE settingsname = %s);"
        % (name, val, possible, desc, section, name))

open(sys.argv[1], "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
print("global settings found:", len(settings))
