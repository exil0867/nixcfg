{ config, pkgs, lib, ... }: {
  systemd.services.docker-create-network-jellyfin = {
    enable = true;
    description = "Create jellyfin docker network";
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = "yes";
      ExecStart = pkgs.writeScript "docker-create-network-jellyfin" ''
        #! ${pkgs.runtimeShell} -e
        ${pkgs.docker}/bin/docker network create jellyfin || true
      '';
    };
    after = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
  };

  virtualisation.oci-containers.containers."jellyfin" = {
    autoStart = true;
    image = "lscr.io/linuxserver/jellyfin:latest";
    environment = {
      PUID = "1420";
      PGID = "1420";
      TZ = "America/New_York";
      JELLYFIN_PublishedServerUrl = "jellyfin.bspwr.com"; # optional
    };
    dependsOn = [ "create-network-jellyfin" ];
    extraOptions = [
      # networks
      "--network=jellyfin"
      # healthcheck
      "--health-cmd"
      "curl --fail localhost:8096 || exit 1"
      "--health-interval"
      "10s"
      "--health-retries"
      "6"
      "--health-timeout"
      "2s"
      "--health-start-period"
      "10s"
      # labels
      "--label"
      "traefik.enable=true"
      "--label"
      "traefik.docker.network=jellyfin"
      "--label"
      "traefik.http.routers.jellyfin.rule=Host(`jellyfin.bspwr.com`)"
      "--label"
      "traefik.http.routers.jellyfin.entrypoints=websecure"
      "--label"
      "traefik.http.routers.jellyfin.tls=true"
      "--label"
      "traefik.http.routers.jellyfin.tls.certresolver=porkbun"
      "--label"
      "traefik.http.routers.jellyfin.tls.domains[0].main=*.bspwr.com"
      "--label"
      "traefik.http.routers.jellyfin.service=jellyfin"
      "--label"
      "traefik.http.routers.jellyfin.middlewares=default@file"
      "--label"
      "traefik.http.services.jellyfin.loadbalancer.server.port=8096"
    ];
  };
  virtualisation.oci-containers.containers."tailscale-jellyfin" = {
    autoStart = true;
    image = "ghcr.io/tailscale/tailscale:latest";
    dependsOn = [
      "create-network-jellyfin" "jellyfin"
    ];
    cmd = [ "tailscaled" "--tun=userspace-networking" ];
    extraOptions = [
      # cap_add
      "--cap-add=NET_ADMIN"
      # sysctls
      "--sysctl"
      "net.ipv4.ip_forward=1"
      "--sysctl"
      "net.ipv6.conf.all.forwarding=1"
      # network_mode
      "--net=container:jellyfin"
      # labels
      ## dependheal
      "--label"
      "dependheal.enable=true"
      "--label"
      "dependheal.parent=jellyfin"
    ];
  };
}
