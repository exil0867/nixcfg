
{
  description = "Nix, NixOS System Flake Configuration";

  inputs =
    {
      nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable"; # Nix Packages (Default)
      nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable"; # Unstable Nix Packages
      nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11"; # Unstable Nix Packages
      nixos-hardware.url = "github:nixos/nixos-hardware/master"; # Hardware Specific Configurations

      # User Environment Manager
      home-manager-unstable = {
        url = "github:nix-community/home-manager";
        inputs.nixpkgs.follows = "nixpkgs-unstable";
      };

      # Stable User Environment Manager
      home-manager-stable = {
        url = "github:nix-community/home-manager/release-25.11";
        inputs.nixpkgs.follows = "nixpkgs-stable";
      };

      # Agenix
      agenix = {
        url = "github:ryantm/agenix";
      };

      # NUR Community Packages
      nur = {
        url = "github:nix-community/NUR";
        # Requires "nur.nixosModules.nur" to be added to the host modules
      };

      # Fixes OpenGL With Other Distros.
      nixgl-stable = {
        url = "github:guibou/nixGL";
        inputs.nixpkgs.follows = "nixpkgs-stable";
      };

      # Fixes OpenGL With Other Distros.
      nixgl-unstable = {
        url = "github:guibou/nixGL";
        inputs.nixpkgs.follows = "nixpkgs-unstable";
      };


      # Neovim
      nixvim-unstable = {
        url = "github:nix-community/nixvim";
        inputs.nixpkgs.follows = "nixpkgs-unstable";
      };

      # Neovim
      nixvim-stable = {
        url = "github:nix-community/nixvim/nixos-25.11";
        inputs.nixpkgs.follows = "nixpkgs-stable";
      };

      # KDE Plasma User Settings Generator - stable
      plasma-manager-stable = {
        url = "github:pjones/plasma-manager";
        inputs.nixpkgs.follows = "nixpkgs-stable";
        inputs.home-manager.follows = "nixpkgs-stable";
      };
      # KDE Plasma User Settings Generator
      plasma-manager-unstable = {
        url = "github:pjones/plasma-manager";
        inputs.nixpkgs.follows = "nixpkgs-unstable";
        inputs.home-manager.follows = "nixpkgs-unstable";
      };
      
      nix-vscode-extensions = {
        url = "github:nix-community/nix-vscode-extensions";
      };
    };

  outputs = inputs @ { self, nixpkgs-stable, nixpkgs-unstable, nixos-hardware, home-manager-unstable, home-manager-stable, nur, nixgl-stable, nixgl-unstable, nixvim-stable, nixvim-unstable, plasma-manager-stable, plasma-manager-unstable, agenix, nix-vscode-extensions, ... }: # Function telling flake which inputs to use
    let
      # Variables Used In Flake
      vars = {
        user = "exil0681";
        location = "$HOME/.setup";
        terminal = "kitty";
        editor = "nvim";
      };
    in
    {
      nixosConfigurations = (
        import ./hosts {
          inherit (nixpkgs-unstable) lib;
          inherit inputs nixpkgs-stable nixpkgs-unstable nixos-hardware home-manager-unstable home-manager-stable nur nixvim-stable nixvim-unstable plasma-manager-stable plasma-manager-unstable agenix nix-vscode-extensions vars; # Inherit inputs
        }
      );

      homeConfigurations = (
        import ./nix {
          inherit (nixpkgs-unstable) lib;
          inherit inputs nixpkgs-stable nixpkgs-unstable home-manager-stable home-manager-unstable plasma-manager-stable plasma-manager-unstable nixgl-stable nixgl-unstable agenix nix-vscode-extensions vars;
        }
      );
    };
}
