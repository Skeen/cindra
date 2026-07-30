-- Proof: Cindra ice processing after the mixed-yield rework (ci-9l6). Mining an
-- ice field yields a FIXED MIX of `ice` + `calcite` in one action (a multi-product
-- resource, see resources.lua) -- calcite is a native mined resource now, there is
-- no feedstock chunk and NO ground crusher. The only processing step left is the
-- MELT, which reuses the vanilla `ice-melting` recipe in the vanilla chemical plant
-- (ci-3mx: reuse vanilla, no custom item/melter/tech). This suite proves:
--   * the ice field mines the fixed ice+calcite mix (ice-majority), and a drill
--     placed on it targets the resource;
--   * `ice` melts to `water` in a vanilla chemical plant on the Cindra surface;
--   * the ci-8n6 economy exploit stays closed BY CONSTRUCTION (no ground crusher,
--     no oxide chunk mined on Cindra -> no free iron/carbon/coal path);
--   * all the retired crusher/oxide-chunk content is gone;
--   * the vanilla prototypes are never mutated.

local H = require("tests.helpers")

local ICE_FIELD = "cindra-ice"
local R_MELT = "ice-melting"
local V_OXIDE = "oxide-asteroid-crushing"          -- vanilla source (untouched, space-only)
local V_OXIDE_ADV = "advanced-oxide-asteroid-crushing"

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

describe("cindra ice processing: the ice field mines a fixed ice+calcite mix (ci-9l6)", function()
  it("mining the ice field yields BOTH ice and calcite, ice-majority, no chunk", function()
    local field = prototypes.entity[ICE_FIELD]
    assert.is_not_nil(field, "the cindra-ice field resource must exist")
    assert.are.equal("resource", field.type, "it is a minable resource")
    local amt = {}
    for _, p in ipairs(field.mineable_properties.products) do
      amt[p.name] = (p.amount or p.amount_max or 1)
    end
    assert.is_true((amt["ice"] or 0) > 0, "mining yields ice")
    assert.is_true((amt["calcite"] or 0) > 0, "mining ALSO yields calcite (the fixed mix)")
    assert.are.equal(2, #field.mineable_properties.products,
      "the ice field yields exactly the ice+calcite mix (no oxide chunk any more)")
    assert.is_true(amt["ice"] > amt["calcite"],
      "ice is the MAJORITY product so the many ice sinks are never starved (ice "
        .. amt["ice"] .. " > calcite " .. amt["calcite"] .. ")")
    assert.is_nil(amt["oxide-asteroid-chunk"], "the field no longer drops the oxide chunk")
  end)

  it("a powered drill on the field mines BOTH ice and calcite into one output (ci-9l6)", function()
    -- The load-bearing runtime proof: a real electric mining drill sitting on the
    -- ice field produces the FIXED MIX -- both products land in the same output, so
    -- the player must sort them and a backed-up output stalls the drill (the puzzle).
    local s = H.cindra_surface()
    local res = s.create_entity({ name = ICE_FIELD, position = { 0, 0 }, amount = 1000000 })
    assert.is_not_nil(res, "the ice field resource must place on Cindra")

    local pole = s.create_entity({ name = "substation", position = { 3, 3 }, force = "player" })
    local power = s.create_entity({ name = "electric-energy-interface", position = { 5, 3 }, force = "player" })
    power.power_production = 10000000
    power.electric_buffer_size = 10000000
    power.energy = 10000000

    local drill = s.create_entity({ name = "electric-mining-drill", position = { 0, 0 }, force = "player" })
    assert.is_not_nil(drill, "an electric mining drill must place over the ice field")
    -- Collect the drop in a chest at the drill's own drop position, so both mined
    -- products flow into one inventory (the mixed-output stream).
    local chest = s.create_entity({ name = "steel-chest", position = drill.drop_position, force = "player" })
    assert.is_not_nil(chest, "a collecting chest must place at the drill's drop position")

    async(2400)
    after_ticks(1200, function()
      assert.is_true(chest.valid)
      local ice = chest.get_item_count("ice")
      local calcite = chest.get_item_count("calcite")
      assert.is_true(ice > 0,
        "mining the ice field must deposit ice (got " .. ice .. ", calcite " .. calcite .. ")")
      assert.is_true(calcite > 0,
        "mining the ice field must ALSO deposit calcite -- the fixed mix (got calcite " .. calcite
          .. ", ice " .. ice .. ")")
      chest.destroy()
      drill.destroy()
      power.destroy()
      pole.destroy()
      res.destroy()
      done()
    end)
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
    local s = H.cindra_surface()
    local e = s.create_entity({ name = "chemical-plant", position = { 6, 6 }, force = "player" })
    assert.is_not_nil(e, "the chemical plant must be placeable on Cindra")
    e.destroy()
  end)

  it("planet-discovery-cindra unlocks the vanilla melt (and nothing crusher-shaped)", function()
    local tech = prototypes.technology["planet-discovery-cindra"]
    assert.is_not_nil(tech, "the Cindra discovery tech must exist")
    local unlocked = {}
    for _, effect in pairs(tech.effects) do
      if effect.type == "unlock-recipe" then unlocked[effect.recipe] = true end
    end
    assert.is_true(unlocked[R_MELT], "discovery unlocks the vanilla ice-melting (ice -> water)")
    -- The retired crusher chain is NOT unlocked (it no longer exists).
    assert.is_nil(unlocked["cindra-ice-crusher"], "no crusher build unlock survives")
    assert.is_nil(unlocked["cindra-oxide-asteroid-crushing"], "no Cindra oxide crush unlock survives")
    assert.is_nil(unlocked["cindra-advanced-oxide-asteroid-crushing"], "no Cindra advanced oxide crush unlock survives")
    -- The vanilla oxide recipes are NOT unlocked by discovery -- they stay for space
    -- platforms only, so we never quietly re-expose the vanilla crushing category.
    assert.is_nil(unlocked[V_OXIDE], "discovery does NOT unlock the vanilla oxide crushing")
    assert.is_nil(unlocked[V_OXIDE_ADV], "discovery does NOT unlock the vanilla advanced oxide crushing")
  end)
end)

