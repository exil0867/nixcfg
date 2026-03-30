{ config, lib, pkgs, vars, ... }:

let
  cfg = config.distroboxDev;
  stableDistroboxBinDir = ".local/share/distrobox/bin";

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
      zsh_args=()
      zshenv_host_path=""

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

      for startup_file in .zshenv .zshrc .zprofile .zlogin; do
        if [ -f "$HOME/$startup_file" ]; then
          resolved_file="$(realpath "$HOME/$startup_file")"
          if [ "$startup_file" = ".zshenv" ]; then
            zshenv_host_path="$resolved_file"
          else
            zsh_args+=("--volume" "$resolved_file:$container_home/$startup_file:ro")
          fi
        fi
      done

      if [ -n "$zshenv_host_path" ]; then
        cat > "$mount_root/.zshenv" <<EOF
export ZSH_DISABLE_COMPFIX=true
source "$container_home/.zshenv.host"
EOF
        zsh_args+=("--volume" "$mount_root/.zshenv:$container_home/.zshenv:ro")
        zsh_args+=("--volume" "$zshenv_host_path:$container_home/.zshenv.host:ro")
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
        "''${zsh_args[@]}" \
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
      if [ "''${#zsh_args[@]}" -gt 0 ]; then
        echo "  zsh: host startup files mounted read-only"
      fi
      echo
      echo "Enter it with:"
      echo "  devbox-enter $box"
    '';
  };

  enterScript = pkgs.writeShellApplication {
    name = "devbox-enter";
    runtimeInputs = [ pkgs.distrobox ];
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

      if [ "''$#" -eq 0 ]; then
        exec "$distrobox_cmd" enter "$box"
      fi

      exec "$distrobox_cmd" enter "$box" -- "''$@"
    '';
  };

  codeScript = pkgs.writeShellApplication {
    name = "devbox-code";
    runtimeInputs = [ pkgs.coreutils pkgs.distrobox ];
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
      extraGroups = [ "podman" "kvm" ];
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

      programs.zsh.shellAliases = {
        dbxsetup = "devbox-create";
        dbxs = "distrobox list";
        devbox-list = "distrobox list";
      };
    };
  };
}
