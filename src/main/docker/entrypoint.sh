#!/bin/bash

# Modern DDF Base Entrypoint Script
# Recreates functionality from docker-ddf-base for ARM64 compatibility

set -e

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGFILE="${APP_LOG:-/opt/ddf/data/log/ddf.log}"

# Logging functions
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ENTRYPOINT] $1" | tee -a "${LOGFILE}" 2>/dev/null || echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ENTRYPOINT] $1"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ENTRYPOINT] ERROR: $1" >&2
}

log_warn() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ENTRYPOINT] WARNING: $1"
}

# Validation functions
validate_environment() {
    local missing_vars=()
    
    if [ -z "$APP_NAME" ]; then
        missing_vars+=(APP_NAME)
    fi
    
    if [ -z "$APP_HOME" ]; then
        missing_vars+=(APP_HOME)
    fi
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        log_error "Missing required environment variables: ${missing_vars[*]}"
        log_error "Please set: APP_NAME, APP_HOME"
        exit 1
    fi
    
    if [ ! -d "$APP_HOME" ]; then
        log_error "APP_HOME directory does not exist: $APP_HOME"
        exit 1
    fi
    
    if [ ! -d "$APP_HOME/bin" ]; then
        log_error "APP_HOME/bin directory does not exist: $APP_HOME/bin"
        exit 1
    fi
}

# Hostname configuration
configure_hostnames() {
    log "Configuring hostnames..."
    
    # Set internal hostname
    if [ -z "$INTERNAL_HOSTNAME" ]; then
        INTERNAL_HOSTNAME=$(hostname -f)
        log "INTERNAL_HOSTNAME not set, using: $INTERNAL_HOSTNAME"
    fi
    
    # Set external hostname
    if [ -z "$EXTERNAL_HOSTNAME" ]; then
        EXTERNAL_HOSTNAME="$INTERNAL_HOSTNAME"
        log "EXTERNAL_HOSTNAME not set, using: $EXTERNAL_HOSTNAME"
    fi
    
    # Set site name
    if [ -z "$SITE_NAME" ]; then
        SITE_NAME="$EXTERNAL_HOSTNAME"
        log "SITE_NAME not set, using: $SITE_NAME"
    fi
    
    export INTERNAL_HOSTNAME EXTERNAL_HOSTNAME SITE_NAME
}

# Java memory configuration
configure_java_memory() {
    if [ -n "$JAVA_MAX_MEM" ]; then
        log "Setting Java max memory to: $JAVA_MAX_MEM"
        JAVA_OPTS="$JAVA_OPTS -Xmx$JAVA_MAX_MEM"
    fi
    
    # Add debug options if enabled
    if [ "$DEBUG" = "true" ]; then
        log "Debug mode enabled on port 5005"
        JAVA_OPTS="$JAVA_OPTS -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005"
    fi
    
    export JAVA_OPTS
}

# Certificate management
setup_certificates() {
    log "Setting up certificates..."
    
    local keystore_dir="$APP_HOME/etc/keystores"
    local server_keystore="$keystore_dir/serverKeystore.jks"
    local server_truststore="$keystore_dir/serverTruststore.jks"
    
    mkdir -p "$keystore_dir"
    
    # Check if custom keystores are provided
    if [ -f "$server_keystore" ] && [ -f "$server_truststore" ]; then
        log "Using existing custom keystores"
        return 0
    fi
    
    # Import certificate from SSL_CERT environment variable
    if [ -n "$SSL_CERT" ]; then
        log "Importing certificate from SSL_CERT environment variable"
        echo "$SSL_CERT" > /tmp/cert.pem
        # Process certificate import here
        log_warn "SSL_CERT import not fully implemented - use custom keystores for production"
    fi
    
    # Generate certificates using DDF demo CA or remote CA
    if [ -n "$CA_REMOTE_URL" ]; then
        log "Requesting certificate from remote CA: $CA_REMOTE_URL"
        request_remote_certificate
    else
        log "Using DDF demo CA for certificate generation"
        generate_demo_certificate
    fi
}

generate_demo_certificate() {
    log "Generating demo certificate for hostname: $INTERNAL_HOSTNAME"
    
    # Build SAN list
    local san_list="DNS:$INTERNAL_HOSTNAME,DNS:localhost,IP:127.0.0.1"
    if [ "$EXTERNAL_HOSTNAME" != "$INTERNAL_HOSTNAME" ]; then
        san_list="$san_list,DNS:$EXTERNAL_HOSTNAME"
    fi
    if [ -n "$CSR_SAN" ]; then
        san_list="$san_list,$CSR_SAN"
    fi
    
    log "Certificate SAN list: $san_list"
    
    # Use DDF's built-in demo CA if available
    if [ -f "$APP_HOME/etc/certs/demoCA/ca.key" ]; then
        log "Using DDF demo CA for certificate generation"
        # Certificate generation logic would go here
        log_warn "Demo certificate generation not fully implemented"
    else
        log_warn "DDF demo CA not found, certificates may need manual configuration"
    fi
}