describe("cindra ice processing: the retired crusher/chunk content is gone (ci-9l6)", function()
  it("has NO ground crusher entity, item, or build recipe", function()
    assert.is_nil(prototypes.entity["cindra-ice-crusher"], "the ground crusher entity must be gone")
    assert.is_nil(prototypes.item["cindra-ice-crusher"], "the ground crusher item must be gone")
    assert.is_nil(prototypes.recipe["cindra-ice-crusher"], "the ground crusher build recipe must be gone")
  end)

  it("has NO Cindra oxide crushing recipes and no cindra-crushing category", function()
    assert.is_nil(prototypes.recipe["cindra-oxide-asteroid-crushing"], "the Cindra plain crush recipe must be gone")
    assert.is_nil(prototypes.recipe["cindra-advanced-oxide-asteroid-crushing"], "the Cindra advanced crush recipe must be gone")
    if prototypes.recipe_category then
      assert.is_nil(prototypes.recipe_category["cindra-crushing"], "the dedicated cindra-crushing category must be gone")
    end
  end)

  it("has NO custom ice item / melter / crushed-ice intermediate / ice tech (ci-3mx still holds)", function()
    assert.is_nil(prototypes.entity["cindra-ice-melter"], "no custom ice-melter entity")
    assert.is_nil(prototypes.item["cindra-ice-melter"], "no custom ice-melter item")
    assert.is_nil(prototypes.item["cindra-crushed-ice"], "no custom crushed-ice item")
    for _, name in ipairs({ "cindra-ice-crushing", "cindra-ice-melting", "cindra-ice-melter" }) do
      assert.is_nil(prototypes.recipe[name], name .. " recipe must not exist")
    end
    assert.is_nil(prototypes.technology["cindra-ice-processing"], "no equivalent ice-processing tech")
  end)
end)

