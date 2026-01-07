{ config, pkgs, lib, ... }:

let
  # Global personal settings shared by all profiles
  baseSettings = {
    "editor.fontLigatures" = true;
    "editor.formatOnSave" = false;
    "editor.wordWrap" = "on";
    "telemetry.telemetryLevel" = "off";
    "update.mode" = "none";
  };

  # Shared JS/TS extensions
  jsExtensions = with pkgs.vscode-extensions; [
    dbaeumer.vscode-eslint
    esbenp.prettier-vscode
  ];
in
{
  programs.vscode = {
    enable = true;
    package = pkgs.vscodium;

    # Default (personal baseline) profile
    profiles.default = {
      userSettings = baseSettings;

      extensions = with pkgs.vscode-extensions; [
        dracula-theme.theme-dracula
      ];
    };

    # Project profiles

    profiles."@chevron/audibly" = {
      userSettings = baseSettings;
      extensions = jsExtensions;
    };

    profiles."@chevron/sprang" = {
      userSettings = baseSettings;
      extensions = jsExtensions;
    };

    profiles."@kitspark/core" = {
      userSettings = baseSettings;
      extensions = jsExtensions;
    };

    profiles."@kitspark/specs" = {
      userSettings = baseSettings;
      extensions = jsExtensions;
    };

    profiles."@kitspark/nextjs-supabase-saas-starter" = {
      userSettings = baseSettings;
      extensions = jsExtensions;
    };

    # Nix profile
    profiles.nix = {
      userSettings = baseSettings;

      extensions = with pkgs.vscode-extensions; [
        bbenoist.nix
        jnoortheen.nix-ide
        kamadorueda.alejandra
      ];
    };
  };
}
