-- Proof: the companion mods load CLEAN when any-planet-start is NOT installed.
-- any-planet-start is an OPTIONAL dependency (`? any-planet-start`), so
-- cindra-start (and cindra-dev-default) can be active without it. This suite
-- ONLY registers when cindra-start is active but any-planet-start is not (see
-- control.lua) — the mirror of test_aps_start.
--
-- The wiring under test:
--   * cindra-start/settings.lua      -> guards APS.add_choice on mods["any-planet-start"]
--   * cindra-start/data.lua          -> guards APS.add_planet   on mods["any-planet-start"]
--   * cindra-dev-default/settings.lua-> guards APS.set_default_choice likewise
--
-- Without APS the `APS` global is nil, so an UNGUARDED call would abort the
-- data/settings stage and NO test would run. The mere fact this suite executes
-- proves the guards held and the mod set loaded clean. The assertions below pin
-- the scenario and prove no APS registration leaked in.

local H = require("tests.helpers")

describe("cindra companion mods without any-planet-start", function()
  it("loads the companion mods with APS absent (proves clean headless load)", function()
    assert.is_false(H.aps_loaded(),
      "this suite only applies when any-planet-start is NOT installed")
    assert.is_not_nil(script.active_mods["cindra-start"], "cindra-start must be active")
    -- cindra-dev-default is the one that calls APS.set_default_choice; prove ITS
    -- guard held too (not just cindra-start's), so the whole companion set is clean.
    -- This suite is registered by the DOCUMENTED APS-absent invocation, which loads
    -- both companion mods, so the requirement is the config's, not an accident.
    assert.is_not_nil(script.active_mods["cindra-dev-default"],
      "cindra-dev-default must also be active (its APS-absent skip path is exercised here)")
  end)

  it("registers nothing with APS: the aps-planet setting does not exist", function()
    -- The `aps-planet` startup setting is defined by any-planet-start itself.
    -- Its absence confirms APS is genuinely not loaded, so add_choice /
    -- set_default_choice had nothing to touch (and were correctly skipped).
    assert.is_nil(settings.startup["aps-planet"],
      "with APS absent there is no aps-planet picker setting to register into")
  end)

  it("keeps Cindra a normal, discoverable planet (no APS start rewrite)", function()
    -- Cindra is defined by the cindra mod, independent of APS, so it exists
    -- regardless. But WITHOUT APS its discovery tech keeps the normal Vulcanus
    -- gate (§6): APS's data-final-fixes prereq-stripping never ran. This is the
    -- inverse of test_aps_start's "prerequisites cleared" assertion.
    assert.is_not_nil(prototypes.space_location["cindra"], "cindra space location must exist")
    local tech = prototypes.technology["planet-discovery-cindra"]
    assert.is_not_nil(tech, "the discovery tech prototype must exist")
    local prereqs = {}
    for _, p in pairs(tech.prerequisites) do prereqs[p.name] = true end
    assert.is_true(prereqs["planet-discovery-vulcanus"],
      "without APS the discovery tech keeps its normal Vulcanus prerequisite (no start rewrite)")
  end)
end)
