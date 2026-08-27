# pi-hashline-edit-pro — hash-anchored file editing for dsh via pi2dsh.
# Ships as a TS source tarball (main: index.ts, no dist); buildNpmPackage
# installs its deps without compiling.
{
  mkNpmPlugin,
  fetchurl,
}:
mkNpmPlugin {
  name = "pi-hashline-edit-pro";
  version = "2.7.2";
  tarball = fetchurl {
    url = "https://registry.npmjs.org/pi-hashline-edit-pro/-/pi-hashline-edit-pro-2.7.2.tgz";
    sha256 = "sha256-JuP8MKNGoaJxxZzxm3qCQwzcFIuSb2ElBasRgYh7YLQ=";
  };
  npmDepsHash = "sha256-n+BptBo4i3Lc+bEhbZBnAwXeKXis4HomJcnbAseFuDU=";
  patchDir = ./vendor;
}