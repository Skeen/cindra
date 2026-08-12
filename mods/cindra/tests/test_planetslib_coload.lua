-- Proof (ci-gg3x, stage 1 of the ci-810e plan): with PlanetsLib ACTUALLY
-- INSTALLED, Cindra still sits exactly where the player left it on the star map.
--
-- The ci-810e spike concluded from PlanetsLib's SOURCE that Cindra is already a
-- clean co-installed sibling, but no Factorio install was reachable from that
-- worktree, so nothing was ever confirmed in-engine. This suite is that
-- confirmation, turned into a repeatable test instead of a one-off log read.
--
-- Sibling coverage:
--   * tests/test_planet.lua           -- the tuned star-map position itself, in the
--                                        canonical run (no PlanetsLib).
--   * tests/test_planetslib_compat.lua -- the preconditions PlanetsLib's
--                                        data-final-fixes imposes on us, asserted
--                                        from OUR side with PlanetsLib ABSENT.
--   * this file                        -- the co-load itself: both mods loaded,
--                                        nothing moved.
--
-- Runs ONLY when PlanetsLib is loaded (control.lua registers it conditionally,
-- the same way the APS suites are registered). Cindra takes NO dependency on
-- PlanetsLib and the library is not vendored, so the default `cindra-test` run
-- never executes this. See README ("PlanetsLib co-load") for the invocation.
--
-- Everything here is player-observable: where the planet is drawn in the star
-- map, which way its baked globe faces, and whether the route to it still exists.

local H = require("tests.helpers")

-- The canonical Cindra star-map position (ci-zyc7 / ci-2sr), duplicated here on
-- purpose: the claim under test is "installing a third-party library does not
-- change these numbers", so the expected values must be stated independently of
-- whatever the prototype happens to say.
local CINDRA_DISTANCE = 5
local CINDRA_ORIENTATION = 0.05
local CINDRA_ICON_ORIENTATION = (CINDRA_ORIENTATION - 0.25) % 1 -- 0.8, fire limb sunward

-- Vanilla neighbours, so a system-wide reshuffle cannot hide behind Cindra alone.
local VANILLA_POSITIONS = {
  vulcanus = { distance = 10, orientation = 0.1 },
  nauvis = { distance = 15, orientation = 0.275 },
}

-- lib/orbits.lua :: SPECIAL_PLACEHOLDERS_FOR_MISSING_PARENT -- where PlanetsLib
-- silently parks a body whose orbit parent did not resolve.
local MISSING_PARENT_DISTANCE = 43168

local function about(actual, expected)
  return math.abs(actual - expected) < 1e-6
end

