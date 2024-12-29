

{ inputs, nixpkgs, nixpkgs-stable, nixpkgs-unstable, nixos-hardware, home-manager, nur, nixvim, plasma-manager, vars, ... }:

let
  system = "x86_64-linux";

  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };

  stable = import nixpkgs-stable {
    inherit system;
    config.allowUnfree = true;
  };

  unstable = import nixpkgs-unstable {
    inherit system;
    config.allowUnfree = true;
  };

  stable-lib = nixpkgs-stable.lib;
  unstable-lib = nixpkgs-unstable.lib;
in
{
  # Desktop Profile
  kairos = unstable-lib.nixosSystem {
    inherit system;
    specialArgs = {
      inherit inputs system stable unstable vars;
      host = {
        hostName = "kairos";
        # mainMonitor = "HDMI-A-2";
        # secondMonitor = "HDMI-A-1";
      };
    };
    modules = [
      nur.modules.nixos.default
      nixvim.nixosModules.nixvim
      ./kairos
      ./configuration.nix

      home-manager.nixosModules.home-manager
      {
        home-manager.backupFileExtension = "backup";
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
      }
    ];
  };

  server = stable-lib.nixosSystem {
    inherit system;
    specialArgs = {
      inherit inputs system stable unstable vars;
      host = {
        hostName = "server";
      };
    };
    modules = [
      nur.modules.nixos.default
      nixvim.nixosModules.nixvim
      ./server
      ./configuration.nix

      home-manager.nixosModules.home-manager
      {
        home-manager.backupFileExtension = "backup";
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
      }
    ];
  };
}
