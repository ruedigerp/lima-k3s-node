{
  description = "Reproducible NixOS + k3s node for Lima";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixos-lima = {
      url = "github:nixos-lima/nixos-lima/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-lima, ... }:
    let
      mkNode = system: nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          nixos-lima.nixosModules.lima
          ./configuration.nix
        ];
      };
    in {
      nixosConfigurations.k3s-node-aarch64 = mkNode "aarch64-linux";
      nixosConfigurations.k3s-node-x86_64 = mkNode "x86_64-linux";
    };
}
