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
        };
        
        services = {
          jellyfin.loadBalancer.servers = [{
            url = "http://127.0.0.1:8096";
          }];
        };
      };
    };
  };

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