-- Proof: Cindra ice processing (§15-4). A TWO-STAGE chain, faithful to the Space
-- Age asteroid model: a ground-standing crusher grinds nightside `ice` into
-- SOLID crushed-ice shards (item-only, like the space-platform crusher -- ci-4or),
-- and a SEPARATE melter turns those shards into `water` (fluid). The player still
-- picks the water<->calcite ratio at the crush step. DESIGN.md §1 (nightward edge
-- = MATTER), §5, §6 (never-mutate-other-planets: private categories, cloned
-- prototypes).

local H = require("tests.helpers")

local CRUSHER = "cindra-ice-crusher"
local MELTER = "cindra-ice-melter"
local CRUSH_CATEGORY = "cindra-ice-crushing"
local MELT_CATEGORY = "cindra-ice-melting"
local R_CRUSH = "cindra-ice-crushing"
local R_CRUSH_CALCITE = "cindra-ice-crushing-calcite"
local R_MELT = "cindra-ice-melting"
local SHARD = "cindra-crushed-ice"

-- Sum a recipe's product amounts by product name, for shape assertions.
local function products(recipe)
  local out = {}
  for _, p in pairs(prototypes.recipe[recipe].products) do
    out[p.name] = (out[p.name] or 0) + (p.amount or 0)
  end
  return out
end

local function ingredients(recipe)
  local out = {}
  for _, i in pairs(prototypes.recipe[recipe].ingredients) do
    out[i.name] = (out[i.name] or 0) + (i.amount or 0)
  end
  return out
end

-- True if any of a recipe's products is a fluid.
local function has_fluid_product(recipe)
  for _, p in pairs(prototypes.recipe[recipe].products) do
    if p.type == "fluid" then return true end
  end
  return false
end

-- LuaRecipePrototype.categories is a dictionary {name -> true}; membership test
-- that also tolerates an array form.
local function in_category(recipe, category)
  local cats = prototypes.recipe[recipe].categories
  if cats[category] then return true end
  for _, v in pairs(cats) do
    if v == category then return true end
  end
  return false
end

