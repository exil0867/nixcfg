set -euo pipefail
# shellcheck disable=SC1091
source @devboxCommon@

repair_box() {
  local box="$1"
  local state_root=""
  local container_home=""
  local project_path=""
  local template=""
  local image_tag=""
  local docker_socket=""
  local docker_socket_dir=""
  local additional_flags="--group-add keep-groups"
  local volume_args=()
  local gitconfig_args=()
  local docker_socket_args=()

  state_root="$(state_root_for "$box")"
  container_home="$state_root/home"

  if [ ! -d "$container_home" ]; then
    echo "Skipping '$box': no managed home at $container_home" >&2
    return 0
  fi

  require_distrobox

  if [ -f "$state_root/template" ]; then
    template="$(cat "$state_root/template")"
  else
    template="$DEVBOX_DEFAULT_TEMPLATE"
    printf '%s\n' "$template" > "$state_root/template"
  fi

  require_template "$template"

  if [ -f "$state_root/project-path" ]; then
    project_path="$(cat "$state_root/project-path")"
    if [ -n "$project_path" ]; then
      if [ -e "$project_path" ]; then
        volume_args=(--volume "$project_path:$project_path:rw")
      else
        echo "Warning: project path for '$box' no longer exists: $project_path" >&2
      fi
    fi
  fi

  if [ -f "$HOME/.gitconfig" ]; then
    gitconfig_args=(--volume "$HOME/.gitconfig:$container_home/.gitconfig:ro")
  fi

  docker_socket="$(podman_socket_path)"
  docker_socket_dir="${docker_socket%/*}"
  ensure_podman_socket "$docker_socket"
  docker_socket_args=(
    --volume "$docker_socket_dir:$docker_socket_dir:rw"
    --volume "$docker_socket:/var/run/docker.sock:rw"
  )
  additional_flags="$additional_flags --env DOCKER_HOST=unix://$docker_socket"

  image_tag="$(template_image "$template")"
  build_template "$template" "$image_tag"
  printf '%s\n' "$image_tag" > "$state_root/image"

  if "$DEVBOX_DISTROBOX_CMD" list --no-color | awk 'NR>1 {print $1}' | grep -Fxq "$box"; then
    echo "Recreating '$box' container object; keeping managed home at $container_home."
    "$DEVBOX_DISTROBOX_CMD" rm --force "$box"
  elif podman container exists "$box"; then
    echo "Recreating '$box' container object; keeping managed home at $container_home."
    podman rm --force "$box"
  fi

  "$DEVBOX_DISTROBOX_CMD" create \
    --name "$box" \
    --image "$image_tag" \
    --yes \
    --hostname "$box" \
    --home "$container_home" \
    --init \
    --nvidia \
    --additional-flags "$additional_flags" \
    "${docker_socket_args[@]}" \
    "${gitconfig_args[@]}" \
    "${volume_args[@]}"

  start_box "$box"
  install_zsh_baseline_packages "$box"
  install_host_command_shim "$box" "cloudflare-tunnel" "cloudflare-tunnel"
  remove_managed_shell_files "$container_home"
  seed_home "$container_home"
  echo "Repaired '$box' with template '$template'."
}

if [ "$#" -gt 0 ]; then
  for box in "$@"; do
    repair_box "$box"
  done
  exit 0
fi

for state_root in "$HOME"/.local/share/devboxes/*; do
  [ -d "$state_root" ] || continue
  repair_box "${state_root##*/}"
done
