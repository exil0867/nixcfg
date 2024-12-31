# plasma.nix
{ config, lib, pkgs, vars, inputs, ... }:

with lib;

let
  # Helper function to merge configurations
  mergeConfigs = cfg1: cfg2: recursiveUpdate cfg1 cfg2;
in
{
  options = {
    plasma = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable KDE Plasma 6";
      };

      defaultSession = mkOption {
        type = types.str;
        default = "plasma";
        description = "Default session for the display manager";
      };

      lookAndFeel = mkOption {
        type = types.str;
        default = "org.kde.breezedark.desktop";
        description = "Plasma look and feel theme";
      };

      nightLight = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable night light";
        };
        mode = mkOption {
          type = types.str;
          default = "location";
          description = "Night light mode";
        };
        location = {
          latitude = mkOption {
            type = types.str;
            default = "36.797598659823876";
            description = "Latitude for night light";
          };
          longitude = mkOption {
            type = types.str;
            default = "10.190596383999777";
            description = "Longitude for night light";
          };
        };
      };

      panels = mkOption {
        type = types.listOf types.attrs;
        default = [
          {
            location = "top";
            height = 48;
            screen = 0;
            floating = false;
            widgets = [
              { name = "org.kde.plasma.kickoff"; }
              {
                iconTasks = {
                  launchers = [
                    "applications:org.kde.dolphin.desktop"
                  ];
                };
              }
              { name = "org.kde.plasma.marginsseparator"; }
              {
                systemTray.items = {
                  shown = [
                    "org.kde.plasma.clipboard"
                    "org.kde.plasma.volume"
                    "org.kde.plasma.bluetooth"
                    "org.kde.plasma.networkmanagement"
                  ];
                };
              }
              { digitalClock = { }; }
            ];
          }
        ];
        description = "Plasma panels configuration";
      };

      shortcuts = mkOption {
        type = types.attrs;
        default = { };
        description = "Custom Plasma shortcuts";
      };

      configFile = mkOption {
        type = types.attrs;
        default = { };
        description = "Custom Plasma config files";
      };

      dataFile = mkOption {
        type = types.attrs;
        default = { };
        description = "Custom Plasma data files";
      };

      plasmaManager = mkOption {
        type = types.unspecified;
        description = "Plasma Manager module to use (stable or unstable)";
      };
    };
  };

  config = mkIf config.plasma.enable {
    services = {
      displayManager = {
        sddm.enable = true;
        defaultSession = config.plasma.defaultSession;
      };
      desktopManager.plasma6.enable = true;
      libinput.enable = true;
      xserver.enable = true;
    };

    home-manager.users.${vars.user} = {
      imports = [ config.plasma.plasmaManager ];
      programs.plasma = {
        enable = true;
        overrideConfig = true;
        workspace.lookAndFeel = config.plasma.lookAndFeel;
        kwin.nightLight = config.plasma.nightLight;
        panels = config.plasma.panels;
        shortcuts = config.plasma.shortcuts; 
        configFile = config.plasma.configFile;
        dataFile = config.plasma.dataFile;
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