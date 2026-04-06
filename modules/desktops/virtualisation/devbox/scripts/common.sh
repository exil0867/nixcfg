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
EOF

  cat > "$container_home/.zshrc" <<'EOF'
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi
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

  status="$(podman inspect "$box" --format '{{.State.Status}}' 2>/dev/null || true)"
  if [ "$status" = "running" ]; then
    return 0
  fi

  timeout 90 "$DEVBOX_DISTROBOX_CMD" enter --no-tty "$box" -- /bin/sh -lc "true" </dev/null >/dev/null 2>&1 || true

  status="$(podman inspect "$box" --format '{{.State.Status}}' 2>/dev/null || true)"
  if [ "$status" != "running" ]; then
    podman start "$box" >/dev/null 2>&1 || true
  fi

  if podman exec "$box" /bin/sh -lc "getent passwd '$DEVBOX_USER' >/dev/null 2>&1"; then
    return 0
  fi

  die "Devbox '$box' failed to become ready."
}

box_shell() {
  local box="$1"
  podman exec "$box" /bin/sh -lc "getent passwd '$DEVBOX_USER' | cut -d: -f7"
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
