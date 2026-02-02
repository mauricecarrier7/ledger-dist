#!/bin/bash
# CodeAtlas Ledger Install Script
# 
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/mauricecarrier7/ledger-dist/main/install.sh | bash
#   curl -fsSL .../install.sh | bash -s -- --version 0.8.2
#   curl -fsSL .../install.sh | bash -s -- --dir ./tools/bin

set -e

# Defaults
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
VERSION="${VERSION:-latest}"
REPO="mauricecarrier7/ledger-dist"
MANIFEST_URL="https://raw.githubusercontent.com/${REPO}/main/versions.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}▸${NC} $1"; }
log_warn() { echo -e "${YELLOW}▸${NC} $1"; }
log_error() { echo -e "${RED}▸${NC} $1"; exit 1; }

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --version|-v) VERSION="$2"; shift 2 ;;
        --dir|-d) INSTALL_DIR="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# Detect platform
OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
    Darwin) PLATFORM="macos" ;;
    Linux) PLATFORM="linux" ;;
    *) log_error "Unsupported OS: $OS" ;;
esac

case "$ARCH" in
    arm64|aarch64) ARCH="arm64" ;;
    x86_64) ARCH="x64" ;;
    *) log_error "Unsupported architecture: $ARCH" ;;
esac

PLATFORM_KEY="${PLATFORM}-${ARCH}"
BINARY_NAME="ledger-${PLATFORM_KEY}"

# Fetch manifest
log_info "Fetching version manifest..."
MANIFEST=$(curl -fsSL "$MANIFEST_URL" 2>/dev/null) || log_error "Failed to fetch manifest"

# Get version info
if [[ "$VERSION" == "latest" ]]; then
    VERSION=$(echo "$MANIFEST" | grep '"latest"' | grep -o '[0-9]*\.[0-9]*\.[0-9]*' | head -1)
    log_info "Latest version: $VERSION"
fi

log_info "Installing ledger v${VERSION} for ${PLATFORM_KEY}..."

# Extract URL and SHA256 from manifest (without jq dependency)
# Find the version block and extract url/sha256
VERSION_BLOCK=$(echo "$MANIFEST" | grep -A 20 "\"version\": \"${VERSION}\"" | head -20)

if [[ -z "$VERSION_BLOCK" ]]; then
    log_error "Version '$VERSION' not found in manifest"
fi

# Extract URL for our platform
DOWNLOAD_URL=$(echo "$VERSION_BLOCK" | grep -A 5 "\"${PLATFORM_KEY}\"" | grep '"url"' | head -1 | sed 's/.*"url": *"\([^"]*\)".*/\1/')
EXPECTED_SHA=$(echo "$VERSION_BLOCK" | grep -A 5 "\"${PLATFORM_KEY}\"" | grep '"sha256"' | head -1 | sed 's/.*"sha256": *"\([^"]*\)".*/\1/')

if [[ -z "$DOWNLOAD_URL" || "$DOWNLOAD_URL" == "null" ]]; then
    log_error "Platform '${PLATFORM_KEY}' not available for version $VERSION"
fi

if [[ -z "$EXPECTED_SHA" ]]; then
    log_error "No checksum found for version $VERSION"
fi

# Create temp directory
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

# Download binary
log_info "Downloading from ${DOWNLOAD_URL}..."
curl -fsSL -o "$TMP_DIR/ledger" "$DOWNLOAD_URL" || log_error "Download failed"

# Verify checksum
log_info "Verifying checksum..."
if command -v sha256sum &> /dev/null; then
    ACTUAL_SHA=$(sha256sum "$TMP_DIR/ledger" | awk '{print $1}')
else
    ACTUAL_SHA=$(shasum -a 256 "$TMP_DIR/ledger" | awk '{print $1}')
fi

if [[ "$EXPECTED_SHA" != "$ACTUAL_SHA" ]]; then
    log_error "Checksum mismatch!\n  Expected: $EXPECTED_SHA\n  Got:      $ACTUAL_SHA"
fi
log_info "Checksum verified ✓"

# CRITICAL: Clear macOS quarantine/provenance attributes
# Without this, the binary will hang on execution!
if [[ "$OS" == "Darwin" ]]; then
    log_info "Clearing macOS quarantine attributes..."
    xattr -cr "$TMP_DIR/ledger" 2>/dev/null || true
fi

# Make executable
chmod +x "$TMP_DIR/ledger"

# Create install directory if needed
mkdir -p "$INSTALL_DIR" 2>/dev/null || true

# Install
log_info "Installing to ${INSTALL_DIR}/ledger..."
if [[ -w "$INSTALL_DIR" ]]; then
    mv "$TMP_DIR/ledger" "$INSTALL_DIR/ledger"
else
    log_warn "Need sudo to install to $INSTALL_DIR"
    sudo mv "$TMP_DIR/ledger" "$INSTALL_DIR/ledger"
fi

# Verify installation
INSTALLED_BIN="${INSTALL_DIR}/ledger"
if [[ -x "$INSTALLED_BIN" ]]; then
    INSTALLED_VERSION=$("$INSTALLED_BIN" --version 2>/dev/null || echo "unknown")
    log_info "Successfully installed ledger v${INSTALLED_VERSION}"
else
    log_error "Installation failed - binary not executable"
fi

echo ""
echo "Installation complete!"
echo "  Location: $INSTALLED_BIN"
echo "  Version:  $INSTALLED_VERSION"
echo ""
echo "Quick start:"
echo "  ledger init           # Initialize in current repo"
echo "  ledger observe        # Run full analysis"  
echo "  ledger --help         # Show all commands"
echo ""

# Check if in PATH
if ! command -v ledger &> /dev/null; then
    log_warn "'ledger' not in PATH. Add this to your shell profile:"
    echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
fi
