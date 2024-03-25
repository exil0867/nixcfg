# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../../common/base.nix
      ../../common/users.nix
      ../../common/networking.nix
      ../../roles/jellyfin.nix
    ];

  # services.pihole = {
  #   enable = true;
  #   serverIp = "100.72.171.50";
  #   persistanceRoot = "/nas/services/pihole";
  # };

  # services.syncthing.settings.folders = {
  #   finance-data = {
  #     path = "/nas/junk/finance-data";
  #     devices = [ "giant-head" ];
  #   };
  #   giant-head-docs = {
  #     path = "/nas/junk/giant-head/docs";
  #     devices = [ "giant-head" ];
  #   };
  # };

  # age.secrets."zfs.key".file = ../../secrets/zfs.key.age;
  # age.secrets."zfs-junk.key".file = ../../secrets/zfs-junk.key.age;
  # age.secrets."backup_ed25519".file = ../../secrets/backup_ed25519.age;
  # age.secrets."backup.passphrase".file = ../../secrets/backup.passphrase.age;


  virtualisation.oci-containers.containers = {
    audiobookshelf = {
      autoStart = true;
      image = "ghcr.io/advplyr/audiobookshelf:latest";
      ports = [
        "13378:80"
      ];
      environment = {
        TZ = "Africa/Tunis"; # Change this to your timezone
      };
    };
  };


  virtualisation = {
    podman = {
      enable = true;

      # Create a `docker` alias for podman, to use it as a drop-in replacement
      dockerCompat = true;
      dockerSocket.enable = true;

      # Required for containers under podman-compose to be able to talk to each other.
      # For Nixos version > 22.11
      #defaultNetwork.settings = {
      #  dns_enabled = true;
      #};

    };
  };

  networking.hostId = "6d778fb4"; # Define your hostname.

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

  networking.hostName = "3x1l-s3rv3r"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #  wget
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?

}