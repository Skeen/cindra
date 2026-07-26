-- Proof: Cindra's SIGNATURE two-temperature quench (§15-6; DESIGN.md §1, §5,
-- §12). The claim: a SINGLE craft requires a HOT input and a COLD input at the
-- same time, and the cryo-hardened alloy is produced ONLY when both are present.
--
-- Two layers of proof, mirroring the quench PoC (mods/quench-poc / ci-o4r) now
-- that the real fire (lava, ci-8mw) and ice (ci-rgv) chains are on main:
--   * Prototype shape -- the recipe carries a temperature-gated HOT fluid (`lava`)
--     AND a COLD consumed item (`cindra-cryo-coolant`); the quench is an electric
--     fluid-crafter in a PRIVATE category; the tech is gated behind BOTH parent
--     chains; nothing shared is mutated.
--   * Runtime behaviour -- a powered quench on Cindra crafts alloy with BOTH
--     inputs, and does NOT craft when either half is missing.

local H = require("tests.helpers")

local HOT = "lava"
local COOLANT = "cindra-cryo-coolant"
local ALLOY = "cindra-cryo-hardened-alloy"
local QUENCH = "cindra-cryo-quench"
local CATEGORY = "cindra-quenching"
local TECH = "cindra-cryo-quenching"
local HOT_MIN = 500

-- Pull the amount of a named entry out of a {type,name,amount} array; nil if absent.
local function amount_of(list, name)
  for _, e in pairs(list) do
    if e.name == name then return e.amount end
  end
  return nil
end

-- LuaRecipePrototype.categories is a dictionary {name -> true}; tolerate an array too.
local function in_category(recipe_name, category)
  local cats = prototypes.recipe[recipe_name].categories
  if cats[category] then return true end
  for _, v in pairs(cats) do
    if v == category then return true end
  end
  return false
end

describe("cindra cryo-quench recipe shape (two-temperature)", function()
  it("requires a HOT temperature-gated fluid AND a COLD item in one craft", function()
    local r = prototypes.recipe[ALLOY]
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
    assert.are.equal(HOT, fluid_ing.name, "the hot half is the manufactured lava fluid")
    assert.are.equal(COOLANT, item_ing.name, "the cold half is the cryo-coolant item")

    -- The gate is the whole point: "hot" is engine-enforced by temperature, not
    -- a name. Sub-threshold molten stock cannot craft.
    assert.are.equal(HOT_MIN, fluid_ing.minimum_temperature,
      "the hot fluid ingredient must be temperature-gated with minimum_temperature")

    assert.are.equal(ALLOY, r.products[1].name, "the recipe must produce cryo-hardened alloy")
  end)

  it("is built by an electric machine with a fluid input, in the private category", function()
    local e = prototypes.entity[QUENCH]
    assert.is_not_nil(e, "the quench building must exist")
    assert.are.equal("assembling-machine", e.type, "it is a crafting machine")
    assert.is_not_nil(e.electric_energy_source_prototype, "the quench must be electric")

    local has_fluid_input = false
    for _, fb in pairs(e.fluidbox_prototypes) do
      if fb.production_type == "input" or fb.production_type == "input-output" then
        has_fluid_input = true
      end
    end
    assert.is_true(has_fluid_input, "the quench must have a fluid input box for the hot input")

    assert.is_true(e.crafting_categories[CATEGORY],
      "the quench crafts in the private cindra-quenching category")
    assert.is_nil(e.crafting_categories["chemistry"],
      "the quench must NOT share the vanilla chemistry category (no recipe leak across planets)")
  end)

  it("does NOT leak into vanilla chemical plants, and leaves the lava fluid intact", function()
    -- The signature recipe lives in a private category, so vanilla chemical
    -- plants never gain it and it never runs there.
    local plant = prototypes.entity["chemical-plant"]
    assert.is_true(plant.crafting_categories["chemistry"],
      "the vanilla chemical plant still crafts vanilla chemistry")
    assert.is_nil(plant.crafting_categories[CATEGORY],
      "the vanilla chemical plant must NOT gain the Cindra quench category")
    assert.is_false(in_category(ALLOY, "chemistry"),
      "the alloy recipe must not live in the vanilla chemistry category")

    -- The hot half reads (never mutates) the shared Vulcanus `lava` fluid: its
    -- canonical 1500 C default must be untouched (never-mutate-other-planets).
    assert.are.equal(1500, prototypes.fluid[HOT].default_temperature,
      "the shared lava fluid keeps its canonical 1500 C (we read it, never mutate it)")
  end)

  it("cold-half recipe: ice -> cryo-coolant (a consumed nightside material)", function()
    local r = prototypes.recipe[COOLANT]
    assert.is_not_nil(r, "the cryo-coolant recipe must exist")
    assert.is_true((amount_of(r.ingredients, "ice") or 0) > 0, "coolant is packed from ice")
    assert.is_true((amount_of(r.products, COOLANT) or 0) > 0, "it produces cryo-coolant")
    assert.is_false(r.enabled, "gated: unlocked by research, not free")
  end)

  it("all quench recipes are gated off by default", function()
    for _, name in ipairs({ ALLOY, COOLANT, QUENCH }) do
      assert.is_false(prototypes.recipe[name].enabled,
        name .. " must be research-gated, not free")
    end
  end)

  it("is unlocked by cindra-cryo-quenching, gated behind BOTH fire and ice chains", function()
    local tech = prototypes.technology[TECH]
    assert.is_not_nil(tech, "the cindra-cryo-quenching technology must exist")
    assert.is_true(tech.valid, "the tech must load (its icon is present)")

    local unlocked = {}
    for _, effect in pairs(tech.effects) do
      if effect.type == "unlock-recipe" then unlocked[effect.recipe] = true end
    end
    assert.is_true(unlocked[QUENCH], "the tech unlocks the quench build recipe")
    assert.is_true(unlocked[COOLANT], "the tech unlocks the coolant recipe")
    assert.is_true(unlocked[ALLOY], "the tech unlocks the signature alloy recipe")

    -- The mechanic expressed as a dependency: you cannot make the alloy until you
    -- command BOTH the hot half (lava) and the cold half (ice processing).
    assert.is_not_nil(tech.prerequisites["cindra-lava"],
      "gated behind the lava spine -- the hot half")
    assert.is_not_nil(tech.prerequisites["cindra-ice-processing"],
      "gated behind ice processing -- the cold half")
  end)

  it("has an item that places the quench, and a gated build recipe", function()
    local item = prototypes.item[QUENCH]
    assert.is_not_nil(item, "the quench item must exist")
    assert.is_not_nil(item.place_result, "the item must place an entity")
    assert.are.equal(QUENCH, item.place_result.name, "the item places the quench")

    assert.is_not_nil(prototypes.item[ALLOY], "the cryo-hardened alloy item must exist")
    assert.is_not_nil(prototypes.item[COOLANT], "the cryo-coolant item must exist")
  end)
end)

