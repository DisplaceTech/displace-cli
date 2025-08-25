# Displace CLI

This directory contains the installation script for the Displace CLI tool. The script is designed to be hosted in the `displacetech/displace-cli` repository to provide easy installation for end users.

## Quick Install (Recommended)

### Linux/macOS (One-liner)
```bash
curl -sSL https://raw.githubusercontent.com/displacetech/displace-cli/main/install.sh | bash
```

### Windows Users
Windows is not natively supported. Please use WSL2:
```bash
wsl --install
wsl
curl -sSL https://raw.githubusercontent.com/displacetech/displace-cli/main/install.sh | bash
```

## Installation Script

### `install.sh` - Universal Installation Script

A comprehensive yet simple installation script for Linux and macOS that handles all installation scenarios:

**Core Features:**
- Automatic platform detection (Linux/macOS, amd64/arm64)
- Smart installation directory selection
- Dependency checking
- Installation verification
- Colored output with progress indicators

**Advanced Features:**
- Install specific versions
- Update existing installations
- Uninstall functionality
- Custom installation directories
- Force installation mode
- Verbose output

**Usage:**

#### Basic Installation
```bash
# Quick install (recommended)
curl -sSL https://raw.githubusercontent.com/displacetech/displace-cli/main/install.sh | bash

# Or download first, then run
wget https://raw.githubusercontent.com/displacetech/displace-cli/main/install.sh
chmod +x install.sh
./install.sh
```

#### Advanced Usage
```bash
# Install specific version
./install.sh --version v1.0.2

# Update existing installation
./install.sh --update

# Install to user directory
./install.sh --user

# Force reinstall
./install.sh --force

# Custom installation directory
./install.sh --install-dir /opt/displace

# Uninstall
./install.sh --uninstall

# Verbose output
./install.sh --verbose

# Show help
./install.sh --help
```

## Supported Platforms

| Platform | Architecture | Status | Binary Format |
|----------|-------------|---------|---------------|
| Linux | amd64 | ✅ Supported | `displace_linux_amd64.tar.gz` |
| Linux | arm64 | ✅ Supported | `displace_linux_arm64.tar.gz` |
| macOS | amd64 | ✅ Supported | `displace_darwin_amd64.zip` |
| macOS | arm64 (Apple Silicon) | ✅ Supported | `displace_darwin_arm64.zip` |
| Windows | amd64 | ⚠️ WSL2 Only | Use Linux binaries in WSL2 |

## Installation Locations

The scripts use the following installation logic:

1. **System Installation** (`/usr/local/bin`):
   - Used when running as root
   - Used when the directory is writable by current user
   - Requires `sudo` for most users

2. **User Installation** (`~/.local/bin`):
   - Used as fallback when system directory isn't writable
   - Automatically adds to PATH in shell profiles
   - No sudo required

3. **Custom Installation**:
   - Specified via `--install-dir` flag
   - User responsible for PATH management

## Dependencies

### Required
- `curl` - For downloading files
- `jq` - For parsing GitHub API responses
- `tar` - For extracting Linux archives
- `unzip` - For extracting macOS archives (usually pre-installed)

### Installation Commands

**Ubuntu/Debian:**
```bash
sudo apt update && sudo apt install -y curl jq tar unzip
```

**CentOS/RHEL/Fedora:**
```bash
sudo dnf install -y curl jq tar unzip
# or: sudo yum install -y curl jq tar unzip
```

**macOS:**
```bash
# Using Homebrew
brew install curl jq

# jq may need to be installed, tar/unzip are built-in
```

## Security Considerations

### Verification
- Scripts verify binary executability after download
- SHA256 checksums are available in releases
- All downloads use HTTPS

### Best Practices
1. **Review scripts before execution**:
   ```bash
   curl -sSL https://raw.githubusercontent.com/displacetech/displace-cli/main/install.sh | less
   ```

2. **Download and inspect locally**:
   ```bash
   wget https://raw.githubusercontent.com/displacetech/displace-cli/main/install.sh
   # Review the script
   cat install.sh
   # Run it
   bash install.sh
   ```

3. **Use specific versions** for reproducible installations:
   ```bash
   ./install.sh --version v1.0.2
   ```

## Troubleshooting

### Common Issues

1. **Permission Denied**:
   ```bash
   # Use user installation
   ./install.sh --user
   
   # Or run with sudo
   sudo ./install.sh
   ```

2. **Binary Not in PATH**:
   ```bash
   # Add to your shell profile
   echo 'export PATH="$PATH:$HOME/.local/bin"' >> ~/.bashrc
   source ~/.bashrc
   ```

3. **curl/jq Not Found**:
   ```bash
   # Install dependencies first
   sudo apt install -y curl jq  # Ubuntu/Debian
   sudo dnf install -y curl jq  # Fedora
   brew install curl jq         # macOS
   ```

4. **Download Fails**:
   - Check internet connection
   - Verify GitHub is accessible
   - Try downloading manually from releases page

5. **Architecture Not Supported**:
   - Currently supports: linux/amd64, linux/arm64, darwin/amd64, darwin/arm64
   - Windows users should use WSL2

### Getting Help

- **GitHub Issues**: https://github.com/displacetech/displace-cli/issues
- **Documentation**: https://github.com/displacetech/displace-cli
- **Discussions**: https://github.com/displacetech/displace-cli/discussions

## Examples

### Standard Installation Flow
```bash
# 1. Install latest version
curl -sSL https://raw.githubusercontent.com/displacetech/displace-cli/main/install.sh | bash

# 2. Verify installation
displace version

# 3. Check for updates
displace update --check-only

# 4. Enable auto-updates
displace update --enable-auto
```

### Advanced Installation Flow
```bash
# 1. Download installer
wget https://raw.githubusercontent.com/displacetech/displace-cli/main/install.sh
chmod +x install.sh

# 2. Install specific version to custom location
./install.sh --version v1.0.2 --install-dir /opt/displace

# 3. Later, update to latest
./install.sh --update

# 4. If needed, uninstall
./install.sh --uninstall
```

### Corporate/Scripted Installation
```bash
#!/bin/bash
# Corporate deployment script

# Set specific version for consistency
VERSION="v1.0.2"
INSTALL_DIR="/opt/displace"

# Download installer
curl -sSfL https://raw.githubusercontent.com/displacetech/displace-cli/main/install.sh -o /tmp/install-displace.sh
chmod +x /tmp/install-displace.sh

# Install specific version
/tmp/install-displace.sh --version "$VERSION" --install-dir "$INSTALL_DIR" --force

# Verify installation
"$INSTALL_DIR/displace" version

# Cleanup
rm /tmp/install-displace.sh
```

## Development

These scripts are designed to be:
- **Self-contained**: Minimal dependencies
- **Robust**: Handle various error conditions
- **User-friendly**: Clear output and error messages
- **Flexible**: Support different installation scenarios
- **Secure**: Verify downloads and permissions

When modifying these scripts, ensure they remain compatible with the supported platforms and maintain the security practices outlined above.
