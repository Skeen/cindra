-- Proof: the start-on-Cindra foundry bootstrap (ci-arw). Normal Cindra play
-- IMPORTS foundries from Vulcanus (the vanilla `foundry` recipe is pressure-gated
-- to Vulcanus AND needs oil lubricant, neither available here). A start-on-Cindra
-- player (any-planet-start) has no Vulcanus and no petrochemistry, so without a
-- native path they SOFT-LOCK. This suite proves the native path exists, is
-- Cindra-buildable, is gated so normal imported play is untouched, and that the
-- bootstrap coal it leans on is finite.
--
-- The APS-only half (the pre-research that hands a from-scratch start this path
-- from tick zero) is proven in tests/test_aps_foundry.lua, which runs only in the
-- APS invocation. Everything here is surface/prototype truth that holds in the
-- plain `mods/cindra` run.

local H = require("tests.helpers")

local T_METALLURGY = "cindra-improvised-metallurgy"
local R_CRUDE = "cindra-crude-lubricant"
local R_MINERAL = "cindra-mineral-lubricant"
local R_FIELD_FOUNDRY = "cindra-field-foundry"

local function ingredients(recipe)
  local out = {}
  for _, i in pairs(prototypes.recipe[recipe].ingredients) do
    out[i.name] = (out[i.name] or 0) + (i.amount or 0)
  end
  return out
end

local function products(recipe)
  local out = {}
  for _, p in pairs(prototypes.recipe[recipe].products) do
    out[p.name] = (out[p.name] or 0) + (p.amount or 0)
  end
  return out
end

-- LuaRecipePrototype.categories is a dictionary {name -> true}; membership test
-- that also tolerates an array form (mirrors test_ice_processing).
local function in_category(recipe, category)
  local cats = prototypes.recipe[recipe].categories
  if cats[category] then return true end
  for _, v in pairs(cats) do
    if v == category then return true end
  end
  return false
end

-- The pressure surface condition the vanilla foundry recipe carries (Vulcanus).
local function pressure_condition(recipe_proto)
  if not recipe_proto.surface_conditions then return nil end
  for _, c in pairs(recipe_proto.surface_conditions) do
    if c.property == "pressure" then return c end
  end
  return nil
end

local field = require("scripts.resource-field")

