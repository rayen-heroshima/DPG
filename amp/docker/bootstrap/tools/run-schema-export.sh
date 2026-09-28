#!/bin/bash
# Runs inside the amp container: creates the Hibernate-mapped schema.
#
# DigiSchemaExport is AMP's own schema tool (it is a commented-out exec-maven
# execution in amp/pom.xml, i.e. a deliberate manual step — AMP normally gets its
# schema from a country dump instead).
#
# Two things have to be arranged first:
#   - DigiConfigManager.initialize() is handed the absolute path
#     "/WEB-INF/moduleConfig", so /WEB-INF has to resolve to the webapp's.
#   - standAloneAmpHibernate.cfg.xml ships with a hardcoded developer database
#     (localhost:5433/amp_togo_35); point it at this stack's database.
set -euo pipefail

ROOT=/usr/local/tomcat/webapps/ROOT
CFG="$ROOT/WEB-INF/classes/standAloneAmpHibernate.cfg.xml"

DB_HOST="${AMP_DB_HOST:-db}"
DB_PORT="${AMP_DB_PORT:-5432}"
DB_NAME="${AMP_DB_NAME:-amp}"
DB_USER="${AMP_DB_USER:-amp}"
DB_PASS="${AMP_DB_PASSWORD:-amp122006}"

ln -sfn "$ROOT/WEB-INF" /WEB-INF

sed -i \
    -e "s|jdbc:postgresql://[^<]*|jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}|" \
    -e "s|<property name=\"hibernate.connection.username\">[^<]*|<property name=\"hibernate.connection.username\">${DB_USER}|" \
    -e "s|<property name=\"hibernate.connection.password\">[^<]*|<property name=\"hibernate.connection.password\">${DB_PASS}|" \
    "$CFG"

cd "$ROOT"
exec java -cp "WEB-INF/classes:WEB-INF/lib/*" org.digijava.kernel.util.DigiSchemaExport "$@"
