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

    local prereqs = {}
    for _, p in pairs(tech.prerequisites) do prereqs[p.name] = true end
    assert.is_true(prereqs["planet-discovery-vulcanus"],
      "Cindra is gated after Vulcanus (§6): its discovery must require planet-discovery-vulcanus")
  end)

  it("loads with its (v1 vanilla) star-map sprite and icon", function()
    local loc = prototypes.space_location["cindra"]
    assert.is_not_nil(loc, "cindra space location must exist")
    assert.is_true(loc.valid, "cindra space location must load (all referenced sprites present)")

    local tech = prototypes.technology["planet-discovery-cindra"]
    assert.is_true(tech.valid, "discovery tech must load (its icon present)")
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
    -- generous baseline solar (placeholder until §15-7 sets the flare curve).
    assert.are.equal(20, s.get_property("gravity"), "cindra is a heavy rocky world")
    assert.are.equal(500, s.get_property("pressure"), "cindra has a thin atmosphere")
    assert.are.equal(400, s.get_property("solar-power"),
      "cindra baseline solar (placeholder; §15-7 sets the flare-driving multiplier)")
    assert.are.equal(25, s.get_property("magnetic-field"), "cindra magnetic-field")
  end)
end)
