{ config, pkgs, lib, ... }:

let
  secretsDir = "/var/lib/syncthing/secrets";
in {
  services.syncthing = {
    enable = true;
    user = "syncthing";         # dedicated user for the service
    group = "syncthing";
    dataDir = "/var/lib/syncthing";
    configDir = "/var/lib/syncthing/config";
    guiAddress = "127.0.0.1:8384"; # web UI only on localhost
    overrideDevices = true;
    overrideFolders = true;
    settings = {
      devices = {
        # Fill in your host device IDs here after first run
        "kairos" = { id = "DEVICEID_KAIROS"; };
        "echo"   = { id = "DEVICEID_ECHO"; };
        "sky"    = { id = "DEVICEID_SKY"; };
      };
      folders = {
        "secrets" = {
          path = secretsDir;
          devices = [ "kairos" "echo" "sky" ];
        };
      };
    };
  };

  # Ensure the directory exists
  systemd.tmpfiles.rules = [
    "d ${secretsDir} 0750 syncthing syncthing -"
  ];

  # Open firewall for Syncthing traffic
  networking.firewall = {
    allowedTCPPorts = [ 22000 8384 ];
    allowedUDPPorts = [ 21027 ];
  };
}
