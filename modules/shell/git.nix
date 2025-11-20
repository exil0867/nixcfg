# Git Configuration
# Enable with "git.enable = true;"
# Add additional Git configuration with "git.extraConfig = { ... };"

{ config, lib, pkgs, vars, inputs, ... }:

with lib;

{
  options = {
    git = {
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
  };

  config = mkIf config.git.enable {
    home-manager.users.${vars.user} = {
      programs.git = {
        enable = true;
        settings.user = {
          name = "Exil";
          email = "exil@kyrena.dev";
        };
      };
    };
  };
}
