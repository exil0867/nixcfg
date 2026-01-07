

{ inputs, nixpkgs-stable, nixpkgs-unstable, nixos-hardware, home-manager-unstable, agenix, home-manager-stable, nur, nixvim-unstable, nixvim-stable, plasma-manager-unstable, plasma-manager-stable, vars, ... }:

let
  system = "x86_64-linux";


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
      nixpkgs-channel = nixpkgs-unstable;
      system-definition = unstable;
      host = {
        hostName = "kairos";
        # mainMonitor = "HDMI-A-2";
        # secondMonitor = "HDMI-A-1";
      };
    };
    modules = [
      nur.modules.nixos.default
      ./kairos
      ./configuration.nix

      home-manager-unstable.nixosModules.home-manager
      {
        home-manager.backupFileExtension = "backup";
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.extraSpecialArgs = {
          inherit inputs;
        };
      }
    ];
  };

  echo = stable-lib.nixosSystem {
    inherit system;
    specialArgs = {
      inherit inputs system stable unstable vars;
      nixpkgs-channel = nixpkgs-stable;
      system-definition = stable;
      host = {
        hostName = "echo";
      };
    };
    modules = [
      nur.modules.nixos.default
      # nixvim-unstable.nixosModules.nixvim
      ./echo
      ./configuration.nix

      home-manager-stable.nixosModules.home-manager
      {
        home-manager.backupFileExtension = "backup";
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.extraSpecialArgs = {
          inherit inputs;
        };
      }
    ];
  };

  sky = stable-lib.nixosSystem {
    inherit system;
    specialArgs = {
      inherit inputs system stable unstable vars;
      nixpkgs-channel = nixpkgs-stable;
      system-definition = stable;
      host = {
        hostName = "sky";
      };
    };
    modules = [
      nur.modules.nixos.default
      # nixvim-unstable.nixosModules.nixvim
      ./sky
      ./configuration.nix

      home-manager-stable.nixosModules.home-manager
      {
        home-manager.backupFileExtension = "backup";
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.extraSpecialArgs = {
          inherit inputs;
        };
      }
    ];
  };
}
