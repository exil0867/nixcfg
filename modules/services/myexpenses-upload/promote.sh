#!/usr/bin/env bash
set -euo pipefail

IN="$1"
OUT="$2"

for f in "$IN"/backup-*.zip; do
  [ -f "$f" ] || continue

  ts="$(date +%Y-%m-%d_%H-%M-%S)"
  tmp="$OUT/.myexpenses-$ts.tmp"
  dst="$OUT/myexpenses-$ts.zip"

  install -m 600 "$f" "$tmp"
  sync "$tmp"
  mv "$tmp" "$dst"
  rm -f "$f"
done
