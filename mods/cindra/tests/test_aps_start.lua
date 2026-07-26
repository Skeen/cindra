-- Proof: the two companion mods wire Cindra into Any Planet Start end-to-end.
-- This suite ONLY loads when the APS chain is present (see control.lua) — the
-- default `mods/cindra` test run does not enable any-planet-start, so it never
-- runs there. It is exercised by the dedicated APS invocation documented in
-- SETUP.md / README, which loads:
--
--   space-age quality elevated-rails recycler
--   any-planet-start cindra-start cindra-dev-default
--
-- with the planet-picker defaulting to Cindra (cindra-dev-default).
--
-- The mere fact this test executes proves the full mod set LOADS CLEAN HEADLESS
-- (a data-stage error would abort before any test runs). The assertions below
-- prove the companion mods did the specific wiring they exist to do:
--
--   * cindra-start/settings.lua   -> APS.add_choice("cindra")   (settings stage)
--   * cindra-dev-default/settings -> APS.set_default_choice(...) (settings stage)
--   * cindra-start/data.lua       -> APS.add_planet{ technology = ... } (data stage)
--
-- In-game start (cargo-pod drop, kit, playable opening) stays a PLAYTEST item.

describe("cindra APS start chain", function()
  it("loads the full companion mod set (proves clean headless load)", function()
    assert.is_not_nil(script.active_mods["any-planet-start"], "any-planet-start must be active")
    assert.is_not_nil(script.active_mods["cindra-start"], "cindra-start must be active")
    assert.is_not_nil(script.active_mods["cindra-dev-default"], "cindra-dev-default must be active")
  end)

  it("registers Cindra as an APS choice AND defaults the picker to it", function()
    -- The picker value resolving to "cindra" is a double proof:
    --   * APS.add_choice("cindra") ran (else "cindra" is not an allowed value
    --     and Factorio would reject it as the default -> load failure), and
    --   * APS.set_default_choice("cindra") ran (cindra-dev-default), else the
    --     picker would still default to APS's built-in "none".
    assert.are.equal("cindra", settings.startup["aps-planet"].value,
      "the APS planet-picker must default to cindra (add_choice + set_default_choice)")
  end)

  it("keeps Cindra as a real start planet (APS.add_planet took effect)", function()
    assert.is_not_nil(game.planets["cindra"], "cindra planet must still exist as the start planet")
    assert.is_not_nil(prototypes.space_location["cindra"], "cindra space location must still exist")
  end)

  it("hands its discovery tech to APS (add_planet{ technology = ... } wired)", function()
    -- Because Cindra is the chosen start, APS's data-final-fixes calls
    -- remove_tech on APS.planets["cindra"].technology: it hides the tech and
    -- clears its prerequisites (you are already on the planet, nothing to
    -- discover). In the plain cindra suite this tech is gated behind
    -- planet-discovery-vulcanus (see test_planet). Its prerequisites being
    -- cleared here proves cindra-start named the right discovery tech.
    local tech = prototypes.technology["planet-discovery-cindra"]
    assert.is_not_nil(tech, "the discovery tech prototype must still exist")
    assert.is_nil(next(tech.prerequisites),
      "APS must have cleared the discovery tech's prerequisites for the Cindra start")
  end)
end)
