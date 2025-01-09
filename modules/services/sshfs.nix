{ config, lib, pkgs, ... }:

let
  # Helper function to create the sshAsUser script
  mkSshAsUserScript = user: pkgs.writeScript "sshAsUser" ''
    user="$1"; shift
    exec ${pkgs.sudo}/bin/sudo -i -u "$user" \
      ${pkgs.openssh}/bin/ssh "$@"
  '';
in
{
  options = {
    sshfsMounts = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          mountPoint = lib.mkOption {
            type = lib.types.str;
            description = "Local mount point for the SSHFS filesystem.";
          };
          remoteUser = lib.mkOption {
            type = lib.types.str;
            description = "Remote user to connect as.";
          };
          remoteHost = lib.mkOption {
            type = lib.types.str;
            description = "Remote host to connect to.";
          };
          remotePath = lib.mkOption {
            type = lib.types.str;
            description = "Remote path to mount.";
            default = "/";
          };
          sshKey = lib.mkOption {
            type = lib.types.str;
            description = "Path to the SSH private key.";
          };
          uid = lib.mkOption {
            type = lib.types.str;
            description = "User ID for the mounted filesystem.";
          };
          gid = lib.mkOption {
            type = lib.types.str;
            description = "Group ID for the mounted filesystem.";
          };
        };
      });
      default = [];
      description = "List of SSHFS mounts to configure.";
    };
  };

  config = lib.mkIf (config.sshfsMounts != []) {
    fileSystems = lib.listToAttrs (map (mount: lib.nameValuePair mount.mountPoint {
      device = "${pkgs.sshfs-fuse}/bin/sshfs#${mount.remoteUser}@${mount.remoteHost}:${mount.remotePath}";
      fsType = "fuse";
      options = [
        "user"
        "uid=${mount.uid}"
        "gid=${mount.gid}"
        "allow_other"
        "exec" # Override "user"'s noexec
        "noatime"
        "nosuid"
        "_netdev"
        "ssh_command=${mkSshAsUserScript mount.remoteUser}\\040${mount.remoteUser}"
        "noauto"
        "x-gvfs-hide"
        "x-systemd.automount"
        "ServerAliveCountMax=1"
        "ServerAliveInterval=15"
        "dir_cache=no"
        "IdentityFile=${mount.sshKey}"
      ];
    }) config.sshfsMounts);

    systemd.automounts = map (mount: {
      where = mount.mountPoint;
      automountConfig.TimeoutIdleSec = "5 min";
    }) config.sshfsMounts;
  };
}