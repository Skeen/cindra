-- Proof: the Cindra electric heater is a heat SOURCE with a CAPPED heat output
-- (600 C) and an UNCAPPED electric power DRAW (electric source, no fuel), gated
-- behind its own tech, and situational-not-strictly-better than the vanilla
-- heating tower it clones. §15-10 (DESIGN.md §5, §7 tuning table, §12 guardrail).

local H = require("tests.helpers")

local HEATER = "cindra-electric-heater"
local HEAT_CAP = 600

describe("cindra electric heater", function()
  it("registers a reactor entity whose heat output is capped at 600 C", function()
    local proto = prototypes.entity[HEATER]
    assert.is_not_nil(proto, "cindra-electric-heater entity must exist")
    assert.are.equal("reactor", proto.type, "it is a heat source (reactor prototype)")

    local heat = proto.heat_buffer_prototype
    assert.is_not_nil(heat, "the heater must have a heat buffer (it produces heat)")
    assert.are.equal(HEAT_CAP, heat.max_temperature,
      "heat output is capped at 600 C (§7): below a reactor, above steam boil")
  end)

  it("draws electricity without limit and burns no fuel (uncapped electric draw)", function()
    local proto = prototypes.entity[HEATER]
    assert.is_not_nil(proto.electric_energy_source_prototype,
      "the heater is an electric consumer (eats power, not fuel)")
    assert.is_nil(proto.burner_prototype,
      "the heater must NOT be a burner -- it draws electricity, never fuel")
  end)

  it("is situational-not-strictly-better than the vanilla heating tower (§12)", function()
    local mine = prototypes.entity[HEATER].heat_buffer_prototype.max_temperature
    local vanilla = prototypes.entity["heating-tower"].heat_buffer_prototype.max_temperature
    assert.is_true(mine < vanilla,
      "the electric heater's heat ceiling (600) must be LOWER than the heating tower's (1000): "
        .. "it trades peak heat + fuel-free operation, not a plain upgrade")
  end)

  it("has an item that places the heater", function()
    local item = prototypes.item[HEATER]
    assert.is_not_nil(item, "cindra-electric-heater item must exist")
    assert.is_not_nil(item.place_result, "the item must place an entity")
    assert.are.equal(HEATER, item.place_result.name, "the item places the heater entity")
  end)

  it("has a recipe gated behind research (not free), built from available items", function()
    local recipe = prototypes.recipe[HEATER]
    assert.is_not_nil(recipe, "cindra-electric-heater recipe must exist")
    assert.is_false(recipe.enabled,
      "the recipe must be disabled by default -- unlocked by research, not free")

    local ingredients = {}
    for _, ing in pairs(recipe.ingredients) do ingredients[ing.name] = ing.amount end
    assert.is_not_nil(ingredients["heat-pipe"], "heat management uses heat pipes")
    assert.is_true((ingredients["steel-plate"] or 0) > 0, "built from steel")
  end)

  it("is unlocked by its own technology (a heating-tower variant)", function()
    local tech = prototypes.technology["cindra-electric-heating"]
    assert.is_not_nil(tech, "cindra-electric-heating technology must exist")
    assert.is_true(tech.valid, "the tech must load (its icon is present)")

    local unlocks = false
    for _, effect in pairs(tech.effects) do
      if effect.type == "unlock-recipe" and effect.recipe == HEATER then unlocks = true end
    end
    assert.is_true(unlocks, "the tech must unlock the electric-heater recipe")

    assert.is_not_nil(tech.prerequisites["heating-tower"],
      "gated as an electric variant of the heating tower (which also grants heat pipes)")
  end)

  it("places and runs as a heat source on the Cindra surface", function()
    local s = H.cindra_surface()
    local e = s.create_entity({ name = HEATER, position = { 0, 0 }, force = "player" })
    assert.is_not_nil(e, "the heater must be placeable on Cindra")
    assert.is_true(e.valid)
    assert.are.equal("reactor", e.type)
    -- A reactor exposes its heat as .temperature; it starts cold and can never
    -- exceed the prototype cap.
    assert.is_number(e.temperature, "the heater reports a heat temperature")
    assert.is_true(e.temperature <= HEAT_CAP, "runtime heat never exceeds the 600 C cap")
    e.destroy()
  end)
end)
