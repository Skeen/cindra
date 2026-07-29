-- Proof: Cindra exists as a real planet, is reachable (gated after Vulcanus),
-- and has its canonical physical parameters. §15 item 1.

local H = require("tests.helpers")

describe("cindra planet", function()
  it("registers a planet prototype named cindra", function()
    assert.is_not_nil(game.planets["cindra"], "cindra planet must exist")
    assert.are.equal("cindra", game.planets["cindra"].name)
  end)

  it("is reachable from Vulcanus (gated after Vulcanus, §6)", function()
    local conn = prototypes.space_connection["vulcanus-cindra"]
    assert.is_not_nil(conn, "the vulcanus -> cindra space connection must exist")
    local names = { [conn.from.name] = true, [conn.to.name] = true }
    assert.is_true(names["vulcanus"], "connection must touch vulcanus")
    assert.is_true(names["cindra"], "connection must touch cindra")
  end)

  it("has a discovery technology (gated behind Vulcanus) that unlocks travel", function()
    local tech = prototypes.technology["planet-discovery-cindra"]
    assert.is_not_nil(tech, "planet-discovery-cindra technology must exist")

    local unlocks_cindra = false
    for _, effect in pairs(tech.effects) do
      if effect.type == "unlock-space-location" then unlocks_cindra = true end
    end
    assert.is_true(unlocks_cindra, "the discovery tech must unlock the cindra space location")

    -- Under any-planet-start (Cindra start), APS hides planet-discovery-cindra
    -- and STRIPS its prerequisites (remove_tech sets technology.prerequisites =
    -- nil): the tech becomes a root, because you already start on Cindra so
    -- there is nothing to gate it behind. The canonical base 4-mod run keeps the
    -- Vulcanus gate (§6). Guard so both configs stay green (matches the
    -- config-aware guard test_mass_driver uses for the same trap).
    --
    -- Gate on `any-planet-start`, NOT `cindra-start`: APS is now an OPTIONAL
    -- dependency, so cindra-start can be active without it. The prereq-stripping
    -- is APS's data-final-fixes, so it only happens when APS itself is present.
    local prereqs = {}
    for _, p in pairs(tech.prerequisites) do prereqs[p.name] = true end
    if script.active_mods["any-planet-start"] then
      assert.is_nil(prereqs["planet-discovery-vulcanus"],
        "under APS the Vulcanus discovery prereq is stripped (tech becomes a root)")
    else
      assert.is_true(prereqs["planet-discovery-vulcanus"],
        "Cindra is gated after Vulcanus (§6): its discovery must require planet-discovery-vulcanus")
    end
  end)

  it("loads with its (v1 vanilla) star-map sprite and icon", function()
    local loc = prototypes.space_location["cindra"]
    assert.is_not_nil(loc, "cindra space location must exist")
    assert.is_true(loc.valid, "cindra space location must load (all referenced sprites present)")

    local tech = prototypes.technology["planet-discovery-cindra"]
    assert.is_true(tech.valid, "discovery tech must load (its icon present)")
  end)

  -- Map-view fixes (ci-2sr): orientation, name, description, no cycle, closer to
  -- the sun, orbit solar, and the shortened reach route.
  describe("map-view presentation (ci-2sr)", function()
    it("points the fiery dayside at the star (tidal lock orientation)", function()
      local loc = prototypes.space_location["cindra"]
      -- The baked star-map icon carries the FIRE hemisphere on its LEFT limb; the
      -- engine's default aims the icon's TOP sunward, leaving fire a quarter-turn
      -- off. planet.lua rotates it: starmap_icon_orientation = (orientation-0.25).
      local expected = (0.05 - 0.25) % 1 -- = 0.8
      assert.is_true(math.abs(loc.starmap_icon_orientation - expected) < 1e-6,
        "fiery dayside must face the star; got " .. tostring(loc.starmap_icon_orientation)
          .. " expected " .. tostring(expected))
      -- Guard the regression: must NOT be the ~90deg-off default (top-at-sun,
      -- orientation + 0.5 = 0.55).
      assert.is_true(math.abs(loc.starmap_icon_orientation - ((0.05 + 0.5) % 1)) > 1e-6,
        "orientation must be corrected away from the default top-at-sun")
    end)

    it("shows just 'Cindra' on the map, no tagline", function()
      local loc = prototypes.space_location["cindra"]
      -- Pinned to the plain space-location-name so the map reads "Cindra";
      -- no tagline anywhere any more (ci-06j, ci-8ua).
      assert.are.equal("space-location-name.cindra", loc.localised_name[1],
        "map name must resolve to the plain 'Cindra' locale key")
    end)

    it("has a real planet description on the map", function()
      local loc = prototypes.space_location["cindra"]
      assert.is_not_nil(loc.localised_description, "planet must carry a map description")
      assert.are.equal("space-location-description.cindra", loc.localised_description[1],
        "description must point at the space-location-description locale key")
    end)

    it("has NO day/night cycle (tidal lock) but keeps a live daylight curve", function()
      local s = H.cindra_surface()
      -- The map view reports the day-night-cycle surface property; an effectively-
      -- infinite value reads as "no cycle" (the old 5-minute value was wrong).
      local cycle = s.get_property("day-night-cycle")
      assert.is_true(cycle > 10000 * 60 * 60,
        "day/night cycle must be effectively infinite (no cycle); got " .. tostring(cycle))
      -- NOT 0 -> not always_day: the flare driver still rides the daylight curve to
      -- swing solar output between events. Freezing that curve would break flares.
      assert.is_false(s.always_day,
        "must not be always_day (0-cycle) -- that flattens the flare's daylight curve")
    end)

    it("orbits clear of the sun but still sunward of Vulcanus (ci-bu4)", function()
      local loc = prototypes.space_location["cindra"]
      local vulc = prototypes.space_location["vulcanus"]
      -- ci-bu4: distance 3 planted Cindra INSIDE the sun disc at the map centre.
      -- Pulled back out to a clear orbit that still reads as the innermost world.
      assert.are.equal(6, loc.distance, "Cindra sits at a clear orbit (distance 6)")
      -- Regression guard: must be pulled well clear of the star, NOT the in-sun
      -- overshoot (distance 3 overlapped the sun disc).
      assert.is_true(loc.distance > 3,
        "orbit must be clear of the sun, not the distance-3 overshoot; got " .. tostring(loc.distance))
      assert.is_true(loc.distance < vulc.distance,
        "Cindra must stay sunward (closer) of Vulcanus: " .. tostring(loc.distance)
          .. " < " .. tostring(vulc.distance))
    end)

    it("bathes orbiting platforms in 1000% solar", function()
      local loc = prototypes.space_location["cindra"]
      assert.are.equal(1000, loc.solar_power_in_space,
        "orbit solar (for space platforms) is 1000% of Nauvis")
    end)

    it("reaches Cindra via a short route (~<=15000), not the old 80000 haul", function()
      local conn = prototypes.space_connection["vulcanus-cindra"]
      assert.is_true(conn.length <= 15000,
        "route must be no longer than the vanilla inter-planet norm; got " .. tostring(conn.length))
      assert.are.equal(12000, conn.length, "the Vulcanus->Cindra hop is short (nearby orbit)")
    end)

    it("carries a Vulcanus/Gleba-tier asteroid field on the approach, not a Nauvis one (ci-bu4)", function()
      -- The route icon composite itself is a data-stage field the runtime API does
      -- not expose (asserted at its source in test_space_appearance.lua). The
      -- ASTEROID field IS exposed, so assert the reported "looks like a Nauvis
      -- path" bug here: the Vulcanus->Cindra approach must carry the same
      -- Vulcanus/Gleba-tier asteroid field vanilla's Vulcanus->Gleba route uses
      -- (built from the identical asteroid definition), never the Nauvis-tier one.
      local function sig(conn_name)
        local conn = prototypes.space_connection[conn_name]
        assert.is_not_nil(conn, "connection must exist: " .. conn_name)
        -- Key each definition by its asteroid name so array order can't matter.
        local by_name = {}
        for _, d in pairs(conn.asteroid_spawn_definitions) do
          by_name[d.asteroid] = d
        end
        return serpent.line(by_name, { sortkeys = true, comment = false })
      end

      assert.are.equal(sig("vulcanus-gleba"), sig("vulcanus-cindra"),
        "the approach must match the Vulcanus/Gleba-tier asteroid field")
      assert.are_not.equal(sig("nauvis-vulcanus"), sig("vulcanus-cindra"),
        "the approach must NOT be the Nauvis-tier field (the 'looks like a Nauvis path' bug)")
    end)
  end)

  it("map gen produces NO vanilla ores, biters, worms, trees or rocks", function()
    local surface = H.cindra_surface()
    surface.request_to_generate_chunks({ 300, 300 }, 3)
    surface.force_generate_chunk_requests()
    local area = { { 260, 260 }, { 340, 340 } }

    for _, ore in pairs({ "iron-ore", "copper-ore", "stone", "coal", "uranium-ore", "crude-oil" }) do
      assert.are.equal(0, surface.count_entities_filtered({ area = area, name = ore }),
        "Cindra must not generate vanilla resource: " .. ore)
    end
    assert.are.equal(0, surface.count_entities_filtered({ area = area, type = "unit-spawner" }),
      "Cindra must not generate biter nests")
    assert.are.equal(0, surface.count_entities_filtered({ area = area, type = "turret" }),
      "Cindra must not generate worm turrets")
    assert.are.equal(0, surface.count_entities_filtered({ area = area, type = "tree" }),
      "Cindra must not generate trees")
    assert.are.equal(0, surface.count_entities_filtered({ area = area, type = "simple-entity" }),
      "Cindra must not generate rocks")
  end)

  it("has the canonical physical parameters (§2, §16)", function()
    local s = H.cindra_surface()
    -- A dense rocky world hugging the star: heavy gravity, thin/no atmosphere,
    -- and the ~10000%-of-Nauvis (100x) surface solar the flare swings across (§15-7).
    assert.are.equal(20, s.get_property("gravity"), "cindra is a heavy rocky world")
    assert.are.equal(500, s.get_property("pressure"), "cindra has a thin atmosphere")
    assert.are.equal(10000, s.get_property("solar-power"),
      "cindra's flare-driving surface solar multiplier (100x Nauvis; §15-7)")
    assert.are.equal(25, s.get_property("magnetic-field"), "cindra magnetic-field")
  end)
end)
