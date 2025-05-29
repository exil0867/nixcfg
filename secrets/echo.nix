let
  keys = import ./keys.nix;
in {
  "cloudflare/email.age".publicKeys = [keys.echo_key];
  "discord/exil0138.age".publicKeys = [keys.echo_key];
  "system/echo-user-pwd.age".publicKeys = [keys.echo_key];
  "reddit/reddit-cleaner.age".publicKeys = [keys.echo_key];
}
