{
  config,
  lib,
  pkgs,
  vars,
  ...
}: let
  cfg = config.distroboxDev;
  stableDistroboxBinDir = ".local/share/distrobox/bin";
  stableTemplateManifest = "$HOME/.local/share/devbox/templates.json";

  renderTemplate = src: replacements:
    let
      names = builtins.attrNames replacements;
    in
      lib.replaceStrings
      (map (name: "@${name}@") names)
      (map (name: replacements.${name}) names)
      (builtins.readFile src);

  writeDevboxApplication = attrs:
    pkgs.writeShellApplication (attrs // {checkPhase = "";});

  defaultTemplates = {
    arch-base = {
      description = "Arch base with zsh, sudo, git, curl, direnv, ripgrep, fd, jq, and Docker CLI.";
      dir = ./templates/arch-base;
      postCreate = null;
    };

    arch-dev = {
      description = "Arch dev base with base-devel, Docker CLI, and yay bootstrapped for the devbox user.";
      dir = ./templates/arch-dev;
      postCreate = null;
    };

    ubuntu-base = {
      description = "Ubuntu 24.04 base with zsh, sudo, git, curl, direnv, ripgrep, fd, jq, and Docker CLI.";
      dir = ./templates/ubuntu-base;
      postCreate = null;
    };

    debian-base = {
      description = "Debian 12 base with zsh, sudo, git, curl, direnv, ripgrep, fd, jq, and Docker CLI.";
      dir = ./templates/debian-base;
      postCreate = null;
    };
  };

  templateManifest = pkgs.writeText "devbox-templates.json" (
    builtins.toJSON (
      lib.mapAttrs (_name: template: {
        description = template.description;
        dir = toString template.dir;
        postCreate =
          if template.postCreate == null
          then ""
          else toString template.postCreate;
      })
      cfg.templates
    )
  );

  devboxCommon = pkgs.writeText "devbox-common.sh" (renderTemplate ./scripts/common.sh {
    defaultTemplate = cfg.defaultTemplate;
    devboxUser = vars.user;
    distroboxCmd = "${stableDistroboxBinDir}/distrobox";
    templateManifest = stableTemplateManifest;
  });

  createScript = writeDevboxApplication {
    name = "devbox-create";
    runtimeInputs = with pkgs; [
      bash
      coreutils
      distrobox
      findutils
      gawk
      gnugrep
      jq
      podman
      systemd
    ];
    text = renderTemplate ./scripts/create.sh {
      devboxCommon = toString devboxCommon;
    };
  };

  enterScript = writeDevboxApplication {
    name = "devbox-enter";
    runtimeInputs = with pkgs; [
      bash
      coreutils
      distrobox
      podman
      jq
    ];
    text = renderTemplate ./scripts/enter.sh {
      devboxCommon = toString devboxCommon;
    };
  };

  codeScript = writeDevboxApplication {
    name = "devbox-code";
    runtimeInputs = with pkgs; [
      bash
      coreutils
      distrobox
      podman
      jq
    ];
    text = renderTemplate ./scripts/code.sh {
      devboxCommon = toString devboxCommon;
    };
  };

  repairScript = writeDevboxApplication {
    name = "devbox-repair-shell";
    runtimeInputs = with pkgs; [
      bash
      coreutils
      distrobox
      gawk
      gnugrep
      jq
      podman
      systemd
    ];
    text = renderTemplate ./scripts/repair.sh {
      devboxCommon = toString devboxCommon;
    };
  };

  templateListScript = writeDevboxApplication {
    name = "devbox-template-list";
    runtimeInputs = with pkgs; [
      bash
      coreutils
      jq
    ];
    text = renderTemplate ./scripts/template-list.sh {
      devboxCommon = toString devboxCommon;
    };
  };
in {
  options.distroboxDev = {
    enable = lib.mkEnableOption "Rootless Podman + Distrobox devboxes";

    defaultTemplate = lib.mkOption {
      type = lib.types.str;
      default = "arch-base";
      description = "Template used when devbox-create is called without an explicit template.";
    };

    templates = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          description = lib.mkOption {
            type = lib.types.str;
            description = "Human-readable template description.";
          };

          dir = lib.mkOption {
            type = lib.types.path;
            description = "Template directory containing a Containerfile.";
          };

          postCreate = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = null;
            description = "Optional shell script run once inside the container after creation.";
          };
        };
      });
      default = defaultTemplates;
      description = "Devbox templates defined in nixcfg.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.hasAttr cfg.defaultTemplate cfg.templates;
        message = "distroboxDev.defaultTemplate must reference an existing template.";
      }
    ];

    virtualisation = {
      containers.enable = true;
      podman = {
        enable = true;
        dockerCompat = true;
        dockerSocket.enable = true;
        defaultNetwork.settings.dns_enabled = true;
      };
    };

    security.unprivilegedUsernsClone = true;
    boot.kernel.sysctl."user.max_user_namespaces" = lib.mkDefault 28633;

    users.users.${vars.user} = {
      extraGroups = ["podman" "kvm"];
      subUidRanges = [
        {
          startUid = 100000;
          count = 65536;
        }
      ];
      subGidRanges = [
        {
          startGid = 100000;
          count = 65536;
        }
      ];
    };

    environment = {
      sessionVariables = {
        DISTROBOX_USE_PODMAN = "1";
        DBX_DEFAULT_TEMPLATE = cfg.defaultTemplate;
      };

      systemPackages = with pkgs; [
        distrobox
        podman
        podman-compose
        fuse-overlayfs
        jq
        slirp4netns
        xauth
        xhost
      ];
    };

    home-manager.users.${vars.user} = {
      home.packages = [
        createScript
        enterScript
        codeScript
        repairScript
        templateListScript
      ];

      home.file.".config/containers/storage.conf".text = ''
        [storage]
        driver = "overlay"

        [storage.options.overlay]
        mount_program = "${pkgs.fuse-overlayfs}/bin/fuse-overlayfs"
      '';

      home.file.".local/share/devbox/templates.json".source = templateManifest;

      home.file."${stableDistroboxBinDir}/distrobox" = {
        executable = true;
        text = ''
          #!/bin/sh
          exec /run/current-system/sw/bin/distrobox "$@"
        '';
      };

      home.file."${stableDistroboxBinDir}/distrobox-init" = {
        executable = true;
        text = ''
          #!/bin/sh
          exec /run/current-system/sw/bin/distrobox-init "$@"
        '';
      };

      home.file."${stableDistroboxBinDir}/distrobox-export" = {
        executable = true;
        text = ''
          #!/bin/sh
          exec /run/current-system/sw/bin/distrobox-export "$@"
        '';
      };

      home.file."${stableDistroboxBinDir}/distrobox-host-exec" = {
        executable = true;
        text = ''
          #!/bin/sh
          exec /run/current-system/sw/bin/distrobox-host-exec "$@"
        '';
      };

      home.file."${stableDistroboxBinDir}/distrobox-generate-entry" = {
        executable = true;
        text = ''
          #!/bin/sh
          exec /run/current-system/sw/bin/distrobox-generate-entry "$@"
        '';
      };

      home.sessionVariables = {
        DISTROBOX_USE_PODMAN = "1";
        DBX_DEFAULT_TEMPLATE = cfg.defaultTemplate;
      };

      systemd.user.services.devbox-podman-warmup = {
        Unit = {
          Description = "Warm rootless Podman state for devboxes";
          Wants = ["podman.socket"];
          After = ["podman.socket"];
        };

        Service = {
          Type = "oneshot";
          ExecStart = "${pkgs.podman}/bin/podman ps --all";
          StandardOutput = "null";
          StandardError = "journal";
        };

        Install.WantedBy = ["default.target"];
      };

      programs.zsh.shellAliases = {
        dbxsetup = "devbox-create";
        dbxs = "distrobox list";
        dbxtemplates = "devbox-template-list";
        devbox-list = "distrobox list";
      };
    };
  };
}