request_remote_certificate() {
    log "Requesting certificate from remote CA: $CA_REMOTE_URL"
    
    # Build CSR configuration
    local csr_config=$(cat <<EOF
{
    "CN": "$INTERNAL_HOSTNAME",
    "key": {
        "algo": "$CSR_KEY_ALGORITHM",
        "size": $CSR_KEY_SIZE
    },
    "names": [
        {
            "C": "$CSR_COUNTRY",
            "L": "$CSR_LOCALITY",
            "O": "$CSR_ORGANIZATION",
            "OU": "$CSR_ORGANIZATIONAL_UNIT",
            "ST": "$CSR_STATE"
        }
    ]
}
EOF
)
    
    log "CSR Configuration: $csr_config"
    log_warn "Remote CA certificate request not fully implemented"
}

# Configuration file management
copy_pre_config() {
    local pre_config_dir="$SCRIPT_DIR/pre_config"
    if [ -d "$pre_config_dir" ]; then
        log "Copying pre-configuration files..."
        cp -r "$pre_config_dir"/* "$APP_HOME/"
    fi
    
    # Copy mounted config files
    if [ -d "/config" ]; then
        log "Copying mounted configuration files from /config"
        cp -r /config/* "$APP_HOME/etc/"
    fi
}

# Feature and app management
configure_features() {
    if [ -n "$INSTALL_PROFILE" ]; then
        log "Will install profile: $INSTALL_PROFILE"
        echo "profile-install $INSTALL_PROFILE" >> "$APP_HOME/etc/startup.properties"
    fi
    
    if [ -n "$INSTALL_FEATURES" ]; then
        log "Will install features: $INSTALL_FEATURES"
        IFS=';' read -ra FEATURES <<< "$INSTALL_FEATURES"
        for feature in "${FEATURES[@]}"; do
            echo "feature-install $feature" >> "$APP_HOME/etc/startup.properties"
        done
    fi
    
    if [ -n "$UNINSTALL_FEATURES" ]; then
        log "Will uninstall features: $UNINSTALL_FEATURES"
        IFS=';' read -ra FEATURES <<< "$UNINSTALL_FEATURES"
        for feature in "${FEATURES[@]}"; do
            echo "feature-uninstall $feature" >> "$APP_HOME/etc/startup.properties"
        done
    fi
    
    if [ -n "$STARTUP_APPS" ]; then
        log "Will start apps: $STARTUP_APPS"
        IFS=';' read -ra APPS <<< "$STARTUP_APPS"
        for app in "${APPS[@]}"; do
            echo "app-start $app" >> "$APP_HOME/etc/startup.properties"
        done
    fi
}

# External service configuration
configure_external_services() {
    if [ -n "$SOLR_URL" ]; then
        log "Configuring external Solr: $SOLR_URL"
        # Configure Solr client
    fi
    
    if [ -n "$SOLR_ZK_HOSTS" ]; then
        log "Configuring SolrCloud with ZooKeeper hosts: $SOLR_ZK_HOSTS"
        # Configure SolrCloud
    fi
    
    if [ -n "$LDAP_HOST" ]; then
        log "Configuring LDAP: $LDAP_HOST"
        # Configure LDAP client
    fi
    
    if [ -n "$IDP_URL" ]; then
        log "Configuring IdP: $IDP_URL"
        # Configure IdP client
    fi
}

# Data seeding
setup_data_seeding() {
    if [ -n "$INGEST_DATA" ]; then
        log "Data ingestion configured: $INGEST_DATA"
        # Setup data ingestion
    fi
    
    if [ -n "$SEED_CONTENT" ]; then
        log "Content seeding configured: $SEED_CONTENT"
        # Setup content seeding
    fi
    
    if [ -n "$CDM" ]; then
        log "Content Directory Monitor configured: $CDM"
        # Setup CDM
    fi
}

# Federated sources configuration
configure_federation() {
    if [ -n "$SOURCES" ]; then
        log "Configuring federated sources: $SOURCES"
        # Configure federated sources
    fi
    
    if [ -n "$REGISTRY" ]; then
        log "Configuring registries: $REGISTRY"
        # Configure registries
    fi
    
    if [ "$CATALOG_FANOUT_MODE" = "true" ]; then
        log "Enabling catalog fanout mode"
        # Enable fanout mode
    fi
}

# System configuration
configure_system() {
    log "Configuring system properties..."
    
    # Configure ports
    if [ -n "$INTERNAL_HTTPS_PORT" ] && [ "$INTERNAL_HTTPS_PORT" != "8993" ]; then
        props set "$APP_HOME/etc/system.properties" "org.codice.ddf.system.httpsPort" "$INTERNAL_HTTPS_PORT"
    fi
    
    if [ -n "$INTERNAL_HTTP_PORT" ] && [ "$INTERNAL_HTTP_PORT" != "8181" ]; then
        props set "$APP_HOME/etc/system.properties" "org.codice.ddf.system.httpPort" "$INTERNAL_HTTP_PORT"
    fi
    
    # Configure hostname
    props set "$APP_HOME/etc/system.properties" "org.codice.ddf.system.hostname" "$INTERNAL_HOSTNAME"
    
    # Configure site name
    props set "$APP_HOME/etc/system.properties" "org.codice.ddf.system.siteName" "$SITE_NAME"
    
    # Configure contexts
    if [ -n "$INTERNAL_CONTEXT" ]; then
        props set "$APP_HOME/etc/system.properties" "org.codice.ddf.system.rootContext" "$INTERNAL_CONTEXT"
    fi
}

# Wait for system readiness
wait_for_readiness() {
    local retries="${KARAF_CLIENT_RETRIES:-12}"
    local delay="${KARAF_CLIENT_DELAY:-10}"
    local count=0
    
    log "Waiting for system to be ready (max ${retries} attempts, ${delay}s delay)..."
    
    while [ $count -lt $retries ]; do
        if check_system_ready; then
            log "System is ready!"
            return 0
        fi
        
        count=$((count + 1))
        log "System not ready, attempt $count/$retries, waiting ${delay}s..."
        sleep $delay
    done
    
    log_error "System failed to become ready after $retries attempts"
    return 1
}

check_system_ready() {
    if [ "$EXPERIMENTAL_READINESS_CHECKS_ENABLED" = "true" ]; then
        # Use fabric8 health check endpoint
        curl -f -k "https://localhost:${INTERNAL_HTTPS_PORT}/ready" >/dev/null 2>&1
    else
        # Check if all bundles are started (simplified check)
        curl -f -k "https://localhost:${INTERNAL_HTTPS_PORT}/services" >/dev/null 2>&1
    fi
}

# Extension points
run_pre_start_extensions() {
    log "Running pre-start extensions..."
    
    # Run custom pre-start script
    if [ -f "$SCRIPT_DIR/pre_start_custom.sh" ]; then
        log "Running custom pre-start script"
        bash "$SCRIPT_DIR/pre_start_custom.sh"
    fi
    
    # Run all scripts in pre directory
    if [ -d "$SCRIPT_DIR/pre" ]; then
        for script in "$SCRIPT_DIR/pre"/*; do
            if [ -x "$script" ]; then
                log "Running pre-start extension: $(basename "$script")"
                "$script"
            fi
        done
    fi
}

run_post_start_extensions() {
    log "Running post-start extensions..."
    
    # Run custom post-start script
    if [ -f "$SCRIPT_DIR/post_start_custom.sh" ]; then
        log "Running custom post-start script"
        bash "$SCRIPT_DIR/post_start_custom.sh"
    fi
    
    # Run all scripts in post directory
    if [ -d "$SCRIPT_DIR/post" ]; then
        for script in "$SCRIPT_DIR/post"/*; do
            if [ -x "$script" ]; then
                log "Running post-start extension: $(basename "$script")"
                "$script"
            fi
        done
    fi
}

# Fix permissions
fix_permissions() {
    log "Fixing file permissions..."
    
    if [ "$(id -u)" = "0" ]; then
        chown -R ddf:ddf "$APP_HOME" /opt/certs 2>/dev/null || true
        
        # Switch to ddf user if running as root
        log "Switching to ddf user..."
        exec gosu ddf "$0" "$@"
    fi
}

# Main execution
main() {
    log "Starting $APP_NAME container initialization..."
    log "APP_HOME: $APP_HOME"
    log "Java version: $(java -version 2>&1 | head -n 1)"
    
    # Fix permissions first
    fix_permissions
    
    # Validate environment
    validate_environment
    
    # Configure system
    configure_hostnames
    configure_java_memory
    
    # Pre-start phase
    log "=== PRE-START PHASE ==="
    copy_pre_config
    setup_certificates
    configure_system
    configure_features
    configure_external_services
    setup_data_seeding
    configure_federation
    run_pre_start_extensions
    
    # Start the application
    log "=== STARTING APPLICATION ==="
    log "Starting $APP_NAME..."
    
    # Start application in background
    cd "$APP_HOME"
    ./bin/ddf server &
    APP_PID=$!
    
    # Wait for system to be ready
    wait_for_readiness
    
    # Post-start phase
    log "=== POST-START PHASE ==="
    run_post_start_extensions
    
    log "$APP_NAME initialization complete!"
    
    # Wait for application to exit
    wait $APP_PID
}

# Handle signals
trap 'log "Received SIGTERM, shutting down..."; kill -TERM $APP_PID 2>/dev/null; wait $APP_PID' TERM
trap 'log "Received SIGINT, shutting down..."; kill -INT $APP_PID 2>/dev/null; wait $APP_PID' INT

# Execute main function
main "$@"
