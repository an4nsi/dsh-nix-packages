# dsh-nix-packages — installable dsh plugins distributed as a flake.
#
#   legacyPackages = the full package+lib set
#   packages       = only the derivations
#   overlays       = nixpkgs overlay exposing plugins as super.<name>
#   lib            = package builders (mkNpmPlugin, mkNpmLeaf, mkCorePackage)
#
# The reusable dsh profile module + thin dsh wrapper builder (mkDsh) live in
# the sibling repo `dsh-nix-wrapper` (github:an4nsi/dsh-nix-wrapper); the two
# flakes are wired as separate inputs by consumers.
#
# Consume from another flake:
#   inputs.dsh-nix-packages.url = "github:an4nsi/dsh-nix-packages";
#   ... pkgs = pkgs // dsh-nix-packages.lib.${pkgs.system}; # builder functions
#   ... or overlays = [ dsh-nix-packages.overlays.${system}.default ]
{
  description = "dsh plugins — flake package set for DeepSeek Harness";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;
    in
    {
      legacyPackages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          dshLib = import ./lib { inherit pkgs; lib = nixpkgs.lib; };
          base = import ./default.nix { pkgs = pkgs; };
          mkCorePackage = import ./lib/mk-core.nix { inherit (nixpkgs) lib; pkgs = pkgs; };
          # core: @deepseek-ai/dsh rc.2, sharing the SINGLE cosmokit derivation
          # (see lib/mk-core.nix). Exposed as packages.<sys>.core.
          core = mkCorePackage {
            version = "0.1.1-rc.2";
            tarballHash = "sha256-R+wF9FraWrh3ea4YqQRWtev/VCHcD/XBeWd9ZeHBYFc=";
            npmDepsHash = "sha256-KqmjvS3vAcvd8Q9yBkG2tuQWfkikqIPWNT13xu9zBJ4=";
            lockDir = ./vendor/dsh;
            cosmokit = base.cosmokit;
          };
        in
        base // { inherit core; });
      packages = forAllSystems (system:
        nixpkgs.lib.filterAttrs (_: v: nixpkgs.lib.isDerivation v) self.legacyPackages.${system});
      overlays = {
        default = import ./overlay.nix;
      };

      lib = forAllSystems (system:
        let
          lib = nixpkgs.lib;
          pkgs = import nixpkgs { inherit system; };
          dshLib = import ./lib { inherit pkgs lib; };
        in
        dshLib // {
          # Package builders (the profile-assembly buildProfile + mkDsh live
          # in dsh-nix-wrapper).
          mkNpmLeaf = import ./lib/mk-leaf.nix { inherit lib pkgs; };
          mkCorePackage = import ./lib/mk-core.nix { inherit lib pkgs; };
        });
    };
}
