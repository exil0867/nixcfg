DEVBOX_USER='@devboxUser@'
DEVBOX_DEFAULT_TEMPLATE='@defaultTemplate@'
DEVBOX_TEMPLATE_MANIFEST='@templateManifest@'
DEVBOX_DISTROBOX_CMD="$HOME/@distroboxCmd@"

die() {
  printf '%s\n' "$*" >&2
  exit 1
}

require_distrobox() {
  if [ ! -x "$DEVBOX_DISTROBOX_CMD" ]; then
    die "Missing stable distrobox wrapper at $DEVBOX_DISTROBOX_CMD"
  fi
}

state_root_for() {
  printf '%s\n' "$HOME/.local/share/devboxes/$1"
}

list_templates() {
  jq -r 'to_entries[] | "\(.key)\t\(.value.description)"' "$DEVBOX_TEMPLATE_MANIFEST" |
    while IFS=$'\t' read -r name description; do
      if [ "$name" = "$DEVBOX_DEFAULT_TEMPLATE" ]; then
        printf '%-16s %s [default]\n' "$name" "$description"
      else
        printf '%-16s %s\n' "$name" "$description"
      fi
    done
}

require_template() {
  local template="$1"
  if ! jq -e --arg name "$template" '.[$name] != null' "$DEVBOX_TEMPLATE_MANIFEST" >/dev/null; then
    printf 'Unknown devbox template: %s\n\nAvailable templates:\n' "$template" >&2
    list_templates >&2
    exit 1
  fi
}

template_field() {
  local template="$1"
  local field="$2"
  jq -r --arg name "$template" --arg field "$field" '.[$name][$field] // empty' "$DEVBOX_TEMPLATE_MANIFEST"
}

template_image() {
  printf 'localhost/devbox-%s:latest\n' "$1"
}

build_template() {
  local template="$1"
  local image_tag="${2:-}"
  local template_dir=""

  require_template "$template"
  template_dir="$(template_field "$template" dir)"
  if [ -z "$image_tag" ]; then
    image_tag="$(template_image "$template")"
  fi

  [ -f "$template_dir/Containerfile" ] || die "Template '$template' is missing a Containerfile."

  podman build \
    --tag "$image_tag" \
    --file "$template_dir/Containerfile" \
    "$template_dir" >&2
}

