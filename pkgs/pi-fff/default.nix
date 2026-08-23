# @ff-labs/pi-fff (installed under "pi-fff") — FFF fuzzy-find tools for dsh
# via pi2dsh. @sinclair/typebox is promoted into deps (runtime import of a
# Pi peer); the @earendil-works peers are handled by pi2dsh at runtime.
{
  mkNpmPlugin,
  fetchurl,
}:
mkNpmPlugin {
  name = "@ff-labs/pi-fff";
  version = "0.10.5";
  tarball = fetchurl {
    url = "https://registry.npmjs.org/@ff-labs/pi-fff/-/pi-fff-0.10.5.tgz";
    sha256 = "sha256-vjZt5SCM4shMsn9wu2LxtH5rRx3a2cZMpZsNw770a2k=";
  };
  npmDepsHash = "sha256-MyR6CqXcXLjp3tHr3BO3L174EQvJ9mHNxXoLFgcKoRU=";
  patchDir = ./vendor;
}