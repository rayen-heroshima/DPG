#!/bin/bash

export UMASK=0022

# Heap and SMTP are environment-overridable so the same image works on a
# laptop and on a deployment host.
AMP_MAX_HEAP="${AMP_MAX_HEAP:-8g}"
AMP_SMTP_HOST="${AMP_SMTP_HOST:-ampdevde.aws.devgateway.org}"
AMP_SMTP_FROM="${AMP_SMTP_FROM:-noreply@developmentgateway.org}"

JAVA_OPTS="-server -Xmx${AMP_MAX_HEAP} -Djava.awt.headless=true"
JAVA_OPTS="$JAVA_OPTS -Demail.mode=smtp -DsmtpHost=${AMP_SMTP_HOST} -DsmtpFrom=${AMP_SMTP_FROM}"
JAVA_OPTS="$JAVA_OPTS -XX:HeapDumpPath=/opt/heapdumps -XX:+HeapDumpOnOutOfMemoryError"

CATALINA_OPTS="-Dorg.apache.jasper.compiler.Parser.STRICT_QUOTE_ESCAPING=false"
CATALINA_OPTS="$CATALINA_OPTS -Dorg.apache.jasper.compiler.Parser.STRICT_WHITESPACE=false"
CATALINA_OPTS="$CATALINA_OPTS -DAMP_DEVELOPMENT=${AMP_DEVELOPMENT:-true}"
CATALINA_OPTS="$CATALINA_OPTS -Djavamelody.datasources=java:comp/env/ampDS,java:comp/env/jcrDS"
CATALINA_OPTS="$CATALINA_OPTS -Djersey.client.connectTimeout=60000 -Djersey.client.readTimeout=600000"

# this hack overcomes phantomjs parsing issues. see https://groups.google.com/a/opencast.org/g/dev/c/0Ghsxe6Wvr0?pli=1
export OPENSSL_CONF=x
