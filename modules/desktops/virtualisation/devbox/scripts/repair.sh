set -euo pipefail
# shellcheck disable=SC1091
source @devboxCommon@

repair_box() {
  local box="$1"
  local state_root=""
  local container_home=""

  state_root="$(state_root_for "$box")"
  container_home="$state_root/home"

  if [ ! -d "$container_home" ]; then
    echo "Skipping '$box': no managed home at $container_home" >&2
    return 0
  fi

  remove_managed_shell_files "$container_home"
  seed_home "$container_home"
  echo "Repaired managed shell files for '$box'."
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
