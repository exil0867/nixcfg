{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  openVsx = inputs.nix-vscode-extensions.extensions.${pkgs.stdenv.hostPlatform.system}.open-vsx;
  baseSettings = {
    "workbench.colorTheme" = "Catppuccin Mocha";
    "editor.fontLigatures" = true;
    "editor.wordWrap" = "on";
    "editor.minimap.enabled" = false;
    "editor.renderWhitespace" = "none";
    "editor.cursorSmoothCaretAnimation" = "on";
    "telemetry.telemetryLevel" = "off";
    "update.mode" = "none";
    "security.workspace.trust.enabled" = false;
    "remote.SSH.useLocalServer" = true;
    "remote.SSH.connectTimeout" = 60;
  };

  nixExtensions = with pkgs.vscode-extensions; [
    bbenoist.nix
    jnoortheen.nix-ide
    kamadorueda.alejandra
  ];

  coreExtensions = with pkgs.vscode-extensions;
    [
      catppuccin.catppuccin-vsc
      editorconfig.editorconfig
      openVsx.jeanp413.open-remote-ssh
      openVsx.antfu.browse-lite
    ]
    ++ nixExtensions;

  jsExtensions = with pkgs.vscode-extensions; [
    dbaeumer.vscode-eslint
    esbenp.prettier-vscode
  ];

  markdownExtensions = with pkgs.vscode-extensions; [
    yzhang.markdown-all-in-one
    davidanson.vscode-markdownlint
  ];

  codeBox = pkgs.writeShellApplication {
    name = "code-box";
    runtimeInputs = [pkgs.coreutils pkgs.vscodium];
    text = builtins.readFile ./code-box.sh;
  };
in {
  home.packages = [codeBox];

  programs.vscode = {
    enable = true;
    package = pkgs.vscodium;

    profiles.default = {
      userSettings = baseSettings;
      extensions = coreExtensions;
    };

    profiles.kitspark-core = {
      userSettings =
        baseSettings
        // {
          "editor.formatOnSave" = true;
          "editor.defaultFormatter" = "esbenp.prettier-vscode";
          "eslint.validate" = ["javascript" "typescript" "typescriptreact"];
          "prettier.requireConfig" = true;
        };
      extensions = coreExtensions ++ jsExtensions;
    };

    profiles.kitspark-kitget = {
      userSettings =
        baseSettings
        // {
          "editor.formatOnSave" = true;
          "editor.defaultFormatter" = "esbenp.prettier-vscode";
          "eslint.validate" = ["javascript" "typescript" "typescriptreact"];
          "prettier.requireConfig" = true;
        };
      extensions = coreExtensions ++ jsExtensions;
    };

    profiles.kitspark-nextjs-supabase = {
      userSettings =
        baseSettings
        // {
          "editor.formatOnSave" = true;
          "editor.defaultFormatter" = "esbenp.prettier-vscode";
          "eslint.validate" = ["javascript" "typescript" "typescriptreact"];
          "prettier.requireConfig" = true;
        };
      extensions = coreExtensions ++ jsExtensions;
    };

    profiles.kitspark-specs = {
      userSettings =
        baseSettings
        // {
          "editor.wordWrap" = "on";
          "editor.quickSuggestions" = {
            "comments" = "off";
            "strings" = "off";
            "other" = "off";
          };
          "markdownlint.config" = {
            "MD013" = false;
          };
        };
      extensions = coreExtensions ++ markdownExtensions;
    };

    profiles.nix = {
      userSettings =
        baseSettings
        // {
          "editor.formatOnSave" = true;
        };
      extensions = coreExtensions;
    };

    profiles.ravage-unweave = {
      userSettings =
        baseSettings
        // {
          "editor.formatOnSave" = true;
          "editor.defaultFormatter" = "esbenp.prettier-vscode";
          "eslint.validate" = ["javascript" "typescript" "typescriptreact"];
          "prettier.requireConfig" = true;
        };
      extensions = coreExtensions ++ jsExtensions;
    };

    profiles.ravage-bonded = {
      userSettings =
        baseSettings
        // {
          "editor.formatOnSave" = true;
          "editor.defaultFormatter" = "esbenp.prettier-vscode";
          "eslint.validate" = ["javascript" "typescript" "typescriptreact"];
          "prettier.requireConfig" = true;
        };
      extensions = coreExtensions ++ jsExtensions;
    };

    profiles.trena = {
      userSettings =
        baseSettings
        // {
          "editor.formatOnSave" = true;
          "editor.defaultFormatter" = "esbenp.prettier-vscode";
          "eslint.validate" = ["javascript" "typescript" "typescriptreact"];
          "prettier.requireConfig" = true;
        };
      extensions = coreExtensions ++ jsExtensions;
    };
  };
}
