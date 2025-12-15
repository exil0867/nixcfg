{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.metrics-agent;
in
{
  options.services.metrics-agent = {
    enable = mkEnableOption "System metrics collection agent";
    
    serverUrl = mkOption {
      type = types.str;
      default = "http://localhost:3001";
      description = "URL of the metrics server";
    };
    
    authTokenFile = mkOption {
      type = types.path;
      description = "Path to file containing authentication token";
      default = config.age.secrets."metrics/token".path;
    };
    
    interval = mkOption {
      type = types.int;
      default = 10;
      description = "How often to send metrics (in seconds)";
    };
  };
  
  config = mkIf cfg.enable {
    systemd.services.metrics-agent = {
      description = "System Metrics Collection Agent";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "metrics-server.service" ];
      wants = [ "network-online.target" "metrics-server.service" ];
      
      script = ''
        while true; do
          # Get hostname (simple method)
          HOSTNAME=$(cat /proc/sys/kernel/hostname 2>/dev/null || echo "unknown")
          
          # Read auth token
          AUTH_TOKEN=$(cat "${cfg.authTokenFile}")
          
          # Get CPU usage (simple method that always works)
          CPU=0
          if [[ -f /proc/stat ]]; then
            # Read first sample
            read cpu user_1 nice_1 system_1 idle_1 iowait_1 irq_1 softirq_1 steal_1 guest_1 guest_nice_1 < /proc/stat
            
            # Wait 1 second for the change in Jiffies
            sleep 1
            
            # Read second sample
            read cpu user_2 nice_2 system_2 idle_2 iowait_2 irq_2 softirq_2 steal_2 guest_2 guest_nice_2 < /proc/stat
            
            # Calculate total and idle time differences using awk for float precision
            CPU=$(awk -v u1="$user_1" -v n1="$nice_1" -v s1="$system_1" -v i1="$idle_1" -v io1="$iowait_1" \
                       -v u2="$user_2" -v n2="$nice_2" -v s2="$system_2" -v i2="$idle_2" -v io2="$iowait_2" \
                       'BEGIN {
                            # Calculate total time in first and second sample
                            TOTAL_1 = u1 + n1 + s1 + i1 + io1
                            TOTAL_2 = u2 + n2 + s2 + i2 + io2
                            
                            # Calculate idle time (idle + iowait) in first and second sample
                            IDLE_1 = i1 + io1
                            IDLE_2 = i2 + io2
                            
                            # Calculate differences
                            DELTA_TOTAL = TOTAL_2 - TOTAL_1
                            DELTA_IDLE = IDLE_2 - IDLE_1
                            
                            # Calculate usage percentage
                            if (DELTA_TOTAL > 0) {
                                USAGE = 100 * (1.0 - (DELTA_IDLE / DELTA_TOTAL))
                                printf "%.1f", USAGE
                            } else {
                                # Avoid division by zero if system is somehow stuck
                                printf "0.0" 
                            }
                        }'
            )
          fi
          
          # Get RAM usage (simple method)
          RAM=0
          if [[ -f /proc/meminfo ]]; then
            TOTAL_MEM=$(grep -m1 MemTotal /proc/meminfo | awk '{print $2}')
            AVAILABLE_MEM=$(grep -m1 MemAvailable /proc/meminfo | awk '{print $2}')
            if [[ $TOTAL_MEM -gt 0 ]]; then
              RAM_PERCENT=$(awk "BEGIN {printf \"%.1f\", 100 * ($TOTAL_MEM - $AVAILABLE_MEM) / $TOTAL_MEM}")
              RAM=$RAM_PERCENT
            fi
          fi
          
          # Get GPU usage if available
          GPU="null"
          if command -v nvidia-smi &> /dev/null; then
            GPU_RAW=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1)
            if [[ -n "$GPU_RAW" ]]; then
              GPU=$(echo "$GPU_RAW" | tr -d '[:space:]')
            fi
          fi
          
          # Create JSON (manually format to avoid issues)
          JSON="{\"hostname\":\"$HOSTNAME\",\"cpu\":$CPU,\"ram\":$RAM,\"gpu\":\"$GPU\"}"
          
          echo "Sending metrics for $HOSTNAME: CPU=$CPU%, RAM=$RAM%, GPU=$GPU"
          
          # Send to server with simple error handling
          if curl -s -X POST \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $AUTH_TOKEN" \
            -d "$JSON" \
            --max-time 5 \
            --connect-timeout 3 \
            "${cfg.serverUrl}/api/metrics" >/dev/null 2>&1; then
            echo "Successfully sent metrics"
          else
            echo "Failed to send metrics (server might be down)"
          fi
          
          # Wait for next interval
          sleep ${toString cfg.interval}
        done
      '';
      
      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = "10s";
      };
      
      path = with pkgs; [
        bash
        curl
        gnugrep
        gawk
        coreutils
        config.hardware.nvidia.package
      ];
    };
  };
}