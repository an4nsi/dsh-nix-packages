#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 nixpkgs#nodejs --command python3
"""update.py — one-shot npm-plugin version bump for repos/dsh-nix-packages.

MIT License
Copyright (c) 2026 anansi & inogai
(ported from dsh-nur/update.py, Copyright (c) 2026 arachnet-agent; MIT.
Concept inspired by numtide/llm-agents.nix scripts/updater.)

Layout differences vs the predecessor (what this port adapts):
  * target file = pkgs/<name>/default.nix — the mkNpmPlugin attrset there
    holds version + tarball URL version + sha256 + npmDepsHash (the old tool
    patched a monolithic flake.nix).
  * per-package patched metadata dir = pkgs/<name>/vendor, EXCEPT
    dsh-better-sidebar whose default.nix uses ./nix (kept-peer schemastery);
    RULES carries the subdir per plugin.
  * pi-hashline-edit-pro ships as an npm tarball now (no longer a srcDir local
    tree), so it is updatable and has a RULES entry.
  * the dsh core and @deepseek-ai/dsh-web-search-exa stay version-pinned:
    core deliberately, exa aligned to core (npm `latest` for exa is
    0.0.1-rc.1 — an OLDER rc; bumping would downgrade). No RULES entry, so
    the tool refuses to touch them.
  * lockfiles are generated with the flake's PINNED nixpkgs nodejs
    (`nix shell --inputs-from <repo> nixpkgs#nodejs`) so the npm writing the
    lock is the same one buildNpmPackage uses in the sandbox (npm 10 vs 11,
    or two 11 minors, write byte-different locks).

What it does for a plugin:
  1. resolve the latest version on the npm registry (or use an explicit one)
  2. download + unpack the tarball, compute its sha256 (SRI)
  3. clean package.json: drop scripts/devDependencies, optionally strip
     peerDependencies, promote chosen peers into dependencies (e.g.
     typescript for pi2dsh, typebox for pi-fff), and/or UN-peer shared
     single-instance leaves so npm never bundles them (schemastery for
     dsh-better-sidebar → kept as a peerDependency)
  4. generate package-lock.json with the SAME npm the nix sandbox uses
     (the pinned nixpkgs#nodejs)
  5. prune @deepseek-ai / @earendil-works residue from the lock
  6. rewrite pkgs/<name>/{vendor,nix}/{package.json,package-lock.json}
  7. patch pkgs/<name>/default.nix (version + tarball sha256 +
     npmDepsHash=fakeHash)
  8. nix build, read the real npmDepsHash from the fixed-output failure,
     patch it in

Usage:  ./update.py <name> [version]      # name = flake plugin name
        ./update.py pi2dsh 0.21.0         # explicit version + hashes
        ./update.py pi-fff                # "already up to date" no-op

(run through `nix shell nixpkgs#python3 nixpkgs#nodejs -c python3 update.py`
if the nix shebang is unavailable — both forms verified working.)
"""

import base64
import hashlib
import os
import json
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request
from urllib.parse import quote
from pathlib import Path

ROOT = Path(__file__).parent
DUMMY = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

# flake plugin name -> (pkg_dir, patch_subdir, strip_peers, promote, keep_peer,
#                       unpeer)
# pkg_dir      = pkgs/<pkg_dir> (nix path literals can't contain @, so the
#                scoped @ff-labs/pi-fff lives under pkgs/pi-fff)
# patch_subdir = subdir holding the patched package.json + lock ("vendor" for
#                every plugin except dsh-better-sidebar which uses "./nix")
# strip_peers  : drop peerDependencies from the cleaned manifest
# promote      : peer names to MOVE into dependencies (bundled here; e.g.
#                typescript for pi2dsh — a runtime import — and
#                @sinclair/typebox for pi-fff)
# keep_peer    : peer names to RETAIN as peerDependencies and NOT bundle —
#                resolved at runtime from the profile's shared top-level
#                node_modules (e.g. schemastery, the single cosmokit instance)
# unpeer       : dependency names to move OUT of dependencies and re-declare as
#                peers (the "keep_peer" twin for manifests that publish the
#                shared leaf as a plain dependency — schemastery in
#                dsh-better-sidebar 0.15.2+ is a published dependency, but the
#                profile invariant demands ONE cosmokit, so it must not be
#                bundled; ./nix declares it as a peer and `legacyPeerDeps`
#                stops npm from fetching it at build time)
RULES = {
    "pi2dsh": ("pi2dsh", "vendor", True, ["typescript"], [], []),
    "dsh-better-sidebar": ("dsh-better-sidebar", "nix", True, [], ["schemastery"], ["schemastery"]),
    "dsh-mobile-ui": ("dsh-mobile-ui", "vendor", False, [], [], []),
    "@ff-labs/pi-fff": ("pi-fff", "vendor", True, ["@sinclair/typebox"], [], []),
    "pi-hashline-edit-pro": ("pi-hashline-edit-pro", "vendor", True, [], [], []),
}


