set -euo pipefail
# shellcheck disable=SC1091
source @devboxCommon@

box="${1:-}"
project_path="${2:-}"
template="${3:-$DEVBOX_DEFAULT_TEMPLATE}"
state_root=""
container_home=""
image_tag=""
gitconfig_args=()

if [ -z "$box" ]; then
  echo "usage: devbox-create <box-name> [project-path] [template]" >&2
  exit 1
fi

require_distrobox
require_template "$template"

state_root="$(state_root_for "$box")"
container_home="$state_root/home"

if "$DEVBOX_DISTROBOX_CMD" list --no-color | awk 'NR>1 {print $1}' | grep -Fxq "$box"; then
  echo "Devbox '$box' already exists."
  echo "Enter it with: devbox-enter $box"
  exit 0
fi

mkdir -p "$state_root" "$container_home"
seed_home "$container_home"

if [ -n "$project_path" ]; then
  project_path="$(realpath "$project_path")"
  printf '%s\n' "$project_path" > "$state_root/project-path"
  volume_args=(--volume "$project_path:$project_path:rw")
else
  volume_args=()
fi

printf '%s\n' "$template" > "$state_root/template"

if [ -f "$HOME/.gitconfig" ]; then
  gitconfig_args=(--volume "$HOME/.gitconfig:$container_home/.gitconfig:ro")
fi

image_tag="$(template_image "$template")"
build_template "$template" "$image_tag"
printf '%s\n' "$image_tag" > "$state_root/image"

"$DEVBOX_DISTROBOX_CMD" create \
  --name "$box" \
  --image "$image_tag" \
  --yes \
  --hostname "$box" \
  --home "$container_home" \
  --init \
  --nvidia \
  --additional-flags "--group-add keep-groups" \
  "${gitconfig_args[@]}" \
  "${volume_args[@]}"

seed_home "$container_home"
install_host_command_shim "$box" "cloudflare-tunnel" "cloudflare-tunnel"
run_post_create "$template" "$box" "$project_path"

echo "Devbox ready:"
echo "  name: $box"
echo "  template: $template"
echo "  image: $image_tag"
echo "  home: $container_home"
if [ -n "$project_path" ]; then
  echo "  project: $project_path"
fi
if [ -f "$HOME/.gitconfig" ]; then
  echo "  git: host ~/.gitconfig mounted read-only"
fi
echo
echo "Enter it with:"
echo "  devbox-enter $box"
