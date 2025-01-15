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
    hostName = "echo";
  };

  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  programs.nix-ld.enable = true;

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Enable sound with pipewire.
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  
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
    enable = false;
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

 git = {
    enable = true;
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

  services = {
    headscale = {
      enable = false;
      address = "0.0.0.0";
      port = 8888;
      settings = {
        dns = {
          override_local_dns = true;
          nameservers.global = [ "1.1.1.1" ]; # TODO: and 100.100.100.100?
          base_domain = "n0t3x1l.dev";
        };
        server_url = "https://headscale.n0t3x1l.dev";
        logtail.enabled = false;
        # log.level = "warn";
        # ip_prefixes
        derp.server = {
          enable = true;
          region_id = 999;
          stun_listen_addr = "0.0.0.0:8888";
        };
      };
    };
  };


  # System Packages
  environment.systemPackages = (with system-definition; [
    transmission_4-gtk
    git
    nginx
    certbot
    librewolf
    tailscale
    headscale
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