def meta_dir(name: str, subdir: str) -> Path:
    return ROOT / "pkgs" / name / subdir


def registry_url(name: str) -> str:
    return "https://registry.npmjs.org/" + quote(name, safe="")


def latest_version(name: str) -> str:
    with urllib.request.urlopen(registry_url(name) + "/latest") as r:
        return json.load(r)["version"]


def fetch_tarball(name: str, version: str) -> bytes:
    url = f"{registry_url(name)}/-/{name.rpartition('/')[-1]}-{version}.tgz"
    with urllib.request.urlopen(url) as r:
        return r.read()


def sri_sha256(data: bytes) -> str:
    return "sha256-" + base64.b64encode(hashlib.sha256(data).digest()).decode()


def clean_package_json(pkg: dict, strip_peers: bool, promote: list[str],
                       keep_peer: list[str] | None = None,
                       unpeer: list[str] | None = None) -> dict:
    pkg = json.loads(json.dumps(pkg))
    pkg.pop("scripts", None)
    pkg.pop("devDependencies", None)
    peers = pkg.pop("peerDependencies", None) or {}
    deps = pkg.setdefault("dependencies", {})
    # unpeer: pull shared single-instance leaves OUT of dependencies and put
    # them back among the peers so they are never bundled (resolved from the
    # shared top-level node_modules — e.g. schemastery, the one cosmokit
    # instance across the whole profile).
    if unpeer:
        for dep_name in unpeer:
            if dep_name in deps:
                peers[dep_name] = deps.pop(dep_name)
    if promote:
        for dep_name in promote:
            deps[dep_name] = peers.get(dep_name, "*")
    # keep_peer: re-declare the listed peers as peerDependencies so they stay
    # a peer (resolved from the shared top-level node_modules) and are NOT
    # bundled/promoted into dependencies.
    if keep_peer:
        kept = {k: v for k, v in peers.items() if k in keep_peer}
        if kept:
            pkg["peerDependencies"] = kept
    return pkg


def gen_lockfile(pkg_dir: Path) -> None:
    # npm's default ~/.npm cache may hold root-owned files from earlier
    # provisioning runs (EACCES); keep the npm cache under $XDG_CACHE_HOME
    # (same place the nix fetcher cache lives) so lockgen is hermetic.
    cache_base = os.environ.get("XDG_CACHE_HOME") or tempfile.gettempdir()
    npm_cache = str(Path(cache_base) / "npm-cache")
    subprocess.run(
        ["nix", "shell", "--inputs-from", str(ROOT), "nixpkgs#nodejs",
         "--command", "npm", "install", "--cache", npm_cache,
         "--package-lock-only", "--omit=dev", "--legacy-peer-deps",
         "--ignore-scripts", "--no-audit", "--no-fund"],
        cwd=pkg_dir, check=True, capture_output=True,
    )
    lock = json.loads((pkg_dir / "package-lock.json").read_text())
    root = lock["packages"].get("", {})
    root.pop("devDependencies", None)
    root.pop("peerDependenciesMeta", None)
    lock["packages"] = {
        k: v for k, v in lock["packages"].items()
        if not any(x in k for x in ("@deepseek-ai", "@earendil-works"))
    }
    (pkg_dir / "package-lock.json").write_text(json.dumps(lock, indent=2))


def tarball_url(name: str, version: str) -> str:
    base = name.rpartition("/")[-1]
    return f"https://registry.npmjs.org/{quote(name, safe='')}/-/{base}-{version}.tgz"


