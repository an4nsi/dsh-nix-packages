# pi2dsh — Pi Host ABI bridge for dsh.
# Built from the npm registry tarball via lib.mkNpmPlugin.
# `typescript` is a peer at runtime (pi2dsh imports it); only its own npm
# deps + typescript-promoted are installed here. The @deepseek-ai/dsh-*
# peers resolve against the profile's flat node_modules (the dsh core).
{
  mkNpmPlugin,
  fetchurl,
}:
mkNpmPlugin {
  name = "pi2dsh";
  version = "0.16.0";
  tarball = fetchurl {
    url = "https://registry.npmjs.org/pi2dsh/-/pi2dsh-0.16.0.tgz";
    sha256 = "sha256-0ygK/uy9iUyumw4ZGn8jzh4HAqlwZkioR+DfUcvbJvA=";
  };
  npmDepsHash = "sha256-/fiuSFHjcElYgadODewYE8cLocGW9UUdfFZNu2zFCV4=";
  patchDir = ./vendor;
}