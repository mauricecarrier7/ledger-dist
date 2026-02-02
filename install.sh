#!/bin/bash
# CodeAtlas Ledger Install Script (with bundled QAAtlas)
# 
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/mauricecarrier7/ledger-dist/main/install.sh | bash
#   curl -fsSL .../install.sh | bash -s -- --version 0.9.1
#   curl -fsSL .../install.sh | bash -s -- --dir ./tools/bin
#   curl -fsSL .../install.sh | bash -s -- --ledger-only  # Skip QAAtlas

set -e

# Defaults
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
VERSION="${VERSION:-latest}"
REPO="mauricecarrier7/ledger-dist"
MANIFEST_URL="https://raw.githubusercontent.com/${REPO}/main/versions.json"
SKIP_QAATLAS=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}▸${NC} $1"; }
log_warn() { echo -e "${YELLOW}▸${NC} $1"; }
log_error() { echo -e "${RED}▸${NC} $1"; exit 1; }
log_step() { echo -e "${BLUE}▸${NC} $1"; }

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --version|-v) VERSION="$2"; shift 2 ;;
        --dir|-d) INSTALL_DIR="$2"; shift 2 ;;
        --ledger-only) SKIP_QAATLAS=true; shift ;;
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

echo ""
echo "╔═══════════════════════════════════════════════════════╗"
echo "║   CodeAtlas Ledger + QAAtlas Installer                ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""

# Fetch manifest
log_step "Fetching version manifest..."
MANIFEST=$(curl -fsSL "$MANIFEST_URL" 2>/dev/null) || log_error "Failed to fetch manifest"

# Get version info
if [[ "$VERSION" == "latest" ]]; then
    VERSION=$(echo "$MANIFEST" | grep '"latest"' | grep -o '[0-9]*\.[0-9]*\.[0-9]*' | head -1)
fi

log_info "Version: $VERSION"
log_info "Platform: ${PLATFORM_KEY}"
log_info "Install directory: ${INSTALL_DIR}"
echo ""

# Extract version block from manifest
VERSION_BLOCK=$(echo "$MANIFEST" | grep -A 30 "\"version\": \"${VERSION}\"" | head -30)

if [[ -z "$VERSION_BLOCK" ]]; then
    log_error "Version '$VERSION' not found in manifest"
fi

# Create install directory if needed
mkdir -p "$INSTALL_DIR" 2>/dev/null || true

# Create temp directory
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

#############################################
# Install Ledger
#############################################
echo "┌─────────────────────────────────────────────────────────┐"
echo "│ Installing Ledger CLI                                   │"
echo "└─────────────────────────────────────────────────────────┘"

# Extract URL and SHA256 for ledger
LEDGER_URL=$(echo "$VERSION_BLOCK" | grep -A 5 "\"${PLATFORM_KEY}\"" | grep '"url"' | head -1 | sed 's/.*"url": *"\([^"]*\)".*/\1/')
LEDGER_SHA=$(echo "$VERSION_BLOCK" | grep -A 5 "\"${PLATFORM_KEY}\"" | grep '"sha256"' | head -1 | sed 's/.*"sha256": *"\([^"]*\)".*/\1/')

if [[ -z "$LEDGER_URL" || "$LEDGER_URL" == "null" ]]; then
    log_error "Platform '${PLATFORM_KEY}' not available for version $VERSION"
fi

log_info "Downloading ledger..."
curl -fsSL -o "$TMP_DIR/ledger" "$LEDGER_URL" || log_error "Ledger download failed"

# Verify checksum
log_info "Verifying checksum..."
if command -v sha256sum &> /dev/null; then
    ACTUAL_SHA=$(sha256sum "$TMP_DIR/ledger" | awk '{print $1}')
else
    ACTUAL_SHA=$(shasum -a 256 "$TMP_DIR/ledger" | awk '{print $1}')
fi

if [[ -n "$LEDGER_SHA" && "$LEDGER_SHA" != "$ACTUAL_SHA" ]]; then
    log_error "Checksum mismatch!\n  Expected: $LEDGER_SHA\n  Got:      $ACTUAL_SHA"
fi
log_info "Checksum verified ✓"

# Clear macOS quarantine
if [[ "$OS" == "Darwin" ]]; then
    xattr -cr "$TMP_DIR/ledger" 2>/dev/null || true
fi

chmod +x "$TMP_DIR/ledger"

