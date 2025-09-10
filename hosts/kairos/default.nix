{  config, vars, unstable, stable, system-definition, inputs, ... }:

let
  plasmaConfig = import ../../modules/desktops/plasma-prefs.nix;
in

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/programs/games.nix
    ../../modules/services/rclone-sftp.nix
    ../../modules/services/mounter.nix
    ../../modules/services/sync-secrets.nix
    ../../modules/desktops/virtualisation/docker.nix
  ] ++
  (import ../../modules/hardware/kairos) ++
  (import ../../modules/desktops/virtualisation);

  # Boot Options
  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 3;
      };
      efi = {
        canTouchEfiVariables = true;
      };
      timeout = 5;
    };
  };

  users.users.${vars.user} = {
    extraGroups = [ "adbusers" ];
    # openssh.authorizedKeys.keys = [];
  };

  mounter.mounts = [
    {
      mountPoint = "/mnt/PNY-CS900-120GB";
      deviceUUID = "f1afb020-5567-41a3-943b-c20320886c21";
      user = "exil0681";
      group = "users";
    }
    {
      mountPoint = "/mnt/TOSHIBA-MQ04ABF100-1TB";
      deviceUUID = "05c63c90-8c1b-4aba-b17c-88ba2f117e1c";
      user = "exil0681";
      group = "users";
    }
  ];

  syncSecrets = {
    enable = true;
    secretsDir = "/mnt/TOSHIBA-MQ04ABF100-1TB/Develop/nixcfg/secrets-sync";
    user = vars.user;
    group = "users";
  };

  networking = {
    hostName = "kairos";
    networkmanager.enable = true;
    firewall.allowedTCPPorts = [ 3000 ];
  };

  services.libinput.mouse.accelProfile = "flat";

  services.pulseaudio.enable = false;

  plasma = {
    enable = true;
    defaultSession = "plasma";
    lookAndFeel = "org.kde.breezedark.desktop";
    plasmaManager = inputs.plasma-manager-unstable.homeModules.plasma-manager;
    panels = [
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
                "applications:librewolf.desktop"
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
              ];
              hidden = [ "org.kde.plasma.networkmanagement" ];
            };
          }
          { digitalClock = { }; }
        ];
      }
    ];
    shortcuts = plasmaConfig.shortcuts;
    configFile = plasmaConfig.configFile;
    dataFile = plasmaConfig.dataFile;
  };

  git = {
    enable = true;
  };
  
  programs.ssh.startAgent = true;

  hardware = {};

  environment = {
    systemPackages = (with system-definition; [
      ungoogled-chromium
      git
      ollama
      # zed-editor
      vscode
      keepassxc
      libreoffice
      librewolf
      sshpass
      gimp
      discord
      bruno
      obs-studio
      bottles
      dbeaver-bin
      # neovide
      handbrake
      # tailscale
      krita
      # spotify
      # firefox-devedition
      # audacity
      # scrcpy
      # osu-lazer
      transmission_4-qt
      android-tools
      android-udev-rules
      aspell
      aspellDicts.en
    ]) ++ (with system-definition.kdePackages; [
      kate
      partitionmanager
      kdenlive
      kcalc
      sonnet
      plasma-systemmonitor
    ]) ++
    (with stable; [
      # Apps
      # firefox # Browser
      # image-roll # Image Viewer
    ]);
  };

  jellyfin-player = {
    enable = true;
    useXcb = true;
  };

  age.secrets."tailscale/preauth-kairos".file = ../../secrets-sync/tailscale/preauth-kairos.age;
  tailscale = {
    enable = false;
    authKeyFile = config.age.secrets."tailscale/preauth-kairos".path;
    loginServer = "http://192.168.1.5:8181";
  };

  services.udev.packages = [ system-definition.android-udev-rules ];

  programs.adb.enable = true;

  docker = {
    enable = true;
    dataRoot = "/var/lib/docker";
  };

  home-manager.users.${vars.user} = {
    imports = [
      inputs.plasma-manager-unstable.homeModules.plasma-manager
    ../../modules/utilities/media-mime.nix
    ];

    mediaMime = "mpv.desktop";
    programs = {
      plasma = {
        powerdevil = {
          AC = {
            autoSuspend = {
              action = "nothing";
              idleTimeout = null;
            };
            dimDisplay = {
              enable = true;
              idleTimeout = 600;
            };
            turnOffDisplay = {
              idleTimeout = 1200;
              idleTimeoutWhenLocked = 1200;
            };
            powerButtonAction = "showLogoutScreen";
            powerProfile = "performance";
          };
        };
        input = {
          mice = [
            {
              accelerationProfile = "none";
              enable = true;
              leftHanded = false;
              middleButtonEmulation = false;
              name = "USB Gaming Mouse";
              naturalScroll = false;
              productId = "fc30";
              scrollSpeed = 1;
              vendorId = "04d9";
            }
          ];
        };
      };
      librewolf = {
        enable = true;
        settings = {
          "webgl.disabled" = false;
          "privacy.clearOnShutdown.history" = false;
          "privacy.clearOnShutdown.cookies" = false;
          "privacy.resistfingerprinting" = false;
        };
      };
      vscode = {
        enable = true;
        profiles.default.extensions = [system-definition.vscode-extensions.ms-vscode-remote.remote-ssh system-definition.vscode-extensions.ms-vscode-remote.remote-containers system-definition.vscode-extensions.ms-vscode-remote.remote-ssh-edit system-definition.vscode-extensions.jnoortheen.nix-ide];
        profiles.default.userSettings = {
          "editor.wordWrap" = "on";
          "github.copilot.enable" = {
            "*" = false;
          };
          "github.copilot.advanced" = {
            "enabled" = false;
          };
        };
      };
    };
  };
 }
