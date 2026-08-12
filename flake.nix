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

        # `cindra-test` — a thin wrapper around scripts/cindra-test.sh: hand it
        # the flake-built factorio-test mod, let the repo script do the rest
        # (seed the data dir, resolve the engine, invoke factorio-test-cli).
        #
        # The runner logic deliberately lives in the repo, not in this nix
        # string: it is then readable, diffable and TESTABLE by
        # tests/factorio-resolve.test.sh, which asserts the hard gate on a
        # missing engine. Install discovery is shared with play.sh via
        # scripts/resolve-factorio.sh, so the dev shell and a plain ./play.sh can
        # never disagree about where the binary is (divergence between two copies
        # of that logic is how ci-j340 stayed broken).
        cindra-test = pkgs.writeShellApplication {
          name = "cindra-test";
          runtimeInputs = [
            pkgs.nodejs
            pkgs.coreutils
            pkgs.gnused
            pkgs.bash
            pkgs.git
          ];
          text = ''
            repo="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
            runner="$repo/scripts/cindra-test.sh"
            if [ ! -x "$runner" ]; then
              echo "error: $runner not found; run cindra-test from inside the cindra repo." >&2
              exit 1
            fi
            export FACTORIO_TEST_MOD="${factorio-test-mod}"
            exec "$runner" "$@"
          '';
        };

        devTools = [
          pkgs.nodejs # factorio-test-cli (via `npm install`)
          pythonEnv # planet/entity art generators (numpy + pillow)
          pkgs.imagemagick # sprite downscaling / mip strips
          pkgs.blender # bake-starmap.py (Cycles)
          pkgs.mesa # lavapipe: the software Vulkan the headless bake needs
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

          # Blender 5.x drives its scene compositor (the star-map bake's Glare
          # bloom) on the GPU even in background mode, and SEGFAULTS on a headless
          # box with no usable GL/Vulkan -- which is every CI machine and every
          # agent sandbox. Point it at Mesa's LAVAPIPE software Vulkan instead:
          # the bake then runs anywhere, and because it is the same software
          # rasteriser on every machine the bloom is reproducible rather than
          # dependent on whatever GPU happens to be present.
          # scripts/render-planet.sh picks the ICD up from here.
          MESA_ICD_DIR = "${pkgs.mesa}/share/vulkan/icd.d";

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
