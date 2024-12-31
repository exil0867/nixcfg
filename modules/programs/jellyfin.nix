{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.jellyfin;
in {
  options.services.jellyfin = {
    enable = mkEnableOption "Jellyfin media server";

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open ports in the firewall for Jellyfin.";
    };

    user = mkOption {
      type = types.str;
      default = "jellyfin";
      description = "User under which Jellyfin runs.";
    };

    hardwareAcceleration = {
      enable = mkEnableOption "Enable hardware acceleration for Jellyfin";

      vaapi = mkOption {
        type = types.bool;
        default = false;
        description = "Enable VAAPI hardware acceleration.";
      };

      intelQSV = mkOption {
        type = types.bool;
        default = false;
        description = "Enable Intel Quick Sync Video (QSV) hardware acceleration.";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      jellyfin
      jellyfin-web
      jellyfin-ffmpeg
    ];

    services.jellyfin = {
      inherit (cfg) user;
      openFirewall = cfg.openFirewall;
    };

    # Enable hardware acceleration if configured
    nixpkgs.config.packageOverrides = mkIf cfg.hardwareAcceleration.enable (pkgs: {
      vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
    });

    hardware.graphics = mkIf (cfg.hardwareAcceleration.enable && (cfg.hardwareAcceleration.vaapi || cfg.hardwareAcceleration.intelQSV)) {
      enable = true;
      extraPackages = with pkgs; (
        []
        ++ optional cfg.hardwareAcceleration.vaapi vaapiVdpau
        ++ optional cfg.hardwareAcceleration.intelQSV intel-media-driver
        ++ optional cfg.hardwareAcceleration.intelQSV intel-vaapi-driver
        ++ optional cfg.hardwareAcceleration.intelQSV intel-compute-runtime
        ++ optional cfg.hardwareAcceleration.intelQSV vpl-gpu-rt
        ++ optional cfg.hardwareAcceleration.intelQSV intel-media-sdk
      );
    };

    # Ensure the Jellyfin user has access to external drives
    systemd.services.jellyfin = mkIf (cfg.user != "jellyfin") {
      serviceConfig = {
        User = cfg.user;
        ExecStartPre = "${pkgs.coreutils}/bin/chown -R ${cfg.user} /var/lib/jellyfin";
      };
    };

    # Overlay for Intro Skipper plugin
    nixpkgs.overlays = mkIf cfg.enable [
      (final: prev: {
        jellyfin-web = prev.jellyfin-web.overrideAttrs (finalAttrs: previousAttrs: {
          installPhase = ''
            runHook preInstall

            # this is the important line
            sed -i "s#</head>#<script src=\"configurationpage?name=skip-intro-button.js\"></script></head>#" dist/index.html

            mkdir -p $out/share
            cp -a dist $out/share/jellyfin-web

            runHook postInstall
          '';
        });
      })
    ];
  };
}