#!/bin/bash
# Runs inside the amp container. Prints "<patch filename>\t<location>" for every
# xml patch in the directories AMP's XmlPatcherService discovers, where location
# is the directory path relative to the webapp root, matching what
# XmlPatcherUtil.computePatchFileLocation() records.
set -uo pipefail

ROOT=/usr/local/tomcat/webapps/ROOT

DIRS="
$ROOT/WEB-INF/classes/WEB-INF/moduleConfig/gateperm/xmlpatches
$ROOT/WEB-INF/moduleConfig/gateperm/xmlpatches
$ROOT/WEB-INF/classes/org/digijava/kernel/xmlpatches
$ROOT/WEB-INF/classes/xmlpatches
$ROOT/xmlpatches
"

for d in $DIRS; do
    [ -d "$d" ] || continue
    find "$d" -type f -iname '*.xml' 2>/dev/null | while read -r f; do
        dir="$(dirname "$f")"
        printf '%s\t%s/\n' "$(basename "$f")" "${dir#$ROOT/}"
    done
done
