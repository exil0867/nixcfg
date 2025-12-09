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
      description = "The user that needs permissions for these folders";
      default = "root";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ 
      wrapperScript 
      pkgs.transmission_4 
    ];

    # Automatically create folders and set permissions
    systemd.tmpfiles.rules = [
      "d ${cfg.mediaDir}/htpc/tv_shows 0775 ${cfg.user} transmission -"
      "d ${cfg.mediaDir}/htpc/movies   0775 ${cfg.user} transmission -"
      "d ${cfg.mediaDir}/htpc/other    0775 ${cfg.user} transmission -"
    ];
  };
}