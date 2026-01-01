{ config, pkgs, lib, vars, ... }:

let
  cfg = config.services.trena-backend;
  
  secretName = "trena-secrets";
  decryptedSecretPath = config.age.secrets.${secretName}.path;

  serviceRoot = "/srv/trena";
  trenaVersion = "v3.2.9";

  directories = [
    serviceRoot
    "${serviceRoot}/postgres"
  ];

  dockercli = "${config.virtualisation.docker.package}/bin/docker";
in
{
  options.services.trena-backend = {
    enable = lib.mkEnableOption "Trena backend (OCI containers)";

    domain = lib.mkOption {
      type = lib.types.str;
      example = "trena-api.kyrena.dev";
    };

    secretFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to the age encrypted .env file containing secrets (JWT_SECRET, DB_PASSWORD, etc.)";
      example = ../../secrets/trena.age;
    };
  };

  config = lib.mkIf cfg.enable {

    age.secrets.${secretName} = {
      file = cfg.secretFile;
    };

    systemd.tmpfiles.rules =
      map (d: "d ${d} 0775 ${vars.user} users - -") directories;

    systemd.services.init-trena-network = {
      description = "Create Docker network for Trena";
      after = [ "network.target" "docker.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig.Type = "oneshot";
      script = ''
        if [ -z "$(${dockercli} network ls --filter name=^trena-net$ --format="{{ .Name }}")" ]; then
          ${dockercli} network create trena-net
        else
          echo "trena-net already exists"
        fi
      '';
    };
    
    virtualisation.oci-containers.backend = "docker";

    virtualisation.oci-containers.containers = {

      trena_postgres = {
        image = "postgres:16-bookworm";
        autoStart = true;

        environmentFiles = [ decryptedSecretPath ];

        environment = {
          POSTGRES_DB = "trena";
          POSTGRES_USER = "trena";
        };

        volumes = [
          "${serviceRoot}/postgres:/var/lib/postgresql/data"
        ];

        extraOptions = [
          "--network=trena-net"
          "--health-cmd=pg_isready -U trena"
        ];
      };

      trena_backend = {
        image = "ghcr.io/exil0867/trena-backend:${trenaVersion}";
        autoStart = true;

        environmentFiles = [ decryptedSecretPath ];

        environment = {
          PORT = "3004";
          NODE_ENV = "production";
          DB_HOST = "trena_postgres";
          DB_PORT = "5432";
          DB_NAME = "trena";
          DB_USER = "trena";
        };

        ports = [ "127.0.0.1:3004:3004" ];
        dependsOn = [ "trena_postgres" ];

        extraOptions = [
          "--network=trena-net"
        ];
      };
    };

    systemd.services.trena-db-migrate = {
      description = "Run Trena DB migrations (manual)";
      after = [ "docker.service" "init-trena-network.service" ];
      wants = [ "agenix.service" ]; 
      serviceConfig = {
        Type = "oneshot";
      };
      script = ''
        ${dockercli} run --rm \
          --network=trena-net \
          --env-file ${decryptedSecretPath} \
          -e PGHOST=trena_postgres \
          -e PGPORT=5432 \
          -e PGUSER=trena \
          -e PGDATABASE=trena \
          ghcr.io/exil0867/trena-backend:${trenaVersion} \
          db-migrate
      '';
    };

    services.traefik.enable = true;

    services.traefik.dynamicConfigOptions.http = {
      routers.trena-api = {
        rule = "Host(`${cfg.domain}`)";
        entryPoints = [ "websecure" ];
        service = "trena-api";
        tls.certResolver = "cloudflare";
      };

      services.trena-api.loadBalancer.servers = [
        { url = "http://127.0.0.1:3004"; }
      ];
    };
  };
}