describe("cindra + PlanetsLib co-load", function()
  it("actually has PlanetsLib loaded, and PlanetsLib actually processed Cindra", function()
    -- Non-vacuity guard. Every other assertion in this file would also pass with
    -- PlanetsLib silently disabled (they are all "nothing changed" claims), so
    -- pin that the library is present AND that it reached Cindra: `is-freezing`
    -- is a surface property PlanetsLib itself defines and sets from our
    -- `entities_require_heating = true`. Nothing in Cindra can produce it.
    assert.is_not_nil(script.active_mods["PlanetsLib"], "PlanetsLib must be active for this suite")
    local s = H.cindra_surface()
    assert.are.equal(1, s.get_property("is-freezing"),
      "PlanetsLib must have derived is-freezing=1 from entities_require_heating;"
      .. " without it this suite proves nothing")
  end)

  it("does not move Cindra on the star map", function()
    -- The headline claim of stage 1. `ensure_all_locations_have_orbits` retro-fits
    -- an orbit onto every location that lacks one, and is meant to be
    -- position-preserving; a star-parented body's absolute position is the
    -- identity of its orbit. If that ever regresses, the player sees Cindra jump
    -- to a different spot in the star map the moment they install PlanetsLib.
    local loc = prototypes.space_location["cindra"]
    assert.is_not_nil(loc, "cindra space location must exist")
    assert.are.equal(CINDRA_DISTANCE, loc.distance,
      "PlanetsLib moved Cindra's orbital distance")
    assert.is_true(about(loc.orientation, CINDRA_ORIENTATION),
      "PlanetsLib moved Cindra around its orbit; got " .. tostring(loc.orientation))
    assert.is_true(math.abs(loc.distance - MISSING_PARENT_DISTANCE) > 1e-6,
      "Cindra was flung to PlanetsLib's missing-parent placeholder: its orbit parent did not resolve")
  end)

  it("does not reshuffle the rest of the solar system either", function()
    -- Cindra staying put while Vulcanus slides would still ruin the star map (and
    -- would mean the retrofit is not position-preserving after all).
    for name, want in pairs(VANILLA_POSITIONS) do
      local loc = prototypes.space_location[name]
      assert.is_not_nil(loc, name .. " must exist")
      assert.are.equal(want.distance, loc.distance, "PlanetsLib moved " .. name)
      assert.is_true(about(loc.orientation, want.orientation),
        "PlanetsLib rotated " .. name .. "; got " .. tostring(loc.orientation))
    end
    assert.is_true(prototypes.space_location["cindra"].distance < prototypes.space_location["vulcanus"].distance,
      "Cindra must stay sunward of Vulcanus (§6 ordering)")
  end)

  it("keeps the tidal-lock quarter turn on the baked globe", function()
    -- PlanetsLib never writes starmap_icon_orientation (its starmap.lua only
    -- reads that layer), so the fire limb must still point at the star.
    local loc = prototypes.space_location["cindra"]
    assert.is_true(about(loc.starmap_icon_orientation, CINDRA_ICON_ORIENTATION),
      "fiery dayside must still face the star; got " .. tostring(loc.starmap_icon_orientation))
  end)

  it("keeps the route to Cindra and the gate in front of it", function()
    -- PlanetsLib's update-connections override is commented out upstream and its
    -- science pass rewrites technology prerequisites mod-wide, so pin the two
    -- things a player needs to actually get here: the hop and its unlock.
    local conn = prototypes.space_connection["vulcanus-cindra"]
    assert.is_not_nil(conn, "the vulcanus -> cindra space connection must survive the co-load")
    assert.are.equal(12000, conn.length, "PlanetsLib changed the length of the approach")

    local tech = prototypes.technology["planet-discovery-cindra"]
    assert.is_not_nil(tech, "the discovery technology must survive the co-load")
    local unlocks_cindra = false
    for _, effect in pairs(tech.effects) do
      if effect.type == "unlock-space-location" then unlocks_cindra = true end
    end
    assert.is_true(unlocks_cindra, "the discovery tech must still unlock the cindra space location")
    local prereqs = {}
    for _, p in pairs(tech.prerequisites) do prereqs[p.name] = true end
    assert.is_true(prereqs["planet-discovery-vulcanus"],
      "PlanetsLib's prerequisite pass must not strip the Vulcanus gate (§6)")
  end)

  it("leaves Cindra's own declared surface properties alone", function()
    -- PlanetsLib is additive here (it adds is-freezing / planet-str); what it must
    -- never do is retune the world the player lands on.
    local s = H.cindra_surface()
    assert.are.equal(20, s.get_property("gravity"), "PlanetsLib changed Cindra's gravity")
    assert.are.equal(500, s.get_property("pressure"), "PlanetsLib changed Cindra's pressure")
    assert.are.equal(10000, s.get_property("solar-power"),
      "PlanetsLib changed the flare-driving solar multiplier")
    assert.are.equal(25, s.get_property("magnetic-field"), "PlanetsLib changed Cindra's magnetic field")
    assert.is_true(s.get_property("day-night-cycle") > 10000 * 60 * 60,
      "PlanetsLib broke the tidal lock (day/night cycle must stay effectively infinite)")
  end)
end)