# Install ledger
if [[ -w "$INSTALL_DIR" ]]; then
    mv "$TMP_DIR/ledger" "$INSTALL_DIR/ledger"
else
    log_warn "Need sudo to install to $INSTALL_DIR"
    sudo mv "$TMP_DIR/ledger" "$INSTALL_DIR/ledger"
fi

LEDGER_VERSION=$("$INSTALL_DIR/ledger" --version 2>/dev/null || echo "unknown")
log_info "Ledger v${LEDGER_VERSION} installed ✓"
echo ""

#############################################
# Install QAAtlas (bundled binary)
#############################################
if [[ "$SKIP_QAATLAS" == "false" ]]; then
    echo "┌─────────────────────────────────────────────────────────┐"
    echo "│ Installing QAAtlas (bundled)                            │"
    echo "└─────────────────────────────────────────────────────────┘"

    # QAAtlas URL - check if included in version manifest first, else use default
    QAATLAS_URL=$(echo "$VERSION_BLOCK" | grep -A 5 '"qaatlas"' | grep '"url"' | head -1 | sed 's/.*"url": *"\([^"]*\)".*/\1/')
    QAATLAS_SHA=$(echo "$VERSION_BLOCK" | grep -A 5 '"qaatlas"' | grep '"sha256"' | head -1 | sed 's/.*"sha256": *"\([^"]*\)".*/\1/')

    # Fallback to release URL if not in manifest
    if [[ -z "$QAATLAS_URL" || "$QAATLAS_URL" == "null" ]]; then
        QAATLAS_URL="https://github.com/mauricecarrier7/ledger-dist/releases/download/v${VERSION}/qaatlas-${PLATFORM}-${ARCH}"
    fi

    log_info "Downloading QAAtlas..."
    if curl -fsSL -o "$TMP_DIR/qaatlas" "$QAATLAS_URL" 2>/dev/null; then
        # Verify checksum if available
        if [[ -n "$QAATLAS_SHA" && "$QAATLAS_SHA" != "null" ]]; then
            if command -v sha256sum &> /dev/null; then
                ACTUAL_QA_SHA=$(sha256sum "$TMP_DIR/qaatlas" | awk '{print $1}')
            else
                ACTUAL_QA_SHA=$(shasum -a 256 "$TMP_DIR/qaatlas" | awk '{print $1}')
            fi
            
            if [[ "$QAATLAS_SHA" != "$ACTUAL_QA_SHA" ]]; then
                log_warn "QAAtlas checksum mismatch, proceeding anyway..."
            else
                log_info "Checksum verified ✓"
            fi
        fi

        # Clear macOS quarantine
        if [[ "$OS" == "Darwin" ]]; then
            xattr -cr "$TMP_DIR/qaatlas" 2>/dev/null || true
        fi

        chmod +x "$TMP_DIR/qaatlas"

        # Install qaatlas
        if [[ -w "$INSTALL_DIR" ]]; then
            mv "$TMP_DIR/qaatlas" "$INSTALL_DIR/qaatlas"
        else
            sudo mv "$TMP_DIR/qaatlas" "$INSTALL_DIR/qaatlas"
        fi

        QAATLAS_VERSION=$("$INSTALL_DIR/qaatlas" --version 2>/dev/null || echo "unknown")
        log_info "QAAtlas v${QAATLAS_VERSION} installed ✓"
    else
        log_warn "QAAtlas binary not available for this release"
        log_warn "QA analysis will use npx fallback (requires Node.js)"
    fi
    echo ""
fi

#############################################
# Summary
#############################################
echo "╔═══════════════════════════════════════════════════════╗"
echo "║   Installation Complete!                              ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""
echo "  Installed binaries:"
echo "    ledger:   ${INSTALL_DIR}/ledger (v${LEDGER_VERSION})"
if [[ -x "${INSTALL_DIR}/qaatlas" ]]; then
    echo "    qaatlas:  ${INSTALL_DIR}/qaatlas (v${QAATLAS_VERSION})"
fi
echo ""
echo "  Quick start:"
echo "    ledger init           # Initialize in current repo"
echo "    ledger observe        # Run full analysis (arch, reach, a11y, qa)"  
echo "    ledger --help         # Show all commands"
echo ""

# Check if in PATH
if ! command -v ledger &> /dev/null; then
    log_warn "'ledger' not in PATH. Add this to your shell profile:"
    echo "    export PATH=\"$INSTALL_DIR:\$PATH\""
fi
