set -euo pipefail
# shellcheck disable=SC1091
source @devboxCommon@

box="${1:-}"
state_root=""
container_home=""
project_file=""
project_path=""
workdir=""
shell_path=""
exec_args=()
shift || true

if [ -z "$box" ]; then
  echo "usage: devbox-enter <box-name> [command...]" >&2
  exit 1
fi

require_distrobox
state_root="$(state_root_for "$box")"
container_home="$state_root/home"
project_file="$state_root/project-path"

if [ -f "$project_file" ]; then
  project_path="$(cat "$project_file")"
fi

mkdir -p "$container_home"
seed_home "$container_home"
start_box "$box"
workdir="$(resolve_workdir "$box" "$PWD" "$project_path")"

if [ "$#" -eq 0 ]; then
  shell_path="$(box_shell "$box")"
  [ -n "$shell_path" ] || shell_path="/bin/sh"
  append_host_env_args exec_args
  exec podman exec -it \
    "${exec_args[@]}" \
    -u "$DEVBOX_USER" \
    -w "$workdir" \
    "$box" \
    "$shell_path" -l
fi

append_host_env_args exec_args
if [ -t 0 ] && [ -t 1 ]; then
  exec_args=(-it "${exec_args[@]}")
fi

exec podman exec \
  "${exec_args[@]}" \
  -u "$DEVBOX_USER" \
  -w "$workdir" \
  "$box" \
  "$@"
