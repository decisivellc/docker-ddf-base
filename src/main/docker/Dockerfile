# Modern ARM64-compatible DDF Base Image
# Recreates functionality from docker-ddf-base with modern dependencies

FROM eclipse-temurin:17-jre-jammy

# Install required system packages and tools
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    jq \
    openssl \
    ca-certificates \
    gosu \
    netcat-openbsd \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Install props tool (architecture-aware)
ENV PROPS_VERSION=v0.1.1
COPY install-props.sh /tmp/install-props.sh
RUN chmod +x /tmp/install-props.sh && \
    /tmp/install-props.sh && \
    rm /tmp/install-props.sh

# Create DDF user
RUN groupadd -r ddf && useradd -r -g ddf ddf

# Set default environment variables for DDF applications
ENV APP_NAME=""
ENV APP_HOME=""
ENV APP_LOG=""
ENV ENTRYPOINT_HOME="/opt/entrypoint"
ENV JAVA_OPTS="-Xms512m -Xmx2g -XX:+UseG1GC -XX:+UseStringDeduplication -Djava.awt.headless=true"

# Network and hostname configuration
ENV EXTERNAL_HOSTNAME=""
ENV INTERNAL_HOSTNAME=""
ENV INTERNAL_HTTPS_PORT="8993"
ENV INTERNAL_HTTP_PORT="8181"
ENV EXTERNAL_HTTPS_PORT="8993"
ENV EXTERNAL_HTTP_PORT="8181"
ENV INTERNAL_CONTEXT=""
ENV EXTERNAL_CONTEXT=""
ENV SITE_NAME=""

# Security and certificate configuration
ENV SSL_CERT=""
ENV CSR_SAN=""
ENV CA_REMOTE_URL=""
ENV CSR_KEY_ALGORITHM="rsa"
ENV CSR_KEY_SIZE="2048"
ENV CSR_COUNTRY="US"
ENV CSR_LOCALITY="Hursley"
ENV CSR_ORGANIZATION="DDF"
ENV CSR_ORGANIZATIONAL_UNIT="Dev"
ENV CSR_STATE="AZ"
ENV CSR_PROFILE="server"

# External service configuration
ENV SOLR_URL=""
ENV SOLR_ZK_HOSTS=""
ENV LDAP_HOST=""
ENV IDP_URL=""

# Application configuration
ENV INSTALL_PROFILE=""
ENV INSTALL_FEATURES=""
ENV UNINSTALL_FEATURES=""
ENV STARTUP_APPS=""
ENV CATALOG_FANOUT_MODE=""
ENV CDM=""
ENV INGEST_DATA=""
ENV SEED_CONTENT=""
ENV SOURCES=""
ENV REGISTRY=""

# System tuning
ENV JAVA_MAX_MEM=""
ENV KARAF_CLIENT_DELAY="10"
ENV KARAF_CLIENT_RETRIES="12"
ENV READINESS_EXCLUSIONS="Apache Karaf :: Features :: Extension|DDF :: Platform :: OSGi :: Conditions|Apache Karaf :: Shell :: Console|DDF :: Platform :: PaxWeb :: Jetty Config"
ENV EXPERIMENTAL_READINESS_CHECKS_ENABLED=""

# Debug configuration
ENV DEBUG=""

# Create entrypoint directory structure
RUN mkdir -p ${ENTRYPOINT_HOME}/{pre,post,templates/{sources,registry},files} \
    && mkdir -p /opt/certs

# Copy entrypoint scripts and templates
COPY entrypoint.sh ${ENTRYPOINT_HOME}/
COPY templates/ ${ENTRYPOINT_HOME}/templates/

# Set permissions
RUN chmod +x ${ENTRYPOINT_HOME}/*.sh \
    && chmod +x ${ENTRYPOINT_HOME}/pre/* 2>/dev/null || true \
    && chmod +x ${ENTRYPOINT_HOME}/post/* 2>/dev/null || true

# Create common DDF directories
RUN mkdir -p /opt/ddf/{bin,data,deploy,etc,lib,system} \
    && chown -R ddf:ddf /opt/ddf /opt/certs ${ENTRYPOINT_HOME}

# Expose common DDF ports
EXPOSE 8181 8993 8101 5005

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=5 \
    CMD curl -f -k https://localhost:${INTERNAL_HTTPS_PORT}/services/catalog || exit 1

# Use the DDF entrypoint
ENTRYPOINT ["/opt/entrypoint/entrypoint.sh"]
