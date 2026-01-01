#!/usr/bin/env bash
set -euo pipefail

# Usage: 
#   htpc-downloader tv "Show Name" "Season 1" "magnet:..."
#   htpc-downloader tv "Show Name" "magnet:..." (No Season)

show_usage() {
    cat <<EOF
Usage: htpc-downloader <type> <name> [season] <magnet>

Examples:
  htpc-downloader tv "Pluto" "magnet:?..."         (Root TV folder)
  htpc-downloader tv "Pluto" "1" "magnet:?..."     (Season 01 folder)
  htpc-downloader movie "Inception" "magnet:?..."  (Movie folder)
EOF
}

TYPE=$1
NAME=$2

# --- Logic for Optional Season ---
if [[ "$TYPE" == "tv" ]]; then
    # Case A: 3 arguments (Type, Name, Magnet) -> No Season
    if [[ $# -eq 3 ]]; then
        MAGNET=$3
        TARGET_DIR="$HTPC_ROOT/htpc/tv_shows/$NAME"
        echo "📺 TV Show (Root): $NAME"

    # Case B: 4 arguments (Type, Name, Season, Magnet) -> With Season
    elif [[ $# -eq 4 ]]; then
        SEASON=$3
        MAGNET=$4
        
        # Normalize Season
        if [[ "$SEASON" =~ ^[0-9]+$ ]]; then
            NORMALIZED_SEASON=$(printf "Season %02d" "$SEASON")
        elif [[ "$SEASON" =~ ^[Ss]eason ]]; then
            NORMALIZED_SEASON="$SEASON"
        else
            NORMALIZED_SEASON="$SEASON"
        fi
        
        TARGET_DIR="$HTPC_ROOT/htpc/tv_shows/$NAME/$NORMALIZED_SEASON"
        echo "📺 TV Show: $NAME"
        echo "📁 Season: $NORMALIZED_SEASON"

    else
        echo "Error: Invalid number of arguments for TV."
        show_usage
        exit 1
    fi

elif [[ "$TYPE" == "movie" ]]; then
    if [[ $# -lt 3 ]]; then
        echo "Error: Movies require: type name magnet"
        show_usage
        exit 1
    fi
    MAGNET=$3
    TARGET_DIR="$HTPC_ROOT/htpc/movies/$NAME"
    echo "🎬 Movie: $NAME"

else
    echo "Error: Type must be 'tv' or 'movie'"
    exit 1
fi

echo "📂 Target: $TARGET_DIR"

# Create directory
mkdir -p "$TARGET_DIR"
chmod 775 "$TARGET_DIR"

# Add to Transmission
# Note: We rely on the clean-torrent.sh script to handle flattening later
echo "⬇️  Adding to Transmission..."
if transmission-remote 127.0.0.1 --add "$MAGNET" -w "$TARGET_DIR"; then
    echo "✅ Success!" 
else
    echo "❌ Failed."
    exit 1
fi