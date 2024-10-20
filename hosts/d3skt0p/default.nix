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

  d3skt0p-plasma6.enable = true;

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
      firefox-devedition
    ];
  };

  sops = {

    defaultSopsFile = secretsFile;
    secrets."hello" = {};
  };

  # services.tailscale = {
  #   enable = true;
  #   extraSetFlags = [
  #     "--login-server=192.168.1.5"
  #   ];
  #   # authKeyFile = sops.secrets."tailscale/s3rv3r/key".path;
  # };
  
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
        userEmail = "exil@n0t3x1l.dev";
        userName = "Exil";
      };
    };
  };
}
