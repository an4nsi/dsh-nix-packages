# dsh-better-sidebar — improved sidebar for the dsh web UI.
# Peer @deepseek-ai/dsh-* resolve against the profile's flat node_modules.
#
# schemastery is provided by the shared top-level node_modules (the
# `schemastery` bundle, sharing the single cosmokit derivation). The SOURCE
# vendor/package.json declares it as a peer, but the nix-build view (nix/)
# strips it so `npm` does not try to fetch a peer — there is exactly one
# cosmokit instance across the whole profile. The remaining deps
# (@codemirror/*, rxjs, ws, clsx) are not shared across plugins, so they stay
# bundled here.
{ mkNpmPlugin, fetchurl, lib }:
mkNpmPlugin {
  name = "dsh-better-sidebar";
  version = "0.16.1";
  tarball = fetchurl {
    url = "https://registry.npmjs.org/dsh-better-sidebar/-/dsh-better-sidebar-0.16.1.tgz";
    sha256 = "sha256-NQSGxxLhcofDFt22uhW8BXQXlqsPTebFwNqucpkT8rM=";
  };
  patchDir = ./nix;
  # schemastery is a kept peer: declared as a peerDependency but NOT bundled.
  # With legacyPeerDeps (--legacy-peer-deps --omit=peer, applied to the main
  # npm ci too) npm never fetches it; it resolves at runtime from the shared
  # top-level `schemastery` bundle (single cosmokit instance).
  legacyPeerDeps = true;
  npmDepsHash = "sha256-tSEtMHPEHL4MlbZ4jdpFJtYLVneo4wcDQlzvRMfcq8U=";
}
