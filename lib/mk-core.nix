# lib/mk-core.nix — build the dsh core (@deepseek-ai/dsh) from the npm tarball.
#
# Recipe mirrors numtide/llm-agents.nix packages/dsh, with one Phase-2 change:
# the core's full dependency closure is installed as before EXCEPT
# @deepseek-ai/cosmokit, which is replaced by a symlink to the SHARED single
# cosmokit derivation (passed in as `cosmokit`). This guarantees exactly one
# cosmokit instance at runtime — the DI container is process-wide, so two
# copies would break schemas / service registration across core + plugins.
#
# `core` itself is a normal derivation; the shared cosmokit is spliced into its
# node_modules via an absolute symlink, so the core's own module resolution
# (anchored at its store path) still finds the single shared instance, and the
# profile's symlinkJoin (which joins core's node_modules) lifts that same
# instance to the profile top-level.
{ lib, pkgs }:
{ version, tarballHash, npmDepsHash, lockDir, cosmokit }:
let
  tarball = pkgs.fetchurl {
    url = "https://registry.npmjs.org/@deepseek-ai/dsh/-/dsh-${version}.tgz";
    hash = tarballHash;
  };
  srcWithLock = pkgs.runCommand "dsh-${version}-src" { } ''
    mkdir -p $out
    tar -xzf ${tarball} -C $out --strip-components=1
    cp ${lockDir}/package-lock.json $out/package-lock.json
  '';
  nodejs = pkgs.nodejs;
in
pkgs.buildNpmPackage {
  pname = "dsh";
  inherit version;
  src = srcWithLock;
  npmDepsFetcherVersion = 2;
  inherit npmDepsHash;
  dontNpmBuild = true;
  nativeBuildInputs = [ pkgs.makeWrapper ];
  postInstall = ''
    rm $out/bin/dsh
    # Drop every bundled @deepseek-ai/cosmokit copy, then point at the shared
    # single derivation (first-wins — no duplicate cosmokit instance).
    find "$out/lib/node_modules/@deepseek-ai/dsh/node_modules" \
      -type d -name cosmokit -exec rm -rf {} +
    ln -s ${cosmokit}/lib/node_modules/@deepseek-ai/cosmokit \
          "$out/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/cosmokit"
    makeWrapper ${lib.getExe nodejs} $out/bin/dsh \
      --argv0 dsh \
      --add-flags "--preserve-symlinks" \
      --add-flags "--expose-internals" \
      --add-flags "$out/lib/node_modules/@deepseek-ai/dsh/lib/bin.js"
  '';
  meta.mainProgram = "dsh";
}
