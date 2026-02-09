{
  config,
  vars,
  unstable,
  stable,
  system-definition,
  lib,
  inputs,
  ...
}: let
in {
  imports =
    [
      ./hardware-configuration.nix
      ../../modules/services/mounter.nix
      ../../modules/services/sync-secrets.nix
      ../../modules/services/immich-oci
      ../../modules/services/immich-backup
      ../../modules/desktops/virtualisation/docker.nix
      ../../modules/services/transmission.nix
      ../../modules/services/htpc-downloader
      ../../modules/programs/jellyfin.nix
      ../../modules/programs/jellyfin-player.nix
      ../../modules/services/metrics-agent
      ../../modules/services/myexpenses-upload
      ../../modules/services/excalidraw.nix
    ]
    ++ (import ../../modules/desktops/virtualisation);

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
    extraGroups = ["transmission"];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIItpAE9vRUSAOZAqG9rUmS58ANi/kIIdM9Ki34kEARIP exilvm@3x1l-d3skt0p"
    ];
  };

  docker = {
    enable = true;
    dataRoot = "/var/lib/docker";
  };

  services.immich-oci.enable = true;

  services.myexpenses-upload = {
    enable = true;
    host = "myexpenses.kyrena.dev";
    path = "/upload";
    finalDir = "/mnt/1TB-ST1000DM010-2EP102/databox/other/MyExpenses";
  };

  services.excalidraw.enable = true;

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
    user = vars.user;
    group = "users";
  };

  networking = {
    hostName = "echo";
    networkmanager.enable = true;
    firewall.allowedTCPPorts = [80 443];
  };

  programs.nix-ld.enable = true;

  gnome = {
    enable = true;

    displayManager.defaultSession = "gnome";

    nightLight = {
      enable = true;
      temperature = 4000;
    };

    interface = {
      colorScheme = "prefer-dark";
      clockShowDate = true;
      clockShowSeconds = false;
    };

    fileManager = {
      confirmTrash = false;
      defaultView = "list-view";
      useTreeView = true;
      sortDirectoriesFirst = true;
      showCreateLink = true;
    };

    wm = {
      focusMode = "click";
      buttonLayout = "appmenu:minimize,maximize,close";
    };

    # Echo-specific settings
    extraDconfSettings = {};
  };

  services.pulseaudio.enable = false;
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
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  services.transmission.settings = {
    download-dir = "/mnt/1TB-ST1000DM010-2EP102/downbox/htpc/other";
    peer-limit-global = 200;
  };

  age.secrets."metrics/token".file = ../../secrets/metrics/token.age;

  services.metrics-agent = {
    enable = true;
    serverUrl = "https://exil.kyrena.dev";
    authTokenFile = config.age.secrets."metrics/token".path;
    interval = 5;
    gpu = "intel";
  };

  programs.htpc-downloader = {
    enable = true;
    mediaDir = "/mnt/1TB-ST1000DM010-2EP102/downbox";
    user = vars.user;
  };

  # Tailscale Configuration
  age.secrets."cloudflare/kyrena.dev-DNS-RW".file = ../../secrets/cloudflare/kyrena.dev-DNS-RW.age;
  # age.secrets."reddit/reddit-cleaner".file = ../../secrets/reddit/reddit-cleaner.age;
  age.secrets."cloudflare/kyrena.dev-tunnel-echo2world" = {
    file = ../../secrets/cloudflare/kyrena.dev-tunnel-echo2world.age;
    owner = vars.user;
    # group = config.services.cloudflared.group;
    mode = "400";
  };

  age.secrets."cloudflare/email".file = ../../secrets/cloudflare/email.age;

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
          # Add this transport section for Immich timeout handling
          transport = {
            respondingTimeouts = {
              readTimeout = "600s";
              writeTimeout = "600s";
              idleTimeout = "600s";
            };
          };
          http.tls = {
            certResolver = "cloudflare";
            domains = [
              {
                main = "kyrena.dev";
                sans = ["*.kyrena.dev"];
              }
            ];
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
          immich = {
            rule = "Host(`immich.kyrena.dev`)";
            entryPoints = ["websecure"];
            service = "immich";
            tls = {
              certResolver = "cloudflare";
            };
          };
          jellyfin = {
            rule = "Host(`jellyfin.kyrena.dev`)";
            entryPoints = ["websecure"];
            service = "jellyfin";
            tls = {
              certResolver = "cloudflare";
            };
          };
          transmission = {
            rule = "Host(`dl.kyrena.dev`)";
            entryPoints = ["websecure"];
            service = "transmission";
            tls = {
              certResolver = "cloudflare";
            };
          };
          excalidraw = {
            rule = "Host(`draw.kyrena.dev`)";
            entryPoints = ["websecure"];
            service = "excalidraw";
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
          immich.loadBalancer.servers = [
            {url = "http://127.0.0.1:2283";}
          ];
          transmission.loadBalancer.servers = [
            {
              url = "http://127.0.0.1:9091";
            }
          ];
          excalidraw.loadBalancer.servers = [
            {
              url = "http://127.0.0.1:8081";
            }
          ];
        };
      };
    };
  };
  services.traefik.environmentFiles = [
    # config.age.secrets."cloudflare/email".path
    config.age.secrets."cloudflare/kyrena.dev-DNS-RW".path
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
          nameservers.global = ["1.1.1.1"]; # TODO: and 100.100.100.100?
          base_domain = "kyrena.dev";
        };
        server_url = "https://headscale.kyrena.dev";
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

  # services.reddit-auto-delete = {
  #   enable = false;
  #   interval = "72h";
  #   environmentFile = config.age.secrets."reddit/reddit-cleaner".path;
  # };

  services.cloudflared = {
    enable = true;
    # user = vars.user;
    tunnels = {
      "64911839-8e12-46f9-9f31-2e8a84fd5406" = {
        credentialsFile = "${config.age.secrets."cloudflare/kyrena.dev-tunnel-echo2world".path}";
        ingress = {
          "jellywrld.kyrena.dev" = "http://localhost:8096";
        };
        default = "http_status:404";
      };
    };
  };

  jellyfin-player = {
    enable = true;
  };

  # System Packages
  environment.systemPackages =
    (with system-definition; [
      compose2nix
      cloudflared
      transmission_4-gtk
      git
      curl
      bottles
      certbot
    ])
    ++ (with system-definition.kdePackages; [
      ])
    ++ (with unstable; [
      ]);

  # Home Manager Configuration
  home-manager.users.${vars.user} = {
    imports = [
      inputs.plasma-manager-stable.homeModules.plasma-manager
    ];
  };
}
