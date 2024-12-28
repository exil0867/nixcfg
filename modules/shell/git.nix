{ config, lib, pkgs, ... }:

with lib;

{
  options.git = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Git configuration for Home Manager.";
    };

    extraConfig = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Additional Git configuration options.";
    };
  };

  config = mkIf config.git.enable {
    programs.git = {
      enable = true;
      userName = "Exil";
      userEmail = "exil@n0t3x1l.dev";
      extraConfig = config.git.extraConfig;
    };
  };
}
