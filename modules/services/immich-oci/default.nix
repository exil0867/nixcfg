{ config, pkgs, lib, vars, ... }:

let
  serviceConfigRoot = "/mnt/1TB-ST1000DM010-2EP102/srv/immich";
  oldGalleryDir = "/mnt/1TB-ST1000DM010-2EP102/databox/photoprism-gallery";
  oldImmichGalleryDir = "/mnt/1TB-ST1000DM010-2EP102/databox/immich-gallery/";
  
  # Pin to specific version to force upgrade
  immichVersion = "v2.3.1";
  
  directories = [
    "${serviceConfigRoot}/"
    "${serviceConfigRoot}/data"
    "${serviceConfigRoot}/postgresql/data"
  ];
in {
  options.services.immich-oci = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Immich via OCI containers";
    };
  };

  config = lib.mkIf config.services.immich-oci.enable {
    age.secrets."immich/index".file = ../../../secrets-sync/immich/index.age;
    systemd.tmpfiles.rules = map (x: "d ${x} 0775 exil0681 users - -") directories;
    
    # Create the dedicated network for the containers
    systemd.services.init-immich-network = {
      description = "Create the network for Immich OCI containers.";
      after = [ "network.target" "docker.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig.Type = "oneshot";
      script = let dockercli = "${config.virtualisation.docker.package}/bin/docker"; in ''
        if [ -z "$(${dockercli} network ls --filter name=^immich-net$ --format="{{ .Name }}")" ]; then
          ${dockercli} network create immich-net
        else
          echo "immich-net network already exists."
        fi
      '';
    };

    virtualisation.oci-containers.backend = "docker";

    virtualisation.oci-containers.containers = {
      immich = {
        image = "ghcr.io/immich-app/immich-server:${immichVersion}";
        autoStart = true;
        environmentFiles = [ config.age.secrets."immich/index".path ];
        user = "1001";
        environment = {
          TZ = "Africa/Tunis";
          IMMICH_VERSION = immichVersion;
          # Use container names as hostnames
          DB_HOSTNAME = "immich_postgres";
          DB_PORT = "5432";
          DB_USERNAME = "postgres";
          DB_DATABASE_NAME = "immich";
          REDIS_HOSTNAME = "immich_valkey";
          REDIS_PORT = "6379";
        };
        volumes = [
          "${serviceConfigRoot}/data:/data"
          "${oldGalleryDir}:/mnt/media/photoprism-gallery:ro"
          "${oldImmichGalleryDir}:/mnt/media/immich-gallery:ro"
          "/etc/localtime:/etc/localtime:ro"
        ];
        ports = ["0.0.0.0:2283:2283"];
        dependsOn = ["immich_postgres" "immich_valkey" "immich_ml"];
        extraOptions = [ 
          "--network=immich-net"
          "--health-cmd=wget --no-verbose --tries=1 --spider http://localhost:2283/api/server-info/ping || exit 1"
        ];
      };

      immich_ml = {
        image = "ghcr.io/immich-app/immich-machine-learning:${immichVersion}";
        autoStart = true;
        volumes = [
          "immich_ml-model-cache:/cache"
        ];
        extraOptions = [ 
          "--network=immich-net"
          "--health-cmd=wget --no-verbose --tries=1 --spider http://localhost:3003/ping || exit 1"
        ];
      };

      immich_valkey = {
        image = "valkey/valkey:8-bookworm";
        autoStart = true;
        extraOptions = [ 
          "--network=immich-net"
          "--health-cmd=redis-cli ping || exit 1"
        ];
      };

      immich_postgres = {
        # Updated to VectorChord image (major change in v2.0.0)
        image = "ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0";
        user = "1001";
        autoStart = true;
        environmentFiles = [ config.age.secrets."immich/index".path ];
        environment = {
          POSTGRES_USER = "postgres";
          POSTGRES_DB = "immich";
          POSTGRES_INITDB_ARGS = "--data-checksums";
          # Uncomment if your database is on HDD instead of SSD
          # DB_STORAGE_TYPE = "HDD";
        };
        volumes = [
          "${serviceConfigRoot}/postgresql/data:/var/lib/postgresql/data"
        ];
        extraOptions = [ 
          "--network=immich-net"
          "--shm-size=128m"
        ];
      };
    };
  };
}