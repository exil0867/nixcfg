{ config, lib, pkgs, ... }:

let
  script = pkgs.writeShellScriptBin "reddit-auto-delete" ''
    #!/bin/sh

    # Read credentials from environment variables
    CLIENT_ID="$REDDIT_CLIENT_ID"
    CLIENT_SECRET="$REDDIT_CLIENT_SECRET"
    USERNAME="$REDDIT_USERNAME"
    PASSWORD="$REDDIT_PASSWORD"
    USER_AGENT="nixos:reddit-auto-delete:v1.0.0 (by /u/$USERNAME)"

    # Get OAuth token (fixed command substitution)
    auth_response=$(${pkgs.curl}/bin/curl -s -X POST \
        -d "grant_type=password&username=$USERNAME&password=$PASSWORD" \
        -u "$CLIENT_ID:$CLIENT_SECRET" \
        -A "$USER_AGENT" \
        https://www.reddit.com/api/v1/access_token)

    access_token=$(echo "$auth_response" | ${pkgs.jq}/bin/jq -r '.access_token')

    if [ "$access_token" = "null" ] || [ -z "$access_token" ]; then
        echo "Failed to get access token"
        echo "Response: $auth_response"
        exit 1
    fi

    # Function to delete items with modhash
    delete_item() {
      fullname="$1"
      type="$2"
      modhash="$3"

      ${pkgs.curl}/bin/curl -s -X POST \
        -H "Authorization: bearer $access_token" \
        -H "X-Modhash: $modhash" \
        -A "$USER_AGENT" \
        -d "id=$fullname" \
        "https://oauth.reddit.com/api/del"
    }

    # Get initial modhash and process saved items
    after=""
    while :; do
      # Get saved items with type=links,comments
      response=$(${pkgs.curl}/bin/curl -s -G \
        -H "Authorization: bearer $access_token" \
        -A "$USER_AGENT" \
        --data-urlencode "after=$after" \
        --data-urlencode "type=links,comments" \
        --data-urlencode "limit=100" \
        "https://oauth.reddit.com/user/$USERNAME/saved")

      # Check valid response
      if ! echo "$response" | ${pkgs.jq}/bin/jq -e '.data.children' > /dev/null; then
        echo "Invalid API response: $response"
        exit 1
      fi

      # Extract modhash from response
      modhash=$(echo "$response" | ${pkgs.jq}/bin/jq -r '.data.modhash')

      # Process items
      items=$(echo "$response" | ${pkgs.jq}/bin/jq -c '.data.children[] | {kind: .kind, name: .data.name, author: .data.author}')
      after=$(echo "$response" | ${pkgs.jq}/bin/jq -r '.data.after // empty')

      echo "$items" | while read -r item; do
        author=$(echo "$item" | ${pkgs.jq}/bin/jq -r '.author')
        kind=$(echo "$item" | ${pkgs.jq}/bin/jq -r '.kind')
        name=$(echo "$item" | ${pkgs.jq}/bin/jq -r '.name')

        if [ "$author" = "$USERNAME" ]; then
          echo "Deleting $name ($kind)..."
          delete_item "$name" "$kind" "$modhash"
          sleep 1  # Rate limit protection
        fi
      done

      [ -z "$after" ] || [ "$after" = "null" ] && break
    done
  '';

in {
  options = {
    services.reddit-auto-delete = {
      enable = lib.mkEnableOption "Reddit auto-delete service";
      interval = lib.mkOption {
        type = lib.types.str;
        default = "hourly";
        description = "Systemd timer interval for running the service";
      };
      environmentFile = lib.mkOption {
        type = lib.types.path;
        description = "Path to file containing Reddit credentials";
      };
    };
  };

  config = lib.mkIf config.services.reddit-auto-delete.enable {
    systemd.services.reddit-auto-delete = {
      description = "Automatically delete saved Reddit posts/comments";
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = config.services.reddit-auto-delete.environmentFile;
        ExecStart = "${script}/bin/reddit-auto-delete";
      };
    };

    systemd.timers.reddit-auto-delete = {
      description = "Timer for Reddit auto-delete service";
      timerConfig = {
        OnUnitActiveSec = config.services.reddit-auto-delete.interval;
        OnBootSec = "5m";
        Unit = "reddit-auto-delete.service";
      };
      wantedBy = [ "timers.target" ];
    };
  };
}