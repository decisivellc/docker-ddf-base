#!/bin/bash

# Props tool installation script for multi-architecture support
# Updated for Codice props v0.1.1+ with exact binary names

set -e

PROPS_VERSION="${PROPS_VERSION:-v0.1.1}"
ARCH=$(uname -m)
OS="linux"

# Map architecture names to match your release assets
case ${ARCH} in
    x86_64)
        PROPS_ARCH="amd64"
        ;;
    aarch64|arm64)
        PROPS_ARCH="arm64"
        ;;
    *)
        echo "Unsupported architecture: ${ARCH}"
        echo "Supported architectures: x86_64 (amd64), aarch64/arm64"
        exit 1
        ;;
esac

echo "Installing props tool ${PROPS_VERSION} for ${OS}/${PROPS_ARCH}"

# If latest, get the latest release tag
if [ "$PROPS_VERSION" = "latest" ]; then
    echo "Fetching latest release version..."
    PROPS_VERSION=$(curl -s https://api.github.com/repos/codice/props/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [ -z "$PROPS_VERSION" ]; then
        echo "Failed to fetch latest version, using v0.1.1"
        PROPS_VERSION="v0.1.1"
    fi
    echo "Latest version: $PROPS_VERSION"
fi

# Construct the exact binary name based on your release pattern
# Format: props_VERSION_OS_ARCH (e.g., props_0.1.1_linux_amd64)
VERSION_NUMBER="${PROPS_VERSION#v}"  # Remove 'v' prefix
BINARY_NAME="props_${VERSION_NUMBER}_${OS}_${PROPS_ARCH}"
DOWNLOAD_URL="https://github.com/codice/props/releases/download/${PROPS_VERSION}/${BINARY_NAME}"

echo "Downloading: $BINARY_NAME"
echo "From: $DOWNLOAD_URL"

# Download the binary
if curl -fsSL "$DOWNLOAD_URL" -o /usr/local/bin/props; then
    echo "Successfully downloaded props binary"
else
    echo "ERROR: Failed to download props binary"
    echo "URL: $DOWNLOAD_URL"
    echo "Expected binary name: $BINARY_NAME"
    echo ""
    echo "Available assets for ${PROPS_VERSION}:"
    echo "- props_${VERSION_NUMBER}_linux_amd64 (Linux x86_64)"
    echo "- props_${VERSION_NUMBER}_linux_arm64 (Linux ARM64)" 
    echo "- props_${VERSION_NUMBER}_darwin_amd64 (macOS Intel)"
    echo "- props_${VERSION_NUMBER}_darwin_arm64 (macOS Apple Silicon)"
    echo "- props_${VERSION_NUMBER}_freebsd_amd64 (FreeBSD)"
    echo "- props_${VERSION_NUMBER}_windows_amd64.exe (Windows)"
    echo ""
    echo "Please check: https://github.com/codice/props/releases/tag/${PROPS_VERSION}"
    exit 1
fi

# Make executable
chmod +x /usr/local/bin/props

# Verify installation
echo "Props tool installed successfully!"
echo "Binary location: $(which props)"
echo "File info: $(ls -la /usr/local/bin/props)"

# Try to get version info (try multiple common patterns)
if /usr/local/bin/props --version >/dev/null 2>&1; then
    echo "Version: $(/usr/local/bin/props --version)"
elif /usr/local/bin/props version >/dev/null 2>&1; then
    echo "Version: $(/usr/local/bin/props version)"
elif /usr/local/bin/props -v >/dev/null 2>&1; then
    echo "Version: $(/usr/local/bin/props -v)"
else
    echo "Props tool ready for use!"
    echo "Try: props --help"
fi
