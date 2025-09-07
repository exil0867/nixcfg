{ config, pkgs, lib, vars, ... }:

let
  serviceConfigRoot = "/mnt/1TB-ST1000DM010-2EP102/srv/immich";
  # immichDataDir = "/mnt/1TB-ST1000DM010-2EP102/srv/immich";
  # photosDir = "/mnt/1TB-ST1000DM010-2EP102/databox/photos";
  oldGalleryDir = "/mnt/1TB-ST1000DM010-2EP102/databox/photoprism-gallery";
  oldImmichGalleryDir = "/mnt/1TB-ST1000DM010-2EP102/databox/immich-gallery/";
  directories = [
    "${serviceConfigRoot}/"
    "${serviceConfigRoot}/data"
    "${serviceConfigRoot}/postgresql/data"
    # "${serviceConfigRoot}/config"
    # "${serviceConfigRoot}/machine-learning"
    # "${photosDir}"
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
    # This service creates the dedicated network for the containers to talk to each other.
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

    # systemd.tmpfiles.rules = [
    #   "d ${immichDataDir}/config 0755 1000 -"
    #   "d ${immichDataDir}/ml 0755 root root -"
    #   "d ${immichDataDir}/postgres 0755 root root -"
    #   "d ${photosDir} 0755 root root -"
    #   "d ${oldGalleryDir} 0755 root root -"
    # ];

    virtualisation.oci-containers.backend = "docker";

    virtualisation.oci-containers.containers = {
      immich = {
        image = "ghcr.io/immich-app/immich-server:release";
        autoStart = true;
        environmentFiles = [ config.age.secrets."immich/index".path ];
        user = "1001";
        # user = vars.user;
        environment = {
          # PUID = "1001";
          # PGID = "100";
          TZ = "Africa/Tunis";
          IMMICH_VERSION = "release";
          # DB_DATA_LOCATION = "./postgres";
          # UPLOAD_LOCATION = "./library";
          # KEY CHANGE: Use container names as hostnames instead of 127.0.0.1
          DB_HOSTNAME = "immich_postgres";
          DB_PORT = "5432";
          DB_USERNAME = "postgres";
          DB_DATABASE_NAME = "immich";
          REDIS_HOSTNAME = "immich_valkey";
          REDIS_PORT = "6379";
          # DB_PASSWORD = config.services.immich-oci.db.password;
          # The rest of your environment variables are fine
          # SERVER_HOST = "0.0.0.0";
          # SERVER_PORT = "8080";
          # DISABLE_MACHINE_LEARNING = "false";
          # DISABLE_TYPESENSE = "false";
          # CUDA_ACCELERATION = "false";
        };
        volumes = [
          # "${serviceConfigRoot}/config:/config"
          # "${photosDir}:/photos"
          "${serviceConfigRoot}/data:/data"
          "${oldGalleryDir}:/mnt/media/photoprism-gallery:ro"
          "${oldImmichGalleryDir}:/mnt/media/immich-gallery:ro"
          "/etc/localtime:/etc/localtime:ro"
          # "${serviceConfigRoot}/machine-learning:/config/machine-learning"
        ];
        ports = ["0.0.0.0:2283:2283"]; # Expose the main Immich UI to the host
        dependsOn = ["immich_postgres" "immich_valkey" "immich_ml"];
        # KEY CHANGE: Attach this container to the dedicated network
        extraOptions = [ "--network=immich-net" ];
      };

      immich_ml = {
        image = "ghcr.io/immich-app/immich-machine-learning:release";
        autoStart = true;
        volumes = [
          "immich_ml-model-cache:/cache"
        ];
        # KEY CHANGE: Attach this container to the dedicated network
        extraOptions = [ "--network=immich-net" ];
        # Port mapping is no longer needed for other containers to connect
      };

      immich_valkey = {
        image = "valkey/valkey:8-bookworm";
        autoStart = true;
        # KEY CHANGE: Attach this container to the dedicated network
        extraOptions = [ "--network=immich-net" ];
        # Port mapping is no longer needed for other containers to connect
      };

      immich_postgres = {
        image = "ghcr.io/immich-app/postgres:14-vectorchord0.3.0-pgvectors0.2.0";
        user = "1001";
        autoStart = true;
        environmentFiles = [ config.age.secrets."immich/index".path ];
        environment = {
          POSTGRES_USER = "postgres";
          # POSTGRES_PASSWORD = config.services.immich-oci.db.password;
          POSTGRES_DB = "immich";
          DB_STORAGE_TYPE = "HDD";
        };
        volumes = [
          "${serviceConfigRoot}/postgresql/data:/var/lib/postgresql/data"
        ];
        # KEY CHANGE: Attach this container to the dedicated network
        extraOptions = [ "--network=immich-net" ];
        # Port mapping is no longer needed for other containers to connect
      };
    };
  };
}