describe("cindra start-on-Cindra foundry bootstrap", function()
  -- --- The finite bootstrap coal (ci-18n: now the VOLCANIC rocks, not the sandy) --
  it("puts a small, FINITE coal trickle in the hand-mined VOLCANIC rocks (ci-18n)", function()
    -- ci-18n moved coal OFF the temperate/sandy rock onto the volcanic rocks in the
    -- lava region. The sandy rock must NO LONGER drop coal...
    local sandy = prototypes.entity["cindra-rock"]
    assert.is_not_nil(sandy, "the sandy bootstrap rock must exist")
    for _, r in pairs(sandy.mineable_properties.products) do
      assert.are_not.equal("coal", r.name,
        "the sandy rock must NOT drop coal any more -- coal is the volcanic rocks' (ci-18n)")
    end
    -- ...and each VOLCANIC rock must drop a small, finite coal trickle (the lubricant
    -- feedstock). Small: a landing trickle, not a windfall -- guards against a fat
    -- coal drop turning the finite rocks into an effectively-infinite coal supply.
    for _, name in ipairs(field.burned_rock_names()) do
      local rock = prototypes.entity[name]
      assert.is_not_nil(rock, name .. " must exist")
      local coal
      for _, r in pairs(rock.mineable_properties.products) do
        if r.name == "coal" then coal = r end
      end
      assert.is_not_nil(coal, "mining a volcanic rock must drop some coal (" .. name .. ")")
      assert.is_true((coal.amount_max or coal.amount) <= 10,
        "the coal drop must stay small (<=10); it is a one-time bootstrap, not a supply (" .. name .. ")")
    end
  end)

  it("has NO mineable/permanent coal source: coal can never scale", function()
    -- The soft-lock rescue must not become an exploit. Coal comes ONLY from the
    -- destroyed-on-mining bootstrap rocks; there is no coal resource patch to
    -- drill, so the coal->lubricant step is inherently a one-time bootstrap (§6).
    assert.is_nil(prototypes.entity["cindra-coal"], "there must be no cindra-coal resource")
    for name, res in pairs(prototypes.get_entity_filtered({ { filter = "type", type = "resource" } })) do
      if name:match("^cindra%-") then
        local mp = res.mineable_properties
        if mp and mp.products then
          for _, p in pairs(mp.products) do
            assert.are_not.equal("coal", p.name,
              "no Cindra resource may yield coal (only the finite rocks do): " .. name)
          end
        end
      end
    end
  end)

  -- --- The native lubricant recipes ---------------------------------------
  it("crude lubricant: finite coal -> lubricant, gated off by default (the bootstrap tier)", function()
    local recipe = prototypes.recipe[R_CRUDE]
    assert.is_not_nil(recipe, R_CRUDE .. " recipe must exist")
    assert.is_false(recipe.enabled, "gated: research unlocks it, never free")
    assert.is_true((ingredients(R_CRUDE)["coal"] or 0) > 0, "it consumes coal (the finite bootstrap feedstock)")
    assert.is_true((products(R_CRUDE)["lubricant"] or 0) > 0, "it produces lubricant (feeds the foundry recipe)")
    assert.is_false(recipe.allowed_effects and recipe.allowed_effects.productivity or false,
      "no productivity: finite coal must not be minted into free lubricant")
  end)

  it("mineral lubricant: renewable stone(+water) -> lubricant, deliberately effortful (the sustain tier)", function()
    local recipe = prototypes.recipe[R_MINERAL]
    assert.is_not_nil(recipe, R_MINERAL .. " recipe must exist")
    assert.is_false(recipe.enabled, "gated: research unlocks it, never free")

    -- Renewable: its inputs are things Cindra mines/makes forever (stone is a
    -- mineable resource, water comes from ice processing), unlike the finite coal.
    local ing = ingredients(R_MINERAL)
    assert.is_true((ing["stone"] or 0) > 0, "it is worked from stone (renewable, 'from rock')")
    assert.is_true((products(R_MINERAL)["lubricant"] or 0) > 0, "it produces lubricant")

    -- Petrochemical-free: no oil-chain input sneaks in.
    for name in pairs(ing) do
      assert.are_not.equal("crude-oil", name, "the native lubricant must be petrochemical-free")
      assert.are_not.equal("heavy-oil", name, "the native lubricant must be petrochemical-free")
      assert.are_not.equal("petroleum-gas", name, "the native lubricant must be petrochemical-free")
    end

    -- Situational-not-strictly-better (§12): the native path must cost MORE per
    -- lubricant than vanilla oil lubricant (10 heavy-oil -> 10 lubricant), so a
    -- player with oil never prefers it. Compare stone-per-lubricant > 1:1.
    assert.is_true((ing["stone"] or 0) / (products(R_MINERAL)["lubricant"]) >= 1,
      "the mineral path must be effortful (>= 1 stone per lubricant), never a free substitute")
  end)

  -- --- The Cindra-buildable foundry recipe --------------------------------
  it("field foundry: a Cindra-buildable recipe that yields the vanilla foundry item", function()
    local recipe = prototypes.recipe[R_FIELD_FOUNDRY]
    assert.is_not_nil(recipe, R_FIELD_FOUNDRY .. " recipe must exist")
    assert.is_false(recipe.enabled, "gated: research unlocks it, never free")
    assert.are.equal(1, products(R_FIELD_FOUNDRY)["foundry"],
      "it produces the vanilla foundry item (a real foundry, no new machine)")
    -- Uses the native lubricant (the thing this whole feature makes reachable).
    assert.is_true((ingredients(R_FIELD_FOUNDRY)["lubricant"] or 0) > 0,
      "it consumes lubricant -- satisfied natively by the recipes above")
    -- crafting-with-fluid so an ordinary assembler (the start kit's) can build it.
    assert.is_true(in_category(R_FIELD_FOUNDRY, "crafting-with-fluid"),
      "category crafting-with-fluid so a plain assembler can build it before any foundry exists")
  end)

  it("field foundry drops the Vulcanus pressure gate (so it works on Cindra)", function()
    -- The whole point: unlike the vanilla recipe, the field recipe is NOT locked
    -- to pressure = 4000, so it can actually be crafted on Cindra (pressure 500).
    local field = prototypes.recipe[R_FIELD_FOUNDRY]
    assert.is_nil(pressure_condition(field),
      "the field foundry recipe must carry no pressure surface condition")

    -- Contrast: the vanilla recipe still IS pressure-gated (guarded below), so
    -- these two recipes are genuinely different paths, not a mutation.
    local vanilla = prototypes.recipe["foundry"]
    local vp = pressure_condition(vanilla)
    assert.is_not_nil(vp, "sanity: the vanilla foundry recipe is pressure-gated (Vulcanus)")
  end)

  it("is deliberately COSTLIER than the imported recipe (normal play still imports)", function()
    -- Situational-not-strictly-better (§12 / DESIGN §8): a post-Vulcanus player
    -- with real foundries must have no reason to field-build. Prove the field
    -- recipe is strictly heavier on the shared structural inputs.
    local field = ingredients(R_FIELD_FOUNDRY)
    local vanilla = ingredients("foundry")
    assert.is_true(field["steel-plate"] >= vanilla["steel-plate"],
      "field foundry uses at least as much steel as the import recipe")
    assert.is_true(field["lubricant"] > vanilla["lubricant"],
      "field foundry demands MORE lubricant than the import recipe (the effort tax)")
    assert.is_true(prototypes.recipe[R_FIELD_FOUNDRY].energy >= prototypes.recipe["foundry"].energy,
      "field foundry takes at least as long to craft as the import recipe")
  end)

  -- --- Gating -------------------------------------------------------------
  it("gates all three behind ONE Cindra-discovery tech (cindra-improvised-metallurgy)", function()
    local tech = prototypes.technology[T_METALLURGY]
    assert.is_not_nil(tech, "the improvised-metallurgy tech must exist")
    assert.is_true(tech.valid, "the tech must load (its icon is present)")

    local unlocks = {}
    for _, effect in pairs(tech.effects) do
      if effect.type == "unlock-recipe" then unlocks[effect.recipe] = true end
    end
    assert.is_true(unlocks[R_CRUDE], "unlocks crude lubricant")
    assert.is_true(unlocks[R_MINERAL], "unlocks mineral lubricant")
    assert.is_true(unlocks[R_FIELD_FOUNDRY], "unlocks the field foundry")

    assert.is_not_nil(tech.prerequisites["planet-discovery-cindra"],
      "gated behind Cindra discovery -- normal play reaches it only after Vulcanus (§6)")
  end)

  -- --- Never-mutate-other-planets -----------------------------------------
  it("does NOT mutate the vanilla foundry recipe (normal import path intact)", function()
    -- The imported-foundry path (DESIGN §8) must be untouched: the vanilla recipe
    -- keeps its Vulcanus pressure gate and its 20-lubricant oil cost. If a future
    -- change mutated it (leaking onto Vulcanus), this fails first.
    local vanilla = prototypes.recipe["foundry"]
    local vp = pressure_condition(vanilla)
    assert.are.equal(4000, vp.min, "the vanilla foundry recipe still requires pressure 4000 (Vulcanus)")
    assert.are.equal(20, ingredients("foundry")["lubricant"],
      "the vanilla foundry recipe still costs 20 oil lubricant (unmutated)")
  end)

  it("leaks no free foundry into normal play: native recipes stay locked without the tech", function()
    -- A fresh force (no Cindra tech researched) must NOT be able to field-build a
    -- foundry or make native lubricant -- proof nothing is handed out for free.
    -- Scoped to NORMAL play: a start-on-Cindra game pre-researches the tech (that
    -- path is proven in the APS suite), so the leak check does not apply there.
    -- Read-only: never toggles the shared force's recipe state (test isolation).
    local force = game.forces["player"]
    if force.technologies[T_METALLURGY].researched then return end
    assert.is_false(force.recipes[R_FIELD_FOUNDRY].enabled,
      "without the tech the field foundry recipe is not craftable")
    assert.is_false(force.recipes[R_CRUDE].enabled,
      "without the tech crude lubricant is not craftable")
    assert.is_false(force.recipes[R_MINERAL].enabled,
      "without the tech mineral lubricant is not craftable")
  end)

  it("no native foundry path leaks outside the APS start context (normal play, ci-7p6)", function()
    -- ci-7p6 acceptance: the start-on-Cindra rescue (pre-researched improvised
    -- metallurgy + the field foundry) must be scoped to an APS Cindra start and
    -- NEVER leak into a normal game. In the default `mods/cindra` run cindra-start
    -- is not even loaded, so nothing pre-researches the tech -- assert that
    -- POSITIVELY (the sibling leak test only guards conditionally). The APS run
    -- legitimately pre-researches it (proved in test_aps_foundry / test_aps_bootstrap),
    -- so this default-play guard is skipped whenever cindra-start is present.
    if script.active_mods["cindra-start"] then return end
    local force = game.forces["player"]
    assert.is_false(force.technologies[T_METALLURGY].researched,
      "normal play must NOT arrive with improvised metallurgy pre-researched (no free native foundry)")
    assert.is_false(force.recipes[R_FIELD_FOUNDRY].enabled,
      "so the Cindra-buildable field foundry stays locked in normal play -- foundries are imported (§8)")
    assert.is_false(force.recipes[R_CRUDE].enabled,
      "and native lubricant stays locked -- no petrochemical-free foundry shortcut leaks into a normal game")
  end)

  -- --- Runtime: the native path actually works on Cindra ------------------
  it("crude-liquefies bootstrap coal into lubricant on Cindra when powered (end-to-end)", function()
    local s = H.cindra_surface()
    local pole = s.create_entity({ name = "substation", position = { 2, 2 }, force = "player" })
    assert.is_not_nil(pole, "substation must place")
    local power = s.create_entity({ name = "electric-energy-interface", position = { 4, 0 }, force = "player" })
    power.power_production = 10000000
    power.electric_buffer_size = 10000000
    power.energy = 10000000

    game.forces["player"].recipes[R_CRUDE].enabled = true

    -- A chemical plant crafts the crude lubricant (chemistry category). It is
    -- placeable on Cindra (no surface gate) -- part of the native path.
    local plant = s.create_entity({ name = "chemical-plant", position = { 0, 0 }, force = "player" })
    assert.is_not_nil(plant, "a chemical plant must place on Cindra")
    plant.set_recipe(R_CRUDE)
    plant.insert({ name = "coal", count = 50 })

    async(1200)
    after_ticks(600, function()
      assert.is_true(plant.valid)
      local lube = plant.get_fluid_count("lubricant")
      assert.is_true(lube > 0,
        "the plant must have made lubricant from coal (got " .. lube
          .. ", coal left " .. plant.get_item_count("coal") .. ")")
      pole.destroy()
      power.destroy()
      plant.destroy()
      done()
    end)
  end)

  it("an on-Cindra foundry + lava caster reach the lava->metal economy (no soft-lock)", function()
    -- The endpoint of the bootstrap: the lava->molten-metal spine is reachable on
    -- Cindra without Vulcanus. Since ci-e8a the spine is SPLIT -- a dedicated
    -- caster makes lava, the foundry melts it -- so pin both halves: the caster
    -- accepts the lava recipe and the on-Cindra foundry accepts the melt recipe.
    -- (Neither entity has a placement surface condition, so both drop and run
    -- here.) The full traversal is ci-uex's proof; this pins ci-arw's
    -- contribution: an on-Cindra metal economy that feeds itself.
    local s = H.cindra_surface()
    game.forces["player"].recipes["cindra-lava"].enabled = true
    -- ci-9yg: on Cindra the cast is the UNMODIFIED vanilla recipe (vanilla lava in,
    -- vanilla stone byproduct back; the loop is kept net stone-negative by the
    -- nerfed stone->lava ratio, not a Cindra-exclusive cast).
    game.forces["player"].recipes["molten-iron-from-lava"].enabled = true

    local caster = s.create_entity({ name = "cindra-lava-manufacturer", position = { 0, 0 }, force = "player" })
    assert.is_not_nil(caster, "a lava caster must be placeable/obtainable on Cindra")
    caster.set_recipe("cindra-lava")
    assert.are.equal("cindra-lava", caster.get_recipe().name,
      "the on-Cindra caster runs manufactured lava -- the fire spine is reachable")

    local foundry = s.create_entity({ name = "foundry", position = { 8, 0 }, force = "player" })
    assert.is_not_nil(foundry, "a foundry must be placeable/obtainable on Cindra")
    foundry.set_recipe("molten-iron-from-lava")
    assert.are.equal("molten-iron-from-lava", foundry.get_recipe().name,
      "the on-Cindra foundry melts vanilla lava into molten metal -- the metal economy is reachable")

    caster.destroy()
    foundry.destroy()
  end)
end)
