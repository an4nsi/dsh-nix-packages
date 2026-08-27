# dsh-nix-packages repository — installable dsh plugins as a flake package set.
#
# Convention:
#   * `lib`      — builder FUNCTIONS (mkNpmPlugin) callable by other packages
#   * `overlays` — make the package set usable as a nixpkgs overlay
#   * `modules`  — NixOS modules (future: systemd module for dsh)
#   * everything else is a derivation the CI tooling builds & caches
#
# `pkgs` must be taken as an argument (never <nixpkgs>); callPackage wires
# each package's { mkNpmPlugin, fetchurl, ... } from (pkgs // { lib }).
{pkgs ? import <nixpkgs> {}}:
let
  customLib = import ./lib { inherit pkgs; lib = pkgs.lib; };
  lib = pkgs.lib // customLib;
  # mkNpmPlugin etc. are exposed at top level so per-package functions can
  # take { mkNpmPlugin, fetchurl } directly (callPackage idiom)
  callPackage = lib.callPackageWith (pkgs // { inherit lib; } // customLib);
  mkNpmLeaf = customLib.mkNpmLeaf;

  # Shared single-instance leaf packages (per-package derivations). They ship
  # prebuilt JS and are unpacked directly (no npm install), so the profile
  # top-level owns their runtime dependency resolution. cosmokit in particular
  # is a process-wide DI container, so it MUST be ONE derivation shared by the
  # core + every plugin (see lib/mk-core.nix).
  sharedCosmokit = mkNpmLeaf {
    name = "@deepseek-ai/cosmokit";
    version = "1.8.2";
    tarballHash = "sha256-dJhuCl0reYRgfVkTl0sIPTDv4xrFwlqLHvyQsG+k7JA=";
  };
  sharedSpec = mkNpmLeaf {
    name = "@standard-schema/spec";
    version = "1.1.0";
    tarballHash = "sha256-p8tyaL4oCrUY1FD4w7B8hvI0FyJcCrU2ke1ZswZ8zq8=";
  };
  sharedSchemastery = mkNpmLeaf {
    name = "@deepseek-ai/schemastery";
    version = "3.18.1";
    tarballHash = "sha256-pktb7WYfMDyyekS8OUIULalTRgzKRFcfidlg81p0toI=";
  };
  # bare `schemastery` alias (the dsh convention: sibling plugins `import "schemastery"`)
  schemasteryAlias = pkgs.runCommand "dsh-schemastery-alias" { } ''
    mkdir -p $out/lib/node_modules
    ln -s ${sharedSchemastery}/lib/node_modules/@deepseek-ai/schemastery $out/lib/node_modules/schemastery
  '';
in {
  # special attributes
  lib = customLib;               # builder functions
  overlays = import ./overlays;  # nixpkgs overlays
  modules = import ./modules;    # NixOS modules

  # Public: the shared cosmokit derivation + the flat, shared schemastery bundle
  # (spec + cosmokit + schemastery + alias symlinked into one node_modules).
  # Every plugin that peers `schemastery` resolves this single tree, so there is
  # exactly one cosmokit instance across the whole profile.
  cosmokit = sharedCosmokit;
  schemastery = pkgs.symlinkJoin {
    name = "dsh-schemastery-bundle";
    paths = [ sharedSpec sharedCosmokit sharedSchemastery schemasteryAlias ];
  };

  # --- dsh plugins (each output = out/lib/node_modules/<name>, the flat
  # node_modules entry the dsh profile peers expect) ---
  pi2dsh = callPackage ./pkgs/pi2dsh {};
  dsh-better-sidebar = callPackage ./pkgs/dsh-better-sidebar {};
  dsh-web-search-exa = callPackage ./pkgs/dsh-web-search-exa {};
  dsh-mobile-ui = callPackage ./pkgs/dsh-mobile-ui {};
  pi-fff = callPackage ./pkgs/pi-fff {};
  pi-hashline-edit-pro = callPackage ./pkgs/pi-hashline-edit-pro {};
}
