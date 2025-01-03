let
  personal_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIItpAE9vRUSAOZAqG9rUmS58ANi/kIIdM9Ki34kEARIP";
  remote_server_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIInjI+XzPKAmRH/S/zpx4XVusY8W0IbG6cithnOZBZJo";
  keys = [personal_key remote_server_key];
in {
  "tailscale/preauth-kairos.age".publicKeys = [personal_key remote_server_key];
  "cloudflare/n0t3x1l.dev-DNS-RW.age".publicKeys = [remote_server_key];
}
