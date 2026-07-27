-- Proof: Cindra ice processing (§15-4). A ground-standing crusher (the Space Age
-- asteroid-crushing model, relocated off the space platform) grinds nightside
-- `ice` into `water`, or into `water + calcite` -- two recipes the player picks
-- between to choose the ratio. DESIGN.md §1 (nightward edge = MATTER), §5, §6
-- (never-mutate-other-planets: private recipe category, cloned prototype).

local H = require("tests.helpers")

local CRUSHER = "cindra-ice-crusher"
local CATEGORY = "cindra-ice-crushing"
local R_WATER = "cindra-ice-crushing"
local R_CALCITE = "cindra-ice-crushing-calcite"

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
  it("registers a crusher building that crafts only in the private ice category", function()
    local proto = prototypes.entity[CRUSHER]
    assert.is_not_nil(proto, "cindra-ice-crusher entity must exist")
    assert.are.equal("assembling-machine", proto.type, "it is a crafting machine (crusher)")

    local cats = proto.crafting_categories
    assert.is_true(cats[CATEGORY], "the crusher crafts in the private cindra-ice-crushing category")
    assert.is_nil(cats["crushing"],
      "the crusher must NOT share the vanilla crushing category (no recipe leak across planets)")
  end)

  it("has a water OUTPUT fluid box (the vanilla crusher emits only solids)", function()
    local proto = prototypes.entity[CRUSHER]
    local boxes = proto.fluidbox_prototypes
    assert.is_not_nil(boxes, "the crusher must have fluid boxes")
    local has_output = false
    for _, fb in pairs(boxes) do
      if fb.production_type == "output" then has_output = true end
    end
    assert.is_true(has_output, "the crusher must expose an OUTPUT fluid box to emit water")
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

  it("water recipe: ice -> water (fluid) only, in the private category, gated off by default", function()
    local recipe = prototypes.recipe[R_WATER]
    assert.is_not_nil(recipe, "cindra-ice-crushing recipe must exist")
    assert.is_true(in_category(R_WATER, CATEGORY), "the water recipe runs in the private crusher category")
    assert.is_false(recipe.enabled, "gated: unlocked by research, not free")

    assert.is_true((ingredients(R_WATER)["ice"] or 0) > 0, "it consumes ice")
    local prods = products(R_WATER)
    assert.is_true((prods["water"] or 0) > 0, "it produces water (a fluid)")
    assert.is_nil(prods["calcite"], "the plain water recipe yields NO calcite (all matter -> water)")
  end)

  it("calcite recipe: ice -> water + calcite, trading water for calcite (the ratio knob)", function()
    local recipe = prototypes.recipe[R_CALCITE]
    assert.is_not_nil(recipe, "cindra-ice-crushing-calcite recipe must exist")
    assert.is_true(in_category(R_CALCITE, CATEGORY), "the calcite recipe runs in the private crusher category")
    assert.is_false(recipe.enabled, "gated: unlocked by research, not free")

    local prods = products(R_CALCITE)
    assert.is_true((prods["water"] or 0) > 0, "it still produces water")
    assert.is_true((prods["calcite"] or 0) > 0, "it also produces calcite")

    -- Both recipes crush the same amount of ice, so choosing calcite costs water:
    -- the two recipes ARE the water<->calcite ratio the player picks.
    assert.are.equal(ingredients(R_WATER)["ice"], ingredients(R_CALCITE)["ice"],
      "both recipes crush the same ice per batch")
    assert.is_true(products(R_CALCITE)["water"] < products(R_WATER)["water"],
      "the calcite recipe yields LESS water than the plain one (matter diverted to calcite)")
  end)

  it("does NOT leak its recipes into the vanilla space crusher (never-mutate invariant)", function()
    local vanilla = prototypes.entity["crusher"]
    assert.is_true(vanilla.crafting_categories["crushing"],
      "the vanilla crusher still crafts vanilla crushing recipes")
    assert.is_nil(vanilla.crafting_categories[CATEGORY],
      "the vanilla space crusher must NOT gain the Cindra ice category")
    for _, name in ipairs({ R_WATER, R_CALCITE }) do
      assert.is_false(in_category(name, "crushing"),
        name .. " must not live in the vanilla crushing category")
    end
  end)

  it("has an item that places the crusher", function()
    local item = prototypes.item[CRUSHER]
    assert.is_not_nil(item, "cindra-ice-crusher item must exist")
    assert.is_not_nil(item.place_result, "the item must place an entity")
    assert.are.equal(CRUSHER, item.place_result.name, "the item places the crusher")
  end)

  it("has a build recipe gated behind research (not free)", function()
    local recipe = prototypes.recipe[CRUSHER]
    assert.is_not_nil(recipe, "cindra-ice-crusher build recipe must exist")
    assert.is_false(recipe.enabled, "the build recipe is unlocked by research, not free")
  end)

  it("is unlocked by the cindra-ice-processing technology (crusher + both recipes)", function()
    local tech = prototypes.technology["cindra-ice-processing"]
    assert.is_not_nil(tech, "cindra-ice-processing technology must exist")
    assert.is_true(tech.valid, "the tech must load (its icon is present)")

    local unlocked = {}
    for _, effect in pairs(tech.effects) do
      if effect.type == "unlock-recipe" then unlocked[effect.recipe] = true end
    end
    assert.is_true(unlocked[CRUSHER], "the tech unlocks the crusher build recipe")
    assert.is_true(unlocked[R_WATER], "the tech unlocks the water recipe")
    assert.is_true(unlocked[R_CALCITE], "the tech unlocks the water+calcite recipe")

    assert.is_not_nil(tech.prerequisites["planet-discovery-cindra"],
      "ice processing is gated behind discovering Cindra")
  end)

  it("minable ice yields ice chunks that the crusher accepts (closed loop, §15 v2 item 8)", function()
    -- The nightside ice field is MINABLE and drops the vanilla `ice` item (Space
    -- Age's chunk-of-ice raw). The crusher's recipes consume exactly that item, so
    -- mining -> crushing -> water is one unbroken chain.
    local ore = prototypes.entity["cindra-ice"]
    assert.is_not_nil(ore, "the cindra-ice resource must exist")
    assert.are.equal("resource", ore.type, "it is a mineable resource")
    local mine = ore.mineable_properties
    assert.is_not_nil(mine, "the ice resource must be mineable")
    assert.is_true(mine.minable, "the ice field can be mined")
    local yields_ice = false
    for _, p in pairs(mine.products or {}) do
      if p.name == "ice" then yields_ice = true end
    end
    assert.is_true(yields_ice, "mining the ice field yields the `ice` chunk item")

    -- And that item is exactly what the crusher consumes.
    assert.is_true((ingredients(R_WATER)["ice"] or 0) > 0, "the water recipe crushes ice chunks")
    assert.is_true((ingredients(R_CALCITE)["ice"] or 0) > 0, "the calcite recipe crushes ice chunks")
  end)

  it("crushes ice into water on Cindra when powered (end-to-end runtime)", function()
    local s = H.cindra_surface()
    -- A cheat power source + a substation so the crusher shares an electric
    -- network and can actually run headless (a pole's supply area auto-connects
    -- every entity standing in it).
    local pole = s.create_entity({ name = "substation", position = { 2, 2 }, force = "player" })
    assert.is_not_nil(pole, "substation must place")
    local power = s.create_entity({
      name = "electric-energy-interface", position = { 4, 0 }, force = "player",
    })
    -- These runtime setters take numbers (W / J), not "10MW" strings.
    power.power_production = 10000000
    power.electric_buffer_size = 10000000
    power.energy = 10000000

    -- The recipe is research-gated; enable it for the force so the machine will
    -- craft it headlessly (equivalent to having researched cindra-ice-processing).
    game.forces["player"].recipes[R_WATER].enabled = true

    local crusher = s.create_entity({ name = CRUSHER, position = { 0, 0 }, force = "player" })
    crusher.set_recipe(R_WATER)
    crusher.insert({ name = "ice", count = 50 })

    async(1200)
    after_ticks(600, function()
      assert.is_true(crusher.valid)
      local water = crusher.get_fluid_count("water")
      assert.is_true(water > 0,
        "the crusher must have produced water from ice after running (got " .. water
          .. ", ice left " .. crusher.get_item_count("ice") .. ")")
      pole.destroy()
      power.destroy()
      crusher.destroy()
      done()
    end)
  end)
end)
