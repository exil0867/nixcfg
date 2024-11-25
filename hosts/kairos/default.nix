{ pkgs, config, vars, inputs, ... }:

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

  netwokring = {
    hostName = "kairos";
  };

  kairos-plasma6.enable = true;

  hardware = {};

  environment = {
    systemPackages = (with pkgs; [
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
    ]) ++ (with pkgs.kdePackages; [
      kate
      partitionmanager
      kdenlive
    ]);
  };


  services.tailscale.enable = true;

 systemd.services.tailscale-autoconnect = {
    description = "Automatic connection to Tailscale";

    after = [ "network-pre.target" "tailscale.service" ];
    wants = [ "network-pre.target" "tailscale.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig.Type = "oneshot";

    script = with pkgs; ''
      # wait for tailscaled to settle
      sleep 2

      # check if we are already authenticated to tailscale
      status="$(${tailscale}/bin/tailscale status -json | ${jq}/bin/jq -r .BackendState)"
      if [ $status = "Running" ]; then # if so, then do nothing
        exit 0
      fi

      # otherwise authenticate with tailscale
      ${tailscale}/bin/tailscale up --login-server http://192.168.1.5:8181 -authkey "$(cat ${config.age.secrets."tailscale/preauth-kairos".path})"
    '';
  };
  
  home-manager.users.${vars.user} = {
    imports = [
      inputs.plasma-manager.homeManagerModules.plasma-manager
    ];
    programs = {
      vscode = {
        enable = true;
        extensions = [pkgs.vscode-extensions.ms-vscode-remote.remote-ssh pkgs.vscode-extensions.ms-vscode-remote.remote-containers pkgs.vscode-extensions.ms-vscode-remote.remote-ssh-edit pkgs.vscode-extensions.jnoortheen.nix-ide];
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
