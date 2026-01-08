{ config, vars, unstable, stable, system-definition, inputs, ... }:

let
in
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/services/sync-secrets.nix
    ../../modules/services/transmission.nix
    ../../modules/services/htpc-downloader
    ../../modules/services/personal-website
    ../../modules/services/metrics-server
    ../../modules/services/metrics-agent
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

  # Personal Website Configuration
  services.personal-website = {
    enable = true;
    domain = "exil.kyrena.dev";
  };


  programs.nix-ld.enable = true;

  users.users.${vars.user} = {
    extraGroups = [ "transmission" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIItpAE9vRUSAOZAqG9rUmS58ANi/kIIdM9Ki34kEARIP exilvm@3x1l-d3skt0p"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIInjI+XzPKAmRH/S/zpx4XVusY8W0IbG6cithnOZBZJo exil@n0t3x1l.dev"
    ];
  };

  networking = {
    hostName = "sky";
    networkmanager.enable = true;
    # Open firewall ports for HTTP/HTTPS
    firewall.allowedTCPPorts = [ 80 443 ];
  };

  # Enable SSH for remote management
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  age.secrets."metrics/token" = {
    file = ../../secrets-sync/metrics/token.age;
    mode = "0400";
  };

  services.metrics-server = {
    enable = true;
  };

  services.metrics-agent = {
    enable = true;
    serverUrl = "https://exil.kyrena.dev";
    authTokenFile = config.age.secrets."metrics/token".path;
    interval = 5;
    gpu = "none";
  };

  # Jellyfin Configuration
  services.jellyfin = {
    enable = true;
    openFirewall = true;
    dataDir = "/data/jellyfin";
    user = vars.user;
  };

  services.transmission.settings = {
    download-dir = "/home/${vars.user}/Data/downbox";
    peer-limit-global = 200;
  };

  programs.htpc-downloader = {
    enable = true;
    mediaDir = "/home/${vars.user}/Data/downbox";
    user = vars.user;
  };


  syncSecrets = {
    enable = true;
    secretsDir = "/home/${vars.user}/Develop/nixcfg/secrets-sync";
    user = vars.user;
    group = "users";
  };


  # age.secrets."deluge/auth" = {
  #   file = ../../secrets/deluge/auth.age;
  #   owner = vars.user;
  #   group = "users";
  #   mode = "0400";
  # };

  # Add this to your configuration
  # services.deluge = {
  #   enable = false;
  #   web.enable = true;
  #   web.openFirewall = true;
  #   declarative = true;
  #   # dataDir = "/home/${vars.user}/data/deluge";
  #   user = vars.user;
  #   group = "users";
    
  #   # Basic configuration
  #   config = {
  #     allow_remote = true;
  #     daemon_port = 58846;
  #     # download_location = "/home/${vars.user}/data/deluge/downloads";
  #     # max_upload_speed = "1000.0";
  #     # share_ratio_limit = "2.0";
  #     listen_ports = [51413 51413]; # Single port for better firewall management
  #     random_port = false;
  #   };
    
  #   # Reference to auth file managed by agenix
  #   authFile = config.age.secrets."deluge/auth".path;
  # };

  # Traefik Configuration
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
            trustedIPs = ["127.0.0.1/32" "::1/128"];
          };
          http.tls = {
            certResolver = "cloudflare";
            domains = [{ main = "kyrena.dev"; sans = [ "*.kyrena.dev" ]; }];
          };
        };
      };
      certificatesResolvers.cloudflare.acme = {
        email = "exil@kyrena.dev";
        storage = "/var/lib/traefik/acme.json";
        dnsChallenge = {
          provider = "cloudflare";
          resolvers = ["1.1.1.1:53" "1.0.0.1:53"];
        };
      };
    };

    dynamicConfigOptions = {
      http = {
        routers = {
          jellyfin = {
            rule = "Host(`jellysky.kyrena.dev`)";
            entryPoints = ["websecure"];
            service = "jellyfin";
            tls = {
              certResolver = "cloudflare";
            };
          };
        };

        services = {
          jellyfin.loadBalancer.servers = [{
            url = "http://127.0.0.1:8096";
          }];
        };
      };
    };
  };

  age.secrets."cloudflare/kyrena.dev-DNS-RW".file = ../../secrets-sync/cloudflare/kyrena.dev-DNS-RW.age;

  services.traefik.environmentFiles = [
    config.age.secrets."cloudflare/kyrena.dev-DNS-RW".path
  ];

  # Ensure the Traefik directory exists
  systemd.services.traefik.preStart = ''
    mkdir -p /var/lib/traefik
    chown -R traefik:traefik /var/lib/traefik
  '';

  # Git Configuration
  programs.git.enable = true;

  # Basic System Packages
  environment.systemPackages = with system-definition; [
    git
    curl 
    wget
    # vim
    htop
    tmux
    traefik
    aria2
  ];

  # Home Manager Configuration
  home-manager.users.${vars.user} = {
    programs = {
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
          plugins = [ "git" ];
          theme = "robbyrussell";
        };
      };
    };
  };
}