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

  it("points the fiery dayside at the star (tidal lock orientation, ci-2sr)", function()
    local loc = prototypes.space_location["cindra"]

    -- The star-map icon bakes the FIRE hemisphere on its left limb and the icy
    -- nightside on the right. The engine's default (unset) aims the icon's TOP
    -- at the sun, leaving that fiery limb ~90deg off sunward. planet.lua rotates
    -- the icon so the fire limb points at the star:
    --   starmap_icon_orientation = (orientation - 0.25) mod 1 = (0.05 - 0.25) = 0.8
    local expected = (0.05 - 0.25) % 1
    assert.is_true(math.abs(loc.starmap_icon_orientation - expected) < 1e-6,
      "tidally-locked fiery dayside must face the star; got " ..
        tostring(loc.starmap_icon_orientation) .. " expected " .. tostring(expected))

    -- Guard the regression: it must NOT be the ~sunward default (top-at-sun,
    -- orientation + 0.5 = 0.55), which is the ~90deg-off orientation this fixes.
    assert.is_true(math.abs(loc.starmap_icon_orientation - ((0.05 + 0.5) % 1)) > 1e-6,
      "orientation must be corrected away from the default top-at-sun (fiery limb was ~90deg off)")
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
