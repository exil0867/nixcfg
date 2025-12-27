{ config, pkgs, lib, ... }:

let
  backupScript = pkgs.writeShellApplication {
    name = "immich-backup-task";
    runtimeInputs = with pkgs; [
      bash
      coreutils
      docker
      gzip
      findutils
      rsync
      util-linux # for mountpoint command
    ];
    text = builtins.readFile ./backup.sh;
  };
in
{
  systemd.services.immich-backup = {
    description = "Immich Backup Service (Database + Files)";
    
    # Ensure this runs after the drives are mounted and Docker is ready
    after = [ 
      "mnt-1TB-ST1000DM010-2EP102.mount" 
      "mnt-1TB-TOSHIBA-MQ04ABF100.mount" 
      "docker.service" 
    ];
    requires = [ "docker.service" ];

    serviceConfig = {
      Type = "oneshot";
      User = "root"; # Needs root for global Docker socket and writing to /mnt backups
      ExecStart = "${backupScript}/bin/immich-backup-task";
    };
  };

  systemd.timers.immich-backup = {
    description = "Timer for Immich Backup (Every 15 days)";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # Run on the 1st and 15th of every month at 03:00 AM
      OnCalendar = "*-*-01,15 03:00:00";
      Persistent = true; # If machine is off, run immediately on boot
      Unit = "immich-backup.service";
    };
  };
}