{ pkgs, vars, inputs, ... }:

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
    ];
  };

 sops = {
    age.keyFile = "~/.config/sops/age/keys.txt";
    secrets.example-key = {};
    secrets."myservice/my_subdir/my_secret" = {};
  };
  
  home-manager.users.${vars.user} = {
    imports = [
      inputs.plasma-manager.homeManagerModules.plasma-manager
    ];
    programs.plasma = {
      enable = true;
      workspace.lookAndFeel = "org.kde.breezedark.desktop";
    };
  };
}
