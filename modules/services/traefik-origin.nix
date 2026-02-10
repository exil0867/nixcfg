{ config, lib, ... }:

with lib;

let
  cfg = config.traefikOrigin;
in {
  options.traefikOrigin = {
    middlewareName = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Traefik middleware name to enforce origin allowlists (null disables).";
    };

    sourceRange = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "CIDRs allowed to reach the origin via Traefik.";
    };
  };

  config = mkIf (cfg.middlewareName != null && cfg.sourceRange != []) {
    services.traefik.dynamicConfigOptions.http.middlewares.${cfg.middlewareName}.ipAllowList.sourceRange =
      cfg.sourceRange;
  };
}
