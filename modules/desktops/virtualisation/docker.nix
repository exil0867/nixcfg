{ config, lib, pkgs, vars, ... }:

let
  cfg = config.docker;
in {
  options.docker = {
    enable = lib.mkEnableOption "Docker";
    dataRoot = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Path to store Docker data";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.docker = {
      enable = true;
      daemon.settings = lib.mkIf (cfg.dataRoot != null) {
        data-root = cfg.dataRoot;
      };
    };
    
    users.groups.docker.members = [ "${vars.user}" ];
    
    environment.systemPackages = with pkgs; [
      docker
      docker-compose
    ];
  };
}