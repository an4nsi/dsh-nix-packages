# dsh-nix-packages overlay — expose every dsh plugin onto `super` (the nixpkgs set)
# as top-level attributes (self.pi2dsh, self.dsh-better-sidebar, …), so a
# user pulls the whole package set into their config without it.
#
final: prev:
let
  isReserved = n: n == "lib" || n == "overlays" || n == "modules";
  nameValuePair = n: v: { name = n; value = v; };
  attrs = import ./default.nix { pkgs = prev; };
in
builtins.listToAttrs
  (map (n: nameValuePair n attrs.${n})
    (builtins.filter (n: !isReserved n)
      (builtins.attrNames attrs)))