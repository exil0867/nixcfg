{ config, lib, pkgs, ... }:

let
  cfg = config.services.myexpenses-upload;

  ingestUser  = "myexpenses-ingest";
  ingestGroup = "myexpenses-ingest";
  incomingDir = "/srv/myexpenses/incoming";

  uploadScript = pkgs.writeShellApplication {
    name = "myexpenses-upload";
    runtimeInputs = with pkgs; [ coreutils ];
    text = builtins.readFile ./upload.sh;
  };

  promoteScript = pkgs.writeShellApplication {
    name = "myexpenses-promote";
    runtimeInputs = with pkgs; [ coreutils ];
    text = builtins.readFile ./promote.sh;
  };

in {
  options.services.myexpenses-upload = {
    enable = lib.mkEnableOption "MyExpenses HTTPS upload ingest service";

    finalDir = lib.mkOption {
      type = lib.types.str;
    };

    host = lib.mkOption {
      type = lib.types.str;
    };

    path = lib.mkOption {
      type = lib.types.str;
      default = "/upload";
    };

    listenAddr = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1:8090";
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
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        ExecStart = ''
          ${pkgs.socat}/bin/socat \
            TCP-LISTEN:${lib.last (lib.splitString ":" cfg.listenAddr)},bind=${lib.head (lib.splitString ":" cfg.listenAddr)},reuseaddr,fork \
            EXEC:'${uploadScript}/bin/myexpenses-upload ${incomingDir}'
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
      pathConfig.PathChanged = incomingDir;
    };

    systemd.services.myexpenses-move = {
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = ''
          ${promoteScript}/bin/myexpenses-promote ${incomingDir} ${cfg.finalDir}
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
