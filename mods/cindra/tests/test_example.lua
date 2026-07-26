-- Template integration test (factorio-test).
--
-- Demonstrates the two reachable test patterns and gives the suite something
-- green to run. Both blocks assert against VANILLA entities so they pass
-- independent of Cindra content. Real Cindra invariants live in test_planet.lua,
-- test_ribbon.lua, and the files that accrue per §15.
--
-- 🚨 Every change to a prototype, recipe, script, or world-gen tweak needs a
-- test like one of these.

-- Pattern 1 — prototype-field assertion.
describe("prototype fields are readable at runtime", function()
  it("reads name and type off a vanilla assembler", function()
    local proto = prototypes.entity["assembling-machine-2"]
    assert.is_not_nil(proto, "assembling-machine-2 must exist")
    assert.are.equal("assembling-machine-2", proto.name)
    assert.are.equal("assembling-machine", proto.type)
  end)
end)

-- Pattern 2 — runtime behaviour.
describe("runtime entity behaviour", function()
  local surface

  before_each(function()
    surface = game.surfaces["nauvis"]
    for _, e in pairs(surface.find_entities_filtered({ area = { { -10, -10 }, { 10, 10 } } })) do
      e.destroy()
    end
  end)

  it("places an entity and observes it after a few ticks", function()
    local chest = surface.create_entity({
      name = "iron-chest", position = { 0, 0 }, force = "player",
    })
    assert.is_not_nil(chest, "iron-chest must place")

    async(60)
    after_ticks(30, function()
      assert.is_true(chest.valid, "entity should still be valid after 30 ticks")
      chest.get_inventory(defines.inventory.chest).insert({ name = "iron-plate", count = 5 })
      assert.are.equal(5, chest.get_item_count("iron-plate"))
      done()
    end)
  end)
end)
