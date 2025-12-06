{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.immich-sync;
in
{
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
        Usually provided by agenix config.age.secrets."...".path
      '';
    };

    user = mkOption {
      type = types.str;
      default = "exil0681";
      description = "The user to run the service as (must have write access to the paths to delete files).";
    };

    paths = mkOption {
      type = types.listOf types.path;
      description = "List of directories to watch and upload.";
    };

    deleteUploaded = mkOption {
      type = types.bool;
      default = true;
      description = "Pass --delete flag: Delete local assets after upload.";
    };

    deleteDuplicates = mkOption {
      type = types.bool;
      default = true;
      description = "Pass --delete-duplicates flag: Delete local assets that are already on the server.";
    };
    
    concurrency = mkOption {
      type = types.int;
      default = 5;
      description = "Upload concurrency.";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.immich-sync = {
      description = "Immich Sync Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        User = cfg.user;
        # Restart helps if the network drops or server is temporarily unreachable
        Restart = "always";
        RestartSec = "10s";
        EnvironmentFile = cfg.environmentFile;
      };

      script = ''
        ${cfg.package}/bin/immich upload \
          --watch \
          --recursive \
          ${optionalString cfg.deleteUploaded "--delete"} \
          ${optionalString cfg.deleteDuplicates "--delete-duplicates"} \
          --concurrency ${toString cfg.concurrency} \
          ${concatStringsSep " " (map (p: "\"${p}\"") cfg.paths)}
      '';
    };
  };
}