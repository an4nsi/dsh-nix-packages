# lib/mk-leaf.nix — build a SINGLE prebuilt npm package as a flat derivation.
#
#   out/lib/node_modules/<name>
#
# The tarball is fetched and unpacked directly — NO `npm install` — so the
# package's own runtime dependencies are NOT bundled. They must be supplied at
# the profile's top-level node_modules by the other shared leaf derivations
# (cosmokit, @standard-schema/spec, …). This is what lets @deepseek-ai/cosmokit
# be a SINGLE derivation shared by the core + every plugin: the cosmokit DI
# container is process-wide, so two copies would break schemas / service
# registration across the core and its plugins.
#
# Usage (from lib):
#   mkNpmLeaf {
#     name = "@deepseek-ai/cosmokit";   # full npm name (scope kept as a dir)
#     version = "1.8.2";
#     tarballHash = "sha256-…";          # SRI or base16 of the npm tarball
#   }
{ lib, pkgs }:
{ name          # full npm name, e.g. "@deepseek-ai/cosmokit"
, version
, tarballHash   # sha256 (SRI or base16) of the npm tarball
}:
let
  # last path segment → the file name in the registry URL
  base = lib.last (lib.splitString "/" name);
  # keep the @scope as a subdirectory under node_modules
  nmDir = lib.concatStringsSep "/" (lib.splitString "/" name);
  tarball = pkgs.fetchurl {
    url = "https://registry.npmjs.org/${name}/-/${base}-${version}.tgz";
    hash = tarballHash;
  };
in
pkgs.runCommand "dsh-leaf-${base}-${version}" { } ''
  mkdir -p "$out/lib/node_modules/${nmDir}"
  tar -xzf ${tarball} -C "$out/lib/node_modules/${nmDir}" --strip-components=1
''
