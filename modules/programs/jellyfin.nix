{ config, lib, pkgs, vars, ... }:

with lib;

{
  options = {
    jellyfin = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable Jellyfin media server.";
      };

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
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable hardware acceleration for Jellyfin.";
        };

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
  };

  config = mkIf config.jellyfin.enable {
    environment.systemPackages = with pkgs; [
      jellyfin
      jellyfin-web
      jellyfin-ffmpeg
    ];

    services.jellyfin = {
      enable = true;
      inherit (config.jellyfin) user openFirewall;
    };

    # Enable hardware acceleration if configured
    hardware.graphics = mkIf (config.jellyfin.hardwareAcceleration.enable &&
      (config.jellyfin.hardwareAcceleration.vaapi || config.jellyfin.hardwareAcceleration.intelQSV)) {
        enable = true;
        extraPackages = with pkgs; (
          []
          ++ optional config.jellyfin.hardwareAcceleration.vaapi vaapiVdpau
          ++ optional config.jellyfin.hardwareAcceleration.intelQSV intel-media-driver
          ++ optional config.jellyfin.hardwareAcceleration.intelQSV intel-vaapi-driver
          ++ optional config.jellyfin.hardwareAcceleration.intelQSV intel-compute-runtime
          ++ optional config.jellyfin.hardwareAcceleration.intelQSV vpl-gpu-rt
          ++ optional config.jellyfin.hardwareAcceleration.intelQSV intel-media-sdk
        );
      };

    # Ensure the Jellyfin user has access to external drives
    systemd.services.jellyfin = mkIf (config.jellyfin.user != "jellyfin") {
      serviceConfig = {
        User = config.jellyfin.user;
        ExecStartPre = "${pkgs.coreutils}/bin/chown -R ${config.jellyfin.user} /var/lib/jellyfin";
      };
    };

    # Combine all overlays into a single definition
    nixpkgs.overlays = [
      # Overlay for vaapiIntel
      (final: prev: {
        vaapiIntel = prev.vaapiIntel.override { enableHybridCodec = true; };
      })

      # Overlay for Intro Skipper plugin
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