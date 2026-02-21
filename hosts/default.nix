{
  inputs,
  nixpkgs-stable,
  nixpkgs-unstable,
  nixos-hardware,
  home-manager-unstable,
  agenix,
  home-manager-stable,
  nur,
  nixvim-unstable,
  nixvim-stable,
  plasma-manager-unstable,
  plasma-manager-stable,
  vars,
  ...
}: let
  system = "x86_64-linux";

  stable = import nixpkgs-stable {
    inherit system;
    config.allowUnfree = true;
  };

  unstable = import nixpkgs-unstable {
    inherit system;
    config = {
      allowUnfree = true;
      permittedInsecurePackages = [
        "librewolf-bin-unwrapped-147.0.3-2"
        "librewolf-bin-147.0.3-2"
      ];
    };
    overlays = [inputs.nix-vscode-extensions.overlays.default];
  };

  stable-lib = nixpkgs-stable.lib;
  unstable-lib = nixpkgs-unstable.lib;
  overlays = [inputs.nix-vscode-extensions.overlays.default];
in {
  # Desktop Profile
  kairos = unstable-lib.nixosSystem {
    inherit system;
    specialArgs = {
      inherit inputs system stable unstable vars;
      nixpkgs-channel = nixpkgs-unstable;
      system-definition = unstable;
      host = {
        hostName = "kairos";
      };
    };
    modules = [
      nur.modules.nixos.default
      ./kairos
      ./configuration.nix

      {
        nixpkgs.overlays = [
          inputs.nix-vscode-extensions.overlays.default
        ];
      }

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

      {
        nixpkgs.overlays = [
          inputs.nix-vscode-extensions.overlays.default
        ];
      }

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
    modules =
      [
        nur.modules.nixos.default
        ./sky
        ./configuration.nix

        {
          nixpkgs.overlays = [
            inputs.nix-vscode-extensions.overlays.default
          ];
        }
      ]
      ++ stable-lib.optional
      (builtins.pathExists ./sky/private.nix)
      ./sky/private.nix
      ++ [
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
