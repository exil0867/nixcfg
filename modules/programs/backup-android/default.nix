{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.backup-android;
  
  backupScript = pkgs.writeShellApplication {
    name = "backup-android";
    runtimeInputs = with pkgs; [
      android-tools
      openssh
      sshpass
      coreutils
      gnugrep
      gawk
    ];
    text = builtins.readFile ./script.sh;
    checkPhase = ":";
  };

in {
  options.programs.backup-android = {
    enable = mkEnableOption "Android backup script";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ backupScript ];
  };
}