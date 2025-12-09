#!/usr/bin/env bash
set -euo pipefail

# Usage: htpc-downloader type "Series Name" ["Season Name/Number"] "MagnetLink"
# Examples:
#   htpc-downloader tv "Pluto" "Season 01" "magnet:?..."
#   htpc-downloader tv "Pluto" "1" "magnet:?..."  # Auto-formats to Season 01
#   htpc-downloader tv "Pluto" "Special" "magnet:?..."
#   htpc-downloader movie "Inception" "magnet:?..."

show_usage() {
    cat <<EOF
Usage: htpc-downloader <type> <name> [season] <magnet>

Types:
  tv      - TV show (requires season)
  movie   - Movie (no season)

Examples:
  htpc-downloader tv "Pluto" "1" "magnet:?..."
  htpc-downloader tv "Attack on Titan" "Season 02" "magnet:?..."
  htpc-downloader tv "Pluto" "Specials" "magnet:?..."
  htpc-downloader movie "Inception" "magnet:?..."

Notes:
  - Season numbers are auto-formatted (1 → Season 01)
  - Custom season names work too (Specials, OVA, etc.)
  - HTPC_ROOT is injected by NixOS: $HTPC_ROOT
EOF
}

# Parse arguments based on type
TYPE=$1
NAME=$2

if [[ "$TYPE" == "tv" ]]; then
    if [[ $# -lt 4 ]]; then
        echo "Error: TV shows require: type name season magnet"
        show_usage
        exit 1
    fi
    SEASON=$3
    MAGNET=$4
elif [[ "$TYPE" == "movie" ]]; then
    if [[ $# -lt 3 ]]; then
        echo "Error: Movies require: type name magnet"
        show_usage
        exit 1
    fi
    MAGNET=$3
else
    echo "Error: Type must be 'tv' or 'movie'"
    show_usage
    exit 1
fi

# Normalize season name (1 → Season 01, 12 → Season 12, "Special" → Special)
normalize_season() {
    local season=$1
    
    # If it's just a number, format it
    if [[ "$season" =~ ^[0-9]+$ ]]; then
        printf "Season %02d" "$season"
    # If it already starts with "Season", keep it
    elif [[ "$season" =~ ^[Ss]eason ]]; then
        echo "$season"
    # Otherwise, assume it's a special name (Specials, OVA, etc.)
    else
        echo "$season"
    fi
}

# Determine target directory
if [[ "$TYPE" == "tv" ]]; then
    NORMALIZED_SEASON=$(normalize_season "$SEASON")
    TARGET_DIR="$HTPC_ROOT/htpc/tv_shows/$NAME/$NORMALIZED_SEASON"
    echo "📺 TV Show: $NAME"
    echo "📁 Season: $NORMALIZED_SEASON"
elif [[ "$TYPE" == "movie" ]]; then
    TARGET_DIR="$HTPC_ROOT/htpc/movies/$NAME"
    echo "🎬 Movie: $NAME"
fi

echo "📂 Target: $TARGET_DIR"

# Create directory with proper permissions
mkdir -p "$TARGET_DIR"
chmod 775 "$TARGET_DIR"

# Add to Transmission
echo "⬇️  Adding to Transmission..."
if transmission-remote 127.0.0.1 --add "$MAGNET" -w "$TARGET_DIR"; then
    echo "✅ Success! Downloading to: $TARGET_DIR"
    echo ""
    echo "💡 Tip: Use 'transmission-remote -l' to check progress"
else
    echo "❌ Failed to add torrent. Is transmission-daemon running?"
    exit 1
fi