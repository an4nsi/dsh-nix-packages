# dsh-mobile-ui — mobile UI tuning for dsh. Zero own dependencies.
{
  mkNpmPlugin,
  fetchurl,
}:
mkNpmPlugin {
  name = "dsh-mobile-ui";
  version = "0.1.1";
  forceEmptyCache = true;
  tarball = fetchurl {
    url = "https://registry.npmjs.org/dsh-mobile-ui/-/dsh-mobile-ui-0.1.1.tgz";
    sha256 = "sha256-jhApwcYS6f+0y7jNCqRn4Ra8pJWe7gL90OKjRcYXZT0=";
  };
  npmDepsHash = "sha256-i/TW0XImpyJ3OyteIGPW30qZYrNa486VFf4J7Dyt/nE=";
  patchDir = ./vendor;
}