{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.syncSecrets;
in {
  options.syncSecrets = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Syncthing for secrets syncing.";
    };

    secretsDir = mkOption {
      type = types.str;
      description = "Path where secrets are synced to.";
    };

    user = mkOption {
      type = types.str;
      default = "exil0681";
      description = "User to run Syncthing as.";
    };

    group = mkOption {
      type = types.str;
      default = "users";
      description = "Group to run Syncthing as.";
    };
  };

  config = mkIf cfg.enable {
    services.syncthing = {
      enable = true;
      user = cfg.user;
      group = cfg.group;
      dataDir = "/home/${cfg.user}/.local/share/syncthing";
      configDir = "/home/${cfg.user}/.config/syncthing";
      guiAddress = "127.0.0.1:8384";
      overrideDevices = true;
      overrideFolders = true;

      settings = {
        devices = {
          "kairos" = { id = "DUQBDTY-4WU4CCG-LHSDWDI-4CDKWV6-33EASZF-IXKYI76-D6UXSHJ-SH7NLAG"; };
          "echo"   = { id = "F43WVLP-HSNPB32-C7MWWI7-4EI2VT4-OZPOIBC-FWY5U5U-K3FN5R2-RKOBBA2"; };
          "sky"    = { id = "DIENRLR-FB7OJ3S-XY7LQBE-GQWIK5L-YGYVSI7-FUD2GS4-FSNIQ4M-MGWBFQ6"; };
        };

        folders = {
          "secrets" = {
            path = cfg.secretsDir;
            devices = [ "kairos" "echo" "sky" ];
          };
        };
      };
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.secretsDir} 0700 ${cfg.user} ${cfg.group} -"
    ];

    networking.firewall.allowedTCPPorts = [ 22000 8384 ];
    networking.firewall.allowedUDPPorts = [ 21027 ];
  };
}
