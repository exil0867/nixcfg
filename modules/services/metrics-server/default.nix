{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.metrics-server;
  
  serverScript = ./server.py;
in
{
  options.services.metrics-server = {
    enable = mkEnableOption "Metrics collection server";
    
    port = mkOption {
      type = types.port;
      default = 3001;
      description = "Port for HTTP metrics endpoint";
    };
    
    authTokenFile = mkOption {
      type = types.path;
      description = "Path to file containing authentication token";
      default = config.age.secrets."metrics/token".path;
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
        ExecStart = "${pkgs.python3}/bin/python ${serverScript}";
        Environment = [
          "SERVER_PORT=${toString cfg.port}"
          "AUTH_TOKEN_FILE=${cfg.authTokenFile}"
        ];
      };
      
      path = with pkgs; [ python3 ];
    };
    
    services.traefik.dynamicConfigOptions = mkIf config.services.traefik.enable {
      http.routers.metrics-api = {
        rule = "Host(`exil.kyrena.dev`) && PathPrefix(`/api/metrics`)";
        entryPoints = [ "websecure" ];
        service = "metrics-api";
        middlewares = lib.optional (config.traefikOrigin.middlewareName != null) config.traefikOrigin.middlewareName;
        tls.certResolver = "cloudflare";
      };
      
      http.routers.metrics-sse = {
        rule = "Host(`exil.kyrena.dev`) && Path(`/ws/metrics`)";
        entryPoints = [ "websecure" ];
        service = "metrics-sse";
        middlewares = lib.optional (config.traefikOrigin.middlewareName != null) config.traefikOrigin.middlewareName;
        tls.certResolver = "cloudflare";
      };
      
      http.services.metrics-api.loadBalancer.servers = [{
        url = "http://127.0.0.1:${toString cfg.port}";
      }];
      
      http.services.metrics-sse.loadBalancer.servers = [{
        url = "http://127.0.0.1:${toString cfg.port}";
      }];
    };
  };
}
