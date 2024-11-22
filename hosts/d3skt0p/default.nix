{ pkgs, config, vars, inputs, ... }:

let

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

  d3skt0p-plasma6.enable = true;

  hardware = {};

  environment = {
    systemPackages = with pkgs; [
      kdePackages.kate
      kdePackages.partitionmanager
      ungoogled-chromium
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
      firefox-devedition
      atlauncher
    ];
  };



  
  home-manager.users.${vars.user} = {
    imports = [
      inputs.plasma-manager.homeManagerModules.plasma-manager
    ];
    programs = {
      vscode = {
        enable = true;
        extensions = [pkgs.vscode-extensions.ms-vscode-remote.remote-ssh pkgs.vscode-extensions.ms-vscode-remote.remote-containers pkgs.vscode-extensions.ms-vscode-remote.remote-ssh-edit];
        userSettings = {
          "editor.wordWrap" = "on";
        };
      };
      git = {
        enable = true;
        userEmail = "exil@n0t3x1l.dev";
        userName = "Exil";
      };
    };
  };
}
