{ config, lib, pkgs, ... }:

{
  options = {
    rcloneSftpMounts = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Name of the rclone remote.";
          };
          host = lib.mkOption {
            type = lib.types.str;
            description = "Remote server hostname or IP address.";
          };
          user = lib.mkOption {
            type = lib.types.str;
            description = "Remote server username.";
          };
          sshKey = lib.mkOption {
            type = lib.types.str;
            description = "Path to the SSH private key on the client.";
          };
          remotePath = lib.mkOption {
            type = lib.types.str;
            description = "Remote directory to mount.";
            default = "/";
          };
          mountPoint = lib.mkOption {
            type = lib.types.str;
            description = "Local directory to mount the remote filesystem.";
          };
          vfsCacheMode = lib.mkOption {
            type = lib.types.str;
            description = "VFS cache mode for rclone.";
            default = "writes";
          };
        };
      });
      default = [];
      description = "List of SFTP mounts to configure using rclone.";
    };
  };

  config = lib.mkIf (config.rcloneSftpMounts != []) {
    environment.systemPackages = [ pkgs.rclone ];

    # Generate rclone configuration files for each mount
    environment.etc = lib.listToAttrs (map (mount: lib.nameValuePair "rclone-${mount.name}.conf" {
      text = ''
        [${mount.name}]
        type = sftp
        host = ${mount.host}
        user = ${mount.user}
        key_file = ${mount.sshKey}
        use_insecure_cipher = false
        disable_hashcheck = true
        ssh_agent_auth = true
      '';
    }) config.rcloneSftpMounts);

    # Configure file systems for each mount
    fileSystems = lib.listToAttrs (map (mount: lib.nameValuePair mount.mountPoint {
      device = "${mount.name}:${mount.remotePath}";
      fsType = "rclone";
      options = [
        "nodev"
        "nofail"
        "allow_other"
        "args2env"
        "config=/etc/rclone-${mount.name}.conf"
        "vfs-cache-mode=${mount.vfsCacheMode}"
      ];
    }) config.rcloneSftpMounts);
  };
}