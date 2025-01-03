{ config, vars, unstable, stable, system-definition, inputs, ... }:

let

in

{
  imports = [
    ./hardware-configuration.nix
    # ../../modules/programs/games.nix
  ] ++
  # (import ../../modules/hardware/kairos) ++
  (import ../../modules/desktops/virtualisation);

  # Boot Options
  boot = {
    loader = {
      grub = {
        enable = true;
        device = "/dev/vda";
        useOSProber = true;
        enableCryptodisk = true;
      };
      efi = {
        canTouchEfiVariables = true;
      };
      timeout = 5;
    };
    initrd = {
      secrets = {
        "/boot/crypto_keyfile.bin" = null;
      };
      luks.devices."luks-5e1b7503-7da3-49fa-bdcd-caa168dc28d5".keyFile = "/boot/crypto_keyfile.bin";
    };
  };

  networking = {
    hostName = "server";
  };

  gnome.enable = true;

  jellyfin = {
    enable = true;
    openFirewall = true;
    user = vars.user;
    hardwareAcceleration = {
      enable = true;
      vaapi = false;
      intelQSV = true;
    };
  };

  git = {
    enable = true;
  };

  hardware = {};

  services.openssh.enable = true;

  services.transmission = {
    enable = true;
    openRPCPort = true;
    package = system-definition.transmission_4-gtk;
    settings = {
      rpc-bind-address = "0.0.0.0";
      rpc-whitelist-enable = false;
      rpc-whitelist = "127.0.0.1,10.0.0.1,192.168.122.1";
    };
    settings = {
      download-dir = "/home/${vars.user}/ServerData/downbox";
    };
  };

  environment = {
    systemPackages = (with system-definition; [
      # ungoogled-chromium
      transmission_4-gtk
      git
      # zed-editor
      # vscode
      # keepassxc
      librewolf
      # gimp
      # discord
      # bruno
      # jellyfin-media-player 
      # obs-studio
      # bottles
      tailscale
      # krita
      # firefox-devedition
      # atlauncher
      # osu-lazer
    ]) ++ (with system-definition.kdePackages; [
      # kate
      # partitionmanager
      # kdenlive
    ]) ++
    (with unstable; [
      # Apps
      # firefox # Browser
      # image-roll # Image Viewer
    ]);
  };


  # tailscale = {
  #   enable = true;
  #   authKeyFile = config.age.secrets."tailscale/preauth-server".path;
  #   loginServer = "http://192.168.1.5:8181"; 
  # };
  
  home-manager.users.${vars.user} = {
    imports = [
      inputs.plasma-manager-stable.homeManagerModules.plasma-manager
    ];
    xdg.userDirs = {
      enable = true;
      createDirectories = true;

      # Add custom directories
      extraConfig = {
        XDG_SERVERDATA_DIR = "/home/${vars.user}/ServerData";
        XDG_DOWNBOX_DIR = "/home/${vars.user}/ServerData/downbox";
      };
    };
  };
}
