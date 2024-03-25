 { config, pkgs, lib, ... }: {
  networking.hostName = "3x1l-s3rv3r";
  networking.useDHCP = lib.mkDefault true;
  networking.useNetworkd = true;
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;
  networking.enableIPv6 = false;
  systemd.network.enable = true;
  systemd.network.wait-online.enable = lib.mkForce false;
  systemd.services.NetworkManager-wait-online.enable = lib.mkForce false;
  networking.nameservers =
    [ "1.1.1.1#one.one.one.one" "1.0.0.1#one.one.one.one" ];
  services.resolved = {
    enable = true;
    dnssec = "true";
    domains = [ "~." ];
    fallbackDns = [ "1.1.1.1#one.one.one.one" "1.0.0.1#one.one.one.one" ];
    extraConfig = ''
      DNSOverTLS=yes
    '';
  };

  }