{ config, pkgs, lib, ... }: {
  imports = [
    # ./services/arr.nix
    # ./services/webdav.nix
    # ./services/filebrowser.nix
    # ./services/portainer.nix
    # ./services/heimdall.nix
    # ./services/heimdall-bspwr.nix
    ./services/jellyfin.nix
    # ./services/headscale.nix
    # ./services/poste.nix
    # ./services/coturn.nix
    # ./services/virt-manager.nix
    # ./services/blog.nix
    # ./services/mullvad-usa.nix
    # ./services/mullvad-sweden.nix
    # ./services/gitea.nix
    # ./services/lxdware.nix
    # ./services/projectsend.nix
    # ./services/photoprism.nix
    # ./services/nextcloud.nix
    # ./services/incognito.nix
    # ./services/piped.nix
    # ./services/traefik.nix
    # ./services/jitsi.nix
    # ./services/matrix.nix
    # ./services/socks-proxy.nix
    # ./services/syncthing.nix
    # ./services/immich.nix
  ];

  # docker autoheal tool
  virtualisation.oci-containers.containers."dependheal" = {
    autoStart = true;
    image = "ghcr.io/whimbree/dependheal:latest";
    volumes = [ "/var/run/docker.sock:/var/run/docker.sock" ];
    environment = { DEPENDHEAL_ENABLE_ALL = "true"; };
  };

  # open TCP port 80 443 for Traefik
  # open TCP port 18089 for Monero Node
  # open TCP port 25565 25585 for Minecraft
  # open TCP port 25 110 143 465 587 993 995 for poste.io
  # open TCP port 3478 for TURN Server
  # open TCP port 2222 for Gitea SSH
  # open TCP port 2200 for Endlessh SSH Tarpit
  networking.firewall.allowedTCPPorts = [
    80
    443
    18089
    25565
    25585
    25
    110
    143
    465
    587
    993
    995
    3478
    2222
    2200
    8096
    8920
  ];

  # open UDP port 3478 for TURN Server
  # open UDP port 10000 for Jitsi Meet
  networking.firewall.allowedUDPPorts = [ 3478 10000 8096 8920];
}