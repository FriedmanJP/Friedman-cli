#!/bin/bash
# Uninstall Friedman-cli: removes ~/.friedman-cli and ~/.local/bin/friedman symlink
set -euo pipefail

INSTALL_DIR="$HOME/.friedman-cli"
LINK="$HOME/.local/bin/friedman"

if [ -L "$LINK" ] || [ -f "$LINK" ]; then
    rm -f "$LINK"
    echo "Removed symlink: $LINK"
else
    echo "No symlink found at $LINK"
fi

if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    echo "Removed directory: $INSTALL_DIR"
else
    echo "No install directory found at $INSTALL_DIR"
fi

echo "Friedman-cli uninstalled."
