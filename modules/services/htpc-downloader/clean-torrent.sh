#!/usr/bin/env bash
set -euo pipefail

# Transmission passes these environment variables automatically:
# TR_TORRENT_DIR: The directory where data was downloaded (e.g. .../Pluto/Season 01)
# TR_TORRENT_NAME: The name of the torrent (e.g. [Group] Pluto Batch)

TARGET_DIR="$TR_TORRENT_DIR"
SUB_DIR="$TARGET_DIR/$TR_TORRENT_NAME"

echo "🧹 Cleanup started for: $TR_TORRENT_NAME"

# Check if the torrent created a subdirectory
if [[ -d "$SUB_DIR" ]]; then
    echo "📂 Detected nested folder: $SUB_DIR"
    echo "⬆️  Moving files up to: $TARGET_DIR"
    
    # Move everything from inside the sub-folder to the target folder
    # shopt -s dotglob ensures we catch hidden files too
    shopt -s dotglob
    mv -n "$SUB_DIR"/* "$TARGET_DIR/"
    shopt -u dotglob
    
    # Remove the now-empty subdirectory
    rmdir "$SUB_DIR"
    echo "✅ Flattening complete."
else
    echo "👍 Torrent is already flat (single file or direct download)."
fi