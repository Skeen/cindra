-- Proof: Cindra ice processing REUSES vanilla recipes end-to-end (ci-3mx). The
-- user was explicit -- "ice crushing should just be oxide asteroid crushing" and
-- "the existing ice melting in the chemical plant", and "stop adding equivalent
-- technologies". So:
--   * the nightside deposit yields the VANILLA `oxide-asteroid-chunk`,
--   * a ground-standing custom crusher (the vanilla crusher is zero-gravity-gated,
--     so it cannot stand on Cindra; DESIGN.md §6 forbids re-scoping vanilla) runs
--     the SAME vanilla `crushing` recipes -> ice (+ calcite),
--   * the vanilla CHEMICAL PLANT runs the vanilla `ice-melting` recipe -> water,
--   * NO custom ice item, crush/melt recipe, ice-melter machine, or ice tech.
-- The whole chain is unlocked by the existing planet-discovery-cindra tech.

local H = require("tests.helpers")

local CRUSHER = "cindra-ice-crusher"
local R_OXIDE = "oxide-asteroid-crushing"
local R_OXIDE_ADV = "advanced-oxide-asteroid-crushing"
local R_MELT = "ice-melting"
local R_VOLATILES = "cindra-volatiles"
local CHUNK = "oxide-asteroid-chunk"
local VOLATILES = "cindra-volatiles"

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

describe("cindra ice processing: no custom duplicates survive (ci-3mx)", function()
  it("has NO custom ice-melter entity or item", function()
    assert.is_nil(prototypes.entity["cindra-ice-melter"], "the custom ice-melter entity must be gone")
    assert.is_nil(prototypes.item["cindra-ice-melter"], "the custom ice-melter item must be gone")
  end)

  it("has NO custom crush/melt recipes and no crushed-ice intermediate", function()
    for _, name in ipairs({ "cindra-ice-crushing", "cindra-ice-crushing-calcite", "cindra-ice-melting", "cindra-ice-melter" }) do
      assert.is_nil(prototypes.recipe[name], name .. " recipe must be gone (reuse vanilla)")
    end
    assert.is_nil(prototypes.item["cindra-crushed-ice"], "the custom crushed-ice item must be gone")
  end)

  it("has NO private ice recipe categories", function()
    -- The old design isolated crush/melt in private categories; reuse-vanilla drops them.
    if prototypes.recipe_category then
      assert.is_nil(prototypes.recipe_category["cindra-ice-crushing"], "no private ice-crushing category")
      assert.is_nil(prototypes.recipe_category["cindra-ice-melting"], "no private ice-melting category")
    end
  end)

  it("has NO equivalent ice technology (the chain hangs off Cindra discovery)", function()
    assert.is_nil(prototypes.technology["cindra-ice-processing"],
      "the equivalent ice-processing tech must be gone (stop adding equivalent technologies)")
  end)
end)

describe("cindra ice processing: the crusher reuses the vanilla crushing recipes", function()
  it("the crusher crafts in the VANILLA crushing category (same recipes as the space crusher)", function()
    local proto = prototypes.entity[CRUSHER]
    assert.is_not_nil(proto, "cindra-ice-crusher entity must exist")
    assert.are.equal("assembling-machine", proto.type, "it is a crafting machine (crusher)")
    assert.is_true(proto.crafting_categories["crushing"],
      "the crusher must run the vanilla `crushing` recipes (reuse-vanilla, not a private category)")
  end)

  it("is placeable on Cindra's heavy-gravity ground (the space-only gate is gone)", function()
    local s = H.cindra_surface()
    local e = s.create_entity({ name = CRUSHER, position = { 0, 0 }, force = "player" })
    assert.is_not_nil(e, "the ice crusher must be placeable on Cindra")
    assert.is_true(e.valid)
    assert.are.equal("assembling-machine", e.type)
    e.destroy()
  end)

  it("crush = the vanilla oxide asteroid crushing: chunk -> ice, and chunk -> ice + calcite (the ratio knob)", function()
    local plain = prototypes.recipe[R_OXIDE]
    local adv = prototypes.recipe[R_OXIDE_ADV]
    assert.is_not_nil(plain, "vanilla oxide-asteroid-crushing must exist")
    assert.is_not_nil(adv, "vanilla advanced-oxide-asteroid-crushing must exist")

    -- Both are vanilla `crushing` recipes and consume the deposit's chunk.
    assert.is_true(in_category(R_OXIDE, "crushing"), "plain crush is a vanilla crushing recipe")
    assert.is_true(in_category(R_OXIDE_ADV, "crushing"), "advanced crush is a vanilla crushing recipe")
    assert.is_true((ingredients(R_OXIDE)[CHUNK] or 0) > 0, "plain crush consumes the oxide chunk")
    assert.is_true((ingredients(R_OXIDE_ADV)[CHUNK] or 0) > 0, "advanced crush consumes the oxide chunk")

    -- Plain yields ice only; advanced trades some ice for calcite -- the calcite the
    -- aluminium refine + science pack need, sourced from the ice chain (ci-3mx).
    assert.is_true((products(R_OXIDE)["ice"] or 0) > 0, "plain crush yields ice")
    assert.is_nil(products(R_OXIDE)["calcite"], "plain crush yields no calcite (all matter -> ice)")
    assert.is_true((products(R_OXIDE_ADV)["ice"] or 0) > 0, "advanced crush still yields ice")
    assert.is_true((products(R_OXIDE_ADV)["calcite"] or 0) > 0, "advanced crush also yields calcite")
    assert.is_true(products(R_OXIDE_ADV)["ice"] < products(R_OXIDE)["ice"],
      "advanced yields FEWER ice than plain (matter diverted to calcite) -- the ratio knob")
  end)
end)

