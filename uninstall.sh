#!/bin/bash
# Uninstall Friedman-cli: removes symlink and wrapper
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WRAPPER="$SCRIPT_DIR/bin/friedman-wrapper"
LINK="$HOME/.local/bin/friedman"

if [ -L "$LINK" ]; then
    rm "$LINK"
    echo "Removed symlink: $LINK"
else
    echo "No symlink found at $LINK"
fi

if [ -f "$WRAPPER" ]; then
    rm "$WRAPPER"
    echo "Removed wrapper: $WRAPPER"
else
    echo "No wrapper found at $WRAPPER"
fi

echo "Friedman-cli uninstalled."
