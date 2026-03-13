{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nut.url = "github:Francesco149/nut";
    nut.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { self, nut, ... }@inputs:
    nut.lib.mf {
      inherit self inputs;
      dir = ./.;
      hosts.nixos = [ ];
    };
}
