#!/usr/bin/env bash
set -euo pipefail

case "$#" in
  0)
    exec code
    ;;
  1)
    BOX="$1"
    exec code --profile "$BOX" "$HOME/Develop"
    ;;
  2)
    BOX="$1"
    TARGET="$2"

    if [[ "$TARGET" = /* ]]; then
      PATH_RESOLVED="$(realpath "$TARGET")"
    else
      PATH_RESOLVED="$(realpath "$HOME/Develop/$TARGET")"
    fi

    exec code --profile "$BOX" "$PATH_RESOLVED"
    ;;
  *)
    echo "usage: code-box [box] [path]"
    exit 1
    ;;
esac
