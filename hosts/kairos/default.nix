{  config, vars, unstable, stable, system-definition, inputs, ... }:

let
  plasmaConfig = import ../../modules/desktops/plasma-prefs.nix;
in

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/programs/games.nix
    ../../modules/services/sshfs.nix
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

  networking = {
    hostName = "kairos";
  };

  services.libinput.mouse.accelProfile = "flat";

  plasma = {
    enable = true;
    defaultSession = "plasma";
    lookAndFeel = "org.kde.breezedark.desktop";
    plasmaManager = inputs.plasma-manager-unstable.homeManagerModules.plasma-manager;
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


# fileSystems."/home/exil0681/media" = {
#     device = "exil0681@192.168.122.213:/";
#     fsType = "fuse.sshfs";
#     options = [
#       "identityfile=/home/exil0681/.ssh/id_ed25519_no_passphrase"
#       "idmap=user"
#       "x-systemd.automount" #< mount the filesystem automatically on first access
#       "allow_other" #< don't restrict access to only the user which `mount`s it (because that's probably systemd who mounts it, not you)
#       "user" #< allow manual `mount`ing, as ordinary user.
#       "_netdev"
#     ];
#   };
#   boot.supportedFilesystems."fuse.sshfs" = true;


  sshfsMounts = [
    {
      mountPoint = "/home/exil0681/mnt/servers";
      remoteUser = "exil0681";
      remoteHost = "192.168.122.213";
      remotePath = "/home/exil0681/ServerData";
      sshKey = "/home/exil0681/.ssh/id_ed25519";
      uid = "exil0681";
      gid = "users";
    }
  ];

  hardware = {};

  environment = {
    systemPackages = (with system-definition; [
      ungoogled-chromium
      git
      zed-editor
      vscode
      keepassxc
      librewolf
      sshpass
      gimp
      discord
      # bruno
      jellyfin-media-player
      obs-studio
      bottles
      neovide
      handbrake
      tailscale
      krita
      firefox-devedition
      atlauncher
      osu-lazer
      transmission_4-qt
    ]) ++ (with system-definition.kdePackages; [
      kate
      partitionmanager
      kdenlive
    ]) ++
    (with stable; [
      # Apps
      # firefox # Browser
      # image-roll # Image Viewer
    ]);
  };

  age.secrets."tailscale/preauth-kairos".file = ../../secrets/tailscale/preauth-kairos.age;
  tailscale = {
    enable = true;
    authKeyFile = config.age.secrets."tailscale/preauth-kairos".path;
    loginServer = "http://192.168.1.5:8181";
  };

  home-manager.users.${vars.user} = {
    imports = [
      inputs.plasma-manager-unstable.homeManagerModules.plasma-manager
    ];
    programs = {
      plasma = {
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
        };
      };
      vscode = {
        enable = true;
        extensions = [system-definition.vscode-extensions.ms-vscode-remote.remote-ssh system-definition.vscode-extensions.ms-vscode-remote.remote-containers system-definition.vscode-extensions.ms-vscode-remote.remote-ssh-edit system-definition.vscode-extensions.jnoortheen.nix-ide];
        userSettings = {
          "editor.wordWrap" = "on";
        };
      };
    };
  };
 }
