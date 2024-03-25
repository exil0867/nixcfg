 { config, pkgs, ... }: {
  # Bootloader.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/vda";
  boot.loader.grub.useOSProber = true;

  boot.initrd.luks.devices."luks-1e15011d-afb3-4779-8262-249ba80d8d64".device = "/dev/disk/by-uuid/1e15011d-afb3-4779-8262-249ba80d8d64";
  # Setup keyfile
  boot.initrd.secrets = {
    "/crypto_keyfile.bin" = null;
  };

  boot.loader.grub.enableCryptodisk=true;

  boot.initrd.luks.devices."luks-019f7ba1-de51-4c17-b12f-e404b943f8e9".keyFile = "/crypto_keyfile.bin";
  boot.initrd.luks.devices."luks-1e15011d-afb3-4779-8262-249ba80d8d64".keyFile = "/crypto_keyfile.bin";

  }