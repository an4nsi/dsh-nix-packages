# dsh-nix-packages

Installable **dsh plugins** distributed as a [NUR](https://github.com/nix-community/NUR)
repository — the plugin packages and the builder library are flake inputs.
NUR registration is planned but not yet submitted; the layout is NUR-compatible and the
`packages` output is what NUR's CI builds and caches once registered.

## Packages

| Package | Version | What it is |
|---|---|---|
| `core` | 0.1.1-rc.2 | `@deepseek-ai/dsh` core, sharing the single cosmokit derivation |
| `pi2dsh` | 0.16.0 | Pi Host ABI bridge — runs Pi extensions as native dsh plugins |
| `dsh-better-sidebar` | 0.15.2 | Improved sidebar for the dsh web UI |
| `dsh-mobile-ui` | 0.1.1 | Mobile UI tuning |
| `pi-fff` | 0.10.5 | FFF fuzzy-find tools (ffgrep/fffind) via pi2dsh |
| `pi-hashline-edit-pro` | 2.6.3 | Hash-anchored file editing via pi2dsh |
| `dsh-web-search-exa` | 0.1.1-rc.2 | Exa search provider (core-aligned; mounted via cordis patch) |
| `cosmokit` / `schemastery` | 1.8.2 / 3.18.1 | Shared single-instance leaves (the DI container + schema lib) |

Each builds onto `out/lib/node_modules/<name>` — exactly the flat entry the
dsh profile node_modules expects.

> The reusable dsh **profile module** + thin **`dsh` wrapper builder** (`mkDsh`)
> live in the sibling repo [`dsh-nix-wrapper`](https://github.com/an4nsi/dsh-nix-wrapper):
> core + plugins come from here, composition comes from there.

## Consume as a flake

```nix
# flake.nix
inputs.dsh-nix-packages.url = "github:an4nsi/dsh-nix-packages";

# 1. as an overlay (exposes pi2dsh, dsh-better-sidebar, … on pkgs)
outputs = { self, nixpkgs, dsh-nix-packages, ... }: let
  system = "x86_64-linux";
  pkgs = import nixpkgs { inherit system; overlays = [ dsh-nix-packages.overlays.default ]; };
in { ... };
```

## Use the builder library (`lib`)

`mkNpmPlugin` turns any npm tarball into a dsh plugin derivation; `mkNpmLeaf`
unpacks a prebuilt shared leaf; `mkCorePackage` builds the core with the
single-cosmokit guarantee.

```nix
dsh-nix-packages.lib.${system}.mkNpmPlugin { name = "pi2dsh"; ... }
```

## Add a plugin

1. `pkgs/<name>/default.nix` — a `callPackage` wiring `{ mkNpmPlugin, fetchurl }`
2. `pkgs/<name>/vendor/` — cleaned package.json + lock
3. one line in `default.nix`

(An automated update flow — version bump + hash resolution + CI — ships in a
later commit.)

## Structure

```
default.nix     NUR entry: lib + overlays + modules + each plugin attr
lib/            builder functions (mkNpmPlugin, mkNpmLeaf, mkCorePackage)
overlay.nix     expose all plugins onto `super`
pkgs/<name>/    one derivation per plugin + its vendor/ metadata
vendor/dsh/     core lock dir (mkCorePackage lockDir)
modules/        NixOS modules (future: dsh systemd module)
```

## Publish to NUR

Follow [NUR: how to add your own repository](https://github.com/nix-community/NUR#how-to-add-your-own-repository)
once the plugin set is stable. The `packages` output is what NUR's CI builds
and caches.
