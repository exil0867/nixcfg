{ config, lib, pkgs, ... }:

let
  cfg = config.services.myexpenses-upload;

  ingestUser  = "myexpenses-ingest";
  ingestGroup = "myexpenses-ingest";

  incomingDir = "/srv/myexpenses/incoming";
in
{

  options.services.myexpenses-upload = {
    enable = lib.mkEnableOption "MyExpenses HTTPS upload ingest service";

    finalDir = lib.mkOption {
      type = lib.types.str;
      description = "Final directory where MyExpenses backups are stored";
    };

    host = lib.mkOption {
      type = lib.types.str;
      example = "myexpenses.kyrena.dev";
      description = "Public hostname used for uploads";
    };

    path = lib.mkOption {
      type = lib.types.str;
      default = "/upload";
      description = "HTTP path used for uploads";
    };

    listenAddr = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1:8090";
      description = "Local address the ingest service listens on";
    };
  };

  config = lib.mkIf cfg.enable {

    users.users.${ingestUser} = {
      isSystemUser = true;
      group = ingestGroup;
    };

    users.groups.${ingestGroup} = {};

    systemd.tmpfiles.rules = [
      "d /srv/myexpenses 0751 root root -"
      "d ${incomingDir} 0700 ${ingestUser} ${ingestGroup} -"
      "d ${cfg.finalDir} 0700 root root -"
    ];

    systemd.services.myexpenses-upload = {
      description = "MyExpenses ingest endpoint";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        ExecStart = ''
          ${pkgs.socat}/bin/socat \
            TCP-LISTEN:${lib.last (lib.splitString ":" cfg.listenAddr)},bind=${lib.head (lib.splitString ":" cfg.listenAddr)},reuseaddr,fork \
            EXEC:${pkgs.writeShellScript "myexpenses-upload" ''
              set -euo pipefail

              # Read request line
              IFS= read -r request || exit 0
              method="$${request%% *}"

              # Consume headers
              while IFS= read -r line; do
                [ -z "$line" ] && break
                [ "$line" = $'\r' ] && break
              done

              # Handle probe requests
              case "$method" in
                OPTIONS|PROPFIND)
                  printf "HTTP/1.1 200 OK\r\n"
                  printf "Allow: PUT, POST, OPTIONS, PROPFIND\r\n"
                  printf "Content-Length: 0\r\n\r\n"
                  exit 0
                  ;;
              esac

              # Store body
              ts="$(date +%s)"
              tmp="${incomingDir}/.backup-$ts.part"
              out="${incomingDir}/backup-$ts.bin"

              cat > "$tmp"
              chmod 600 "$tmp"
              mv "$tmp" "$out"

              # Response
              printf "HTTP/1.1 200 OK\r\n"
              printf "Connection: close\r\n"
              printf "Content-Length: 2\r\n\r\nOK"
            ''}
        '';
        User = ingestUser;
        Group = ingestGroup;
        NoNewPrivileges = true;
        PrivateTmp = true;
        Restart = "always";
      };
    };

    systemd.paths.myexpenses-move = {
      wantedBy = [ "multi-user.target" ];
      pathConfig = {
        PathChanged = incomingDir;
        PathGlob = "backup-*.bin";
      };
    };

    systemd.services.myexpenses-move = {
      description = "Promote MyExpenses backups to final storage";

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "myexpenses-move" ''
          set -euo pipefail

          IN="${incomingDir}"
          OUT="${cfg.finalDir}"

          for f in "$IN"/backup-*.bin; do
            [ -f "$f" ] || continue

            ts="$(date +%Y-%m-%d_%H-%M-%S)"
            tmp="$OUT/.myexpenses-$ts.tmp"
            dst="$OUT/myexpenses-$ts.bin"

            install -m 600 "$f" "$tmp"
            sync "$tmp"
            mv "$tmp" "$dst"
            rm -f "$f"
          done
        '';
      };
    };

    services.traefik.dynamicConfigOptions.http.routers.myexpenses-upload = {
      rule = "Host(`${cfg.host}`) && PathPrefix(`${cfg.path}`)";
      entryPoints = [ "websecure" ];
      service = "myexpenses-upload";
      tls.certResolver = "cloudflare";
      middlewares = [ "myexpenses-buffer" ];
    };

    services.traefik.dynamicConfigOptions.http.middlewares.myexpenses-buffer.buffering = {
      maxRequestBodyBytes = 104857600;
    };

    services.traefik.dynamicConfigOptions.http.services.myexpenses-upload = {
      loadBalancer.servers = [
        { url = "http://${cfg.listenAddr}"; }
      ];
    };
  };
}
