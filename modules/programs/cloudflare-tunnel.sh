#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: cloudflare-tunnel [--port PORT] [--env-file FILE [--set KEY[:host|url]]...]...

Multiple --env-file groups can be given. Each group defines the file and the
variables to update when the tunnel URL is ready.

Modes:
  host  -> write only the hostname (example.trycloudflare.com)
  url   -> write the full URL (https://example.trycloudflare.com)

If no --env-file is provided at all, .env is used with any --set specs
(or WEBSOCKET_BASE_URL:host if none are given).

Examples:
  # Two files, different variables
  cloudflare-tunnel --port 3000 \
    --env-file frontend/.env --set NEXT_PUBLIC_SITE_URL:url \
    --env-file backend/.env  --set API_HOST:host --set WS_URL:url

  # Default: single .env with a default variable
  cloudflare-tunnel --port 8080

  # Multiple updates to the same file (two separate groups)
  cloudflare-tunnel --port 8080 \
    --env-file .env --set KEY1:host \
    --env-file .env --set KEY2:url
EOF
}

port="8080"
# Array of groups: each group is "file::spec1|spec2|..."
groups=()
current_file=""
current_specs=()

finalize_current_group() {
  if [[ -n "$current_file" ]]; then
    local joined
    if [[ ${#current_specs[@]} -gt 0 ]]; then
      # join specs with '|'
      printf -v joined '%s|' "${current_specs[@]}"
      joined="${joined%|}"   # remove trailing |
    else
      joined=""
    fi
    groups+=("${current_file}::${joined}")
    current_file=""
    current_specs=()
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --port)
      port="${2:-}"
      shift 2
      ;;
    --env-file)
      finalize_current_group
      current_file="${2:-}"
      shift 2
      ;;
    --set)
      if [[ -z "$current_file" ]]; then
        # No --env-file seen yet -> treat as default .env group (create it now)
        current_file=".env"
      fi
      current_specs+=("${2:-}")
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
finalize_current_group

# If no groups at all, create a default .env group with default spec
if [[ ${#groups[@]} -eq 0 ]]; then
  groups+=(".env::WEBSOCKET_BASE_URL:host")
fi

if [[ -z "$port" ]]; then
  echo "Missing required value for --port" >&2
  exit 1
fi

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

  local key value found
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

resolved_url=""
buffer=""

# Process groups: for each group, build the list of (key, mode) pairs
declare -A group_entries   # file -> list of "key mode" pairs
declare -a file_order      # preserve order of files

for group in "${groups[@]}"; do
  file="${group%%::*}"
  specs_str="${group#*::}"

  if [[ -z "$specs_str" ]]; then
    continue  # empty spec list – skip this group
  fi

  IFS='|' read -ra specs <<< "$specs_str"
  for spec in "${specs[@]}"; do
    while IFS=$'\t' read -r key mode; do
      group_entries["$file"]+="$key $mode"$'\n'
    done < <(parse_set "$spec")
  done

  # track order of first appearance
  if [[ ! " ${file_order[*]} " =~ " ${file} " ]]; then
    file_order+=("$file")
  fi
done

cloudflared tunnel --url "http://127.0.0.1:${port}" --no-autoupdate 2>&1 | while IFS= read -r -n 1 char; do
  buffer+="$char"
  if [[ -n "$resolved_url" ]]; then
    continue
  fi

  if [[ "$buffer" =~ (https://[a-z0-9-]+\.trycloudflare\.com) ]]; then
    resolved_url="${BASH_REMATCH[1]}"
    host="${resolved_url#https://}"

    # Update each file with its own set of keys
    for file in "${file_order[@]}"; do
      updates=()
      # Read the stored pairs for this file
      while IFS=' ' read -r key mode; do
        [[ -z "$key" ]] && continue
        if [[ "$mode" == "url" ]]; then
          updates+=("$key" "$resolved_url")
        else
          updates+=("$key" "$host")
        fi
      done <<< "${group_entries[$file]}"

      if [[ ${#updates[@]} -gt 0 ]]; then
        update_env_file "$file" "${updates[@]}"
        printf 'Updated %s with %s\n' "$file" "$(printf '%s=%s ' "${updates[@]}")"
      fi
    done

    printf 'Tunnel URL: %s\n' "$resolved_url"
  fi
done