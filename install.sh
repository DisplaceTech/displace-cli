#!/bin/bash

# Displace CLI Installer
# This script downloads and installs the latest version of displace CLI
# Usage: curl -sSL https://raw.githubusercontent.com/displacetech/displace-cli/main/install.sh | bash

set -euo pipefail

# Configuration
REPO="displacetech/displace-cli"
GITHUB_API="https://api.github.com"
BINARY_NAME="displace"
DEFAULT_INSTALL_DIR="/usr/local/bin"
USER_INSTALL_DIR="$HOME/.local/bin"
TEMP_DIR="/tmp/displace-install"

# Script options
INSTALL_VERSION=""
UPDATE_MODE=false
UNINSTALL_MODE=false
FORCE_INSTALL=false
INSTALL_DIR=""
VERBOSE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

fatal() {
    error "$1"
    exit 1
}

# Show usage information
show_usage() {
    echo "Displace CLI Installer"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --version VERSION     Install specific version (e.g., v2025.08.abc123)"
    echo "  --update             Update existing installation to latest version"
    echo "  --uninstall          Remove displace installation"
    echo "  --force              Force installation (overwrite existing)"
    echo "  --install-dir DIR    Custom installation directory"
    echo "  --user               Install to user directory (~/.local/bin)"
    echo "  --verbose            Enable verbose output"
    echo "  --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Install latest version"
    echo "  $0 --version v2025.08.abc123         # Install specific version"
    echo "  $0 --update                          # Update to latest"
    echo "  $0 --user --force                    # Force install to user directory"
    echo "  $0 --uninstall                       # Remove installation"
    echo ""
    echo "Quick install (no download):"
    echo "  curl -sSL https://raw.githubusercontent.com/displacetech/displace-cli/main/install.sh | bash"
    echo ""
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --version)
                INSTALL_VERSION="$2"
                shift 2
                ;;
            --update)
                UPDATE_MODE=true
                shift
                ;;
            --uninstall)
                UNINSTALL_MODE=true
                shift
                ;;
            --force)
                FORCE_INSTALL=true
                shift
                ;;
            --install-dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            --user)
                INSTALL_DIR="$USER_INSTALL_DIR"
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                fatal "Unknown option: $1\nUse --help for usage information"
                ;;
        esac
    done
}

debug() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# Detect current installation
detect_installation() {
    debug "Detecting existing installation..."
    
    CURRENT_INSTALL_PATH=""
    CURRENT_VERSION=""
    
    # Check if binary is in PATH
    if command -v "$BINARY_NAME" >/dev/null 2>&1; then
        CURRENT_INSTALL_PATH=$(command -v "$BINARY_NAME")
        debug "Found existing installation: $CURRENT_INSTALL_PATH"
        
        # Get current version
        if CURRENT_VERSION=$($BINARY_NAME version 2>/dev/null | grep -o 'Version: [^[:space:]]*' | cut -d' ' -f2); then
            debug "Current version: $CURRENT_VERSION"
        else
            warn "Could not determine current version"
        fi
    else
        debug "No existing installation found in PATH"
    fi
}

# Determine installation directory
determine_install_dir() {
    if [[ -n "$INSTALL_DIR" ]]; then
        debug "Using specified install directory: $INSTALL_DIR"
        return
    fi
    
    # If updating and we found an existing installation, use that location
    if [[ "$UPDATE_MODE" == true ]] && [[ -n "$CURRENT_INSTALL_PATH" ]]; then
        INSTALL_DIR=$(dirname "$CURRENT_INSTALL_PATH")
        debug "Using existing install directory for update: $INSTALL_DIR"
        return
    fi
    
    # Default logic
    if [[ $EUID -eq 0 ]]; then
        INSTALL_DIR="$DEFAULT_INSTALL_DIR"
        debug "Running as root, using system directory: $INSTALL_DIR"
    elif [[ -w "$DEFAULT_INSTALL_DIR" ]]; then
        INSTALL_DIR="$DEFAULT_INSTALL_DIR"
        debug "System directory is writable: $INSTALL_DIR"
    else
        INSTALL_DIR="$USER_INSTALL_DIR"
        debug "Using user directory: $INSTALL_DIR"
        
        # Ensure user bin directory exists and is in PATH
        mkdir -p "$INSTALL_DIR"
        if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
            warn "Directory $INSTALL_DIR is not in PATH"
            warn "Consider adding this to your shell profile:"
            echo "  export PATH=\"\$PATH:$INSTALL_DIR\""
        fi
    fi
}

