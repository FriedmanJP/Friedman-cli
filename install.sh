#!/bin/bash
set -euo pipefail

# Friedman-cli standalone installer for Linux (x86_64)
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/FriedmanJP/Friedman-cli/master/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/FriedmanJP/Friedman-cli/master/install.sh | bash -s -- --version 1.0.7

REPO="FriedmanJP/Friedman-cli"
INSTALL_DIR="$HOME/.frdc"
BIN_DIR="$HOME/.local/bin"

# --- Parse arguments ---
VERSION=""
while [ $# -gt 0 ]; do
    case "$1" in
        --version)
            if [ $# -lt 2 ]; then
                echo "Error: --version requires an argument" >&2
                exit 1
            fi
            VERSION="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# --- Detect platform ---
OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
    Darwin)
        cat <<'EOF'
Pre-built macOS binaries are not distributed because macOS Gatekeeper requires
Apple Developer code signing and notarization.

Run or build Friedman-cli from source on macOS (requires Julia 1.13+):
  git clone https://github.com/FriedmanJP/Friedman-cli.git
  cd Friedman-cli
  julia --project -e 'using Pkg; Pkg.instantiate()'
  julia --project bin/frdc --help

Or compile a local standalone bundle (offline, zero-Julia once built):
  julia build_release.jl
  ./build/frdc/bin/frdc --version
EOF
        exit 0
        ;;
    Linux)
        PLATFORM="linux"
        ;;
    *)
        echo "Error: Unsupported OS: $OS" >&2
        echo "Pre-built Linux binaries support Linux (x86_64). On Windows use install.ps1 or Microsoft Store." >&2
        exit 1
        ;;
esac

case "$ARCH" in
    x86_64|amd64)
        ARCH_NAME="x86_64"
        ;;
    *)
        echo "Error: Pre-built Linux binaries are available only for x86_64 (detected: $ARCH)." >&2
        echo "To run or build from source on $ARCH (requires Julia 1.13+):" >&2
        echo "  git clone https://github.com/${REPO}.git && cd Friedman-cli" >&2
        echo "  julia --project -e 'using Pkg; Pkg.instantiate()'" >&2
        echo "  julia build_release.jl" >&2
        exit 1
        ;;
esac

echo "Detected platform: ${PLATFORM}-${ARCH_NAME}"

# --- Check for curl ---
if ! command -v curl >/dev/null 2>&1; then
    echo "Error: curl is required but not found." >&2
    echo "Install it via your package manager:" >&2
    echo "  Ubuntu/Debian: sudo apt install curl" >&2
    echo "  RHEL/Fedora:   sudo yum install curl" >&2
    exit 1
fi

# --- Fetch version ---
if [ -z "$VERSION" ]; then
    echo "Fetching latest release..."
    RELEASE_JSON=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null) || {
        echo "Error: Failed to fetch latest release from GitHub API." >&2
        echo "You may be rate-limited. Try specifying a version:" >&2
        echo "  curl -fsSL https://raw.githubusercontent.com/${REPO}/master/install.sh | bash -s -- --version 1.0.7" >&2
        exit 1
    }
    VERSION=$(echo "$RELEASE_JSON" | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"v\{0,1\}\([^"]*\)".*/\1/')
    if [ -z "$VERSION" ]; then
        echo "Error: Could not parse version from GitHub API response." >&2
        exit 1
    fi
fi

echo "Installing standalone Friedman-cli v${VERSION} (zero Julia required)..."

# --- Construct download URL ---
ARCHIVE_NAME="frdc-v${VERSION}-${PLATFORM}-${ARCH_NAME}.tar.gz"
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/v${VERSION}/${ARCHIVE_NAME}"

# --- Download archive ---
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "Downloading ${ARCHIVE_NAME}..."
curl -fSL "$DOWNLOAD_URL" -o "$TMPDIR/$ARCHIVE_NAME" || {
    echo "Error: Failed to download ${DOWNLOAD_URL}" >&2
    echo "Check that version v${VERSION} exists at:" >&2
    echo "  https://github.com/${REPO}/releases" >&2
    exit 1
}

# --- Verify checksum ---
CHECKSUM_URL="https://github.com/${REPO}/releases/download/v${VERSION}/checksums.sha256"
echo "Verifying checksum..."
if curl -fsSL "$CHECKSUM_URL" -o "$TMPDIR/checksums.sha256" 2>/dev/null; then
    cd "$TMPDIR"
    grep "$ARCHIVE_NAME" checksums.sha256 > check.sha256 || true
    if [ -s check.sha256 ]; then
        if command -v sha256sum >/dev/null 2>&1; then
            sha256sum -c check.sha256 || {
                echo "Error: Checksum verification failed! The download may be corrupted." >&2
                exit 1
            }
        elif command -v shasum >/dev/null 2>&1; then
            shasum -a 256 -c check.sha256 || {
                echo "Error: Checksum verification failed! The download may be corrupted." >&2
                exit 1
            }
        else
            echo "Warning: No sha256sum or shasum found, skipping checksum verification."
        fi
    else
        echo "Warning: Archive not found in checksums file, skipping verification."
    fi
    cd - >/dev/null
else
    echo "Warning: Could not download checksums file, skipping verification."
fi

# --- Extract to temp, then safe-replace install dir ---
echo "Installing to ${INSTALL_DIR}..."
mkdir -p "$TMPDIR/extract"
tar -xzf "$TMPDIR/$ARCHIVE_NAME" -C "$TMPDIR/extract"

if [ -d "$TMPDIR/extract/frdc" ]; then
    EXTRACTED="$TMPDIR/extract/frdc"
elif [ -d "$TMPDIR/extract/friedman" ]; then
    EXTRACTED="$TMPDIR/extract/friedman"
else
    EXTRACTED="$TMPDIR/extract"
fi

rm -rf "$INSTALL_DIR"
mv "$EXTRACTED" "$INSTALL_DIR"

# --- Create PATH shim ---
mkdir -p "$BIN_DIR"
ln -sf "$INSTALL_DIR/bin/frdc" "$BIN_DIR/frdc"

# --- Verify ---
echo ""
"$INSTALL_DIR/bin/frdc" --version
echo "Friedman-cli (frdc) installed successfully!"

if [ -e "$HOME/.local/bin/friedman" ] || [ -d "$HOME/.friedman-cli" ]; then
    echo "Note: Legacy friedman installation detected (~/.friedman-cli or ~/.local/bin/friedman); run uninstall.sh or remove it manually."
fi

# --- PATH guidance ---
if ! echo "$PATH" | tr ':' '\n' | grep -qx "$BIN_DIR"; then
    echo ""
    echo "Add ${BIN_DIR} to your PATH by adding this line to your shell profile:"
    SHELL_NAME="$(basename "${SHELL:-sh}")"
    case "$SHELL_NAME" in
        zsh)  echo "  echo 'export PATH=\"${BIN_DIR}:\$PATH\"' >> ~/.zshrc" ;;
        bash) echo "  echo 'export PATH=\"${BIN_DIR}:\$PATH\"' >> ~/.bashrc" ;;
        fish) echo "  fish_add_path ${BIN_DIR}" ;;
        *)    echo "  export PATH=\"${BIN_DIR}:\$PATH\"" ;;
    esac
    echo ""
    echo "Then restart your shell or run: export PATH=\"${BIN_DIR}:\$PATH\""
fi

echo ""
echo "To uninstall: rm -rf ${INSTALL_DIR} ${BIN_DIR}/frdc"
