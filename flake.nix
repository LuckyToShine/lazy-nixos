{
  description = "NixOS configuration - Optimized for 64GB USB";

  inputs = {
    # Pinned nixpkgs commit
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    inir = {
      url = "github:snowarch/inir";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-matlab = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "gitlab:doronbehar/nix-matlab";
    };
    nix-claude-code = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:ryoppippi/nix-claude-code"; 
    };
  };

  outputs = { self, nixpkgs, home-manager, nix-matlab, nix-claude-code, ... }@inputs: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {
        inherit inputs;
        zen-browser = inputs.zen-browser;
      };
      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.lazy = import ./home.nix;
        }
      ];
    };
  };
}