describe("cindra ice processing: the ci-8n6 economy exploit is closed BY CONSTRUCTION (ci-9l6)", function()
  -- The old exploit: a ground crusher running the vanilla `crushing` category could
  -- reprocess the ice field's oxide chunks into metallic/carbonic chunks and crush
  -- those into FREE iron and FREE carbon/coal, bypassing the power-manufactured,
  -- petrochemical-free economy. ci-9l6 removed BOTH halves of that path: there is no
  -- ground crusher, and no oxide chunk is mined on Cindra. Prove neither can return.

  it("no CINDRA machine runs the vanilla `crushing` category (only the space crusher does)", function()
    for name, proto in pairs(prototypes.entity) do
      local cats = proto.crafting_categories
      if cats and cats["crushing"] then
        assert.are.equal("crusher", name,
          "only the vanilla space crusher may run `crushing`; found extra machine '" .. name .. "'")
      end
    end
  end)

  it("no Cindra ground resource yields ANY asteroid chunk (no feedstock for the exploit)", function()
    -- Every product minable from a Cindra resource or Cindra rock.
    local mined = {}
    for name, proto in pairs(prototypes.entity) do
      if name:sub(1, 7) == "cindra-" and (proto.type == "resource" or proto.type == "simple-entity") then
        local mp = proto.mineable_properties
        if mp and mp.minable and mp.products then
          for _, p in ipairs(mp.products) do mined[p.name] = true end
        end
      end
    end
    for _, chunk in ipairs({ "oxide-asteroid-chunk", "metallic-asteroid-chunk", "carbonic-asteroid-chunk" }) do
      assert.is_nil(mined[chunk],
        "no Cindra ground resource may yield '" .. chunk .. "' -- it would feed the crushing exploit")
    end
    -- Sanity: the ice field DOES yield the intended pair.
    assert.is_true(mined["ice"] and mined["calcite"], "the ice field still yields the intended ice+calcite")
  end)
end)

describe("cindra ice processing: never mutates the vanilla prototypes (DESIGN §6)", function()
  it("the vanilla crusher + chemical plant + oxide recipes are unchanged (we reuse, never edit vanilla)", function()
    local vanilla_crusher = prototypes.entity["crusher"]
    assert.is_not_nil(vanilla_crusher, "the vanilla space crusher must still exist")
    assert.is_true(vanilla_crusher.crafting_categories["crushing"],
      "the vanilla space crusher still crafts vanilla crushing recipes")

    local vanilla_plant = prototypes.entity["chemical-plant"]
    assert.is_true(vanilla_plant.crafting_categories["chemistry"],
      "the vanilla chemical plant still crafts vanilla chemistry recipes")
    assert.is_true((ingredients(R_MELT)["ice"] or 0) > 0, "vanilla ice-melting still consumes ice")

    -- The vanilla oxide crushing recipes are untouched: they still exist, still
    -- yield ice, and still live in the vanilla `crushing` category for the space
    -- crusher. (We no longer clone them at all.)
    assert.is_not_nil(prototypes.recipe[V_OXIDE], "vanilla oxide-asteroid-crushing still exists")
    assert.is_not_nil(prototypes.recipe[V_OXIDE_ADV], "vanilla advanced-oxide-asteroid-crushing still exists")
    assert.is_true(in_category(V_OXIDE, "crushing"), "vanilla oxide crushing stays in the vanilla category")
    assert.is_true(in_category(V_OXIDE_ADV, "crushing"), "vanilla advanced oxide crushing stays in the vanilla category")
    assert.is_true((products(V_OXIDE)["ice"] or 0) > 0, "vanilla oxide crushing still yields ice")
  end)
end)

describe("cindra ice processing: end-to-end melt on Cindra (ice -> water)", function()
  it("melts ice into water in a chemical plant on the Cindra surface", function()
    local s = H.cindra_surface()
    local pole = s.create_entity({ name = "substation", position = { 2, 2 }, force = "player" })
    assert.is_not_nil(pole, "substation must place")
    local power = s.create_entity({
      name = "electric-energy-interface", position = { 4, 0 }, force = "player",
    })
    power.power_production = 10000000
    power.electric_buffer_size = 10000000
    power.energy = 10000000

    -- The melt is research-gated; enable it for the force so the plant crafts
    -- headlessly (equivalent to having researched planet-discovery-cindra).
    game.forces["player"].recipes[R_MELT].enabled = true

    local plant = s.create_entity({ name = "chemical-plant", position = { -4, 0 }, force = "player" })
    plant.set_recipe(R_MELT)
    -- The `ice` now comes straight off the mixed ice field (a mining yield); feed a
    -- stack in directly, exactly as a belt from the sorted drill output would.
    plant.insert({ name = "ice", count = 50 })

    async(2400)
    after_ticks(1200, function()
      assert.is_true(plant.valid)
      local water = plant.get_fluid_count("water")
      assert.is_true(water > 0,
        "the chemical plant must have produced water from ice (got " .. water
          .. ", ice left " .. plant.get_item_count("ice") .. ")")
      pole.destroy()
      power.destroy()
      plant.destroy()
      done()
    end)
  end)
end)
