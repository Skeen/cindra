-- Proof of the two-temperature recipe (planet_design.md §8 + §12 item 1).
--
-- The claim under test: a single craft can require a HOT input and a COLD input
-- at the same time, and the alloy is produced ONLY when both are present. Two
-- layers of proof:
--
--   Pattern 1 (prototype shape): the recipe genuinely carries a fluid ingredient
--   that is temperature-gated (hot) AND an item ingredient (cold), and the
--   quench building is an electric fluid-crafting machine.
--
--   Pattern 2 (runtime behaviour): a powered quench building crafts the alloy
--   only when BOTH inputs are supplied — and, critically, NOT when the fluid is
--   present but below the hot threshold. That last case is the empirical proof
--   that `minimum_temperature` gating (modeling approach "b") actually works in
--   Factorio 2.1, which is the real technical risk the PoC exists to retire.

local HOT = "quench-poc-molten-metal"
local COOLANT = "quench-poc-cryo-coolant"
local ALLOY = "quench-poc-cryo-alloy"
local QUENCH = "quench-poc-cryo-quench"
local RECIPE = "quench-poc-cryo-alloy"
local HOT_MIN = 500

describe("cryo-quench recipe shape (two-temperature)", function()
  it("requires a HOT fluid and a COLD item in the same craft", function()
    local r = prototypes.recipe[RECIPE]
    assert.is_not_nil(r, "the quench recipe must exist")

    local fluid_ing, item_ing
    for _, ing in pairs(r.ingredients) do
      if ing.type == "fluid" then
        fluid_ing = ing
      elseif ing.type == "item" then
        item_ing = ing
      end
    end

    assert.is_not_nil(fluid_ing, "recipe must have a fluid (hot) ingredient")
    assert.is_not_nil(item_ing, "recipe must have an item (cold, consumed) ingredient")
    assert.are.equal(HOT, fluid_ing.name)
    assert.are.equal(COOLANT, item_ing.name)
    -- The gate is the whole point: the hot input is hot by temperature, not name.
    assert.are.equal(HOT_MIN, fluid_ing.minimum_temperature,
      "the hot fluid ingredient must be temperature-gated with minimum_temperature")
    assert.are.equal(ALLOY, r.products[1].name, "the recipe must produce cryo-hardened alloy")
  end)

  it("is built by an electric machine with a fluid input", function()
    local e = prototypes.entity[QUENCH]
    assert.is_not_nil(e, "the quench building must exist")
    assert.is_not_nil(e.electric_energy_source_prototype, "the quench must be electric")

    local has_fluid_input = false
    for _, fb in pairs(e.fluidbox_prototypes) do
      if fb.production_type == "input" or fb.production_type == "input-output" then
        has_fluid_input = true
      end
    end
    assert.is_true(has_fluid_input, "the quench building must have a fluid input box for the hot input")
  end)
end)

describe("cryo-quench runtime (crafts only with BOTH inputs)", function()
  local surface

  -- Build a powered quench building on a cleaned patch of nauvis. Power comes
  -- from a full accumulator on the same one-pole grid (the same pattern the
  -- coercia suite uses to run electric machines in tests).
  local function powered_quench()
    surface = game.surfaces["nauvis"]
    for _, e in pairs(surface.find_entities_filtered({ area = { { -20, -20 }, { 20, 20 } } })) do
      if e.type ~= "character" then
        e.destroy()
      end
    end

    local pole = surface.create_entity({ name = "medium-electric-pole", position = { 3, 0 }, force = "player" })
    assert.is_not_nil(pole, "power pole must place")
    local acc = surface.create_entity({ name = "accumulator", position = { 3, 3 }, force = "player" })
    acc.energy = acc.electric_buffer_size -- full: plenty of power to run the quench

    local m = surface.create_entity({ name = QUENCH, position = { 0, 0 }, force = "player", recipe = RECIPE })
    assert.is_not_nil(m, "quench building must place")
    return m
  end

  it("crafts alloy when BOTH the hot fluid and the cold item are present", function()
    local m = powered_quench()
    m.insert_fluid({ name = HOT, amount = 200, temperature = HOT_MIN + 100 }) -- hot: above the gate
    m.insert({ name = COOLANT, count = 50 })

    async(600)
    after_ticks(240, function()
      assert.is_true(m.get_item_count(ALLOY) > 0,
        "with both a hot input and a cold input, the quench must produce alloy")
      done()
    end)
  end)

  it("does NOT craft when the COLD item is missing", function()
    local m = powered_quench()
    m.insert_fluid({ name = HOT, amount = 200, temperature = HOT_MIN + 100 }) -- hot input only

    async(600)
    after_ticks(240, function()
      assert.are.equal(0, m.get_item_count(ALLOY),
        "no cold input -> no alloy (the recipe genuinely needs the cold half)")
      done()
    end)
  end)

  it("does NOT craft when the HOT fluid is missing", function()
    local m = powered_quench()
    m.insert({ name = COOLANT, count = 50 }) -- cold input only

    async(600)
    after_ticks(240, function()
      assert.are.equal(0, m.get_item_count(ALLOY),
        "no hot input -> no alloy (the recipe genuinely needs the hot half)")
      done()
    end)
  end)

  it("does NOT craft when the fluid is present but COLD (below the hot threshold)", function()
    local m = powered_quench()
    -- Both ingredients are physically present, but the molten metal is cold.
    -- This is the empirical proof that minimum_temperature gating works.
    m.insert_fluid({ name = HOT, amount = 200, temperature = 50 }) -- well below HOT_MIN
    m.insert({ name = COOLANT, count = 50 })

    async(600)
    after_ticks(240, function()
      assert.are.equal(0, m.get_item_count(ALLOY),
        "temperature gate: sub-threshold molten metal must not craft even with coolant present")
      done()
    end)
  end)
end)
