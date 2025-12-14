{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.metrics-agent;
  
  collectMetricsScript = pkgs.writeShellScriptBin "collect-metrics" ''
    #!/usr/bin/env bash
    set -euo pipefail
    
    HOSTNAME=$(cat /proc/sys/kernel/hostname)
    AUTH_TOKEN_PATH="$1"
    SERVER_URL="$2"
    
    # Read auth token
    AUTH_TOKEN="$(cat "$AUTH_TOKEN_PATH")"
    
    # CPU usage
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
    
    # Send to metrics server
    curl -X POST \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $AUTH_TOKEN" \
      -d "$JSON" \
      --max-time 10 \
      --silent \
      --show-error \
      "$SERVER_URL/api/metrics" 2>/dev/null || true
  '';
in
{
  options.services.metrics-agent = {
    enable = mkEnableOption "System metrics collection agent";
    
    serverUrl = mkOption {
      type = types.str;
      default = "https://exil.kyrena.dev";
      description = "URL of the metrics server";
    };
    
    authTokenFile = mkOption {
      type = types.path;
      description = "Path to file containing authentication token";
    };
    
    interval = mkOption {
      type = types.str;
      default = "10s";
      description = "How often to send metrics";
    };
  };
  
  config = mkIf cfg.enable {
    systemd.services.metrics-agent = {
      description = "System Metrics Collection Agent";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      
      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = "10s";
        Environment = [
          "PATH=${lib.makeBinPath (with pkgs; [ coreutils curl procps gnugrep gnused gawk unixtools.top ])}"
        ];
      };
      
      script = ''
        while true; do
          ${collectMetricsScript}/bin/collect-metrics \
            "${cfg.authTokenFile}" \
            "${cfg.serverUrl}"
          sleep ${cfg.interval}
        done
      '';
    };
  };
}