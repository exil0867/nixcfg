{ pkgs, ... }:
{
  imports = [
  ];

  # Allow unfree packages
  nixpkgs.config = {
    allowUnfree = true;
  };

  home.packages = with pkgs; [
    btop
    wget
    unzip
  ];


  home.stateVersion = "22.05";

  programs.gpg.enable = true;
}