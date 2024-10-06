{ lib, config, pkgs, host, vars, ... }:

{
  home-manager.users.${vars.user} = {
    home = {
      pointerCursor = {
        gtk.enable = false;
        name = "Dracula-cursors";
        package = pkgs.dracula-theme;
        size = if host.hostName == "xps" then 26 else 16;
      };
    };

    # gtk = lib.mkIf (config.gnome.enable == false) {
    #   enable = false;
    #   theme = {
    #     #name = "Dracula";
    #     #name = "Catppuccin-Mocha-Compact-Blue-Dark";
    #     name = "Orchis-Dark-Compact";
    #     #package = pkgs.dracula-theme;
    #     # package = pkgs.catppuccin-gtk.override {
    #     #   accents = ["blue"];
    #     #   size = "compact";
    #     #   variant = "mocha";
    #     # };
    #     package = pkgs.orchis-theme;
    #   };
    #   iconTheme = {
    #     name = "Papirus-Dark";
    #     package = pkgs.papirus-icon-theme;
    #   };
    #   font = {
    #     name = "FiraCode Nerd Font Mono Medium";
    #   };
    # };

    # qt = {
    #   enable = true;
    #   platformTheme.name = "gtk";
    #   style = {
    #     name = "adwaita-dark";
    #     package = pkgs.adwaita-qt;
    #   };
    # };
  };

  # environment.variables = {
  #   QT_QPA_PLATFORMTHEME = "gtk2";
  # };
}
