# dsh-web-ding — job-completion browser notifications + chime for the dsh web UI.
#
# Pure-client plugin: the host half (lib/index.js) is an empty apply, and the
# browser half (exports["./client"] -> lib/client.js) self-registers under
# window.__ModuleLoader__.load({ id: "dsh-web-ding", ... }). lib/ is COMMITTED
# to the source repo (no build step needed; buildScript omitted).
#
# The client bundle externalizes react / cordis / dsh-client-runtime /
# dsh-client-ui-slots, which resolve at runtime from the core's flat platform
# node_modules, so nothing is installed here (forceEmptyCache, legacy peers
# irrelevant — the vendor package.json declares no deps/peers at all). No
# dsh.bundle → the consuming profile must mount it via cordis.patch.yml.
{
  mkNpmPlugin,
  fetchurl,
}:
mkNpmPlugin {
  name = "dsh-web-ding";
  version = "0.3.0";
  forceEmptyCache = true;
  tarball = fetchurl {
    url = "https://codeload.github.com/an4nsi/dsh-web-ding/tar.gz/6ea077247fff4527c4152e85f5463923a9f820ac";
    sha256 = "sha256-69iyVZWE1N8KWQNfs8kEKFNRBV/z/QWZFCvn8khFiPk=";
  };
  npmDepsHash = "sha256-o1sti5ptPVEKNIA9DFXX6JnlgqAjKkGNRioVe43MTfo=";
  patchDir = ./vendor;
}
