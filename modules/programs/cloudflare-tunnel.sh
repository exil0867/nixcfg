#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: cloudflare-tunnel [--port PORT] [--env-file FILE] [--set KEY[:host|url]]...

Each --set entry is KEY[:host|url].
  host = write only the hostname, e.g. example.trycloudflare.com
  url  = write the full https URL

Examples:
  cloudflare-tunnel --port 8080 --env-file .env --set WEBSOCKET_BASE_URL:host
  cloudflare-tunnel --port 3000 --env-file ../tdoc/apps/web/.env.local --set NEXT_PUBLIC_SITE_URL:url
EOF
}

port="8080"
env_file=".env"
set_specs=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --port)
      port="${2:-}"
      shift 2
      ;;
    --env-file)
      env_file="${2:-}"
      shift 2
      ;;
    --set)
      set_specs+=("${2:-}")
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$port" || -z "$env_file" ]]; then
  echo "Missing required values for --port or --env-file" >&2
  exit 1
fi

if [[ ${#set_specs[@]} -eq 0 ]]; then
  set_specs=(WEBSOCKET_BASE_URL:host)
fi

resolved_url=""
buffer=""

parse_set() {
  local spec="$1"
  local key="${spec%%:*}"
  local mode="host"

  if [[ "$spec" == *:* ]]; then
    mode="${spec#*:}"
  fi

  if [[ -z "$key" ]]; then
    echo "Invalid --set value: $spec" >&2
    exit 1
  fi
  if [[ "$mode" != "host" && "$mode" != "url" ]]; then
    echo "Invalid mode in --set value: $spec" >&2
    exit 1
  fi

  printf '%s\t%s\n' "$key" "$mode"
}

update_env_file() {
  local file_path="$1"
  shift

  touch "$file_path"

  local tmp_file
  tmp_file="$(mktemp)"
  cp "$file_path" "$tmp_file"

  local key value current_line found
  while [[ $# -gt 0 ]]; do
    key="$1"
    value="$2"
    shift 2
    found=0

    if grep -qE "^[[:space:]]*(export[[:space:]]+)?${key}=" "$tmp_file"; then
      sed -i -E "s|^[[:space:]]*(export[[:space:]]+)?${key}=.*$|${key}=${value}|" "$tmp_file"
      found=1
    fi

    if [[ "$found" -eq 0 ]]; then
      printf '%s=%s\n' "$key" "$value" >>"$tmp_file"
    fi
  done

  mv "$tmp_file" "$file_path"
}

set_entries=()
for spec in "${set_specs[@]}"; do
  while IFS=$'\t' read -r key mode; do
    set_entries+=("$key" "$mode")
  done < <(parse_set "$spec")
done

cloudflared tunnel --url "http://127.0.0.1:${port}" --no-autoupdate 2>&1 | while IFS= read -r -n 1 char; do
  buffer+="$char"
  if [[ -n "$resolved_url" ]]; then
    continue
  fi

  if [[ "$buffer" =~ (https://[a-z0-9-]+\.trycloudflare\.com) ]]; then
    resolved_url="${BASH_REMATCH[1]}"
    host="${resolved_url#https://}"

    updates=()
    for ((i = 0; i < ${#set_entries[@]}; i += 2)); do
      key="${set_entries[i]}"
      mode="${set_entries[i + 1]}"
      if [[ "$mode" == "url" ]]; then
        updates+=("$key" "$resolved_url")
      else
        updates+=("$key" "$host")
      fi
    done

    update_env_file "$env_file" "${updates[@]}"
    printf 'Updated %s with %s\n' "$env_file" "$(printf '%s=%s ' "${updates[@]}")"
    printf 'Tunnel URL: %s\n' "$resolved_url"
  fi
done
