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
  boot.loader = {
    grub = {
      enable = true;
      device = "/dev/vda";
      useOSProber = true;
      enableCryptodisk = true;
    };
    efi.canTouchEfiVariables = true;
    timeout = 5;
  };

  boot.initrd = {
    secrets."/boot/crypto_keyfile.bin" = null;
    luks.devices."luks-5e1b7503-7da3-49fa-bdcd-caa168dc28d5".keyFile = "/boot/crypto_keyfile.bin";
  };

  networking.hostName = "server";

  # Enable GNOME
  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Jellyfin Configuration
  services.jellyfin = {
    enable = true;
    openFirewall = true;
    user = vars.user;
  };

  # Git Configuration
  programs.git.enable = true;

  # Hardware Configuration
  hardware = {};

  # OpenSSH
  services.openssh.enable = true;

  # Transmission Configuration
  services.transmission = {
    enable = true;
    openRPCPort = true;
    package = system-definition.transmission_4-gtk;
    settings = {
      rpc-bind-address = "0.0.0.0";
      rpc-whitelist-enable = false;
      rpc-whitelist = "127.0.0.1,10.0.0.1,192.168.122.1";
      download-dir = "/home/${vars.user}/ServerData/downbox";
    };
  };

  # Tailscale Configuration
  age.secrets."cloudflare/n0t3x1l.dev-DNS-RW".file = ../../secrets/cloudflare/n0t3x1l.dev-DNS-RW.age;
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  # ACME (Let's Encrypt) Configuration
  security.acme = {
    acceptTerms = true;
    defaults.email = "exiL@n0t3x1l.dev";
    certs."n0t3x1l.dev" = {
      group = config.services.caddy.group;
      domain = "n0t3x1l.dev";
      extraDomainNames = [ "*.n0t3x1l.dev" ];
      dnsProvider = "cloudflare";
      dnsResolver = "1.1.1.1:53";
      dnsPropagationCheck = true;
      environmentFile = config.age.secrets."cloudflare/n0t3x1l.dev-DNS-RW".path;
    };
  };

  # Caddy Configuration
  services.caddy = {
    enable = true;
    virtualHosts."jellyfin.n0t3x1l.dev".extraConfig = ''
      reverse_proxy http://localhost:8096
      tls /var/lib/acme/n0t3x1l.dev/cert.pem /var/lib/acme/n0t3x1l.dev/key.pem {
        protocols tls1.3
      }
    '';
    virtualHosts."ok.n0t3x1l.dev".extraConfig = ''
      respond "OK"
      tls /var/lib/acme/n0t3x1l.dev/cert.pem /var/lib/acme/n0t3x1l.dev/key.pem {
        protocols tls1.3
      }
    '';
  };

  # System Packages
  environment.systemPackages = (with system-definition; [
    transmission_4-gtk
    git
    nginx
    certbot
    librewolf
    tailscale
  ]) ++ (with system-definition.kdePackages; [
    # kate
    # partitionmanager
    # kdenlive
  ]) ++ (with unstable; [
    # firefox
    # image-roll
  ]);

  # Home Manager Configuration
  home-manager.users.${vars.user} = {
    imports = [
      inputs.plasma-manager-stable.homeManagerModules.plasma-manager
    ];
    xdg.userDirs = {
      enable = true;
      createDirectories = true;
      extraConfig = {
        XDG_SERVERDATA_DIR = "/home/${vars.user}/ServerData";
        XDG_DOWNBOX_DIR = "/home/${vars.user}/ServerData/downbox";
      };
    };
  };
}