# Detect operating system and architecture
detect_platform() {
    local os arch
    
    # Detect OS
    case "$(uname -s)" in
        Linux*)  os="linux" ;;
        Darwin*) os="darwin" ;;
        *)       fatal "Unsupported operating system: $(uname -s)" ;;
    esac
    
    # Detect architecture
    case "$(uname -m)" in
        x86_64|amd64) arch="amd64" ;;
        arm64|aarch64) arch="arm64" ;;
        *) fatal "Unsupported architecture: $(uname -m)" ;;
    esac
    
    PLATFORM_OS="$os"
    PLATFORM_ARCH="$arch"
    
    log "Detected platform: ${PLATFORM_OS}/${PLATFORM_ARCH}"
}

# Check for required dependencies
check_dependencies() {
    local deps=("curl" "jq" "tar")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        fatal "Missing required dependencies: ${missing[*]}\nPlease install them and try again."
    fi
}

# Get release information from GitHub API
get_release_info() {
    local version="$1"
    local api_url
    
    if [[ "$version" == "latest" ]]; then
        api_url="${GITHUB_API}/repos/${REPO}/releases/latest"
        log "Fetching latest release information..."
    else
        api_url="${GITHUB_API}/repos/${REPO}/releases/tags/${version}"
        log "Fetching release information for version $version..."
    fi
    
    local release_info
    if ! release_info=$(curl -sSf "$api_url"); then
        if [[ "$version" == "latest" ]]; then
            fatal "Failed to fetch latest release information from GitHub API"
        else
            fatal "Version $version not found. Check available versions at: https://github.com/${REPO}/releases"
        fi
    fi
    
    # Extract release information
    RELEASE_VERSION=$(echo "$release_info" | jq -r '.tag_name // empty')
    RELEASE_NAME=$(echo "$release_info" | jq -r '.name // empty')
    RELEASE_BODY=$(echo "$release_info" | jq -r '.body // empty')
    
    if [[ -z "$RELEASE_VERSION" ]]; then
        fatal "No release information found"
    fi
    
    debug "Release version: $RELEASE_VERSION"
    debug "Release name: $RELEASE_NAME"
    
    # Determine asset name based on platform
    local asset_name
    if [[ "$PLATFORM_OS" == "linux" ]]; then
        asset_name="${BINARY_NAME}_${PLATFORM_OS}_${PLATFORM_ARCH}.tar.gz"
    else
        asset_name="${BINARY_NAME}_${PLATFORM_OS}_${PLATFORM_ARCH}.zip"
    fi
    
    # Find download URL for our platform
    DOWNLOAD_URL=$(echo "$release_info" | jq -r ".assets[] | select(.name == \"$asset_name\") | .browser_download_url")
    
    if [[ -z "$DOWNLOAD_URL" ]]; then
        fatal "No binary found for platform ${PLATFORM_OS}/${PLATFORM_ARCH} in release $RELEASE_VERSION"
    fi
    
    debug "Download URL: $DOWNLOAD_URL"
}