seed_home() {
  local container_home="$1"
  mkdir -p "$container_home"

  cat > "$container_home/.zshenv" <<'EOF'
export ZSH_DISABLE_COMPFIX=true
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=10000
export SAVEHIST=10000
EOF

  cat > "$container_home/.zshrc" <<'EOF'
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' group-name ''

autoload -Uz compinit
if [ -d "$HOME/.cache/zsh" ]; then
  compinit -d "$HOME/.cache/zsh/zcompdump"
else
  mkdir -p "$HOME/.cache/zsh"
  compinit -d "$HOME/.cache/zsh/zcompdump"
fi

setopt APPEND_HISTORY
setopt AUTO_CD
setopt EXTENDED_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt HIST_SAVE_NO_DUPS
setopt INTERACTIVE_COMMENTS
setopt NO_BEEP
setopt PROMPT_SUBST
setopt SHARE_HISTORY

autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search

bindkey -e
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey '^[[C' forward-char
bindkey '^[[D' backward-char
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[3~' delete-char

if [[ -z "${TERM:-}" || "${TERM:-}" = "dumb" ]]; then
  export TERM=xterm-256color
fi

autoload -Uz vcs_info
zstyle ':vcs_info:git:*' formats ' %F{yellow}(git:%b)%f'
zstyle ':vcs_info:git:*' actionformats ' %F{yellow}(git:%b|%a)%f'
precmd() { vcs_info }

if [[ -z "${PROMPT:-}" ]]; then
  PROMPT='%F{cyan}%n@%m%f:%F{blue}%~%f${vcs_info_msg_0_} %# '
fi

if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

for plugin_file in \
  /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh; do
  if [ -r "$plugin_file" ]; then
    source "$plugin_file"
    break
  fi
done

for plugin_file in \
  /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
  if [ -r "$plugin_file" ]; then
    source "$plugin_file"
    break
  fi
done
EOF

  cat > "$container_home/.zprofile" <<'EOF'
# Managed by devbox.
EOF

  cat > "$container_home/.bashrc" <<'EOF'
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook bash)"
fi
EOF

  cat > "$container_home/.bash_profile" <<'EOF'
[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"
EOF

  cat > "$container_home/.profile" <<'EOF'
# Managed by devbox.
EOF

  cat > "$container_home/.bash_logout" <<'EOF'
# Managed by devbox.
EOF
}

remove_managed_shell_files() {
  local container_home="$1"

  rm -f \
    "$container_home/.zshenv" \
    "$container_home/.zshrc" \
    "$container_home/.zprofile" \
    "$container_home/.bashrc" \
    "$container_home/.bash_profile" \
    "$container_home/.profile" \
    "$container_home/.bash_logout"
}

start_box() {
  local box="$1"
  local status=""
  local state_error=""

  status="$(podman inspect "$box" --format '{{.State.Status}}' 2>/dev/null || true)"
  if [ "$status" = "running" ]; then
    return 0
  fi

  # Safe to run simple start once the first-time interactive setup is finished
  podman start "$box" >/dev/null 2>&1 || true

  if podman exec "$box" /bin/sh -lc "getent passwd '$DEVBOX_USER' >/dev/null 2>&1"; then
    return 0
  fi

  state_error="$(podman inspect "$box" --format '{{.State.Error}}' 2>/dev/null || true)"
  if [ -n "$state_error" ]; then
    die "Devbox '$box' failed to become ready. Podman error: $state_error"
  fi

  die "Devbox '$box' failed to become ready."
}

box_shell() {
  local box="$1"
  podman exec "$box" /bin/sh -lc "getent passwd '$DEVBOX_USER' | cut -d: -f7"
}

preferred_shell() {
  local box="$1"
  local shell_path=""

  shell_path="$(podman exec "$box" /bin/sh -lc '
    if command -v zsh >/dev/null 2>&1; then
      command -v zsh
    elif [ -x /usr/bin/zsh ]; then
      printf "/usr/bin/zsh\n"
    elif [ -x /bin/zsh ]; then
      printf "/bin/zsh\n"
    else
      getent passwd "'"$DEVBOX_USER"'" | cut -d: -f7
    fi
  ')"

  if [ -n "$shell_path" ]; then
    printf '%s\n' "$shell_path"
    return 0
  fi

  printf '/bin/sh\n'
}

box_home() {
  local box="$1"
  podman exec "$box" /bin/sh -lc "getent passwd '$DEVBOX_USER' | cut -d: -f6"
}

resolve_workdir() {
  local box="$1"
  local requested="$2"
  local fallback="$3"
  local candidate=""

  for candidate in "$requested" "$fallback" "$(box_home "$box")" "/"; do
    [ -n "$candidate" ] || continue
    if podman exec "$box" /bin/sh -lc 'cd "$1" >/dev/null 2>&1' sh "$candidate" >/dev/null 2>&1; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  printf '/\n'
}

run_post_create() {
  local template="$1"
  local box="$2"
  local project_path="$3"
  local post_create=""

  post_create="$(template_field "$template" postCreate)"
  [ -n "$post_create" ] || return 0
  [ -f "$post_create" ] || die "Template '$template' references a missing post-create script."

  start_box "$box"
  podman exec -i "$box" /bin/sh -s -- "$DEVBOX_USER" "$project_path" < "$post_create"
}

install_zsh_baseline_packages() {
  local box="$1"

  podman exec -u 0 "$box" /bin/sh -lc '
    set -eu

    if command -v pacman >/dev/null 2>&1; then
      pacman -Syu --noconfirm
      pacman -S --noconfirm --needed \
        zsh \
        zsh-autosuggestions \
        zsh-completions \
        zsh-syntax-highlighting
      exit 0
    fi

    if command -v apt-get >/dev/null 2>&1; then
      export DEBIAN_FRONTEND=noninteractive
      apt-get update
      apt-get install -y --no-install-recommends \
        zsh \
        zsh-autosuggestions \
        zsh-syntax-highlighting
      exit 0
    fi

    echo "No known package manager found for Zsh baseline packages." >&2
    exit 0
  '
}

append_host_env_args() {
  local -n target_ref="$1"
  local var=""

  for var in \
    DISPLAY \
    WAYLAND_DISPLAY \
    XDG_RUNTIME_DIR \
    DBUS_SESSION_BUS_ADDRESS \
    PULSE_SERVER \
    SSH_AUTH_SOCK \
    TERM \
    COLORTERM \
    XAUTHORITY
  do
    if [ -n "${!var:-}" ]; then
      target_ref+=(-e "$var=${!var}")
    fi
  done
}

install_host_command_shim() {
  local box="$1"
  local command_name="$2"
  local host_command="$3"

  podman exec -u 0 "$box" /bin/sh -lc "
    set -eu
    mkdir -p /usr/local/bin
    cat > /usr/local/bin/$command_name <<'EOF'
#!/usr/bin/env sh
exec distrobox-host-exec $host_command \"\$@\"
EOF
    chmod 755 /usr/local/bin/$command_name
  "
}
