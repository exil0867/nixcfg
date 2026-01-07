#  GNOME Configuration Module
#  Enable with "gnome.enable = true;"
#  Customize behavior with gnome.* options
{
  config,
  lib,
  pkgs,
  vars,
  inputs,
  ...
}:
with lib; {
  options = {
    gnome = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable GNOME desktop environment";
      };

      # Display manager options
      displayManager = {
        defaultSession = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Default session to use (e.g., 'gnome', 'plasma')";
        };
      };

      # Night light (blue light filter)
      nightLight = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable night light (reduces blue light at night)";
        };
        temperature = mkOption {
          type = types.int;
          default = 4000;
          description = "Color temperature for night light (lower = warmer)";
        };
      };

      # Interface preferences
      interface = {
        colorScheme = mkOption {
          type = types.enum ["default" "prefer-dark" "prefer-light"];
          default = "prefer-dark";
          description = "Color scheme preference";
        };

        clockShowDate = mkOption {
          type = types.bool;
          default = true;
          description = "Show date in top bar clock";
        };

        clockShowSeconds = mkOption {
          type = types.bool;
          default = false;
          description = "Show seconds in top bar clock";
        };
      };

      # File manager (Nautilus) settings
      fileManager = {
        confirmTrash = mkOption {
          type = types.bool;
          default = false;
          description = "Ask for confirmation before moving files to trash";
        };

        defaultView = mkOption {
          type = types.enum ["icon-view" "list-view"];
          default = "list-view";
          description = "Default view mode for file manager";
        };

        useTreeView = mkOption {
          type = types.bool;
          default = true;
          description = "Enable tree view in list mode";
        };

        sortDirectoriesFirst = mkOption {
          type = types.bool;
          default = true;
          description = "Sort directories before files";
        };

        showCreateLink = mkOption {
          type = types.bool;
          default = true;
          description = "Show option to create symbolic links";
        };
      };

      # Window manager behavior
      wm = {
        focusMode = mkOption {
          type = types.enum ["click" "sloppy" "mouse"];
          default = "click";
          description = "Window focus mode";
        };

        buttonLayout = mkOption {
          type = types.str;
          default = "appmenu:minimize,maximize,close";
          description = "Window button layout";
        };
      };

      # Extensions to enable
      extensions = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "List of GNOME extensions to enable";
        example = ["appindicatorsupport@rgcjonas.gmail.com"];
      };

      # Additional dconf settings
      extraDconfSettings = mkOption {
        type = types.attrs;
        default = {};
        description = "Additional dconf settings to apply";
        example = {
          "org/gnome/desktop/input-sources" = {
            sources = [(mkTuple ["xkb" "us"])];
          };
        };
      };
    };
  };

  config = mkIf (config.gnome.enable) {
    services = {
      desktopManager = {
        gnome = {
          enable = true;
        };
      };
      displayManager = {
        gdm = {
          enable = true;
          wayland = mkDefault true;
        };
      };
      xserver = {
        enable = true;
        xkb = {
          layout = mkDefault "us";
          options = mkDefault "eurosign:e";
        };
      };
    };

    # Set default session if specified
    services.displayManager.defaultSession =
      mkIf (config.gnome.displayManager.defaultSession != null)
      config.gnome.displayManager.defaultSession;

    # Install useful GNOME apps
    environment.systemPackages = with pkgs;
      [
        gnome-tweaks
        dconf-editor
      ]
      ++ (
        with pkgs.gnomeExtensions;
        # Map extension names to packages if needed
          [
            clipboard-history
            emoji-copy
            dash-to-dock
          ]
      );

    # xdg.portal = {
    #   enable = true;
    #   extraPortals = with pkgs; [
    #     xdg-desktop-portal-gnome
    #   ];
    # };

    # Exclude some default GNOME apps
    environment.gnome.excludePackages = with pkgs; [
      epiphany # web browser
      gnome-tour
      gnome-music
      geary # email
    ];

    home-manager.users.${vars.user} = {
      dconf.settings = mkMerge [
        # Base settings
        {
          # Night light
          "org/gnome/settings-daemon/plugins/color" = {
            night-light-enabled = config.gnome.nightLight.enable;
            night-light-temperature =
              mkIf config.gnome.nightLight.enable
              config.gnome.nightLight.temperature;
          };

          # Interface
          "org/gnome/desktop/interface" = {
            color-scheme = config.gnome.interface.colorScheme;
            clock-show-date = config.gnome.interface.clockShowDate;
            clock-show-seconds = config.gnome.interface.clockShowSeconds;
          };

          # Window manager
          "org/gnome/desktop/wm/preferences" = {
            button-layout = config.gnome.wm.buttonLayout;
            focus-mode = config.gnome.wm.focusMode;
          };

          # File manager (nautilus)
          "org/gnome/nautilus/preferences" = {
            default-folder-viewer = config.gnome.fileManager.defaultView;
            show-create-link = config.gnome.fileManager.showCreateLink;
          };

          "org/gnome/nautilus/list-view" = {
            use-tree-view = config.gnome.fileManager.useTreeView;
          };

          "org/gtk/settings/file-chooser" = {
            sort-directories-first = config.gnome.fileManager.sortDirectoriesFirst;
          };

          "org/gtk/gtk4/settings/file-chooser" = {
            sort-directories-first = config.gnome.fileManager.sortDirectoriesFirst;
          };

          "org/gnome/shell/keybindings" = {
            screenshot = ["<Super>c"];
            show-screenshot-ui = ["<Shift><Super>s"];
          };

          "org/gnome/desktop/wm/keybindings" = {
            switch-to-workspace-1 = ["<Super>F1"];
            switch-to-workspace-2 = ["<Super>F2"];
            switch-to-workspace-3 = ["<Super>F3"];
            switch-to-workspace-4 = ["<Super>F4"];
          };

          "org/gnome/settings-daemon/plugins/power" = {
            sleep-inactive-ac-type = "nothing";
            sleep-inactive-battery-type = "nothing";
            sleep-inactive-ac-timeout = 0;
            sleep-inactive-battery-timeout = 0;
            idle-dim = false;
          };

          "org/gnome/desktop/input-sources" = {
            sources = [
              (lib.gvariant.mkTuple ["xkb" "us"])
              (lib.gvariant.mkTuple ["xkb" "fr+azerty"])
              (lib.gvariant.mkTuple ["xkb" "ara"])
            ];
          };

          "org/gnome/shell" = {
            disable-user-extensions = false;
            enabled-extensions = [
              pkgs.gnomeExtensions.clipboard-history.extensionUuid
              pkgs.gnomeExtensions.emoji-copy.extensionUuid
              pkgs.gnomeExtensions.dash-to-dock.extensionUuid
            ];
          };

          "org/gnome/shell/extensions/clipboard-history" = {
            history-size = 200;
            window-width-percentage = 50;
            cache-size = 10;
            cache-only-favorites = false;
            notify-on-copy = false;
            confirm-clear = true;
            move-item-first = true;
            enable-keybindings = true;
            display-mode = 0;
            disable-down-arrow = false;
            strip-text = false;
            private-mode = false;
            paste-on-selection = false;
            process-primary-selection = false;
            ignore-password-mimes = true;
            toggle-menu = ["<Super>b"];
          };

          "org/gnome/shell/extensions/emoji-copy" = {
            always-show = false;
            paste-on-select = true;
            active-keybind = true;
            emoji-keybind = ["<Super>period"];
          };

          "org/gnome/shell/extensions/dash-to-dock" = {
            apply-custom-theme = true;
            custom-theme-shrink = false;

            dock-position = 2;
            multi-monitor = false;

            dock-fixed = false;
            intellihide = true;
            autohide-in-fullscreen = true;

            click-action = 1;
            scroll-action = 1;

            show-running = true;
            isolate-monitors = false;
            isolate-workspaces = false;

            show-trash = false;

            show-mounts = false;
            show-mounts-only-mounted = false;
            show-mounts-network = false;
          };
          "org/gnome/settings-daemon/plugins/media-keys" = {
            screenshot = [];
            screenshot-window = [];
            screenshot-area = [];
            custom-keybindings = [
              "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/flameshot-full/"
              "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/flameshot-region/"
              "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/flameshot-gui/"
            ];
          };

          "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/flameshot-full" = {
            name = "Flameshot Full Screen";
            binding = "<Super>c";
            command = "bash -c 'QT_QPA_PLATFORM=wayland flameshot screen --clipboard'";
          };

          "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/flameshot-region" = {
            name = "Flameshot Region";
            binding = "<Super>x";
            command = "bash -c 'QT_QPA_PLATFORM=wayland flameshot gui --clipboard'";
          };

          "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/flameshot-gui" = {
            name = "Flameshot GUI";
            binding = "<Super><Shift>s";
            command = "bash -c 'QT_QPA_PLATFORM=wayland flameshot gui'";
          };
          "org/gnome/desktop/interface" = {
            monospace-font-name = "Inconsolata 11";
          };
        }

        # User-provided extra settings
        config.gnome.extraDconfSettings
      ];

      # Enable extensions if specified
      home.packages = with pkgs.gnomeExtensions; (
        if builtins.elem "appindicatorsupport@rgcjonas.gmail.com" config.gnome.extensions
        then [appindicator]
        else []
      );
    };
  };
}
