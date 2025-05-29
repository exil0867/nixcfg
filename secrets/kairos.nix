let
  keys = import ./keys.nix;
in {
  "tailscale/preauth-kairos.age".publicKeys = [keys.personal_key keys.echo_key];
}
