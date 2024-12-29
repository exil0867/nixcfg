{  config, vars, unstable, stable, inputs, ... }:

let

in

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/programs/games.nix
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

  kairos-plasma6.enable = true;

  git = {
    enable = true;
  };

  hardware = {};

  environment = {
    systemPackages = (with unstable; [
      ungoogled-chromium
      git
      zed-editor
      vscode
      keepassxc
      librewolf
      gimp
      discord
      # bruno
      jellyfin-media-player 
      obs-studio
      # bottles
      handbrake
      tailscale
      krita
      firefox-devedition
      atlauncher
      osu-lazer
    ]) ++ (with unstable.kdePackages; [
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
      vscode = {
        enable = true;
        extensions = [stable.vscode-extensions.ms-vscode-remote.remote-ssh unstable.vscode-extensions.ms-vscode-remote.remote-containers unstable.vscode-extensions.ms-vscode-remote.remote-ssh-edit unstable.vscode-extensions.jnoortheen.nix-ide];
        userSettings = {
          "editor.wordWrap" = "on";
        };
      };
    };
  };
}
