-- Cryo-quench PoC control-stage entry point.
--
-- The PoC has no runtime gameplay handlers — the whole proof lives in the
-- prototypes (the recipe) and is exercised by the factorio-test suite below.
-- The bootstrap only runs when the factorio-test mod is present, so the mod is
-- an inert prototype-only add-on in a normal game.
if script.active_mods["factorio-test"] then
  require("__factorio-test__/init")({
    "tests/test_quench",
  }, {
    load_luassert = true,
  })
end
