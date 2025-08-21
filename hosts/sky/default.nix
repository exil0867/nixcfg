{ config, vars, unstable, stable, system-definition, inputs, ... }:

let
in
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/services/sync-secrets.nix
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

  programs.nix-ld.enable = true;

  users.users.${vars.user} = {
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

  # Jellyfin Configuration
  services.jellyfin = {
    enable = true;
    openFirewall = true;
    dataDir = "/data/jellyfin";
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
        };
      };

      certificatesResolvers.letsencrypt.acme = {
        email = "exil@n0t3x1l.dev";
        storage = "/var/lib/traefik/acme.json";
        httpChallenge = {
          entryPoint = "web";
        };
      };
    };

    dynamicConfigOptions = {
      http = {
        routers = {
          jellyfin = {
            rule = "Host(`jellysky.n0t3x1l.dev`)";
            entryPoints = ["websecure"];
            service = "jellyfin";
            tls = {
              certResolver = "letsencrypt";
            };
          };
          # Add Deluge router
          deluge = {
            rule = "Host(`dlsky.n0t3x1l.dev`)";
            entryPoints = ["websecure"];
            service = "deluge";
            tls = {
              certResolver = "letsencrypt";
            };
          };
        };

        services = {
          jellyfin.loadBalancer.servers = [{
            url = "http://127.0.0.1:8096";
          }];
          # Add Deluge service
          deluge.loadBalancer.servers = [{
            url = "http://127.0.0.1:8112";
          }];
        };
      };
    };
  };

  age.secrets."cloudflare/n0t3x1l.dev-DNS-RW".file = ../../secrets/cloudflare/n0t3x1l.dev-DNS-RW.age;

  services.traefik.environmentFiles = [
    config.age.secrets."cloudflare/n0t3x1l.dev-DNS-RW".path
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
    vim
    htop
    tmux
    traefik
    aria2
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
          plugins = [ "git" ];
          theme = "robbyrussell";
        };
      };
    };
  };
}