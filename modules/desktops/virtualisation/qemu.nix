{
  lib,
  config,
  pkgs,
  stable,
  inputs,
  vars,
  ...
}: {
  virtualisation = {
    libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm.override {
          hostCpuOnly = false;
          cephSupport = false;
          glusterfsSupport = false;
        };
        swtpm.enable = true;
      };
    };
    spiceUSBRedirection.enable = true;
  };

  users.users.${vars.user}.extraGroups = ["libvirtd"];

  environment.systemPackages = with pkgs; [
    spice
    spice-gtk
    spice-protocol
    virt-viewer
    #virtio-win
    #win-spice
  ];
  programs.virt-manager.enable = true;

  home-manager.users.${vars.user} = {
    dconf.settings = {
      "org/virt-manager/virt-manager/connections" = {
        autoconnect = ["qemu:///system"];
        uris = ["qemu:///system"];
      };
    };
  };
}
