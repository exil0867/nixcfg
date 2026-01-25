{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  openVsx = pkgs.open-vsx;
  marketplace = pkgs.vscode-marketplace;
  baseSettings = {
    "workbench.colorTheme" = "One Dark Pro Night Flat";
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
    "github.copilot.inlineSuggest.enable" = false;
    "github.copilot.editor.enableAutoCompletions" = false;
    "settingsSync.enabled" = false;
    "github.copilot.enable" = {
      "*" = false;
    };
    "github.copilot.editor.enableCodeActions" = false;
    "chat.agent.enabled" = false;
    "chat.disableAIFeatures" = true;
  };

  nixExtensions = with marketplace; [
    bbenoist.nix
    jnoortheen.nix-ide
    kamadorueda.alejandra
  ];

  coreExtensions = with marketplace;
    [
      zhuangtongfa.material-theme
      editorconfig.editorconfig
      ms-vscode-remote.remote-ssh
      github.vscode-github-actions
      github.vscode-pull-request-github
      github.remotehub
      antfu.browse-lite
    ]
    ++ nixExtensions;

  jsExtensions = with marketplace; [
    dbaeumer.vscode-eslint
    esbenp.prettier-vscode
  ];

  markdownExtensions = with marketplace; [
    yzhang.markdown-all-in-one
    davidanson.vscode-markdownlint
  ];

  codeBox = pkgs.writeShellApplication {
    name = "code-box";
    runtimeInputs = [pkgs.coreutils pkgs.vscode];
    text = builtins.readFile ./code-box.sh;
  };
in {
  home.packages = [codeBox];

  programs.vscode = {
    enable = true;
    package = pkgs.vscode;

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

    profiles.kitspark-nextjs-supabase-source = {
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