describe("cindra ice processing: melting reuses the vanilla chemical-plant recipe", function()
  it("ice melts via the VANILLA ice-melting recipe (chemistry category): ice -> water", function()
    local recipe = prototypes.recipe[R_MELT]
    assert.is_not_nil(recipe, "the vanilla ice-melting recipe must exist")
    assert.is_true(in_category(R_MELT, "chemistry"), "ice-melting is a vanilla chemistry (chemical-plant) recipe")
    assert.is_true((ingredients(R_MELT)["ice"] or 0) > 0, "it consumes ice")
    assert.is_true((products(R_MELT)["water"] or 0) > 0, "it produces water (a fluid)")
  end)

  it("the vanilla chemical plant runs it and stands on any gravity (no custom melter needed)", function()
    local plant = prototypes.entity["chemical-plant"]
    assert.is_not_nil(plant, "the vanilla chemical plant must exist")
    assert.is_true(plant.crafting_categories["chemistry"], "the chemical plant crafts chemistry recipes")
    -- It is placeable on Cindra (no zero-gravity gate, unlike the crusher).
    local s = H.cindra_surface()
    local e = s.create_entity({ name = "chemical-plant", position = { 6, 6 }, force = "player" })
    assert.is_not_nil(e, "the chemical plant must be placeable on Cindra")
    e.destroy()
  end)
end)

describe("cindra ice processing: the nightside deposit + tech unlock", function()
  it("the nightside ice deposit yields the vanilla oxide-asteroid-chunk (crusher feedstock)", function()
    local res = prototypes.entity["cindra-ice"]
    assert.is_not_nil(res, "the cindra-ice deposit must exist")
    assert.are.equal("resource", res.type, "it is a minable resource")
    assert.are.equal(CHUNK, res.mineable_properties.products[1].name,
      "the ice field must yield the vanilla oxide-asteroid-chunk (feeds vanilla crushing)")
  end)

  it("planet-discovery-cindra unlocks the crusher build + the vanilla crush/melt recipes (no new tech)", function()
    local tech = prototypes.technology["planet-discovery-cindra"]
    assert.is_not_nil(tech, "the Cindra discovery tech must exist")
    local unlocked = {}
    for _, effect in pairs(tech.effects) do
      if effect.type == "unlock-recipe" then unlocked[effect.recipe] = true end
    end
    assert.is_true(unlocked[CRUSHER], "discovery unlocks the ground crusher build recipe")
    assert.is_true(unlocked[R_OXIDE], "discovery unlocks the vanilla oxide crushing")
    assert.is_true(unlocked[R_OXIDE_ADV], "discovery unlocks the vanilla advanced oxide crushing (calcite)")
    assert.is_true(unlocked[R_MELT], "discovery unlocks the vanilla ice-melting")
  end)

  it("the crusher build recipe is gated (unlocked by research, not free)", function()
    local recipe = prototypes.recipe[CRUSHER]
    assert.is_not_nil(recipe, "the crusher build recipe must exist")
    assert.is_false(recipe.enabled, "the crusher build is unlocked by research, not free")
    local item = prototypes.item[CRUSHER]
    assert.is_not_nil(item, "the crusher item must exist")
    assert.are.equal(CRUSHER, item.place_result.name, "the item places the crusher")
  end)
end)

