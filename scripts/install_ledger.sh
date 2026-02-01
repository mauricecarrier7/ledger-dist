#!/usr/bin/env bash
#
# install_ledger.sh - Install CodeAtlas ledger CLI with SHA256 verification
#
# Usage:
#   ./install_ledger.sh --version 0.1.0 [--platform macos-arm64] [--install-dir ./tools/bin]
#
# Environment variables:
#   LEDGER_VERSION    - Version to install (overrides --version)
#   LEDGER_PLATFORM   - Platform (overrides --platform)
#   LEDGER_INSTALL_DIR - Installation directory (overrides --install-dir)
#
# Exit codes:
#   0 - Success
#   1 - General error
#   2 - Version not found
#   3 - Checksum verification failed
#   4 - Download failed
#   5 - Missing dependencies

set -euo pipefail

# Configuration
DIST_REPO="mauricecarrier7/ledger-dist"
MANIFEST_URL="https://raw.githubusercontent.com/${DIST_REPO}/main/versions.json"
DEFAULT_INSTALL_DIR="./tools/bin"

# Colors (disabled in CI)
if [[ -t 1 ]] && [[ -z "${CI:-}" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

die() {
    log_error "$1"
    exit "${2:-1}"
}

# Check dependencies
check_dependencies() {
    local missing=()

    command -v curl >/dev/null 2>&1 || missing+=("curl")
    command -v shasum >/dev/null 2>&1 || command -v sha256sum >/dev/null 2>&1 || missing+=("shasum or sha256sum")
    command -v jq >/dev/null 2>&1 || missing+=("jq")

    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Missing required dependencies: ${missing[*]}" 5
    fi
}

# Detect platform
detect_platform() {
    local os arch
    os="$(uname -s | tr '[:upper:]' '[:lower:]')"
    arch="$(uname -m)"

    case "$os" in
        darwin) os="macos" ;;
        linux) os="linux" ;;
        *) die "Unsupported operating system: $os" 1 ;;
    esac

    case "$arch" in
        arm64|aarch64) arch="arm64" ;;
        x86_64|amd64) arch="x64" ;;
        *) die "Unsupported architecture: $arch" 1 ;;
    esac

    echo "${os}-${arch}"
}

# Compute SHA256
compute_sha256() {
    local file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{print $1}'
    else
        shasum -a 256 "$file" | awk '{print $1}'
    fi
}

# Fetch manifest
fetch_manifest() {
    local manifest
    log_info "Fetching version manifest from ${MANIFEST_URL}..."

    manifest=$(curl -fsSL "$MANIFEST_URL" 2>/dev/null) || \
        die "Failed to fetch manifest from ${MANIFEST_URL}" 4

    echo "$manifest"
}

# Get version info from manifest
get_version_info() {
    local manifest="$1"
    local version="$2"
    local platform="$3"

    local version_entry
    version_entry=$(echo "$manifest" | jq -r --arg v "$version" '.versions[] | select(.version == $v)')

    if [[ -z "$version_entry" || "$version_entry" == "null" ]]; then
        log_error "Version '$version' not found in manifest"
        log_info "Available versions:"
        echo "$manifest" | jq -r '.versions[].version' | sed 's/^/  - /'
        exit 2
    fi

    local artifact_info
    artifact_info=$(echo "$version_entry" | jq -r --arg p "$platform" '.artifacts[$p]')

    if [[ -z "$artifact_info" || "$artifact_info" == "null" ]]; then
        log_error "Platform '$platform' not found for version '$version'"
        log_info "Available platforms for $version:"
        echo "$version_entry" | jq -r '.artifacts | keys[]' | sed 's/^/  - /'
        exit 2
    fi

    echo "$artifact_info"
}

