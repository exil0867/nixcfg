set -euo pipefail
# shellcheck disable=SC1091
source @devboxCommon@

box="${1:-}"
state_root=""
project_file=""
project_path="${2:-}"
exec_args=()
shift 2>/dev/null || true

if [ -z "$box" ]; then
  echo "usage: devbox-code <box-name> [project-path] [code-args...]" >&2
  exit 1
fi

require_distrobox
state_root="$(state_root_for "$box")"
project_file="$state_root/project-path"

if [ -z "$project_path" ] && [ -f "$project_file" ]; then
  project_path="$(cat "$project_file")"
fi

if [ -z "$project_path" ]; then
  project_path="$PWD"
fi

project_path="$(realpath "$project_path")"

start_box "$box"
append_host_env_args exec_args

exec podman exec \
  "${exec_args[@]}" \
  -u "$DEVBOX_USER" \
  -w "$project_path" \
  "$box" \
  code \
  --new-window \
  "$project_path" "$@"
