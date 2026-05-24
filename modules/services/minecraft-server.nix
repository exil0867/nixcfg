{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.minecraft-private;
in
{
  options.services.minecraft-private = {
    enable = mkEnableOption "Private optimized PaperMC Minecraft server for non-official clients";

    openPublicFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to open port 25565 to the entire internet.";
    };

    allowedIPs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "List of specific friend IPs allowed to connect if openPublicFirewall is false.";
    };
  };

  config = mkIf cfg.enable {
    # Force allow unfree packages within this context for the Minecraft server package
    nixpkgs.config.allowUnfree = true;

    services.minecraft-server = {
      enable = true;
      eula = true;
      
      # Using PaperMC for performance optimizations
      package = pkgs.papermcServers.papermc-1_21_9;

      # Managed conditionally below via networking.firewall
      openFirewall = false; 

      # Resource containment: limits RAM usage to protect critical host services
      jvmOpts = "-Xms1024M -Xmx1536M -Djava.net.preferIPv4Stack=true -XX:+UseG1GC";

      serverProperties = {
        server-port = 25565;
        online-mode = false; # Required for non-official / Ely.by clients
        white-list = false;  # Handled via AuthMe plugin instead of vanilla UUID checks
        max-players = 5;
        view-distance = 6;
        simulation-distance = 5;
        difficulty = 2;
        motd = "Sky Private Server";
#        enforce-secure-profile = false;
      };

      declarative = true;
    };

    # Firewall implementation matching your configuration requirements
    networking.firewall = {
      allowedTCPPorts = mkIf cfg.openPublicFirewall [ 25565 ];
      
      extraCommands = mkIf (!cfg.openPublicFirewall && cfg.allowedIPs != [ ]) ''
        ${concatMapStringsSep "\n" (ip: "iptables -A INPUT -p tcp -s ${ip} --dport 25565 -j ACCEPT") cfg.allowedIPs}
      '';
    };
  };
}