describe("cindra cryo-quench runtime (crafts only with BOTH inputs)", function()
  -- Build a powered quench on a cleaned Cindra surface. A cheat power source + a
  -- substation share an electric network so the quench runs headless (same
  -- pattern as the ice-processing suite).
  local function powered_quench()
    local s = H.cindra_surface()
    local pole = s.create_entity({ name = "substation", position = { 2, 2 }, force = "player" })
    assert.is_not_nil(pole, "substation must place")
    local power = s.create_entity({
      name = "electric-energy-interface", position = { 4, 0 }, force = "player",
    })
    power.power_production = 10000000
    power.electric_buffer_size = 10000000
    power.energy = 10000000

    -- Enable the gated recipe for the force (equivalent to having researched it).
    game.forces["player"].recipes[ALLOY].enabled = true

    local m = s.create_entity({ name = QUENCH, position = { 0, 0 }, force = "player" })
    assert.is_not_nil(m, "the quench must be placeable on Cindra")
    m.set_recipe(ALLOY)
    return m
  end

  it("crafts alloy when BOTH the hot fluid and the cold item are present", function()
    local m = powered_quench()
    -- Lava at its canonical 1500 C is well above the hot gate.
    m.insert_fluid({ name = HOT, amount = 400, temperature = 1500 })
    m.insert({ name = COOLANT, count = 50 })

    async(1200)
    after_ticks(600, function()
      assert.is_true(m.valid)
      assert.is_true(m.get_item_count(ALLOY) > 0,
        "with both a hot input and a cold input, the quench must produce alloy (got "
          .. m.get_item_count(ALLOY) .. ")")
      m.destroy()
      done()
    end)
  end)

  it("does NOT craft when the COLD item is missing", function()
    local m = powered_quench()
    m.insert_fluid({ name = HOT, amount = 400, temperature = 1500 }) -- hot input only

    async(900)
    after_ticks(480, function()
      assert.are.equal(0, m.get_item_count(ALLOY),
        "no cold input -> no alloy (the recipe genuinely needs the cold half)")
      m.destroy()
      done()
    end)
  end)

  it("does NOT craft when the HOT fluid is missing", function()
    local m = powered_quench()
    m.insert({ name = COOLANT, count = 50 }) -- cold input only

    async(900)
    after_ticks(480, function()
      assert.are.equal(0, m.get_item_count(ALLOY),
        "no hot input -> no alloy (the recipe genuinely needs the hot half)")
      m.destroy()
      done()
    end)
  end)
end)