describe("cindra ice processing", function()
  it("crusher crafts only in the private ice-crushing category (never vanilla crushing)", function()
    local proto = prototypes.entity[CRUSHER]
    assert.is_not_nil(proto, "cindra-ice-crusher entity must exist")
    assert.are.equal("assembling-machine", proto.type, "it is a crafting machine (crusher)")

    local cats = proto.crafting_categories
    assert.is_true(cats[CRUSH_CATEGORY], "the crusher crafts in the private cindra-ice-crushing category")
    assert.is_nil(cats["crushing"],
      "the crusher must NOT share the vanilla crushing category (no recipe leak across planets)")
  end)

  it("crusher is SOLID -> SOLID: it has NO fluid outputs (a grinder, not a boiler -- ci-4or)", function()
    local proto = prototypes.entity[CRUSHER]
    local boxes = proto.fluidbox_prototypes
    -- Either no fluid boxes at all, or none that are outputs. The point: the
    -- crusher must never emit a fluid; water is born only at the melt step.
    if boxes then
      for _, fb in pairs(boxes) do
        assert.are_not.equal("output", fb.production_type,
          "the ice crusher must NOT expose an output fluid box -- it emits solids only")
      end
    end
  end)

  it("is placeable on Cindra's heavy-gravity ground (the space-only gate is gone)", function()
    -- The vanilla crusher is gated to zero gravity; Cindra has heavy gravity, so
    -- the clone must drop that surface condition. Placing it on the Cindra
    -- surface proves the gate is gone (and that it stands on the ground, not orbit).
    local s = H.cindra_surface()
    local e = s.create_entity({ name = CRUSHER, position = { 0, 0 }, force = "player" })
    assert.is_not_nil(e, "the ice crusher must be placeable on Cindra")
    assert.is_true(e.valid)
    assert.are.equal("assembling-machine", e.type)
    e.destroy()
  end)

  it("crush recipe: ice -> crushed-ice (SOLID) only, no fluid, gated off by default", function()
    local recipe = prototypes.recipe[R_CRUSH]
    assert.is_not_nil(recipe, "cindra-ice-crushing recipe must exist")
    assert.is_true(in_category(R_CRUSH, CRUSH_CATEGORY), "the crush recipe runs in the private crusher category")
    assert.is_false(recipe.enabled, "gated: unlocked by research, not free")

    assert.is_true((ingredients(R_CRUSH)["ice"] or 0) > 0, "it consumes ice")
    assert.is_false(has_fluid_product(R_CRUSH), "the crush recipe must produce NO fluid (crusher is solid->solid)")
    local prods = products(R_CRUSH)
    assert.is_true((prods[SHARD] or 0) > 0, "it produces crushed-ice shards")
    assert.is_nil(prods["water"], "the crusher must NOT produce water (ci-4or)")
    assert.is_nil(prods["calcite"], "the plain crush recipe yields NO calcite (all matter -> shards)")
  end)

  it("crush+calcite recipe: ice -> crushed-ice + calcite (the ratio knob), still no fluid", function()
    local recipe = prototypes.recipe[R_CRUSH_CALCITE]
    assert.is_not_nil(recipe, "cindra-ice-crushing-calcite recipe must exist")
    assert.is_true(in_category(R_CRUSH_CALCITE, CRUSH_CATEGORY),
      "the calcite crush recipe runs in the private crusher category")
    assert.is_false(recipe.enabled, "gated: unlocked by research, not free")

    assert.is_false(has_fluid_product(R_CRUSH_CALCITE),
      "the calcite crush recipe must produce NO fluid (crusher is solid->solid)")
    local prods = products(R_CRUSH_CALCITE)
    assert.is_true((prods[SHARD] or 0) > 0, "it still produces crushed-ice shards")
    assert.is_true((prods["calcite"] or 0) > 0, "it also produces calcite (item)")

    -- Both recipes crush the same amount of ice, so choosing calcite costs shards
    -- (hence downstream water): the two recipes ARE the ratio the player picks.
    assert.are.equal(ingredients(R_CRUSH)["ice"], ingredients(R_CRUSH_CALCITE)["ice"],
      "both crush recipes crush the same ice per batch")
    assert.is_true(products(R_CRUSH_CALCITE)[SHARD] < products(R_CRUSH)[SHARD],
      "the calcite recipe yields FEWER shards than the plain one (matter diverted to calcite)")
  end)

  it("melter crafts only in the private ice-melting category (never vanilla chemistry)", function()
    local proto = prototypes.entity[MELTER]
    assert.is_not_nil(proto, "cindra-ice-melter entity must exist")
    assert.are.equal("assembling-machine", proto.type, "it is a crafting machine (melter)")

    local cats = proto.crafting_categories
    assert.is_true(cats[MELT_CATEGORY], "the melter crafts in the private cindra-ice-melting category")
    assert.is_nil(cats["chemistry"],
      "the melter must NOT share the vanilla chemistry category (no recipe leak across planets)")
  end)

  it("melter has a water OUTPUT fluid box (this is where the fluid is born)", function()
    local proto = prototypes.entity[MELTER]
    local boxes = proto.fluidbox_prototypes
    assert.is_not_nil(boxes, "the melter must have fluid boxes")
    local has_output = false
    for _, fb in pairs(boxes) do
      if fb.production_type == "output" then has_output = true end
    end
    assert.is_true(has_output, "the melter must expose an OUTPUT fluid box to emit water")
  end)

  it("melt recipe: crushed-ice (item) -> water (fluid), in the private melt category, gated off", function()
    local recipe = prototypes.recipe[R_MELT]
    assert.is_not_nil(recipe, "cindra-ice-melting recipe must exist")
    assert.is_true(in_category(R_MELT, MELT_CATEGORY), "the melt recipe runs in the private melter category")
    assert.is_false(recipe.enabled, "gated: unlocked by research, not free")

    assert.is_true((ingredients(R_MELT)[SHARD] or 0) > 0, "it consumes crushed-ice shards (an item)")
    assert.is_nil(ingredients(R_MELT)["ice"], "it consumes crushed-ice, not raw ice (that is the crusher's job)")
    local prods = products(R_MELT)
    assert.is_true((prods["water"] or 0) > 0, "it produces water (a fluid)")
    assert.is_true(has_fluid_product(R_MELT), "water must be a FLUID product")
  end)

  it("neither machine leaks its recipes into vanilla space crusher / chemical plant (never-mutate)", function()
    local vanilla_crusher = prototypes.entity["crusher"]
    assert.is_true(vanilla_crusher.crafting_categories["crushing"],
      "the vanilla crusher still crafts vanilla crushing recipes")
    assert.is_nil(vanilla_crusher.crafting_categories[CRUSH_CATEGORY],
      "the vanilla space crusher must NOT gain the Cindra crush category")

    local vanilla_plant = prototypes.entity["chemical-plant"]
    assert.is_true(vanilla_plant.crafting_categories["chemistry"],
      "the vanilla chemical plant still crafts vanilla chemistry recipes")
    assert.is_nil(vanilla_plant.crafting_categories[MELT_CATEGORY],
      "the vanilla chemical plant must NOT gain the Cindra melt category")

    for _, name in ipairs({ R_CRUSH, R_CRUSH_CALCITE }) do
      assert.is_false(in_category(name, "crushing"),
        name .. " must not live in the vanilla crushing category")
    end
    assert.is_false(in_category(R_MELT, "chemistry"),
      R_MELT .. " must not live in the vanilla chemistry category")
  end)

  it("has items that place both machines", function()
    for _, name in ipairs({ CRUSHER, MELTER }) do
      local item = prototypes.item[name]
      assert.is_not_nil(item, name .. " item must exist")
      assert.is_not_nil(item.place_result, "the item must place an entity")
      assert.are.equal(name, item.place_result.name, "the item places its machine")
    end
  end)

  it("has build recipes for both machines, gated behind research (not free)", function()
    for _, name in ipairs({ CRUSHER, MELTER }) do
      local recipe = prototypes.recipe[name]
      assert.is_not_nil(recipe, name .. " build recipe must exist")
      assert.is_false(recipe.enabled, "the build recipe is unlocked by research, not free")
    end
  end)

  it("cindra-ice-processing technology unlocks both machines and all three recipes", function()
    local tech = prototypes.technology["cindra-ice-processing"]
    assert.is_not_nil(tech, "cindra-ice-processing technology must exist")
    assert.is_true(tech.valid, "the tech must load (its icon is present)")

    local unlocked = {}
    for _, effect in pairs(tech.effects) do
      if effect.type == "unlock-recipe" then unlocked[effect.recipe] = true end
    end
    assert.is_true(unlocked[CRUSHER], "the tech unlocks the crusher build recipe")
    assert.is_true(unlocked[MELTER], "the tech unlocks the melter build recipe")
    assert.is_true(unlocked[R_CRUSH], "the tech unlocks the plain crush recipe")
    assert.is_true(unlocked[R_CRUSH_CALCITE], "the tech unlocks the crush+calcite recipe")
    assert.is_true(unlocked[R_MELT], "the tech unlocks the melt recipe")

    assert.is_not_nil(tech.prerequisites["planet-discovery-cindra"],
      "ice processing is gated behind discovering Cindra")
  end)

  it("crushes ice into shards, then melts shards into water on Cindra (end-to-end, powered)", function()
    local s = H.cindra_surface()
    -- A cheat power source + a substation so both machines share an electric
    -- network and can actually run headless (a pole's supply area auto-connects
    -- every entity standing in it).
    local pole = s.create_entity({ name = "substation", position = { 2, 2 }, force = "player" })
    assert.is_not_nil(pole, "substation must place")
    local power = s.create_entity({
      name = "electric-energy-interface", position = { 4, 0 }, force = "player",
    })
    power.power_production = 10000000
    power.electric_buffer_size = 10000000
    power.energy = 10000000

    -- The recipes are research-gated; enable them for the force so the machines
    -- craft headlessly (equivalent to having researched cindra-ice-processing).
    game.forces["player"].recipes[R_CRUSH].enabled = true
    game.forces["player"].recipes[R_MELT].enabled = true

    local crusher = s.create_entity({ name = CRUSHER, position = { 0, 0 }, force = "player" })
    crusher.set_recipe(R_CRUSH)
    crusher.insert({ name = "ice", count = 50 })

    local melter = s.create_entity({ name = MELTER, position = { -4, 0 }, force = "player" })
    melter.set_recipe(R_MELT)

    async(2400)
    after_ticks(600, function()
      assert.is_true(crusher.valid)
      -- Stage 1: the crusher produced SOLID shards, and NO water (it emits no fluid).
      local shards = crusher.get_item_count(SHARD)
      assert.is_true(shards > 0,
        "the crusher must have produced crushed-ice from ice (got " .. shards
          .. ", ice left " .. crusher.get_item_count("ice") .. ")")
      assert.are.equal(0, crusher.get_fluid_count("water"),
        "the crusher must produce NO water (it has no fluid output -- ci-4or)")

      -- Feed the shards to the melter and let it run.
      local moved = crusher.remove_item({ name = SHARD, count = shards })
      melter.insert({ name = SHARD, count = moved })

      after_ticks(1200, function()
        assert.is_true(melter.valid)
        -- Stage 2: the melter turned the shards into water (the fluid step).
        local water = melter.get_fluid_count("water")
        assert.is_true(water > 0,
          "the melter must have produced water from crushed-ice (got " .. water
            .. ", shards left " .. melter.get_item_count(SHARD) .. ")")
        pole.destroy()
        power.destroy()
        crusher.destroy()
        melter.destroy()
        done()
      end)
    end)
  end)
end)
