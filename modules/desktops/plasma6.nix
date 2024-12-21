#
#  KDE Plasma 6 Configuration
#  Enable with "kde.enable = true;"
#  Get the plasma configs in a file with $ nix run github:pjones/plasma-manager > <file>
#

{ config, lib, pkgs, vars, inputs, ... }:

with lib;
{
  options = {
    plasma6 = {
      enable = mkOption {
        type = types.bool;
        default = false;
      };
    };
  };

  config = mkIf (config.plasma6.enable) {
    programs = {
      zsh.enable = true;
    };

    services = {
      displayManager = {
        sddm.enable = true;
        # defaultSession = "plasmawayland";
      };
      desktopManager = {
        plasma6 = {
          enable = true;
        };
      };
      libinput = {
        enable = true;
        mouse = {
          accelProfile = "flat";
        };
      };
      xserver = {
        enable = true;
        xkb = {
          layout = "us";
          options = "eurosign:e";
        };
      };
    };

    home-manager.users.${vars.user} = {
      imports = [
        inputs.plasma-manager.homeManagerModules.plasma-manager
      ];
      programs.plasma = {
        enable = true;
        session.sessionRestore.restoreOpenApplicationsOnLogin = "startWithEmptySession";
        spectacle.shortcuts = {
          captureWindowUnderCursor = "Meta+Z";
          captureCurrentMonitor = "Meta+C";
          captureRectangularRegion = "Meta+X";
        };
        input.keyboard.layouts = [
          {
            layout = "us";
          }
          {
            layout = "fr";
            variant = "azerty";
          }
          {
            layout = "ara";
          }
        ];
      };
    };
  };
}
