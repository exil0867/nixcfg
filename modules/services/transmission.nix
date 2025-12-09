{ pkgs, ... }:
{
  services.transmission = {
    enable = true;
    package = pkgs.transmission_4-gtk;
    openRPCPort = false;
    openPeerPorts = true;
    settings = {
      rpc-bind-address = "127.0.0.1";
      rpc-whitelist-enabled = true;
      rpc-whitelist = "127.0.0.1";
      rpc-authentication-required = false; 
    };
  };
}