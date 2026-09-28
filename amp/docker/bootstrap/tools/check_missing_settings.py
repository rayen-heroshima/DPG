"""Emit SQL listing which GlobalSettingsConstants names have no row yet.

Reads one setting name per line and writes a query that returns the missing ones.
"""
import sys

names = [l.strip().replace("'", "''")
         for l in open(sys.argv[1], encoding="utf-8") if l.strip()]
vals = ",".join("('%s')" % n for n in names)
sql = ("SELECT v.n FROM (VALUES %s) AS v(n) "
       "WHERE NOT EXISTS (SELECT 1 FROM amp_global_settings g WHERE g.settingsname = v.n) "
       "ORDER BY 1;" % vals)
open(sys.argv[2], "w", encoding="utf-8", newline="\n").write(sql)
print("checking %d setting names" % len(names))