# Download and verify binary
download_and_verify() {
    local url="$1"
    local expected_sha256="$2"
    local output_file="$3"

    local temp_file
    temp_file=$(mktemp)
    trap "rm -f '$temp_file'" EXIT

    log_info "Downloading from ${url}..."
    curl -fsSL -o "$temp_file" "$url" || die "Download failed" 4

    log_info "Verifying SHA256 checksum..."
    local actual_sha256
    actual_sha256=$(compute_sha256 "$temp_file")

    if [[ "$actual_sha256" != "$expected_sha256" ]]; then
        log_error "Checksum verification FAILED!"
        log_error "  Expected: $expected_sha256"
        log_error "  Actual:   $actual_sha256"
        die "Binary integrity check failed. Aborting installation." 3
    fi

    log_success "Checksum verified: $actual_sha256"

    # Move to final location
    mv "$temp_file" "$output_file"
    chmod +x "$output_file"
    trap - EXIT
}

# Print usage
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Install CodeAtlas ledger CLI with SHA256 verification.

Options:
  --version VERSION      Version to install (required, or set LEDGER_VERSION)
  --platform PLATFORM    Target platform (default: auto-detect)
                         Supported: macos-arm64, macos-x64
  --install-dir DIR      Installation directory (default: $DEFAULT_INSTALL_DIR)
  --manifest-url URL     Custom manifest URL (for testing)
  --help                 Show this help message

Environment Variables:
  LEDGER_VERSION         Override --version
  LEDGER_PLATFORM        Override --platform
  LEDGER_INSTALL_DIR     Override --install-dir

Examples:
  # Install specific version
  ./install_ledger.sh --version 0.1.0

  # Install to custom directory
  ./install_ledger.sh --version 0.1.0 --install-dir /usr/local/bin

  # Use environment variables
  LEDGER_VERSION=0.1.0 ./install_ledger.sh

Exit Codes:
  0 - Success
  1 - General error
  2 - Version not found
  3 - Checksum verification failed
  4 - Download failed
  5 - Missing dependencies
EOF
}

# Main
main() {
    local version="${LEDGER_VERSION:-}"
    local platform="${LEDGER_PLATFORM:-}"
    local install_dir="${LEDGER_INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"
    local manifest_url="$MANIFEST_URL"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --version)
                version="$2"
                shift 2
                ;;
            --platform)
                platform="$2"
                shift 2
                ;;
            --install-dir)
                install_dir="$2"
                shift 2
                ;;
            --manifest-url)
                manifest_url="$2"
                shift 2
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                die "Unknown option: $1. Use --help for usage." 1
                ;;
        esac
    done

    # Validate version
    if [[ -z "$version" ]]; then
        die "Version is required. Use --version or set LEDGER_VERSION." 1
    fi

    # Check dependencies
    check_dependencies

    # Auto-detect platform if not specified
    if [[ -z "$platform" ]]; then
        platform=$(detect_platform)
        log_info "Detected platform: $platform"
    fi

    # Create install directory
    mkdir -p "$install_dir"

    # Fetch manifest
    MANIFEST_URL="$manifest_url"
    local manifest
    manifest=$(fetch_manifest)

    # Get version info
    log_info "Looking up version $version for platform $platform..."
    local artifact_info
    artifact_info=$(get_version_info "$manifest" "$version" "$platform")

    local url sha256
    url=$(echo "$artifact_info" | jq -r '.url')
    sha256=$(echo "$artifact_info" | jq -r '.sha256')

    if [[ "$sha256" == PLACEHOLDER_* ]]; then
        die "Version $version has not been released yet (placeholder checksum)" 2
    fi

    # Download and verify
    local output_file="${install_dir}/ledger"
    download_and_verify "$url" "$sha256" "$output_file"

    # Verify installation
    log_info "Verifying installation..."
    local installed_version
    installed_version=$("$output_file" --version 2>/dev/null | head -1) || \
        die "Failed to verify installed binary" 1

    log_success "Ledger CLI installed successfully!"
    echo ""
    echo "Installation details:"
    echo "  Version:  $version"
    echo "  Platform: $platform"
    echo "  Location: $(realpath "$output_file")"
    echo "  Binary:   $installed_version"
    echo ""
    echo "Sanity check:"
    "$output_file" --help | head -5
}

main "$@"