def patch_pkg(path: Path, name: str, *, version: str | None,
              sha256: str | None, npm_hash: str | None) -> None:
    src = path.read_text()
    start = src.index(f'name = "{name}";')
    # opening brace of the mkNpmPlugin attrset = the last '{' before the name
    # line (the header comments carry no braces)
    open_i = src.rindex("{", 0, start)
    depth = 0
    for i in range(open_i, len(src)):
        if src[i] == "{":
            depth += 1
        elif src[i] == "}":
            depth -= 1
            if depth == 0:
                end = i + 1
                break
    block = src[open_i:end]
    if version:
        block = re.sub(r'version = ".*?";', f'version = "{version}";', block, count=1)
        block = re.sub(r'url = ".*?\.tgz";',
                       f'url = "{tarball_url(name, version)}";', block, count=1)
    if sha256:
        block = re.sub(r'sha256 = ".*?";', f'sha256 = "{sha256}";', block, count=1)
    if npm_hash:
        block = re.sub(r'npmDepsHash = .*?;', f'npmDepsHash = "{npm_hash}";', block, count=1)
    path.write_text(src[:open_i] + block + src[end:])
    print(f"  {path.relative_to(ROOT)}: {name} updated")


def real_npm_hash(attr: str) -> str:
    r = subprocess.run(["nix", "build", f".#packages.x86_64-linux.{attr}", "--no-link"],
                       capture_output=True, text=True)
    m = re.search(r"got:\s*(sha256-[A-Za-z0-9+/=]+)", r.stdout + r.stderr)
    if not m:
        print("!! nix build did not report a hash mismatch", file=sys.stderr)
        sys.exit(1)
    return m.group(1)


def main() -> None:
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help"):
        print(__doc__)
        sys.exit(0)
    name = sys.argv[1]
    if name not in RULES:
        sys.exit(f"no rule for {name}; rules: {', '.join(RULES)}")
    pkg_name, subdir, strip_peers, promote, keep_peer, unpeer = RULES[name]

    vdir = meta_dir(pkg_name, subdir)
    current = json.loads((vdir / "package.json").read_text())["version"]
    new = sys.argv[2] if len(sys.argv) > 2 else latest_version(name)
    print(f"{name}: {current} -> {new}")
    if new == current:
        print("already up to date")
        return

    data = fetch_tarball(name, new)
    sha = sri_sha256(data)

    with tempfile.TemporaryDirectory() as tmp:
        pkg_dir = Path(tmp) / "pkg"
        pkg_dir.mkdir()
        shutil.unpack_archive(io_bytes(data), pkg_dir)
        # npm tarballs unpack to package/ (or the package name for scoped)
        inner = pkg_dir / "package"
        if not inner.exists():
            inner = pkg_dir
        pkg = json.loads((inner / "package.json").read_text())
        clean = clean_package_json(pkg, strip_peers, promote, keep_peer, unpeer)
        (inner / "package.json").write_text(json.dumps(clean, indent=2))
        gen_lockfile(inner)
        vdir.mkdir(parents=True, exist_ok=True)
        shutil.copy(inner / "package.json", vdir / "package.json")
        shutil.copy(inner / "package-lock.json", vdir / "package-lock.json")

    pkg_nix = ROOT / "pkgs" / pkg_name / "default.nix"
    patch_pkg(pkg_nix, name, version=new, sha256=sha, npm_hash=None)
    print("dummy npmDepsHash set; building to resolve real hash...")
    patch_pkg(pkg_nix, name, version=None, sha256=None, npm_hash=DUMMY)
    # build attr = the flake attr (pkg_dir), e.g. pi-fff, not the scoped name
    real = real_npm_hash(pkg_name)
    patch_pkg(pkg_nix, name, version=None, sha256=None, npm_hash=real)
    print(f"done: {name} {new} (tarball {sha[:24]}…, deps {real[:24]}…)")


def io_bytes(data: bytes):  # shutil.unpack_archive wants a path-like
    f = tempfile.NamedTemporaryFile(suffix=".tgz", delete=False)
    f.write(data); f.close()
    return f.name


if __name__ == "__main__":
    main()
