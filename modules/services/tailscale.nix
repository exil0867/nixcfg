{ config, lib, pkgs, ... }:

with lib;

let
  defaultAuthKeyFile = "/etc/nixos/secrets-sync/tailscale-preauth.key";
in
{
  options.tailscale = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Tailscale service and auto-connect functionality.";
    };

    authKeyFile = mkOption {
      type = types.str;
      default = defaultAuthKeyFile;
      description = "Path to the Tailscale auth key file.";
    };

    loginServer = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Optional custom login server for Tailscale.";
    };
  };

  config = mkIf config.tailscale.enable {
    services.tailscale.enable = true;

    systemd.services.tailscale-autoconnect = {
      description = "Automatic connection to Tailscale";
      after = [ "network-pre.target" "tailscale.service" ];
      wants = [ "network-pre.target" "tailscale.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig.Type = "oneshot";

      script = ''
        # wait for tailscaled to settle
        sleep 2

        # check if we are already authenticated to tailscale
        status="$(${pkgs.tailscale}/bin/tailscale status -json | ${pkgs.jq}/bin/jq -r .BackendState)"
        if [ "$status" = "Running" ]; then
          exit 0
        fi

        # otherwise authenticate with tailscale
        ${pkgs.tailscale}/bin/tailscale up \
          ${optionalString (config.tailscale.loginServer != null) "--login-server ${config.tailscale.loginServer}"} \
          -authkey "$(cat ${config.tailscale.authKeyFile})"
      '';
    };
  };
}
