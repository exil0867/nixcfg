#!/usr/bin/env bash
set -euo pipefail

incomingDir="$1"

# Read request line
IFS= read -r request || exit 0
method="${request%% *}"

# Consume headers
while IFS= read -r line; do
  [ -z "$line" ] && break
  [ "$line" = $'\r' ] && break
done

# Handle probe requests
case "$method" in
  OPTIONS|PROPFIND)
    printf "HTTP/1.1 200 OK\r\n"
    printf "Allow: PUT, POST, OPTIONS, PROPFIND\r\n"
    printf "Content-Length: 0\r\n\r\n"
    exit 0
    ;;
esac

ts="$(date +%s)"
tmp="$incomingDir/.backup-$ts.part"
out="$incomingDir/backup-$ts.zip"

cat > "$tmp"
chmod 600 "$tmp"
mv "$tmp" "$out"

printf "HTTP/1.1 200 OK\r\n"
printf "Connection: close\r\n"
printf "Content-Length: 2\r\n\r\nOK"
