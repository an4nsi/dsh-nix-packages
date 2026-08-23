# @deepseek-ai/dsh-web-search-exa — Exa search provider for the dsh web UI.
#
# Thin plugin: every peer (@deepseek-ai/dsh-launch-environment, dsh-web,
# dsh-invariants, cordis) AND its only dependency (@deepseek-ai/schemastery)
# resolve from the core's flat platform node_modules, so nothing is installed
# here (forceEmptyCache). No dsh.bundle → the consuming profile must mount it
# via cordis.patch.yml (function plugin injecting into ctx.web).
{
  mkNpmPlugin,
  fetchurl,
}:
mkNpmPlugin {
  name = "@deepseek-ai/dsh-web-search-exa";
  version = "0.1.0-rc.7";
  forceEmptyCache = true;
  tarball = fetchurl {
    url = "https://registry.npmjs.org/@deepseek-ai/dsh-web-search-exa/-/dsh-web-search-exa-0.1.0-rc.7.tgz";
    sha256 = "sha256-Vu50uuowBlAjijkOGZDcG2znmwLVoORTReUgXxbga+k=";
  };
  npmDepsHash = "sha256-KLiBy9FWHkj9KjPKeo4nYyEE7vyO+D+09vqtTltSeFM=";
  patchDir = ./vendor;
}