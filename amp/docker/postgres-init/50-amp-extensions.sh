#!/bin/bash
# Runs once, on first start of an empty postgres data volume, after the
# postgis image's own 10_postgis.sh has set up template_postgis.
#
# POSTGRES_USER / POSTGRES_DB (set in docker-compose.yml to the AMP role and
# database) are already created by the official entrypoint, and the postgis
# image has installed the postgis extension into POSTGRES_DB. This adds the
# rest of what AMP's GIS endpoints expect.
set -euo pipefail

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<'SQL'
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;
SQL

echo "amp-init: postgis extensions ready in ${POSTGRES_DB}"
