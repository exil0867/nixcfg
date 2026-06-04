#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source @devboxCommon@

box="${1:-}"

if [ -z "$box" ]; then
  echo "usage: devbox-init <box-name>" >&2
  exit 1
fi

require_distrobox

echo "Initializing devbox '${box}'..."
echo "This executes the first-time Distrobox boot sequence in your terminal foreground."
echo "--------------------------------------------------------------------------------"

# Pass 'true' so it runs the entire setup setup loop, executes, and exits cleanly
"$DEVBOX_DISTROBOX_CMD" enter "$box" -- true

echo "--------------------------------------------------------------------------------"
echo "Deploying Cloudflare tunnel host-command shim..."
install_host_command_shim "$box" "cloudflare-tunnel" "cloudflare-tunnel"

echo "Initialization complete! You can now use: devbox-enter ${box}"