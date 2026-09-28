"""Generate the amp_xml_patch registry seed.

Two problems this solves on an empty database:

1. Patch DISCOVERY inserts an AmpXmlPatch row per unrecorded patch file. The
   first such insert triggers AmpEntityInterceptor.onFlushDirty ->
   ContentTranslationUtil.multilingualIsEnabled() -> a FROM AmpGlobalSettings
   query -> Hibernate auto-flush of that same pending row -> the interceptor
   again, recursing until StackOverflowError. Pre-recording every patch means
   discovery inserts nothing and the recursion never starts.

2. Patch EXECUTION aborts the entire session on the first failure, and the
   versioned patches are incremental migrations written against older schemas —
   they cannot replay against a schema generated fresh from the current
   mappings. So they are recorded as already-applied (state=1, CLOSED), which is
   the state a restored dump would have them in.

   The exception is xmlpatches/general/views/, which AMP itself resets to OPEN
   on every boot (see SimpleSQLPatcher) because those patches rebuild the v_*
   views. Those stay OPEN (state=0).

Reads a TSV of "<patch filename>\t<location>" on stdin (produced by scanning the
deployed webapp) and writes the seed SQL.
"""
import sys

VIEWS_LOCATION = "xmlpatches/general/views/"

seen = {}
for line in sys.stdin:
    line = line.rstrip("\n")
    if not line or "\t" not in line:
        continue
    name, loc = line.split("\t", 1)
    loc = loc.lstrip("/")           # AMP records locations relative to the webapp root
    # a filename may appear in several discovery dirs; AMP keys on the name
    # alone (patch_id is the primary key), so keep the shortest path
    if name not in seen or len(loc) < len(seen[name]):
        seen[name] = loc


def esc(s):
    return s.replace("'", "''")


rows = []
open_count = 0
for name in sorted(seen):
    loc = seen[name]
    state = 0 if loc == VIEWS_LOCATION else 1
    if state == 0:
        open_count += 1
    rows.append("  ('%s', '%s', now(), %d)" % (esc(name), esc(loc), state))

if not rows:
    raise SystemExit("no patches found on stdin")

sql = (
    "-- amp_xml_patch registry: %d patches (%d left OPEN for general/views).\n"
    "INSERT INTO amp_xml_patch (patch_id, location, discovered, state) VALUES\n"
    "%s\nON CONFLICT (patch_id) DO NOTHING;\n"
    % (len(rows), open_count, ",\n".join(rows))
)

with open(sys.argv[1], "w", encoding="utf-8", newline="\n") as fh:
    fh.write(sql)

print("patch registry: %d patches, %d open (general/views)" % (len(rows), open_count))
