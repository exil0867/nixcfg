{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.mounter;
in
{
  options.mounter = {
    mounts = mkOption {
      type = types.listOf (types.submodule {
        options = {
          mountPoint = mkOption {
            type = types.str;
            description = "The mount point for the filesystem.";
          };
          deviceUUID = mkOption {
            type = types.str;
            description = "The UUID of the device to mount.";
          };
          fsType = mkOption {
            type = types.str;
            default = "ext4";
            description = "The filesystem type.";
          };
          options = mkOption {
            type = types.listOf types.str;
            default = [ "users" "nofail" "exec" ];
            description = "Mount options for the filesystem.";
          };
          user = mkOption {
            type = types.str;
            description = "The user to own the mounted directory.";
          };
          group = mkOption {
            type = types.str;
            description = "The group to own the mounted directory.";
          };
        };
      });
      default = [];
      description = "List of mounts with ownership changes.";
    };
  };

  config = {
    fileSystems = listToAttrs (map (mount: {
      name = mount.mountPoint;
      value = {
        device = "/dev/disk/by-uuid/${mount.deviceUUID}";
        fsType = mount.fsType;
        options = mount.options;
      };
    }) cfg.mounts);

    systemd.services = listToAttrs (map (mount: {
      name = "chown-${replaceStrings ["/"] ["-"] (removePrefix "/" mount.mountPoint)}";
      value = {
        description = "Change ownership of ${mount.mountPoint} to ${mount.user}:${mount.group}";
        after = [ "${replaceStrings ["/"] ["-"] (removePrefix "/" mount.mountPoint)}.mount" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.coreutils}/bin/chown -R ${mount.user}:${mount.group} ${mount.mountPoint}";
        };
      };
    }) cfg.mounts);
  };
}