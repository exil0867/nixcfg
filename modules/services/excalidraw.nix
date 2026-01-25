{ config, pkgs, lib, vars, ... }:

let
  storagePath = "/mnt/1TB-ST1000DM010-2EP102/srv/excalidraw";
in {
  options.services.excalidraw = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Excalidraw service with persistence";
    };
  };

  config = lib.mkIf config.services.excalidraw.enable {
    # Ensure storage directory exists
    systemd.tmpfiles.rules = [
      "d ${storagePath} 0775 ${vars.user} users - -"
    ];

    virtualisation.oci-containers.backend = "docker";

    virtualisation.oci-containers.containers = {
      excalidraw = {
        image = "ghcr.io/ozencb/excalidraw-persist:0.18.0-persist.1";
        autoStart = true;
        ports = ["127.0.0.1:8081:80"];
        volumes = [
          "${storagePath}:/app/data"
        ];
        environment = {
          # For excalidraw-persist, it uses /app/data/database.sqlite by default
        };
      };
    };
  };
}
