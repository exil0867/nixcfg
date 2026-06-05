{ config, lib, ... }:

let
  cfg = config.services.joplin-server-oci;
  dockercli = "${config.virtualisation.docker.package}/bin/docker";
in
{
  options.services.joplin-server-oci = {
    enable = lib.mkEnableOption "Joplin Server via OCI containers";

    hostName = lib.mkOption {
      type = lib.types.str;
      default = "joplin.kyrena.dev";
      description = "Public hostname for Joplin Server.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 22300;
      description = "Local Joplin Server port.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/data/joplin";
      description = "Persistent storage root for Joplin Server.";
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "joplin/server:3.7.1";
      description = "Joplin Server container image.";
    };

    postgresImage = lib.mkOption {
      type = lib.types.str;
      default = "postgres:16";
      description = "PostgreSQL container image.";
    };

    database = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "joplin";
        description = "PostgreSQL database name.";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "joplin";
        description = "PostgreSQL database user.";
      };

      passwordFile = lib.mkOption {
        type = lib.types.path;
        description = "Environment file containing POSTGRES_PASSWORD for both containers.";
      };
    };

    traefik = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Expose Joplin Server through Traefik.";
      };

      entryPoint = lib.mkOption {
        type = lib.types.str;
        default = "websecure";
        description = "Traefik entry point.";
      };

      certResolver = lib.mkOption {
        type = lib.types.str;
        default = "cloudflare";
        description = "Traefik TLS certificate resolver.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 root root - -"
    ];

    virtualisation.docker.enable = true;
    virtualisation.oci-containers.backend = "docker";

    systemd.services.init-joplin-network = {
      description = "Create the Docker network for Joplin Server.";
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig.Type = "oneshot";
      script = ''
        if ! ${dockercli} network inspect joplin-net >/dev/null 2>&1; then
          ${dockercli} network create joplin-net
        fi
      '';
    };

    virtualisation.oci-containers.containers = {
      joplin_postgres = {
        image = cfg.postgresImage;
        autoStart = true;
        environmentFiles = [ cfg.database.passwordFile ];
        environment = {
          POSTGRES_DB = cfg.database.name;
          POSTGRES_USER = cfg.database.user;
        };
        volumes = [
          "${cfg.dataDir}/postgres:/var/lib/postgresql/data"
        ];
        extraOptions = [ "--network=joplin-net" ];
      };

      joplin = {
        image = cfg.image;
        autoStart = true;
        environmentFiles = [ cfg.database.passwordFile ];
        environment = {
          APP_BASE_URL = "https://${cfg.hostName}";
          APP_PORT = toString cfg.port;
          DB_CLIENT = "pg";
          POSTGRES_DATABASE = cfg.database.name;
          POSTGRES_HOST = "joplin_postgres";
          POSTGRES_PORT = "5432";
          POSTGRES_USER = cfg.database.user;
        };
        ports = [ "127.0.0.1:${toString cfg.port}:${toString cfg.port}" ];
        dependsOn = [ "joplin_postgres" ];
        extraOptions = [ "--network=joplin-net" ];
      };
    };

    systemd.services.docker-joplin_postgres = {
      after = [ "init-joplin-network.service" ];
      requires = [ "init-joplin-network.service" ];
    };

    systemd.services.docker-joplin = {
      after = [ "init-joplin-network.service" ];
      requires = [ "init-joplin-network.service" ];
    };

    services.traefik.dynamicConfigOptions = lib.mkIf cfg.traefik.enable {
      http = {
        routers.joplin = {
          rule = "Host(`${cfg.hostName}`)";
          entryPoints = [ cfg.traefik.entryPoint ];
          service = "joplin";
          middlewares = lib.optional (config.traefikOrigin.middlewareName != null) config.traefikOrigin.middlewareName;
          tls.certResolver = cfg.traefik.certResolver;
        };

        services.joplin.loadBalancer.servers = [
          { url = "http://127.0.0.1:${toString cfg.port}"; }
        ];
      };
    };
  };
}
