# pi-hashline-edit-pro — hash-anchored file editing for dsh via pi2dsh.
# Ships as a TS source tarball (main: index.ts, no dist); buildNpmPackage
# installs its deps without compiling.
{
  mkNpmPlugin,
  fetchurl,
}:
mkNpmPlugin {
  name = "pi-hashline-edit-pro";
  version = "2.6.3";
  tarball = fetchurl {
    url = "https://registry.npmjs.org/pi-hashline-edit-pro/-/pi-hashline-edit-pro-2.6.3.tgz";
    sha256 = "sha256-Ls6gIL+FJHHUTLdknYHOj+IU1jcPQfUuzOJOaoclMhM=";
  };
  npmDepsHash = "sha256-yIy9lJfcvyv5VJAjgKpJ2UnA+Y04NYyNVqO+5tNeymw=";
  patchDir = ./vendor;
}