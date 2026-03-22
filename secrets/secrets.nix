let
  personal_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIItpAE9vRUSAOZAqG9rUmS58ANi/kIIdM9Ki34kEARIP";
  kairos_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGejHkTo/wf6g9QRAKnpLV9FWTNEoh7OMUpum3q+xN+V";
  echo_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIInjI+XzPKAmRH/S/zpx4XVusY8W0IbG6cithnOZBZJo";
  sky_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA5OBgoL9DV+lrXUhKAq32mQPVDvyaaHNNoibhULIiuO";
in {
  "cloudflare/kyrena.dev-DNS-RW.age".publicKeys = [echo_key sky_key];
  "tailscale/preauth-kairos.age".publicKeys = [kairos_key echo_key];
  "cloudflare/email.age".publicKeys = [echo_key];
  "discord/exil0138.age".publicKeys = [echo_key];
  "system/echo-user-pwd.age".publicKeys = [echo_key];
  "reddit/reddit-cleaner.age".publicKeys = [echo_key];
  "deluge/auth.age".publicKeys = [sky_key];
  "immich/server.age".publicKeys = [echo_key];
  "immich/sync.age".publicKeys = [kairos_key];
  "metrics/token.age".publicKeys = [kairos_key echo_key sky_key];
  "trena/main.age".publicKeys = [sky_key];
  "kitspark/web.age".publicKeys = [sky_key];
  "cloudflare/kitspark.dev-DNS-RW.age".publicKeys = [sky_key];
}
