{
  description = "NixOS configuration and home-manager configurations";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    darwin = {
      url = "github:lnl7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprsome = {
      url = "github:sopa0/hyprsome";
    };
    agenix = {
      url = "github:ryantm/agenix";
    };
  };
  outputs = { home-manager, nixpkgs, darwin, hyprsome, agenix, ...}:
  {
    nixosConfigurations.s3rv3r = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        agenix.nixosModules.default
        ./hosts/s3rv3r/configuration.nix
        home-manager.nixosModules.home-manager {
          home-manager.useUserPackages = true;
          home-manager.users.exil0359 = {
            imports = [
              ./home/default.nix
            ];
          };
        } 
      ];
    };
  };
}