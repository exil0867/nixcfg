#
#  Apps
#
#  flake.nix
#   ├─ ./hosts
#   │   └─ configuration.nix
#   └─ ./modules
#       └─ ./programs
#           ├─ default.nix *
#           └─ ...
#

[
  ./flatpak.nix
  ./games.nix
  ./kitty.nix
  ./obs.nix
  ./jellyfin.nix
  ./jellyfin-player.nix
]
