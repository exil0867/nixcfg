let
  personal_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIItpAE9vRUSAOZAqG9rUmS58ANi/kIIdM9Ki34kEARIP";
  remote_server_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIInjI+XzPKAmRH/S/zpx4XVusY8W0IbG6cithnOZBZJo";
  sky_server_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMqlP73DfKLVHNBbff/Uz4GHx+yq7ONBfFLHRLu+AK8e";
  keys = [personal_key remote_server_key sky_server_key];
in {
  "tailscale/preauth-kairos.age".publicKeys = [personal_key remote_server_key];
  "cloudflare/n0t3x1l.dev-DNS-RW.age".publicKeys = [remote_server_key sky_server_key];
  "cloudflare/n0t3x1l.dev-tunnel-echo2world.age".publicKeys = [remote_server_key];
  "cloudflare/email.age".publicKeys = [remote_server_key];
  "discord/exil0138.age".publicKeys = [remote_server_key];
  "system/echo-user-pwd.age".publicKeys = [remote_server_key];
  "reddit/reddit-cleaner.age".publicKeys = [remote_server_key];
  "deluge/auth.age".publicKeys = [sky_server_key];
}
