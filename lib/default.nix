# lib/default.nix — the builder functions for dsh plugins.
#
# A NUR `lib` is a set of FUNCTIONS (not derivations). Two builders are
# exposed here; together they turn npm packages into the flat node_modules
# layout the dsh profile peers expect.
#
# All pure functions of { lib, pkgs }: no reference to core/profile/home, so
# they are reusable by any flake/overlay that wants to install a dsh plugin.
# (The profile assembler `buildProfile` used to live here as well — it moved
# to the sibling repo dsh-nix-wrapper with the reusable dsh profile module.)
{ lib, pkgs }:
let
  # --- single prebuilt npm package as a flat derivation (no npm install):
  # used for the shared leaf packages (cosmokit, @standard-schema/spec,
  # schemastery) so the profile top-level owns their dependency resolution.
  mkNpmLeaf = import ./mk-leaf.nix { inherit lib pkgs; };

  # --- npm-registry plugin: buildNpmPackage installs its own deps.
  # patchDir carries a cleaned package.json + a lock generated with the same
  # npm the sandbox uses (npm 10 vs 11 write byte-different locks). srcDir is
  # the deprecated local-source variant (hashline now ships as a tarball).
  mkNpmPlugin =
    {
      name,
      version,
      tarball ? null,
      npmDepsHash,
      # dir with patched package.json (+ package-lock.json) overriding the
      # published one: scripts/devDeps stripped, chosen peers promoted to deps
      patchDir ? null,
      srcDir ? null,
      # dep-less plugins make the npm-deps cache empty; npmConfigHook then
      # refuses unless forceEmptyCache is set.
      forceEmptyCache ? false,
      # when a plugin lists a dep as a peerDependency that must NOT be bundled
      # (e.g. schemastery, resolved from the shared top-level node_modules),
      # pass legacyPeerDeps = true so npm does not auto-install the peer.
      legacyPeerDeps ? false,
      # Optional build step run on the SOURCE tree (before npm install /
      # packaging). Use for local-source plugins whose runtime files (e.g.
      # lib/) are a gitignored esbuild artifact not present in srcDir. esbuild
      # is provided on PATH.
      buildScript ? null,
    }:
    let
      npmFlags' = [ "--ignore-scripts" ]
        ++ lib.optional legacyPeerDeps "--legacy-peer-deps"
        ++ lib.optional legacyPeerDeps "--omit=peer";
      src' = pkgs.runCommand "${name}-${version}-src" {
        nativeBuildInputs = lib.optional (buildScript != null) pkgs.esbuild;
      } ''
        mkdir -p $out
        ${if srcDir != null then "cp -r ${srcDir}/. $out/" else "tar -xzf ${tarball} -C $out --strip-components=1"}
        chmod -R u+w $out
        ${if patchDir != null then "cp ${patchDir}/package.json $out/package.json\ncp ${patchDir}/package-lock.json $out/package-lock.json" else ""}
        ${lib.optionalString (buildScript != null) ''
          cd $out
          ${buildScript}
        ''}
      '';
      built = pkgs.buildNpmPackage {
        pname = name;
        inherit version;
        src = src';
        inherit npmDepsHash;
        dontNpmBuild = true;
        inherit npmFlags';
        npmInstallFlags = [ "--omit=dev" ]
        ++ lib.optionals legacyPeerDeps [ "--legacy-peer-deps" "--omit=peer" ];
        # npm prune re-resolves the lock WITHOUT the peer flags (would try to
        # fetch peer tarballs offline); install already ran --omit=dev, so
        # prune has nothing to remove.
        dontNpmPrune = legacyPeerDeps;
        inherit forceEmptyCache;
        # dep-less plugins: npm install creates no node_modules and the
        # shebang-patch hook's `find node_modules` then fails; create it early
        preConfigure = "mkdir -p node_modules";
      };
    in
    pkgs.runCommand "dsh-plugin-${name}" { } ''
      mkdir -p "$out/lib/node_modules/$(dirname ${name})"
      # point at the INNER package dir so its own node_modules (deps)
      # sits at node_modules/<name>/node_modules for Node resolution
      ln -s ${built}/lib/node_modules/${name} $out/lib/node_modules/${name}
    '';
in
{
  inherit mkNpmPlugin mkNpmLeaf;
}
