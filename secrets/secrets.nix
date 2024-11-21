let
  personal_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIItpAE9vRUSAOZAqG9rUmS58ANi/kIIdM9Ki34kEARIP";
  remote_server_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMRBd09TZ22IUNl3oST8w2/imcenmjTd9To5RL8O4rDc";
  keys = [personal_key remote_server_key];
in {
  "secret1.age".publicKeys = keys;
}