describe("cindra volatiles: a PROCESSING recipe on the crusher, not a mining yield (ci-4xx)", function()
  it("the volatiles recipe is a crushing recipe: oxide chunk -> cindra-volatiles", function()
    local r = prototypes.recipe[R_VOLATILES]
    assert.is_not_nil(r, "the cindra-volatiles processing recipe must exist")
    assert.is_true(in_category(R_VOLATILES, "crushing"),
      "it must be a `crushing` recipe so the ground crusher runs it (reuse the ice crusher)")
    assert.is_true((ingredients(R_VOLATILES)[CHUNK] or 0) > 0,
      "it consumes the deep-nightside oxide chunk (the field's only yield now)")
    assert.is_true((products(R_VOLATILES)[VOLATILES] or 0) > 0,
      "it produces the frozen volatiles the science pack needs")
  end)

  it("the crusher can run it (the volatiles recipe is in the crusher's crafting categories)", function()
    assert.is_true(prototypes.entity[CRUSHER].crafting_categories["crushing"],
      "the ice crusher crafts `crushing` recipes, so it runs the volatiles extraction too")
  end)

  it("planet-discovery-cindra unlocks the volatiles recipe (reachable with the rest of the chain)", function()
    local tech = prototypes.technology["planet-discovery-cindra"]
    local unlocked = {}
    for _, effect in pairs(tech.effects) do
      if effect.type == "unlock-recipe" then unlocked[effect.recipe] = true end
    end
    assert.is_true(unlocked[R_VOLATILES],
      "discovery unlocks the volatiles processing recipe (no chicken-and-egg for the science pack)")
    assert.is_false(prototypes.recipe[R_VOLATILES].enabled,
      "the volatiles recipe is unlocked by research, not free")
  end)

  it("end-to-end: the Cindra crusher turns chunks into volatiles (runtime)", function()
    local s = H.cindra_surface()
    s.create_entity({ name = "substation", position = { 2, 2 }, force = "player" })
    local power = s.create_entity({
      name = "electric-energy-interface", position = { 4, 0 }, force = "player",
    })
    power.power_production = 10000000
    power.electric_buffer_size = 10000000
    power.energy = 10000000

    game.forces["player"].recipes[R_VOLATILES].enabled = true

    local crusher = s.create_entity({ name = CRUSHER, position = { 0, 0 }, force = "player" })
    crusher.set_recipe(R_VOLATILES)
    crusher.insert({ name = CHUNK, count = 10 })

    async(2400)
    after_ticks(900, function()
      assert.is_true(crusher.valid)
      local vol = crusher.get_item_count(VOLATILES)
      assert.is_true(vol > 0,
        "the crusher must have produced volatiles from oxide chunks (got " .. vol
          .. ", chunks left " .. crusher.get_item_count(CHUNK) .. ")")
      power.destroy()
      crusher.destroy()
      done()
    end)
  end)
end)

describe("cindra ice processing: never mutates the vanilla prototypes (DESIGN §6)", function()
  it("the vanilla crusher + chemical plant are unchanged (we clone, never edit vanilla)", function()
    local vanilla_crusher = prototypes.entity["crusher"]
    assert.is_true(vanilla_crusher.crafting_categories["crushing"],
      "the vanilla space crusher still crafts vanilla crushing recipes")

    local vanilla_plant = prototypes.entity["chemical-plant"]
    assert.is_true(vanilla_plant.crafting_categories["chemistry"],
      "the vanilla chemical plant still crafts vanilla chemistry recipes")

    -- The reused recipes keep their vanilla shape (we only reference them in a tech
    -- unlock; we never edit ingredients/products/category).
    assert.is_true((ingredients(R_MELT)["ice"] or 0) > 0, "vanilla ice-melting still consumes ice")
    assert.is_true((products(R_OXIDE)["ice"] or 0) > 0, "vanilla oxide crushing still yields ice")
  end)
end)

describe("cindra ice processing: end-to-end on Cindra (crush chunk -> ice, melt ice -> water)", function()
  it("crushes chunks into ice on the Cindra crusher, then melts ice into water in a chemical plant", function()
    local s = H.cindra_surface()
    -- A cheat power source + a substation so both machines share an electric
    -- network and can actually run headless.
    local pole = s.create_entity({ name = "substation", position = { 2, 2 }, force = "player" })
    assert.is_not_nil(pole, "substation must place")
    local power = s.create_entity({
      name = "electric-energy-interface", position = { 4, 0 }, force = "player",
    })
    power.power_production = 10000000
    power.electric_buffer_size = 10000000
    power.energy = 10000000

    -- The recipes are research-gated; enable them for the force so the machines
    -- craft headlessly (equivalent to having researched planet-discovery-cindra).
    game.forces["player"].recipes[R_OXIDE].enabled = true
    game.forces["player"].recipes[R_MELT].enabled = true

    local crusher = s.create_entity({ name = CRUSHER, position = { 0, 0 }, force = "player" })
    crusher.set_recipe(R_OXIDE)
    crusher.insert({ name = CHUNK, count = 10 })

    local plant = s.create_entity({ name = "chemical-plant", position = { -4, 0 }, force = "player" })
    plant.set_recipe(R_MELT)

    async(2400)
    after_ticks(600, function()
      assert.is_true(crusher.valid)
      -- Stage 1: the crusher turned chunks into ice (the vanilla oxide crushing).
      local ice = crusher.get_item_count("ice")
      assert.is_true(ice > 0,
        "the crusher must have produced ice from oxide chunks (got " .. ice
          .. ", chunks left " .. crusher.get_item_count(CHUNK) .. ")")

      -- Feed the ice to the chemical plant and let it melt.
      local moved = crusher.remove_item({ name = "ice", count = ice })
      plant.insert({ name = "ice", count = moved })

      after_ticks(1200, function()
        assert.is_true(plant.valid)
        -- Stage 2: the chemical plant melted the ice into water (the vanilla recipe).
        local water = plant.get_fluid_count("water")
        assert.is_true(water > 0,
          "the chemical plant must have produced water from ice (got " .. water
            .. ", ice left " .. plant.get_item_count("ice") .. ")")
        pole.destroy()
        power.destroy()
        crusher.destroy()
        plant.destroy()
        done()
      end)
    end)
  end)
end)
