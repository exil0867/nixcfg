{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.htpc-downloader;

  # 1. Read the Bash files (External files, as requested)
  rawDownloaderScript = builtins.readFile ./htpc-downloader.sh;
  rawCleanerScript    = builtins.readFile ./clean-torrent.sh;

  # 2. Package the Downloader (Injects HTPC_ROOT)
  wrapperScript = pkgs.writeScriptBin "htpc-downloader" ''
    #!${pkgs.bash}/bin/bash
    export HTPC_ROOT="${cfg.mediaDir}"
    ${rawDownloaderScript}
  '';

  # 3. Package the Cleaner (Runs as is)
  cleanerScript = pkgs.writeScriptBin "clean-torrent" ''
    #!${pkgs.bash}/bin/bash
    ${rawCleanerScript}
  '';
in
{
  options.programs.htpc-downloader = {
    enable = mkEnableOption "HTPC Downloader Script";
    mediaDir = mkOption { type = types.str; };
    user = mkOption { type = types.str; };
  };

  config = mkIf cfg.enable {
    # Install both scripts globally (optional, but good for debugging)
    environment.systemPackages = [ 
      wrapperScript 
      cleanerScript
      pkgs.transmission_4 
    ];

    # Configure Transmission to use the cleaner script
    services.transmission.settings = {
      script-torrent-done-enabled = true;
      script-torrent-done-filename = "${cleanerScript}/bin/clean-torrent";
    };

    # Permissions
    users.users.${cfg.user}.extraGroups = [ "transmission" ];
    
    systemd.tmpfiles.rules = [
      "d ${cfg.mediaDir}/htpc 2775 ${cfg.user} transmission -"
      "d ${cfg.mediaDir}/htpc/tv_shows 2775 ${cfg.user} transmission -"
      "d ${cfg.mediaDir}/htpc/movies 2775 ${cfg.user} transmission -"
      "d ${cfg.mediaDir}/htpc/other 2775 ${cfg.user} transmission -"
    ];
  };
}