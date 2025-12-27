{ pkgs }:

pkgs.stdenv.mkDerivation {
  pname = "gnome-clipboard-history";
  version = "1.4.7";

  src = pkgs.fetchFromGitHub {
    owner = "SUPERCILEX";
    repo = "gnome-clipboard-history";
    rev = "master";
    hash = "sha256-4HYmDxxMH56oPXajCjJbYmDYVqTtK3j1lDRmJnSxu/Y=";
  };

  nativeBuildInputs = [
    pkgs.gnumake
    pkgs.gnome-shell
    pkgs.gettext
    pkgs.glib
  ];

  installPhase = ''
    EXT_DIR=$out/share/gnome-shell/extensions/clipboard-history@alexsaveau.dev
    mkdir -p $EXT_DIR
    cp -r * $EXT_DIR
  '';
}
