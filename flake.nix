{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-parts,
      ...
    }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import ./lib/systems.nix;

      flake.inputs = {
        # re-export dependencies.
        # the calling flake can `.follows` them without re-evaluating
        inherit flake-parts;
      };

      flake.lib = rec {
        mkFlake = import ./lib/mkFlake.nix {
          inherit nixpkgs flake-parts;
          nut = self;
        };
        mkDumbModule = import ./lib/mkDumbModule.nix;
        mkDevShell = import ./lib/mkDevShell.nix;

        # shorthands for my own convenience
        mf = mkFlake;
        dumb = name: attrset: mkDumbModule { inherit name attrset; };
      };

      flake.templates.default = {
        path = ./templates/default;
        description = "minimal nix-utils NixOS config";
      };

      flake.templates.hyprland = {
        path = ./templates/hyprland;
        description = "basic hyprland config";
      };
    };
}
