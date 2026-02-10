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

    firewallAllowedCidrs = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "IPv4 CIDRs allowed to reach Syncthing (22000/8384 TCP, 21027 UDP). Empty disables firewall openings.";
    };

    firewallAllowedCidrs6 = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "IPv6 CIDRs allowed to reach Syncthing (22000/8384 TCP, 21027 UDP). Empty disables firewall openings.";
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
          "kairos" = { id = "Y3R73CQ-XYQMSAZ-PC3LGFW-JYJNFRS-FXHSAIF-3TYPVMK-RLK7YZE-RFFUKQX"; };
          "echo"   = { id = "Z5DKVKQ-WDXF2AD-VRFVHAD-Z3ZX5PM-VS57LJS-GL76DRQ-FHLPD2Q-HFBIVQE"; };
          "sky"    = { id = "7YBYOQH-GC6R7LC-RE5L52D-FV2SDDQ-DLJC4FE-VIW3EJE-O4HRCQU-AVWC5QJ"; };
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

    # Optional: restrict Syncthing ports to allowed CIDRs only.
    networking.firewall.extraInputRules = lib.mkIf (cfg.firewallAllowedCidrs != [] || cfg.firewallAllowedCidrs6 != []) (
      let
        v4 = lib.concatStringsSep ", " cfg.firewallAllowedCidrs;
        v6 = lib.concatStringsSep ", " cfg.firewallAllowedCidrs6;
        v4Rules = lib.optionalString (cfg.firewallAllowedCidrs != []) ''
          ip saddr { ${v4} } tcp dport { 22000, 8384 } accept
          ip saddr { ${v4} } udp dport 21027 accept
        '';
        v6Rules = lib.optionalString (cfg.firewallAllowedCidrs6 != []) ''
          ip6 saddr { ${v6} } tcp dport { 22000, 8384 } accept
          ip6 saddr { ${v6} } udp dport 21027 accept
        '';
      in ''
        ${v4Rules}
        ${v6Rules}
      ''
    );
  };
}
