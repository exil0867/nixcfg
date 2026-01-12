{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.immich-sync;
in {
  options.services.immich-sync = {
    enable = mkEnableOption "Immich Sync Service";

    package = mkOption {
      type = types.package;
      default = pkgs.immich-cli;
      description = "The immich-cli package to use.";
    };

    environmentFile = mkOption {
      type = types.path;
      description = ''
        Path to file containing env vars IMMICH_INSTANCE_URL and IMMICH_API_KEY.
      '';
    };

    user = mkOption {
      type = types.str;
      default = "exil0681";
      description = "User to run the service as.";
    };

    paths = mkOption {
      type = types.listOf types.path;
      description = "Directories to upload.";
    };

    deleteUploaded = mkOption {
      type = types.bool;
      default = true;
      description = "Delete local assets after upload.";
    };

    deleteDuplicates = mkOption {
      type = types.bool;
      default = true;
      description = "Delete duplicate assets.";
    };

    concurrency = mkOption {
      type = types.int;
      default = 5;
      description = "Upload concurrency.";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.immich-sync = {
      description = "Immich Sync (batch upload)";

      after = ["network-online.target"];
      wants = ["network-online.target"];

      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        EnvironmentFile = cfg.environmentFile;
      };

      script = ''
        ${cfg.package}/bin/immich upload \
          --recursive \
          ${optionalString cfg.deleteUploaded "--delete"} \
          ${optionalString cfg.deleteDuplicates "--delete-duplicates"} \
          --concurrency ${toString cfg.concurrency} \
          ${concatStringsSep " " (map (p: "\"${p}\"") cfg.paths)}
      '';
    };

    systemd.timers.immich-sync = {
      wantedBy = ["timers.target"];

      timerConfig = {
        OnBootSec = "5m";
        OnUnitActiveSec = "30m";
      };
    };
  };
}
