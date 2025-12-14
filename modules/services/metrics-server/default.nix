{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.metrics-server;
  
  metricsServerScript = ./server.py;
in
{
  options.services.metrics-server = {
    enable = mkEnableOption "Metrics collection server";
    
    port = mkOption {
      type = types.port;
      default = 3001;
      description = "Port for HTTP metrics endpoint";
    };
    
    wsPort = mkOption {
      type = types.port;
      default = 3002;
      description = "Port for WebSocket server (unused, kept for compatibility)";
    };
    
    authTokenFile = mkOption {
      type = types.path;
      description = "Path to file containing authentication token";
    };
  };
  
  config = mkIf cfg.enable {
    systemd.services.metrics-server = {
      description = "Metrics Collection Server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      
      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = "10s";
        # 2. Run the external script with environment variables
        ExecStart = "${pkgs.python3}/bin/python3 ${metricsServerScript}";
        Environment = [
          "SERVER_PORT=${toString cfg.port}"
          "AUTH_TOKEN_FILE=${cfg.authTokenFile}"
        ];
      };
    };
    
    # Add Traefik routes for Server-Sent Events
    services.traefik.dynamicConfigOptions = {
      http.routers.metrics-api = {
        rule = "Host(`exil.kyrena.dev`) && PathPrefix(`/api/metrics`)";
        entryPoints = [ "websecure" ];
        service = "metrics-api";
        tls.certResolver = "letsencrypt";
      };
      
      http.routers.metrics-sse = {
        rule = "Host(`exil.kyrena.dev`) && Path(`/ws/metrics`)";
        entryPoints = [ "websecure" ];
        service = "metrics-api";
        tls.certResolver = "letsencrypt";
      };
      
      http.services.metrics-api.loadBalancer.servers = [{
        url = "http://127.0.0.1:${toString cfg.port}";
      }];
    };
  };
}