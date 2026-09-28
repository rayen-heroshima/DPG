#!/bin/bash
# Container entrypoint for the AMP webapp.
#
# The JDBC coordinates are baked into WEB-INF/../META-INF/context.xml at build
# time by the XSLT step in pom.xml. This script rewrites them from the
# environment so that a single image can be pointed at any database.
set -euo pipefail

CATALINA_HOME="${CATALINA_HOME:-/usr/local/tomcat}"
WEBAPP_ROOT="$CATALINA_HOME/webapps/ROOT"
CONTEXT_XML="$WEBAPP_ROOT/META-INF/context.xml"

AMP_DB_HOST="${AMP_DB_HOST:-db}"
AMP_DB_PORT="${AMP_DB_PORT:-5432}"
AMP_DB_NAME="${AMP_DB_NAME:-amp}"
AMP_DB_USER="${AMP_DB_USER:-amp}"
AMP_DB_PASSWORD="${AMP_DB_PASSWORD:-amp122006}"
AMP_SERVER_NAME="${AMP_SERVER_NAME:-localhost}"
AMP_DB_WAIT_TIMEOUT="${AMP_DB_WAIT_TIMEOUT:-120}"

# Runtime state that lives on disk. Mount these as volumes to survive a
# container replacement: jackrabbit keeps its lucene index here (the content
# itself goes to the jcrDS database) and AMP keeps its own lucene indexes.
# The Dockerfile already creates /opt/heapdumps, so a failure here is not
# worth aborting the boot over.
mkdir -p "$WEBAPP_ROOT/jackrabbit" "$WEBAPP_ROOT/lucene" /opt/heapdumps 2>/dev/null || true

# Escape the characters sed treats specially in a replacement: a backslash,
# '&' (which stands for the whole match) and our '|' delimiter. Without this,
# the '&amp;' separators in the JDBC URL expand to the entire matched string.
sed_replacement() {
    printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'
}

# These land inside XML attribute values, so '&', '<' and '"' have to be
# entities or Tomcat will fail to parse context.xml.
xml_escape() {
    printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/"/\&quot;/g'
}

rewrite_context_xml() {
    if [[ ! -f "$CONTEXT_XML" ]]; then
        echo "entrypoint: $CONTEXT_XML not found, leaving datasources untouched" >&2
        return
    fi

    # Attribute values live in XML, so the query-string separators are &amp;.
    local url="jdbc:postgresql://${AMP_DB_HOST}:${AMP_DB_PORT}/${AMP_DB_NAME}"
    url="${url}?useUnicode=true&amp;characterEncoding=UTF-8&amp;jdbcCompliantTruncation=false"

    local url_esc user_esc pass_esc host_esc
    # The URL is built with '&amp;' already, so it only needs sed escaping.
    url_esc=$(sed_replacement "$url")
    user_esc=$(sed_replacement "$(xml_escape "$AMP_DB_USER")")
    pass_esc=$(sed_replacement "$(xml_escape "$AMP_DB_PASSWORD")")
    host_esc=$(sed_replacement "$(xml_escape "$AMP_SERVER_NAME")")

    # Both ampDS and jcrDS point at the same database, so a global replace is
    # what we want. '|' is the delimiter because the URL is full of slashes.
    sed -i \
        -e "s|url=\"jdbc:[^\"]*\"|url=\"${url_esc}\"|g" \
        -e "s|username=\"[^\"]*\"|username=\"${user_esc}\"|g" \
        -e "s|password=\"[^\"]*\"|password=\"${pass_esc}\"|g" \
        -e "s|\(<Environment name=\"hostname\"[^>]*value=\)\"[^\"]*\"|\1\"${host_esc}\"|" \
        "$CONTEXT_XML"

    echo "entrypoint: datasources -> ${AMP_DB_USER}@${AMP_DB_HOST}:${AMP_DB_PORT}/${AMP_DB_NAME}"
}

rewrite_context_xml

echo "entrypoint: waiting for ${AMP_DB_HOST}:${AMP_DB_PORT} (timeout ${AMP_DB_WAIT_TIMEOUT}s)"
"$CATALINA_HOME/bin/wait-for-it.sh" \
    --host="$AMP_DB_HOST" --port="$AMP_DB_PORT" \
    --timeout="$AMP_DB_WAIT_TIMEOUT" --strict

exec "$@"
