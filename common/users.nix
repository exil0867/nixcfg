
{ config, pkgs, ... }:

{
  users.mutableUsers = false;
  users.users.exil0359 = {
    uid = 1000;
    initialPassword = "changeme";
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" ];
    openssh.authorizedKeys.keys = [];
  };
}

