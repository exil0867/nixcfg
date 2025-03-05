{ config, lib, pkgs, vars, ... }:
let
  cfg = config.jellyfin-player;
in {
  options.jellyfin-player = {
    enable = lib.mkEnableOption "Jellyfin Media Player";
    
    useXcb = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Use XCB platform when launching Jellyfin Media Player";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      jellyfin-media-player
    ];

    home-manager.users.${vars.user} = {
      xdg.desktopEntries.jellyfin-media-player = {
        name = "Jellyfin Media Player";
        genericName = "Media Player";
        exec = 
          if cfg.useXcb 
          then "jellyfinmediaplayer --platform=xcb %U"
          else "jellyfinmediaplayer %U";
        icon = "jellyfin-media-player";
        comment = "Jellyfin Media Player";
        categories = [ "AudioVideo" "Video" "Player" ];
        settings = {
          TryExec = "jellyfinmediaplayer";
        };
      };
    };
  };
}