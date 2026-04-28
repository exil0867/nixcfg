{ config, lib, pkgs, ... }:

let
  cfg = config.programs."cloudflare-tunnel";

  cloudflareTunnel = pkgs.writeShellApplication {
    name = "cloudflare-tunnel";
    runtimeInputs = with pkgs; [
      bash
      cloudflared
      coreutils
      gnugrep
      gnused
    ];
    text = builtins.readFile ./cloudflare-tunnel.sh;
    checkPhase = ":";
  };
in
{
  options.programs."cloudflare-tunnel" = {
    enable = lib.mkEnableOption "Cloudflare quick tunnel helper";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cloudflareTunnel ];
  };
}
