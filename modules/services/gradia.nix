{
  config,
  pkgs,
  lib,
  ...
}: let
  downloadsDir = "${config.home.homeDirectory}/Downloads";

  gradiaFullCmd = "${pkgs.gradia}/bin/gradia --screenshot=FULL --output-dir ${downloadsDir}";

  gradiaRegionCmd = "${pkgs.gradia}/bin/gradia --screenshot=INTERACTIVE --output-dir ${downloadsDir}";
in {
  home.packages = [
    pkgs.gradia
  ];

  dconf.settings = {
    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/gradia-full/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/gradia-region/"
      ];
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/gradia-full" = {
      name = "Gradia Full Screenshot";
      command = gradiaFullCmd;
      binding = "<Super>c";
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/gradia-region" = {
      name = "Gradia Region Screenshot";
      command = gradiaRegionCmd;
      binding = "<Super>x";
    };
  };
}
