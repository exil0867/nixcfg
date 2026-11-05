set -euo pipefail
# shellcheck disable=SC1091
source @devboxCommon@

repair_box() {
  local box="$1"
  local state_root=""
  local container_home=""

  state_root="$(state_root_for "$box")"

  if [ ! -d "$state_root" ]; then
    echo "Skipping '$box': no managed devbox state at $state_root" >&2
    return 0
  fi

  start_box "$box"
  container_home="$(box_home "$box")"
  if [ -z "$container_home" ] || [ ! -d "$container_home" ]; then
    echo "Skipping '$box': no accessible managed home at ${container_home:-<unset>}" >&2
    return 0
  fi

  install_zsh_baseline_packages "$box"
  install_host_command_shim "$box" "cloudflare-tunnel" "cloudflare-tunnel"
  remove_managed_shell_files "$container_home"
  seed_home "$container_home"
  echo "Repaired Zsh baseline for '$box'."
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