# Compare versions to check if update is needed
version_compare() {
    local current="$1"
    local target="$2"
    
    # Remove 'v' prefix if present
    current=${current#v}
    target=${target#v}
    
    if [[ "$current" == "$target" ]]; then
        return 1  # Same version
    fi
    
    # For CalVer, we can do a simple string comparison after normalization
    # since YYYY.MM.PATCH format sorts lexicographically
    if [[ "$current" < "$target" ]]; then
        return 0  # Current is older
    else
        return 1  # Current is newer or same
    fi
}

# Download and extract the binary
download_binary() {
    log "Creating temporary directory..."
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"
    
    local archive_name="displace-archive"
    local archive_path="${TEMP_DIR}/${archive_name}"
    
    log "Downloading ${BINARY_NAME} ${LATEST_VERSION}..."
    if ! curl -sSfL "$DOWNLOAD_URL" -o "$archive_path"; then
        fatal "Failed to download binary"
    fi
    
    log "Extracting binary..."
    cd "$TEMP_DIR"
    
    if [[ "$DOWNLOAD_URL" == *.tar.gz ]]; then
        if ! tar -xzf "$archive_name"; then
            fatal "Failed to extract tar.gz archive"
        fi
    elif [[ "$DOWNLOAD_URL" == *.zip ]]; then
        if ! command -v unzip >/dev/null 2>&1; then
            fatal "unzip is required to extract .zip files"
        fi
        if ! unzip -q "$archive_name"; then
            fatal "Failed to extract zip archive"
        fi
    else
        fatal "Unsupported archive format"
    fi
    
    # Find the extracted binary
    if [[ ! -f "$BINARY_NAME" ]]; then
        fatal "Binary '$BINARY_NAME' not found in archive"
    fi
    
    # Make it executable
    chmod +x "$BINARY_NAME"
    
    log "Binary extracted successfully"
}

# Verify the downloaded binary
verify_binary() {
    log "Verifying binary..."
    
    if [[ ! -x "${TEMP_DIR}/${BINARY_NAME}" ]]; then
        fatal "Downloaded binary is not executable"
    fi
    
    # Test that the binary runs
    if ! "${TEMP_DIR}/${BINARY_NAME}" version >/dev/null 2>&1; then
        warn "Binary verification failed - the binary may not be compatible with your system"
        warn "Proceeding anyway..."
    else
        success "Binary verification passed"
    fi
}

# Install the binary
install_binary() {
    local target_path="${INSTALL_DIR}/${BINARY_NAME}"
    
    # Check if target already exists
    if [[ -f "$target_path" ]] && [[ "$FORCE_INSTALL" == false ]]; then
        if [[ "$UPDATE_MODE" == false ]]; then
            fatal "Binary already exists at $target_path\nUse --force to overwrite or --update to upgrade"
        fi
    fi
    
    log "Installing ${BINARY_NAME} to ${target_path}..."
    
    # Create install directory if it doesn't exist
    if [[ ! -w "$(dirname "$target_path")" ]]; then
        if command -v sudo >/dev/null 2>&1; then
            sudo mkdir -p "$INSTALL_DIR"
            sudo cp "${TEMP_DIR}/${BINARY_NAME}" "$target_path"
            sudo chmod +x "$target_path"
        else
            fatal "No write permission to $INSTALL_DIR and sudo not available"
        fi
    else
        mkdir -p "$INSTALL_DIR"
        cp "${TEMP_DIR}/${BINARY_NAME}" "$target_path"
        chmod +x "$target_path"
    fi
    
    success "Installed ${BINARY_NAME} to ${target_path}"
}

# Uninstall existing installation
uninstall() {
    log "Starting uninstallation..."
    
    if [[ -z "$CURRENT_INSTALL_PATH" ]]; then
        warn "No existing installation found in PATH"
        return 0
    fi
    
    local install_dir
    install_dir=$(dirname "$CURRENT_INSTALL_PATH")
    
    log "Removing $CURRENT_INSTALL_PATH..."
    
    if [[ ! -w "$install_dir" ]]; then
        if command -v sudo >/dev/null 2>&1; then
            sudo rm -f "$CURRENT_INSTALL_PATH"
        else
            fatal "No write permission to remove $CURRENT_INSTALL_PATH and sudo not available"
        fi
    else
        rm -f "$CURRENT_INSTALL_PATH"
    fi
    
    success "Uninstalled $BINARY_NAME from $CURRENT_INSTALL_PATH"
    
    # Clean up user configuration (optional)
    local config_dir="$HOME/.displace"
    if [[ -d "$config_dir" ]]; then
        echo ""
        read -p "Remove configuration directory $config_dir? [y/N]: " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$config_dir"
            success "Removed configuration directory"
        else
            log "Configuration directory preserved"
        fi
    fi
}

# Final verification
final_verification() {
    log "Performing final verification..."
    
    # Check if binary is in PATH
    if command -v "$BINARY_NAME" >/dev/null 2>&1; then
        local installed_version
        installed_version=$($BINARY_NAME version 2>/dev/null | grep -o 'Version:.*' | head -1 || echo "unknown")
        success "Installation successful! $installed_version"
        
        # Show basic usage
        echo ""
        log "Quick start:"
        echo "  $BINARY_NAME --help        # Show help"
        echo "  $BINARY_NAME version       # Show version info"
        echo "  $BINARY_NAME update        # Check for updates"
        
    else
        warn "Binary installed but not found in PATH"
        warn "You may need to restart your shell or run:"
        echo "  export PATH=\"\$PATH:$INSTALL_DIR\""
    fi
}

# Cleanup temporary files
cleanup() {
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

# Show installation summary
show_summary() {
    echo ""
    echo "======================================"
    if [[ "$UPDATE_MODE" == true ]]; then
        success "Displace CLI Update Complete!"
        if [[ -n "$CURRENT_VERSION" ]]; then
            echo "Updated from: $CURRENT_VERSION"
        fi
    else
        success "Displace CLI Installation Complete!"
    fi
    echo "======================================"
    echo "Version: $RELEASE_VERSION"
    echo "Install Path: ${INSTALL_DIR}/${BINARY_NAME}"
    echo ""
    echo "Quick start:"
    echo "  $BINARY_NAME --help        # Show help"
    echo "  $BINARY_NAME version       # Show version info"
    echo "  $BINARY_NAME update        # Check for updates"
    echo ""
    echo "Documentation: https://github.com/${REPO}"
    echo "Report Issues: https://github.com/${REPO}/issues"
    echo ""
}

# Handle script interruption
trap cleanup EXIT INT TERM

# Main installation flow
main() {
    parse_args "$@"
    
    echo ""
    echo "======================================"
    log "Displace CLI Installer"
    echo "======================================"
    echo ""
    
    # Handle uninstall mode
    if [[ "$UNINSTALL_MODE" == true ]]; then
        detect_installation
        uninstall
        return 0
    fi
    
    detect_platform
    check_dependencies
    detect_installation
    determine_install_dir
    
    # Determine version to install
    local target_version="${INSTALL_VERSION:-latest}"
    
    # Handle update mode
    if [[ "$UPDATE_MODE" == true ]]; then
        if [[ -z "$CURRENT_VERSION" ]]; then
            fatal "No existing installation found to update"
        fi
        
        log "Current version: $CURRENT_VERSION"
        
        # Get latest version info
        get_release_info "latest"
        
        # Check if update is needed
        if ! version_compare "$CURRENT_VERSION" "$RELEASE_VERSION"; then
            log "Already running the latest version ($CURRENT_VERSION)"
            return 0
        fi
        
        log "Update available: $CURRENT_VERSION → $RELEASE_VERSION"
    else
        get_release_info "$target_version"
        
        # Check if same version is already installed
        if [[ -n "$CURRENT_VERSION" ]] && [[ "$CURRENT_VERSION" == "$RELEASE_VERSION" ]] && [[ "$FORCE_INSTALL" == false ]]; then
            log "Version $RELEASE_VERSION is already installed"
            log "Use --force to reinstall or --update to check for newer versions"
            return 0
        fi
    fi
    
    download_binary
    verify_binary
    install_binary
    final_verification
    show_summary
}

# Run main function
main "$@"
