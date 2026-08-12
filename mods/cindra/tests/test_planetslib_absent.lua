-- Proof (ci-dza6, stage 3 of the ci-810e plan): the `"? PlanetsLib"` dependency
-- is genuinely OPTIONAL. Cindra loads and plays with the library NOT installed,
-- and none of PlanetsLib's global mutations reach a player who did not ask for
-- them.
--
-- This is the mirror of tests/test_planetslib_coload.lua and registers only when
-- PlanetsLib is absent (control.lua), the same way test_aps_absent mirrors
-- test_aps_start. The default `cindra-test` run is the absent case, so this is
-- the suite that guards what almost every player actually gets.
--
-- The load-bearing proof is that this suite RUNS AT ALL. Factorio refuses to
-- enable a mod whose non-optional dependency is missing, so demoting the `?`
-- (to a bare name, or to `~`) does not fail one assertion -- it takes the whole
-- mod set down and no Cindra test executes. That distinction is invisible to
-- unit-tests/test_dependencies.lua, which can only read the text of info.json.
--
-- Why it matters, per docs/planetslib-evaluation.md §4.1: PlanetsLib's data
-- stage rewrites the vanilla centrifuge, sets `weight` on ~100 vanilla items,
-- strips hidden-tech prerequisites across the whole technology tree, mirrors lab
-- science onto the Biolab and adds tooltip machinery to every recipe. A hard
-- dependency would conscript every Cindra player into all of it -- Cindra
-- changing Nauvis/Vulcanus, which the AGENTS.md load-bearing invariant forbids.
--
-- Sibling coverage:
--   * tests/test_planetslib_compat.lua -- the preconditions PlanetsLib's
--     data-final-fixes imposes on us, pinned from our own side in EVERY config.
--   * tests/test_planetslib_coload.lua -- both mods loaded, nothing moved.
--   * unit-tests/test_dependencies.lua -- the info.json text itself.

local H = require("tests.helpers")

-- Surface properties PlanetsLib's own data-final-fixes defines and populates.
-- Nothing in Cindra (or vanilla Space Age) can produce them, so their absence is
-- a clean witness that the library never ran.
local PLANETSLIB_PROPERTIES = { "is-freezing" }

-- A startup setting PlanetsLib itself registers (the gas-percentage assert
-- toggle). Same role as test_aps_absent's `aps-planet` probe.
local PLANETSLIB_SETTING = "PlanetsLib-enforce-gas-percentage"

-- Read a surface property that may not be defined in this mod set: get_property
-- errors on an unknown name rather than returning nil.
local function property_exists(surface, name)
  local ok = pcall(function() return surface.get_property(name) end)
  return ok
end

describe("cindra without PlanetsLib", function()
  it("loads with PlanetsLib absent (proves the dependency is optional)", function()
    assert.is_nil(script.active_mods["PlanetsLib"],
      "this suite only applies when PlanetsLib is NOT installed")
    assert.is_not_nil(script.active_mods["cindra"],
      "cindra must be active: a non-optional PlanetsLib dependency would have"
      .. " stopped the whole mod set from loading instead")
  end)

  it("forces none of PlanetsLib's global mutations on the player", function()
    -- The concrete difference between `?` and a hard dependency, stated as world
    -- state: with the library uninstalled the game simply has none of its
    -- additions. If this ever starts failing, Cindra has begun dragging
    -- PlanetsLib into games that never installed it.
    assert.is_nil(settings.startup[PLANETSLIB_SETTING],
      "PlanetsLib's own startup settings must not exist in a game without it")
    local s = H.cindra_surface()
    for _, name in ipairs(PLANETSLIB_PROPERTIES) do
      assert.is_false(property_exists(s, name),
        "surface property '" .. name .. "' is defined by PlanetsLib; it must not"
        .. " exist in a mod set that does not include the library")
    end
  end)

  it("keeps Cindra a complete, reachable planet on its own", function()
    -- Cindra must not have quietly started leaning on the library for anything a
    -- player needs: the planet, the hop that gets them there, and the tech that
    -- unlocks it are all Cindra's own prototypes.
    assert.is_not_nil(game.planets["cindra"], "the cindra planet must exist unaided")
    assert.is_not_nil(prototypes.space_location["cindra"],
      "the cindra space location must exist unaided")
    assert.is_not_nil(prototypes.space_connection["vulcanus-cindra"],
      "the route to Cindra must exist without PlanetsLib")

    local tech = prototypes.technology["planet-discovery-cindra"]
    assert.is_not_nil(tech, "the discovery technology must exist without PlanetsLib")
    local unlocks_cindra = false
    for _, effect in pairs(tech.effects) do
      if effect.type == "unlock-space-location" then unlocks_cindra = true end
    end
    assert.is_true(unlocks_cindra,
      "the discovery tech must still unlock the cindra space location")
  end)

  it("keeps the surface the player lands on fully defined", function()
    -- The co-load suite pins these same numbers against PlanetsLib moving them;
    -- here they pin that Cindra states them itself rather than inheriting any
    -- library default. A planet whose ribbon physics came from PlanetsLib would
    -- read differently the moment the library went missing.
    local s = H.cindra_surface()
    assert.are.equal(20, s.get_property("gravity"))
    assert.are.equal(500, s.get_property("pressure"))
    assert.are.equal(10000, s.get_property("solar-power"),
      "the flare-driving solar multiplier is Cindra's own")
    assert.is_true(s.get_property("day-night-cycle") > 10000 * 60 * 60,
      "the tidal lock must hold with no library installed")
  end)
end)
