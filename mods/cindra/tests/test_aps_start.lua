-- Proof: the companion mods wire Cindra into Any Planet Start end-to-end.
-- This suite ONLY loads when APS is present AND Cindra is the CHOSEN start (see
-- control.lua) — the default `mods/cindra` test run does not enable
-- any-planet-start, so it never runs there. It is exercised by the dedicated APS
-- invocation documented in SETUP.md / README, which loads:
--
--   space-age quality elevated-rails recycler
--   any-planet-start cindra-start cindra-dev-default
--
-- with the planet-picker defaulting to Cindra (cindra-dev-default).
--
-- ci-e9sj: the registration used to key on APS being INSTALLED, which is a
-- different (and perfectly normal) world -- APS installed, Cindra offered, some
-- other planet started. Everything below asserts the CHOSEN-start rewrite, so it
-- belongs here; the offered-but-not-chosen world is tests/test_aps_offered.
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

local H = require("tests.helpers")

describe("cindra APS start chain", function()
  it("loads the companion mod set on a Cindra start (proves clean headless load)", function()
    assert.is_true(H.aps_loaded(), "any-planet-start must be active")
    assert.is_not_nil(script.active_mods["cindra-start"], "cindra-start must be active")
    assert.is_true(H.aps_cindra_start(), "Cindra must be the chosen APS start for this suite")
  end)

  it("registers Cindra as an APS choice (add_choice took effect)", function()
    -- cindra-start's own contribution, and the only one it makes in EVERY
    -- APS install: Cindra appears among the picker's allowed values. Asserted
    -- from the setting PROTOTYPE, so it holds whether or not Cindra is the
    -- value currently selected (tests/test_aps_offered asserts the same thing
    -- in the not-chosen world).
    local picker = prototypes.mod_setting["aps-planet"]
    assert.is_not_nil(picker, "APS's aps-planet picker setting must exist")
    local offered = {}
    for _, v in pairs(picker.allowed_values or {}) do offered[v] = true end
    assert.is_true(offered["cindra"], "cindra-start must add Cindra to the picker's choices")
  end)

  it("defaults the picker to Cindra when the dev default mod is loaded", function()
    -- set_default_choice is cindra-dev-default's doing, NOT cindra-start's --
    -- a plain APS + cindra-start install leaves the picker on APS's built-in
    -- "none" and the player chooses. So only assert the default where the mod
    -- that sets it is actually loaded; otherwise assert the picker still got
    -- to Cindra some other way (the player picked it), which is this suite's
    -- registration precondition.
    if script.active_mods["cindra-dev-default"] then
      -- The setting's DEFAULT, not its current value: the value could be a
      -- leftover in mod-settings.dat, whereas the default is what
      -- set_default_choice actually moved.
      assert.are.equal("cindra", prototypes.mod_setting["aps-planet"].default_value,
        "cindra-dev-default must default the APS planet-picker to cindra")
    else
      assert.is_true(H.aps_cindra_start(),
        "without cindra-dev-default the picker is on Cindra only because it was chosen")
    end
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
