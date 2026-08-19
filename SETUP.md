# Setup — what to add manually after cloning

The repo is self-contained for **source and the dev/test toolchain**: a
`flake.nix` provides factorio-test (built from upstream, no longer vendored)
plus node, lua, python+numpy+pillow, imagemagick, blender, patchelf, jq + curl
(for `play.sh`'s mod fetch), and a `cindra-test` runner. Two things are **not** in the flake and must be provided
locally after a fresh clone: the Factorio game binary (licensing) and the node
package for `factorio-test-cli`.

## 0. Enter the dev shell (provides every tool)

```sh
nix develop
```

This builds/pulls factorio-test from its upstream GitHub source and drops you in
a shell with the whole toolchain on PATH. Everything below assumes you are
inside this shell. (Nix must have flakes enabled.)

## 1. Node dependencies (for the test runner CLI)

```sh
npm install
```

Installs `factorio-test-cli` into `node_modules/` (gitignored). One-time per
clone. The factorio-test **mod** itself comes from the flake, not npm.

## 2. Factorio install (required, shared)

The game binary (multi-GB, licensed) cannot be distributed via nix and is
**gitignored**. Provide a **Factorio 2.1.9 Space Age** install once and point
every clone at it — no 4GB copy per worktree:

- `FACTORIO_PATH` — full path to the binary, **or**
- `FACTORIO_DIR` — install root (binary expected at
  `$FACTORIO_DIR/bin/x64/factorio`), **or**
- an in-repo `./factorio` (a real extraction or a symlink to a shared install),
  **or**
- nothing at all: a `factorio-patched/` or `factorio/` install in **any parent
  directory** is found automatically (checked at each level, patched first).

The upward search is what makes a fresh clone or agent worktree work with no
setup: worktrees sit at `<workspace>/hq/<rig>/polecats/<name>/<repo>` while the
shared install sits at `<workspace>/factorio-patched`, so it is found from any
depth. The explicit env vars still win, so an override is always available; a
set-but-broken one is an error rather than a silent fall-through.

`scripts/resolve-factorio.sh` is the single source of truth for this, used by
`play.sh`, the integration runner (`scripts/cindra-test.sh`, which the flake's
`cindra-test` wraps) and the in-engine render harnesses. Run it by hand to see
what a given directory resolves to:

```sh
./scripts/resolve-factorio.sh        # prints the binary path, or explains and exits 1
```

**A missing engine is a hard failure, never a skip.** `cindra-test` exits
non-zero without seeding anything when no binary resolves, so an in-engine run
that never happened can't be mistaken for a clean one. If you can't resolve an
install, escalate or leave the work open — do not report an in-engine result.

**A run that executes zero tests is a hard failure too.** The CLI happily exits 0
reporting `525 skipped, 0 passed` when a filter matches nothing (a renamed
describe block is enough), so `cindra-test` reads the summary back and fails a
run in which nothing passed. Same rule as above: a run that did not happen must
never read as a run that passed.

To create a fresh install:

1. Obtain the Linux Space Age tarball
   (`factorio-space-age_linux_2.1.9.tar.xz`) from your factorio.com account.
2. Extract it (e.g. to a shared location, or `./factorio/`):
   ```sh
   tar -xf factorio-space-age_linux_2.1.9.tar.xz -C .
   ```
3. **On NixOS**, patch the binary so graphics work:
   ```sh
   ./scripts/patchelf-factorio.sh          # patches ./factorio by default
   ./scripts/patchelf-factorio.sh /path/to/other/bin/x64/factorio   # or a specific binary
   ```
   Sets a concrete nix-store glibc ELF interpreter **and** the RUNPATH so SDL can
   find libX11 / libGL at runtime. **Required after every fresh extraction** — a
   stock tarball ships the FHS interpreter, which gives "cannot execute: required
   file not found" on NixOS, and its empty RUNPATH crashes SDL with the misleading
   "No available video device" even on a machine with a display.

   You usually don't need to run this by hand: **`./play.sh` auto-detects an
   unpatched binary** (a missing interpreter, or on NixOS a missing RUNPATH) and
   runs this script on the binary it resolved — including one pointed at via
   `FACTORIO_PATH` / `FACTORIO_DIR` — before launching. Set `PLAY_NO_PATCHELF=1`
   to skip the auto-run and just be told the exact command.

Verify:

```sh
"${FACTORIO_PATH:-./factorio/bin/x64/factorio}" --version   # → Version: 2.1.9
```

## Then — run the tests

The `cindra-test` runner (from the flake) symlinks the flake-built factorio-test
into the data dir and invokes the CLI with the DLC set the suite needs
(`recycler` is a required built-in DLC in 2.1). From inside `nix develop`:

```sh
cindra-test               # full integration suite (default N-S ribbon)
npm run test:unit         # plain-Lua unit tests
npm run test:integration:horizontal   # the E-W ribbon, in its own run
npm test                  # all of it
```

The orientation is a startup setting read at the data stage, so the horizontal
ribbon needs a separate run: `CINDRA_ORIENTATION=horizontal cindra-test` seeds
and enables `mods/cindra-dev-horizontal` (which flips the setting default) and
runs the rotated-world suite. See the README section for what it asserts.

Point it at a shared Factorio without touching the repo:

```sh
FACTORIO_DIR=/path/to/factorio-install cindra-test
```

## Companion mods (Any-Planet-Start chain)

`cindra-test [MOD ...] [-- CLI-ARG ...]` enables the mods you name alongside the
base DLC set (and passes anything after `--` to the CLI verbatim), so the
`cindra-start` / `cindra-dev-default` suites run by seeding those mods into the
data dir and naming them. See the "Companion mods" block in
[`README.md`](README.md#companion-mods-any-planet-start-chain). Any Planet Start
is an optional dependency and is not vendored; the with-APS suite needs a local
checkout (from the mod portal) pointed at by `APS_PATH`, while the without-APS
suite needs no external mod.

### Playtesting the start chain with `./play.sh`

`./play.sh` launches the full playtest set: `cindra` + the APS start chain
(`any-planet-start` + `cindra-start` + `cindra-dev-default`) + `helmod` (recipe
math). APS and Helmod are still un-vendored; play.sh finds each one, in order,
from `$APS_PATH` / `$HELMOD_ZIP`, a local `.play-cache/`, or the Factorio
install's `mods/` folder, and as a last resort **fetches** it from the mod
portal into `.play-cache/` (using the install's `player-data.json` credentials,
so log into factorio.com in-game once). Set `PLAY_NO_FETCH=1` to stay offline —
play.sh then launches with whatever it found and skips any missing mod. A shared
install that already ships `helmod_*.zip` in its `mods/` needs no download.

Run `./play.sh` **from inside `nix develop`**: the fetch fallback needs `jq` and
`curl` (both provided by the dev shell), and on NixOS play.sh auto-runs
`patchelf-factorio.sh` (which needs `patchelf` + `nix`) on an unpatched binary
before launching. Outside the shell, install those tools yourself or the fetch /
auto-patch steps are skipped with a warning.

## Regenerated automatically — do NOT add these manually

- `factorio-test-data-dir/` — created/refreshed by `cindra-test` each run
  (including the `factorio-test_<version>` symlink into the nix store).
- `mods-bundle/` — created by `play.sh` each run.
- `.play-cache/` — mods `play.sh` fetched from the portal (APS / Helmod).
- `node_modules/`, `package-lock.json` — from `npm install`.
- `result` — a `nix build` output symlink (only if you run `nix build`).
