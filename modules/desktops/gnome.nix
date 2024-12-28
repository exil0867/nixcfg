#
#  KDE Plasma 6 Configuration
#  Enable with "kde.enable = true;"
#  Get the plasma configs in a file with $ nix run github:pjones/plasma-manager > <file>
#

{ config, lib, pkgs, vars, inputs, ... }:

with lib;
{
  options = {
    gnome = {
      enable = mkOption {
        type = types.bool;
        default = false;
      };
    };
  };

  config = mkIf (config.gnome.enable) {
    services = {
      # displayManager = {
      #   sddm.enable = true;
      #   # defaultSession = "plasmawayland";
      # };
      # desktopManager = {
      #   plasma6 = {
      #     enable = true;
      #   };
      # };
      # libinput = {
      #   enable = true;
      #   mouse = {
      #     accelProfile = "flat";
      #   };
      # };
      xserver = {
        enable = true;
        displayManager.gdm.enable = true;
        desktopManager.gnome.enable = true;
        xkb = {
          layout = "us";
          options = "eurosign:e";
        };
      };
    };

    home-manager.users.${vars.user} = {
      dconf.settings =
          {
            "org/gnome/desktop/input-sources" = {
              sources = [
                (lib.hm.gvariant.mkTuple [ "xkb" "us+dvorak-intl" ])
              ] ++ lib.optional config.talyz.media-center.enable
                (lib.hm.gvariant.mkTuple [ "xkb" "se" ]);
              xkb-options = [ "eurosign:e" "ctrl:nocaps" "numpad:mac" "kpdl:dot" ];
            };

            "org/gnome/settings-daemon/plugins/color" = {
              night-light-enabled = true;
            };

            "org/gnome/desktop/interface" = {
              color-scheme = "prefer-dark";
            };


            # File browser (nautilus) settings
            "org/gnome/nautilus/settings" = {
              confirm-trash = false;
              default-folder-viewer = "list-view";
              # default-sort-order = "type";
              show-create-link = true;
            };
            "org/gnome/nautilus/list-view" = {
              use-tree-view = true;
            };

            "org/gtk/Settings/FileChooser" = {
              sort-directories-first = true;
              sort-column = "type";
            };
          };
    };
  };
}
