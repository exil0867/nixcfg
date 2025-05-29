let
  keys = import ./keys.nix;
in {
  "deluge/auth.age".publicKeys = [keys.sky_server_key];
  "cloudflare/n0t3x1l.dev-DNS-RW.age".publicKeys = [keys.echo_key keys.sky_server_key];
  "cloudflare/n0t3x1l.dev-tunnel-echo2world.age".publicKeys = [keys.echo_key];
}
