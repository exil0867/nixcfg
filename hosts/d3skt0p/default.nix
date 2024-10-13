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
      firefox-devedition
    ];
  };

  sops = {

    defaultSopsFile = secretsFile;
    age.keyFile = "/home/${vars.user}/.config/sops/age/keys.txt";
    secrets."tailscale/s3rv3r/key" = {};
  };

  services.tailscale.enable = true;

  systemd.services.tailscale-autoconnect = {
    description = "Automatic connection to Tailscale";

    # make sure tailscale is running before trying to connect to tailscale
    after = [ "network-pre.target" "tailscale.service" ];
    wants = [ "network-pre.target" "tailscale.service" ];
    wantedBy = [ "multi-user.target" ];

    # set this service as a oneshot job
    serviceConfig.Type = "oneshot";

    # have the job run this shell script
    script = with pkgs; ''
      # wait for tailscaled to settle
      sleep 2

      # check if we are already authenticated to tailscale
      status="$(${tailscale}/bin/tailscale status -json | ${jq}/bin/jq -r .BackendState)"
      if [ $status = "Running" ]; then # if so, then do nothing
        exit 0
      fi

      # otherwise authenticate with tailscale
      ${tailscale}/bin/tailscale up --login-server=192.168.1.5 --authkey $(cat /run/secrets/tailscale/s3rv3r/key)
    '';
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
