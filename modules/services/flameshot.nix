{ config, pkgs, lib, ... }:

let
  flameshotWrapped = pkgs.symlinkJoin {
    name = "flameshot-wrapped";
    paths = [ pkgs.flameshot ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/flameshot \
        --set XDG_CURRENT_DESKTOP GNOME \
        --set QT_QPA_PLATFORM wayland
    '';
  };
in
{
  home.packages = [
    flameshotWrapped
    pkgs.grim
    pkgs.wl-clipboard
  ];

  services.flameshot = {
    enable = true;
    package = flameshotWrapped;
    settings = {
      General = {
        useGrimAdapter = true;
        disabledGrimWarning = true;

        savePath = "${config.home.homeDirectory}/Downloads";
        savePathFixed = true;

        saveAsFileExtension = ".png";
        filenamePattern = "%F_%H-%M-%S";
        saveAfterCopy = true;

        showStartupLaunchMessage = false;
        showHelp = false;
        disabledTrayIcon = true;
      };
    };
  };
}
