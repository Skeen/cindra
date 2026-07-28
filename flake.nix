{
  description =
    "Cindra mod dev/test shell: factorio-test (unvendored, built from upstream) plus the art + test toolchain";

  # Mirrors the pattern of the parent workspace flake
  # (../../../flake.nix), which builds gt/beads from GitHub inputs. Here the
  # GitHub input is factorio-test: instead of committing vendor/factorio-test,
  # we pull GlassBricks/FactorioTest and compile its TypeScript -> Lua mod in a
  # nix derivation, then hand the built mod to the test harness.
  #
  # The Factorio game binary is deliberately NOT provided here: it cannot be
  # redistributed (licensing) and stays a local, manual install. See SETUP.md.
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # Upstream test framework, sourced (not vendored). submodules=1 pulls the
    # luassert/say git submodules the mod build (build:copy-luassert) needs.
    factorio-test = {
      url = "git+https://github.com/GlassBricks/FactorioTest?submodules=1";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      factorio-test,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };

        # Python with the art-pipeline deps (gen-planet-maps.py,
        # gen-entity-art.py). bake-starmap.py runs inside Blender's own python,
        # so it doesn't rely on this env.
        pythonEnv = pkgs.python3.withPackages (ps: [
          ps.numpy
          ps.pillow
        ]);

        # Compile the factorio-test mod (TypeScript -> Lua via tstl) and lay it
        # out as a ready-to-load Factorio mod directory. Output is byte-identical
        # to the old committed vendor/factorio-test for the core runtime files.
        factorio-test-mod = pkgs.buildNpmPackage {
          pname = "factorio-test-mod";
          version = "3.1.1";
          src = factorio-test;

          # From `nix build` hash-mismatch on the fetchDeps step; bump whenever
          # the factorio-test input (package-lock.json) changes.
          npmDepsHash = "sha256-gpvcneLpSZLvqqIlx0qWZjfg7alL7YJyIdboCoo+fAY=";

          # Root is an npm workspaces monorepo (cli/types/mod); only the mod
          # workspace produces the shippable Factorio mod.
          buildPhase = ''
            runHook preBuild
            npm run build --workspace mod
            runHook postBuild
          '';

          # Package the built mod exactly as the mod portal would: drop the
          # dev-only files listed in mod/info.json's package.ignore, plus the
          # workspace node_modules symlink and now-empty source dirs.
          installPhase = ''
            runHook preInstall
            mkdir -p "$out"
            cp -r mod/. "$out/"
            rm -rf "$out/node_modules"
            find "$out" \( -name 'tsconfig*.json' -o -name 'package*.json' \
              -o -name '*.ts' -o -name '*.xcf' \) -delete
            find "$out" -type d -empty -delete
            runHook postInstall
          '';

          dontFixup = true;

          meta = {
            description = "Factorio Test mod (GlassBricks/FactorioTest), built from source";
            homepage = "https://github.com/GlassBricks/FactorioTest";
            license = pkgs.lib.licenses.mit;
          };
        };

        # `cindra-test` — wire the flake-built factorio-test mod into the runner
        # data dir and invoke factorio-test-cli with the DLC set the suite needs
        # (recycler is a required 2.1 built-in that space-age/quality depend on).
        # The Factorio binary is user-provided (FACTORIO_PATH or ./factorio).
        cindra-test = pkgs.writeShellApplication {
          name = "cindra-test";
          runtimeInputs = [
            pkgs.nodejs
            pkgs.coreutils
            pkgs.gnused
          ];
          text = ''
            repo="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
            ft_mod="${factorio-test-mod}"
            # Factorio binary (gitignored ~4GB install): FACTORIO_PATH (binary)
            # wins, else FACTORIO_DIR (install root), else the in-repo ./factorio.
            # Mirrors play.sh so one shared install serves every clone.
            if [ -n "''${FACTORIO_PATH:-}" ]; then
              factorio_path="$FACTORIO_PATH"
            elif [ -n "''${FACTORIO_DIR:-}" ]; then
              factorio_path="$FACTORIO_DIR/bin/x64/factorio"
            else
              factorio_path="$repo/factorio/bin/x64/factorio"
            fi
            data_dir="''${FACTORIO_TEST_DATA_DIR:-$repo/factorio-test-data-dir}"

            version="$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$ft_mod/info.json" | head -1)"
            mkdir -p "$data_dir/mods"
            ln -sfn "$ft_mod" "$data_dir/mods/factorio-test_$version"

            if [ ! -x "$factorio_path" ]; then
              echo "error: Factorio binary not found at $factorio_path" >&2
              echo "The game is a manual, local install (see SETUP.md); set FACTORIO_PATH to override." >&2
              exit 1
            fi

            cli="$repo/node_modules/.bin/factorio-test"
            if [ ! -x "$cli" ]; then
              echo "error: factorio-test-cli not installed; run 'npm install' first (see SETUP.md)." >&2
              exit 1
            fi

            exec "$cli" run \
              --factorio-path "$factorio_path" \
              --data-directory "$data_dir" \
              --mod-path "$repo/mods/cindra" \
              --mods space-age quality elevated-rails recycler "$@"
          '';
        };

        devTools = [
          pkgs.nodejs # factorio-test-cli (via `npm install`)
          pythonEnv # planet/entity art generators (numpy + pillow)
          pkgs.imagemagick # sprite downscaling / mip strips
          pkgs.blender # bake-starmap.py (Cycles)
          pkgs.lua # plain-Lua unit tests (unit-tests/test_*.lua)
          pkgs.git
          pkgs.patchelf # scripts/patchelf-factorio.sh (NixOS)
          pkgs.jq # play.sh -> scripts/fetch-mod.sh (mod-portal JSON)
          pkgs.curl # play.sh -> scripts/fetch-mod.sh (mod-portal download)
          cindra-test
        ];
      in
      {
        packages = {
          default = factorio-test-mod;
          factorio-test-mod = factorio-test-mod;
        };

        apps.test = {
          type = "app";
          program = "${cindra-test}/bin/cindra-test";
        };

        devShells.default = pkgs.mkShell {
          packages = devTools;

          # Expose the built mod so SETUP.md / CI can symlink it into a data dir
          # without hardcoding a store path.
          FACTORIO_TEST_MOD = factorio-test-mod;

          shellHook = ''
            echo "cindra dev shell — factorio-test built at: $FACTORIO_TEST_MOD"
            echo "  npm install          # one-time: fetch factorio-test-cli"
            echo "  cindra-test          # run the integration suite (needs a local Factorio; see SETUP.md)"
            echo "  npm run test:unit    # plain-Lua unit tests"
          '';
        };
      }
    );
}
