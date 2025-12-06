let
  personal_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIItpAE9vRUSAOZAqG9rUmS58ANi/kIIdM9Ki34kEARIP";
  echo_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIInjI+XzPKAmRH/S/zpx4XVusY8W0IbG6cithnOZBZJo";
  sky_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEriuOuF5+iFUxyOZx3adyDj2mUt5hmJN73y/14v0pL2";
in {
  "cloudflare/kyrena.dev-DNS-RW.age".publicKeys = [echo_key sky_key];
  "tailscale/preauth-kairos.age".publicKeys = [personal_key echo_key];
  "cloudflare/email.age".publicKeys = [echo_key];
  "discord/exil0138.age".publicKeys = [echo_key];
  "system/echo-user-pwd.age".publicKeys = [echo_key];
  "reddit/reddit-cleaner.age".publicKeys = [echo_key];
  "deluge/auth.age".publicKeys = [sky_key];
  "immich/server.age".publicKeys = [echo_key];
}
