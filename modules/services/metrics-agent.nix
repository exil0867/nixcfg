{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.metrics-agent;
  
  metricsScript = pkgs.writeShellScript "collect-metrics" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    # Add common utilities to PATH
    export PATH="${pkgs.nettools}/bin:${pkgs.procps}/bin:${pkgs.gnugrep}/bin:${pkgs.coreutils}/bin:${pkgs.gnused}/bin:${pkgs.gawk}/bin:${pkgs.curl}/bin:$PATH"
    
    HOSTNAME=$(hostname)
    
    # CPU usage (1 second average)
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
    
    # Send to metrics server with auth token
    curl -X POST \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $(cat ${cfg.authTokenFile})" \
      -d "$JSON" \
      --max-time 5 \
      "${cfg.serverUrl}/api/metrics" || true
  '';
in
{
  options.services.metrics-agent = {
    enable = mkEnableOption "System metrics collection agent";
    
    serverUrl = mkOption {
      type = types.str;
      description = "URL of the metrics server";
      example = "https://exil.kyrena.dev";
    };
    
    authTokenFile = mkOption {
      type = types.path;
      description = "Path to file containing authentication token (agenix secret)";
    };
    
    interval = mkOption {
      type = types.str;
      default = "5s";
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
      };
      
      script = ''
        while true; do
          ${metricsScript}
          sleep ${cfg.interval}
        done
      '';
    };
  };
}