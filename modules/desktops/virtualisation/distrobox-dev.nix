{
  config,
  lib,
  pkgs,
  vars,
  ...
}: let
  cfg = config.distroboxDev;
  stableDistroboxBinDir = ".local/share/distrobox/bin";
  zshDirenvHook = ''
    case \$- in
      *i*)
        if command -v direnv >/dev/null 2>&1; then
          if ! typeset -f _direnv_hook >/dev/null 2>&1; then
            eval "\$(direnv hook zsh)"
          fi
        fi
        ;;
    esac
  '';

  createScript = pkgs.writeShellApplication {
    name = "devbox-create";
    runtimeInputs = with pkgs; [
      bash
      coreutils
      distrobox
      findutils
      gawk
      gnugrep
      podman
    ];
    text = ''
            set -euo pipefail

            distrobox_cmd="$HOME/${stableDistroboxBinDir}/distrobox"
            box="''${1:-}"
            project_path="''${2:-}"
            image="''${3:-${cfg.defaultImage}}"
            state_root="$HOME/.local/share/devboxes/$box"
            container_home="$state_root/home"
            mount_root="$state_root/mounts"
            gitconfig_args=()
            shell_args=()
            zshenv_host_path=""
            zshrc_host_path=""
            zprofile_host_path=""
            zlogin_host_path=""
            bashrc_host_path=""
            bash_profile_host_path=""
            profile_host_path=""

            if [ -z "$box" ]; then
              echo "usage: devbox-create <box-name> [project-path] [image]" >&2
              exit 1
            fi

            if [ ! -x "$distrobox_cmd" ]; then
              echo "Missing stable distrobox wrapper at $distrobox_cmd" >&2
              echo "Rebuild Home Manager/NixOS to install the wrapper set." >&2
              exit 1
            fi

            mkdir -p "$state_root" "$mount_root" "$container_home"

            if [ -f "$HOME/.gitconfig" ]; then
              gitconfig_args=(--volume "$HOME/.gitconfig:$container_home/.gitconfig:ro")
            fi

            for startup_file in .zshenv .zshrc .zprofile .zlogin .bashrc .bash_profile .profile; do
              if [ -f "$HOME/$startup_file" ]; then
                resolved_file="$(realpath "$HOME/$startup_file")"
                if [ "$startup_file" = ".zshenv" ]; then
                  zshenv_host_path="$resolved_file"
                elif [ "$startup_file" = ".zshrc" ]; then
                  zshrc_host_path="$resolved_file"
                elif [ "$startup_file" = ".zprofile" ]; then
                  zprofile_host_path="$resolved_file"
                elif [ "$startup_file" = ".zlogin" ]; then
                  zlogin_host_path="$resolved_file"
                elif [ "$startup_file" = ".bashrc" ]; then
                  bashrc_host_path="$resolved_file"
                elif [ "$startup_file" = ".bash_profile" ]; then
                  bash_profile_host_path="$resolved_file"
                elif [ "$startup_file" = ".profile" ]; then
                  profile_host_path="$resolved_file"
                fi
              fi
            done

            if [ -n "$zshenv_host_path" ]; then
              cat > "$mount_root/.zshenv" <<EOF
      export ZSH_DISABLE_COMPFIX=true
      source "$container_home/.zshenv.host"
      ${zshDirenvHook}
      EOF
              shell_args+=("--volume" "$mount_root/.zshenv:$container_home/.zshenv:ro")
              shell_args+=("--volume" "$zshenv_host_path:$container_home/.zshenv.host:ro")
            fi

            cat > "$mount_root/.zshrc" <<EOF
      if [ -f "$container_home/.zshrc.host" ]; then
        source "$container_home/.zshrc.host"
      fi

      if command -v direnv >/dev/null 2>&1; then
        if ! typeset -f _direnv_hook >/dev/null 2>&1; then
          eval "\$(direnv hook zsh)"
        fi
      fi
      EOF
            shell_args+=("--volume" "$mount_root/.zshrc:$container_home/.zshrc:ro")

            if [ -n "$zshrc_host_path" ]; then
              shell_args+=("--volume" "$zshrc_host_path:$container_home/.zshrc.host:ro")
            fi

            if [ -n "$zprofile_host_path" ]; then
              shell_args+=("--volume" "$zprofile_host_path:$container_home/.zprofile:ro")
            fi

            if [ -n "$zlogin_host_path" ]; then
              shell_args+=("--volume" "$zlogin_host_path:$container_home/.zlogin:ro")
            fi

            cat > "$mount_root/.bashrc" <<EOF
      if [ -f "$container_home/.bashrc.host" ]; then
        . "$container_home/.bashrc.host"
      fi

      if command -v direnv >/dev/null 2>&1; then
        if ! declare -F _direnv_hook >/dev/null 2>&1; then
          eval "\$(direnv hook bash)"
        fi
      fi
      EOF
            shell_args+=("--volume" "$mount_root/.bashrc:$container_home/.bashrc:ro")

            if [ -n "$bashrc_host_path" ]; then
              shell_args+=("--volume" "$bashrc_host_path:$container_home/.bashrc.host:ro")
            fi

            if [ -n "$bash_profile_host_path" ]; then
              shell_args+=("--volume" "$bash_profile_host_path:$container_home/.bash_profile:ro")
            fi

            if [ -n "$profile_host_path" ]; then
              shell_args+=("--volume" "$profile_host_path:$container_home/.profile:ro")
            fi

            if [ -n "$project_path" ]; then
              project_path="$(realpath "$project_path")"
              mkdir -p "$state_root"
              printf '%s\n' "$project_path" > "$state_root/project-path"
              volume_args=(--volume "$project_path:$project_path:rw")
            else
              volume_args=()
            fi

            if "$distrobox_cmd" list --no-color | awk 'NR>1 {print $1}' | grep -Fxq "$box"; then
              echo "Devbox '$box' already exists."
              echo "Enter it with: devbox-enter $box"
              exit 0
            fi

            "$distrobox_cmd" create \
              --name "$box" \
              --image "$image" \
              --yes \
              --hostname "$box" \
              --home "$container_home" \
              --init \
              --nvidia \
              --additional-flags "--group-add keep-groups" \
              "''${gitconfig_args[@]}" \
              "''${shell_args[@]}" \
              "''${volume_args[@]}"

            echo "Devbox ready:"
            echo "  name: $box"
            echo "  home: $container_home"
            if [ -n "$project_path" ]; then
              echo "  project: $project_path"
            fi
            if [ -f "$HOME/.gitconfig" ]; then
              echo "  git: host ~/.gitconfig mounted read-only"
            fi
            if [ "''${#shell_args[@]}" -gt 0 ]; then
              echo "  shell: startup files mounted read-only with direnv auto-hook"
            fi
            echo
            echo "Enter it with:"
            echo "  devbox-enter $box"
    '';
  };

  enterScript = pkgs.writeShellApplication {
    name = "devbox-enter";
    runtimeInputs = [pkgs.distrobox repairShellScript];
    text = ''
      set -euo pipefail

      distrobox_cmd="$HOME/${stableDistroboxBinDir}/distrobox"
      box="''${1:-}"
      shift || true

      if [ -z "$box" ]; then
        echo "usage: devbox-enter <box-name> [command...]" >&2
        exit 1
      fi

      if [ ! -x "$distrobox_cmd" ]; then
        echo "Missing stable distrobox wrapper at $distrobox_cmd" >&2
        echo "Rebuild Home Manager/NixOS to install the wrapper set." >&2
        exit 1
      fi

      devbox-repair-shell "$box" >/dev/null

      if [ "''$#" -eq 0 ]; then
        exec "$distrobox_cmd" enter "$box"
      fi

      exec "$distrobox_cmd" enter "$box" -- "''$@"
    '';
  };

  codeScript = pkgs.writeShellApplication {
    name = "devbox-code";
    runtimeInputs = [pkgs.coreutils pkgs.distrobox];
    text = ''
      set -euo pipefail

      distrobox_cmd="$HOME/${stableDistroboxBinDir}/distrobox"
      box="''${1:-}"
      state_root="$HOME/.local/share/devboxes/$box"
      project_file="$state_root/project-path"
      project_path="''${2:-}"
      shift 2>/dev/null || true

      if [ -z "$box" ]; then
        echo "usage: devbox-code <box-name> [project-path] [code-args...]" >&2
        exit 1
      fi

      if [ ! -x "$distrobox_cmd" ]; then
        echo "Missing stable distrobox wrapper at $distrobox_cmd" >&2
        echo "Rebuild Home Manager/NixOS to install the wrapper set." >&2
        exit 1
      fi

      if [ -z "$project_path" ] && [ -f "$project_file" ]; then
        project_path="$(cat "$project_file")"
      fi

      if [ -z "$project_path" ]; then
        project_path="$PWD"
      fi

      project_path="$(realpath "$project_path")"

      exec "$distrobox_cmd" enter "$box" -- code \
        --new-window \
        "$project_path" "''$@"
    '';
  };

  repairShellScript = pkgs.writeShellApplication {
    name = "devbox-repair-shell";
    runtimeInputs = with pkgs; [
      bash
      coreutils
      findutils
      gnugrep
    ];
    text = ''
            set -euo pipefail

            repair_box() {
              local box="$1"
              local state_root="$HOME/.local/share/devboxes/$box"
              local container_home="$state_root/home"
              local mount_root="$state_root/mounts"
              local zshenv_host_path="$container_home/.zshenv.host"
              local zshenv_path="$mount_root/.zshenv"

              [ -d "$state_root" ] || return 0
              mkdir -p "$mount_root"

              if [ -f "$zshenv_host_path" ] || [ -f "$zshenv_path" ]; then
                cat > "$zshenv_path" <<EOF
      export ZSH_DISABLE_COMPFIX=true
      if [ -f "$zshenv_host_path" ]; then
        source "$zshenv_host_path"
      fi
      ${zshDirenvHook}
      EOF
              fi
            }

            if [ "''$#" -gt 0 ]; then
              for box in "''$@"; do
                repair_box "$box"
              done
              exit 0
            fi

            for state_root in "$HOME"/.local/share/devboxes/*; do
              [ -d "$state_root" ] || continue
              repair_box "''${state_root##*/}"
            done
    '';
  };
in {
  options.distroboxDev = {
    enable = lib.mkEnableOption "Rootless Podman + Distrobox development workflow";

    defaultImage = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/library/ubuntu:24.04";
      description = "Default image used for new devboxes.";
    };
  };

  config = lib.mkIf cfg.enable {
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
        DBX_DEFAULT_IMAGE = cfg.defaultImage;
      };

      systemPackages = with pkgs; [
        distrobox
        podman
        podman-compose
        fuse-overlayfs
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
        repairShellScript
      ];

      home.file.".config/containers/storage.conf".text = ''
        [storage]
        driver = "overlay"

        [storage.options.overlay]
        mount_program = "${pkgs.fuse-overlayfs}/bin/fuse-overlayfs"
      '';

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
        DBX_DEFAULT_IMAGE = cfg.defaultImage;
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
        devbox-list = "distrobox list";
      };
    };
  };
}
