{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.programs.htpc-downloader;
  rawScript = builtins.readFile ../scripts/htpc-downloader.sh;
  wrapperScript = pkgs.writeScriptBin "htpc-downloader" ''
    #!${pkgs.bash}/bin/bash
    # Inject the variable from the module configuration
    export HTPC_ROOT="${cfg.mediaDir}"
    ${rawScript}
  '';
in
{
  # Define standard options for this module
  options.programs.htpc-downloader = {
    enable = mkEnableOption "HTPC Downloader Script";
    mediaDir = mkOption {
      type = types.str;
      description = "The root path where media should be downloaded";
      example = "/mnt/data/downbox";
    };
    user = mkOption {
      type = types.str;
      description = "Primary owner of the HTPC media files";
    };
  };

  config = mkIf cfg.enable {
    users.users.${cfg.user}.extraGroups = [ "transmission" ];
    
    environment.systemPackages = [ 
      wrapperScript 
      pkgs.transmission_4 
    ];

    # Automatically create folders and set permissions
    systemd.tmpfiles.rules = [
      # Create root directories with setgid and write permissions for group
      "d ${cfg.mediaDir}/htpc 2775 ${cfg.user} transmission -"
      "d ${cfg.mediaDir}/htpc/tv_shows 2775 ${cfg.user} transmission -"
      "d ${cfg.mediaDir}/htpc/movies 2775 ${cfg.user} transmission -"
      "d ${cfg.mediaDir}/htpc/other 2775 ${cfg.user} transmission -"
      
      # Recursively fix permissions on ALL existing content
      "Z ${cfg.mediaDir}/htpc 2775 ${cfg.user} transmission -"
    ];
  };
}