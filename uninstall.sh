#!/bin/bash
# Uninstall Friedman-cli (frdc): removes ~/.frdc and ~/.local/bin/frdc symlink
# (and cleans up legacy ~/.friedman-cli / ~/.local/bin/friedman if present).
set -euo pipefail

for LINK in "$HOME/.local/bin/frdc" "$HOME/.local/bin/friedman"; do
    if [ -L "$LINK" ] || [ -f "$LINK" ]; then
        rm -f "$LINK"
        echo "Removed symlink: $LINK"
    fi
done

for DIR in "$HOME/.frdc" "$HOME/.friedman-cli"; do
    if [ -d "$DIR" ]; then
        rm -rf "$DIR"
        echo "Removed directory: $DIR"
    fi
done

echo "Friedman-cli (frdc) uninstalled."
