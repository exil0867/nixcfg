{ config, pkgs, lib, vars, ... }:

let
  secretsDir = "/home/${vars.user}/secrets-sync";
in {
  services.syncthing = {
    enable = true;
    user = vars.user;
    group = "users";
    dataDir = "/home/${vars.user}/.local/share/syncthing";
    configDir = "/home/${vars.user}/.config/syncthing";
    guiAddress = "127.0.0.1:8384"; # web UI only on localhost
    overrideDevices = true;
    overrideFolders = true;
    settings = {
      devices = {
        # Fill in your host device IDs here after first run
        "kairos" = { id = "DUQBDTY-4WU4CCG-LHSDWDI-4CDKWV6-33EASZF-IXKYI76-D6UXSHJ-SH7NLAG"; };
        "echo"   = { id = "F43WVLP-HSNPB32-C7MWWI7-4EI2VT4-OZPOIBC-FWY5U5U-K3FN5R2-RKOBBA2"; };
        "sky"    = { id = "DIENRLR-FB7OJ3S-XY7LQBE-GQWIK5L-YGYVSI7-FUD2GS4-FSNIQ4M-MGWBFQ6"; };
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
    "d ${secretsDir} 0700 ${vars.user} users -"
  ];

  # Open firewall for Syncthing traffic
  networking.firewall = {
    allowedTCPPorts = [ 22000 8384 ];
    allowedUDPPorts = [ 21027 ];
  };
}
