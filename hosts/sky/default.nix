{ config, vars, unstable, stable, system-definition, inputs, ... }:

let
in
{
  imports = [
    ./hardware-configuration.nix
  ];

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
    hostName = "sky";
    networkmanager.enable = true;
  };

  # Enable SSH for remote management
  services.openssh = {
    enable = true;
    authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIItpAE9vRUSAOZAqG9rUmS58ANi/kIIdM9Ki34kEARIP exilvm@3x1l-d3skt0p"
    ];
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Git Configuration
  programs.git.enable = true;

  # Basic System Packages
  environment.systemPackages = with system-definition; [
    git
    curl
    wget
    vim
    htop
    tmux
  ];

  # Home Manager Configuration
  home-manager.users.${vars.user} = {
    programs = {
      ssh = {
        enable = true;
      };
      zsh = {
        enable = true;
        enableCompletion = true;
        syntaxHighlighting.enable = true;

        shellAliases = {
          ll = "ls -l";
          update = "sudo nixos-rebuild switch";
        };
        history = {
          size = 10000;
        };
        oh-my-zsh = {
          enable = true;
          plugins = [ "git" "thefuck" ];
          theme = "robbyrussell";
        };
      };
    };
  };
}