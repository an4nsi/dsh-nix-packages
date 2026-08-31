# dsh-fork-view — pi-web-style nested fork/subagent process tree in the dsh
# web sidebar. BUNDLE plugin (dsh.bundle.patch → cordis.patch.yml) with a
# client half.
#
# lib/ is a gitignored esbuild artifact, so the codeload tarball has no lib/:
# buildScript re-runs the exact build.mjs invocations against src/ using the
# esbuild CLI provided on PATH by mkNpmPlugin. schemastery is a KEPT peer:
# stripped from the nix-build view (vendor/), so npm never bundles it — it
# resolves at runtime from the profile's shared top-level `schemastery` bundle
# (single cosmokit instance). esbuild devDep is stripped too, so nothing is
# installed here (forceEmptyCache; the vendor manifest declares no deps/peers).
{
  mkNpmPlugin,
  fetchurl,
}:
mkNpmPlugin {
  name = "dsh-fork-view";
  version = "0.1.0";
  forceEmptyCache = true;
  tarball = fetchurl {
    url = "https://codeload.github.com/an4nsi/dsh-fork-view/tar.gz/574ae04487953530ead398ded6de66e4113b4ae8";
    sha256 = "sha256-Dlbt/+27cefcElnFBweihC0ooRDA71II4DF191m6BIE=";
  };
  buildScript = ''
    # mirror of build.mjs: lib/client.js (CJS, react external) + lib/index.js (ESM, schemastery external)
    esbuild src/client/index.jsx --bundle --format=cjs --outfile=lib/client.js --external:react --external:react/jsx-runtime --jsx=transform --jsx-factory=jsx --jsx-fragment=Fragment
    esbuild src/index.js --bundle --format=esm --outfile=lib/index.js --external:schemastery
  '';
  npmDepsHash = "sha256-Iuy6GkYJzswLpVgkkXV9JcMrX+Jevjyyevfv0P4ldp4=";
  patchDir = ./vendor;
}
