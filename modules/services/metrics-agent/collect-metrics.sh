#!@bash@/bin/bash
# Note: Nix will substitute @bash@ with the path to bash

set -euo pipefail

# Add common utilities to PATH
export PATH="@nettools@/bin:@procps@/bin:@gnugrep@/bin:@coreutils@/bin:@gnused@/bin:@gawk@/bin:@curl@/bin:$PATH"

HOSTNAME=$(hostname)
AUTH_TOKEN_PATH=$1 # Passed as argument from Nix module
SERVER_URL=$2      # Passed as argument from Nix module

# CPU usage (1 second average)
# *Consider using 'mpstat' from 'sysstat' for a less intrusive measure*
CPU=$(top -bn2 -d 1 | grep "Cpu(s)" | tail -1 | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')

# RAM usage
RAM=$(free | grep Mem | awk '{printf "%.1f", ($3/$2) * 100.0}')

# GPU usage (NVIDIA only, optional)
if command -v nvidia-smi &> /dev/null; then
  GPU=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | head -1)
else
  GPU="null"
fi

# Build JSON payload
JSON=$(cat <<EOF
{
  "hostname": "$HOSTNAME",
  "timestamp": $(date +%s),
  "cpu": $CPU,
  "ram": $RAM,
  "gpu": $GPU
}
EOF
)

# Send to metrics server with auth token. 
# REMOVED '|| true' for better debugging.
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(cat $AUTH_TOKEN_PATH)" \
  -d "$JSON" \
  --max-time 10 \
  "$SERVER_URL/api/metrics"