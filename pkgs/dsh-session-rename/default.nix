# dsh-session-rename — rename_session host tool: finalize the session title
# at wrap-up ([tag] [tag] summary format).
#
# Pure host plugin: all four peers (@deepseek-ai/cordis, @deepseek-ai/dsh-session,
# @deepseek-ai/dsh-session-title, @deepseek-ai/dsh-tools) resolve at runtime from
# the consuming profile's flat node_modules (the dsh core), so nothing is
# installed here (forceEmptyCache; the vendor manifest declares no deps/peers).
# lib/ is COMMITTED to the source repo (no build step needed; buildScript
# omitted). No dsh.bundle → the consuming profile must mount it via
# cordis.patch.yml.
{
  mkNpmPlugin,
  fetchurl,
}:
mkNpmPlugin {
  name = "dsh-session-rename";
  version = "0.1.0";
  forceEmptyCache = true;
  tarball = fetchurl {
    url = "https://codeload.github.com/an4nsi/dsh-session-rename/tar.gz/e3720ea3cfb7b2d505bc495a46a57090eae86e89";
    sha256 = "sha256-M52vXYT5M5xu6U5l0wOswPyKadLrsI5UASOwXlBD1j0=";
  };
  npmDepsHash = "sha256-RZkdn+cmmOVCus3cwxzIqmDdILl5r9T+HDqy6xXSplE=";
  patchDir = ./vendor;
}
