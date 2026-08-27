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
  version = "0.21.0";
  tarball = fetchurl {
    url = "https://registry.npmjs.org/pi2dsh/-/pi2dsh-0.21.0.tgz";
    sha256 = "sha256-YUazC91QRX6yIGtzWArAm7eWBLXrRWs6qAYSkIooVKI=";
  };
  npmDepsHash = "sha256-WUQI5snWpWe8CuONku0i5p4ypU6j+H+t95P/wDI/f1A=";
  patchDir = ./vendor;
}