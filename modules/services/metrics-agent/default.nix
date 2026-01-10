{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.metrics-agent;

  metricsAgent = pkgs.writeShellApplication {
    name = "metrics-agent";
    runtimeInputs =
      with pkgs;
      [
        bash
        curl
        gawk
        gnugrep
        coreutils
      ]
      ++ lib.optional (cfg.gpu == "nvidia") config.hardware.nvidia.package;
    text = builtins.readFile ./script.sh;
    checkPhase = ":";
  };
in
{
  options.services.metrics-agent = {
    enable = mkEnableOption "System metrics collection agent";

    gpu = mkOption {
      type = types.enum [ "nvidia" "intel" "none" ];
      default = "none";
      description = "Type of GPU to monitor. Only 'nvidia' adds nvidia-smi to path.";
    };

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

      serviceConfig = {
        Type = "simple";
        ExecStart =
          "${metricsAgent}/bin/metrics-agent "
          + cfg.serverUrl + " "
          + cfg.authTokenFile + " "
          + toString cfg.interval;
        Restart = "always";
        RestartSec = "10s";
      };
    };
  };
}
