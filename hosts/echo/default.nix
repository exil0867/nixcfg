{ config, vars, unstable, stable, system-definition, inputs, ... }:

let
in
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/services/mounter.nix
    ../../modules/services/sync-secrets.nix
    ../../modules/desktops/virtualisation/docker.nix
  ] ++
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

  users.users.${vars.user} = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIItpAE9vRUSAOZAqG9rUmS58ANi/kIIdM9Ki34kEARIP exilvm@3x1l-d3skt0p"
    ];
  };

  mounter.mounts = [
    {
      mountPoint = "/mnt/1TB-ST1000DM010-2EP102";
      deviceUUID = "8661c3d7-ab61-4ac7-a542-51a74b946b9f";
      user = vars.user;
      group = "users";
      encrypted = true;
      luksName = "cryptdata";
    }
    {
      mountPoint = "/mnt/1TB-TOSHIBA-MQ04ABF100";
      deviceUUID = "a6a28b6e-e366-40c5-94ad-fca5d2f6cce5";
      user = vars.user;
      group = "users";
    }
  ];

  syncSecrets = {
    enable = true;
    secretsDir = "/home/${vars.user}/nixcfg/secrets-sync";
    user = vars.user;
    group = "users";
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
    dataDir = "/mnt/1TB-ST1000DM010-2EP102/data/jellyfin";
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
      download-dir = "/mnt/1TB-ST1000DM010-2EP102/downbox";
    };
  };

  # Tailscale Configuration
  age.secrets."cloudflare/n0t3x1l.dev-DNS-RW".file = ../../secrets-sync/cloudflare/n0t3x1l.dev-DNS-RW.age;
  age.secrets."reddit/reddit-cleaner".file = ../../secrets-sync/reddit/reddit-cleaner.age;
  age.secrets."cloudflare/n0t3x1l.dev-tunnel-echo2world" = {
    file = ../../secrets-sync/cloudflare/n0t3x1l.dev-tunnel-echo2world.age;
    owner = vars.user;
    group = config.services.cloudflared.group;
    mode = "400";
  };

  age.secrets."cloudflare/email".file = ../../secrets-sync/cloudflare/email.age;
  networking.firewall.allowedTCPPorts = [ 80 443 ];

#   # ACME (Let's Encrypt) Configuration
#  security.acme = {
#    acceptTerms = true;
#    defaults.email = "exiL@n0t3x1l.dev";
#    certs."n0t3x1l.dev" = {
#      group = config.services.caddy.group;
#      domain = "n0t3x1l.dev";
#      extraDomainNames = [ "*.n0t3x1l.dev" ];
#      dnsProvider = "cloudflare";
#      dnsResolver = "1.1.1.1:53";
#      dnsPropagationCheck = true;
#      environmentFile = config.age.secrets."cloudflare/n0t3x1l.dev-DNS-RW".path;
#    };
#  };

 git = {
    enable = true;
  };

services.traefik = {
      enable = true;
      

      staticConfigOptions = {
        entryPoints = {
          web = {
            address = ":80";
            http.redirections.entryPoint = {
              to = "websecure";
              scheme = "https";
              permanent = true;
            };
          };

          websecure = {
            address = ":443";
            forwardedHeaders = {
              trustedIPs = ["127.0.0.1/32" "::1/128" "192.168.1.0/24"];
            };
            # http.tls = {
            #   certResolver = "cloudflare";
            #   domains = [{ main = "n0t3x1l.dev"; sans = [ "*.n0t3x1l.dev" ]; }];
            # };
          };
        };

        certificatesResolvers.cloudflare.acme = {
          email = "exil@n0t3x1l.dev";
          storage = "/var/lib/traefik/acme.json";
          dnsChallenge = {
            provider = "cloudflare";
            resolvers = ["1.1.1.1:53" "1.0.0.1:53"];
          };
          # Add the Cloudflare API token
          # dnsChallenge.env.CF_DNS_API_TOKEN = "your-cloudflare-api-token";
        };
      };

      dynamicConfigOptions = {
        http = {
          routers = {
            jellyfin = {
              rule = "Host(`jellyfin.n0t3x1l.dev`)";
              entryPoints = ["websecure"];
              service = "jellyfin";
              tls = {
                certResolver = "cloudflare";
              };
            };

            transmission = {
              rule = "Host(`dl.n0t3x1l.dev`)";
              entryPoints = ["websecure"];
              service = "transmission";
              tls = {
                certResolver = "cloudflare";
              };
            };
          };

          services = {
            jellyfin.loadBalancer.servers = [
              {
                url = "http://127.0.0.1:8096";
              }
            ];

            transmission.loadBalancer.servers = [
              {
                url = "http://127.0.0.1:9091";
              }
            ];
          };
        };
      };
    };
services.traefik.environmentFiles = [
        # config.age.secrets."cloudflare/email".path
        config.age.secrets."cloudflare/n0t3x1l.dev-DNS-RW".path
      ];

    # Ensure the Traefik directory exists
    systemd.services.traefik.preStart = ''
      mkdir -p /var/lib/traefik
      chown -R traefik:traefik /var/lib/traefik
    '';
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

  services.reddit-auto-delete = {
    enable = true;
    interval = "72h";
    environmentFile = config.age.secrets."reddit/reddit-cleaner".path;
  };

  services.cloudflared = {
    enable = true;
    user = vars.user;
    tunnels = {
      "64911839-8e12-46f9-9f31-2e8a84fd5406" = {
        credentialsFile = "${config.age.secrets."cloudflare/n0t3x1l.dev-tunnel-echo2world".path}";
        ingress = {
          "jellywrld.n0t3x1l.dev" = "http://localhost:8096";
        };
        default = "http_status:404";
      };
    };
  };

  jellyfin-player = {
    enable = true;
  };

  docker = {
    enable = true;
  };

  # System Packages
  environment.systemPackages = (with system-definition; [
    compose2nix
    cloudflared
    transmission_4-gtk
    git
    curl
    nginx
    bottles
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
  };
}
