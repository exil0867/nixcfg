{ pkgs, vars, inputs, ... }:

let
  secretsFile = builtins.path {
    name = "secrets";
    path = ../../secrets/d3skt0p.yaml;
  };
in

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/programs/games.nix
  ] ++
  (import ../../modules/hardware/d3skt0p) ++
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

  plasma6.enable = true;

  hardware = {};

  environment = {
    systemPackages = with pkgs; [
      kdePackages.kate
      kdePackages.partitionmanager
      git
      zed-editor
      vscode
      keepassxc
      librewolf
      gimp
      jellyfin-media-player 
      obs-studio
      bottles
      tailscale
      krita
    ];
  };

  sops = {

    defaultSopsFile = secretsFile;
    age.keyFile = "/home/${vars.user}/.config/sops/age/keys.txt";
    secrets."user-pwd" = {};
  };

  services.tailscale.enable = true;
  
  home-manager.users.${vars.user} = {
    imports = [
      inputs.plasma-manager.homeManagerModules.plasma-manager
    ];
    programs = {
      plasma = {
        enable = true;
        workspace.lookAndFeel = "org.kde.breezedark.desktop";
      };
      git = {
        userEmail = "exil@n0t3x1l.dev";
        userName = "Exil";
      };
    };
  };
}
