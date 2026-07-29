-- Proof: Cindra's HEADLINE science pack (§15-12; DESIGN.md §2 checklist, §5).
--
-- The bead's MANDATORY assertions, plus the tech-tree fold:
--   1. PETROCHEMICAL-FREE, NATIVE INPUTS ONLY -- no oil/coal/plastic/sulfur/etc.
--      anywhere in the recipe; every ingredient is a Cindra material.
--   2. A REAL ENERGY COST, IN A STOCK MACHINE -- a high crafting-time
--      (energy_required), crafted in an ORDINARY assembling machine (ci-2tz: the
--      bespoke crafting machine is GONE). No bespoke crafting building survives.
--   3. A REAL SCIENCE PACK -- an item a lab will actually accept as research input.
--   4. THE FOLDED TREE -- the pack has a real downstream unlock: orbital launch now
--      branches off `cindra-science` and is researched WITH the Cindra pack.

local H = require("tests.helpers")

local PACK = "cindra-science-pack"
local TECH = "cindra-science"
local ALUMINIUM = "cindra-aluminium"
local VOLATILES = "cindra-volatiles"

-- Anything whose lineage passes through oil, coal, or biology. The pack must
-- contain NONE of these, directly. (The whole planet ships zero oil/coal chemistry.)
local PETROCHEMICAL = {
  ["crude-oil"] = true, ["petroleum-gas"] = true, ["light-oil"] = true,
  ["heavy-oil"] = true, ["lubricant"] = true, ["sulfuric-acid"] = true,
  ["plastic-bar"] = true, ["sulfur"] = true, ["coal"] = true,
  ["solid-fuel"] = true, ["rocket-fuel"] = true, ["carbon"] = true,
  ["wood"] = true, ["spoilage"] = true, ["bioflux"] = true,
}

-- "Native inputs only": every ingredient is either a Cindra-exclusive item
-- (cindra-*) or one of the plain materials the planet produces on its own (the
-- ice chain crushes nightside chunks into ice + calcite and melts ice to water;
-- the ribbon mines stone). This allowlist is
-- deliberately narrow so a future (tune) that swapped in a petrochemical would
-- fail here even if it slipped the blacklist above.
local NATIVE_NON_CINDRA = {
  ["calcite"] = true, ["water"] = true, ["ice"] = true, ["stone"] = true,
}

local function is_native(name)
  return name:sub(1, 7) == "cindra-" or NATIVE_NON_CINDRA[name] == true
end

-- LuaRecipePrototype.categories is a dictionary {name -> true}; tolerate an array.
local function recipe_in_category(recipe_name, category)
  local cats = prototypes.recipe[recipe_name].categories
  if cats[category] then return true end
  for _, v in pairs(cats) do
    if v == category then return true end
  end
  return false
end

describe("cindra science pack: petrochemical-free, native inputs only", function()
  it("has a recipe built ONLY from native, non-petrochemical inputs", function()
    local r = prototypes.recipe[PACK]
    assert.is_not_nil(r, "the cindra-science-pack recipe must exist")

    assert.is_true(#r.ingredients > 0, "the pack must actually cost something")
    for _, ing in pairs(r.ingredients) do
      assert.is_nil(PETROCHEMICAL[ing.name],
        "ingredient '" .. ing.name .. "' is petrochemical/biological -- the pack must be free of it")
      assert.is_true(is_native(ing.name),
        "ingredient '" .. ing.name .. "' is not a native Cindra input (native-inputs-only rule)")
    end
  end)

  it("is built on the SIGNATURE product (aluminium) -- the planet's identity distilled", function()
    local names = {}
    for _, ing in pairs(prototypes.recipe[PACK].ingredients) do names[ing.name] = ing.amount end
    assert.is_true((names[ALUMINIUM] or 0) > 0,
      "the headline science must consume the signature aluminium (the power-manufactured metal)")
    assert.is_true((names[VOLATILES] or 0) > 0,
      "and the deep-nightside volatiles -- both lethal edges in one pack")
  end)

  it("sources its volatiles from a PROCESSING recipe, not a mining yield (ci-4xx)", function()
    -- ci-4xx relocated volatiles off the ice field's mining drop and onto a
    -- processing recipe. Prove the science-pack input is obtainable that way:
    -- (1) a recipe produces cindra-volatiles, (2) it consumes only native inputs
    -- (petrochemical-free like the pack itself), (3) the ice field does NOT drop
    -- volatiles, and (4) the recipe is reachable (unlocked before/with the pack).
    local vr = prototypes.recipe[VOLATILES]
    assert.is_not_nil(vr, "a recipe named cindra-volatiles must exist (the processing source)")

    local makes = false
    for _, p in pairs(vr.products) do if p.name == VOLATILES then makes = true end end
    assert.is_true(makes, "the recipe must actually produce the volatiles item")

    assert.is_true(#vr.ingredients > 0, "volatiles must cost a real input (a worked output, not free)")
    for _, ing in pairs(vr.ingredients) do
      assert.is_nil(PETROCHEMICAL[ing.name],
        "volatiles-processing input '" .. ing.name .. "' must be petrochemical-free")
    end

    -- The field itself must NOT drop volatiles any more (the whole point of ci-4xx).
    local field = prototypes.entity["cindra-ice"]
    if field then
      for _, p in ipairs(field.mineable_properties.products) do
        assert.are_not.equal(VOLATILES, p.name,
          "mining the ice field must not yield volatiles -- they are a processing output now")
      end
    end

    -- Reachable: the recipe is research-gated (never free) and unlocked by the
    -- Cindra discovery tech -- which is transitively required before the pack tech
    -- (cindra-science -> cindra-aluminium -> the discovery-gated ice chain), so the
    -- science pack stays craftable end-to-end with no chicken-and-egg.
    assert.is_false(vr.enabled, "the volatiles recipe is unlocked by research, not free")
    local discovery = prototypes.technology["planet-discovery-cindra"]
    assert.is_not_nil(discovery, "the Cindra discovery tech must exist")
    local unlocks_volatiles = false
    for _, e in pairs(discovery.effects) do
      if e.type == "unlock-recipe" and e.recipe == VOLATILES then unlocks_volatiles = true end
    end
    assert.is_true(unlocks_volatiles,
      "planet-discovery-cindra must unlock the volatiles recipe (reachable with the rest of the ice chain)")
  end)

  it("produces a real science-pack item (in the science-pack subgroup)", function()
    local item = prototypes.item[PACK]
    assert.is_not_nil(item, "the cindra-science-pack item must exist")
    assert.are.equal("science-pack", item.subgroup.name,
      "it must live in the science-pack subgroup, like every vanilla pack")
  end)
end)

describe("cindra science pack: a real energy cost, crafted in a STOCK machine", function()
  it("costs a large amount of crafting time (the energy lever)", function()
    local r = prototypes.recipe[PACK]
    -- energy_required is the crafting time; a long craft means the assembler
    -- draws power the whole time, so a pack costs real energy to make -- and its
    -- aluminium input is the planet's most power-hungry product on top of that.
    assert.is_true(r.energy >= 45,
      "the pack recipe must cost real crafting time (got " .. tostring(r.energy) .. "s)")
  end)

  it("crafts in the stock `crafting` category -- an ordinary assembling machine runs it", function()
    assert.is_true(recipe_in_category(PACK, "crafting"),
      "the pack must craft in the vanilla `crafting` category, so a stock assembler makes it")

    -- A vanilla assembling machine must actually be able to run this recipe (the
    -- proof there is no bespoke machine gate): every assembler crafts `crafting`.
    for _, am in ipairs({ "assembling-machine-1", "assembling-machine-2", "assembling-machine-3" }) do
      assert.is_true(prototypes.entity[am].crafting_categories["crafting"] == true,
        am .. " must be able to craft the pack's category")
    end
  end)

  it("has NO bespoke crafting machine (ci-6km: ripped out) -- no private category survives", function()
    -- The pack crafts in the stock `crafting` category (asserted above), so no
    -- bespoke machine gates it. The old private `cindra-science` recipe category a
    -- bespoke machine would have used must not survive on any recipe or entity.
    for name, recipe in pairs(prototypes.recipe) do
      if recipe.categories then
        assert.is_nil(recipe.categories["cindra-science"],
          "recipe '" .. name .. "' still lives in the removed private crafting category")
      end
    end
    for name, ent in pairs(prototypes.entity) do
      if ent.crafting_categories then
        assert.is_nil(ent.crafting_categories["cindra-science"],
          "entity '" .. name .. "' still declares the removed private crafting category")
      end
    end
  end)
end)

describe("cindra science pack: the tech tree (headline science + folded unlocks)", function()
  it("the pack recipe is research-gated, not free", function()
    assert.is_false(prototypes.recipe[PACK].enabled, "the pack recipe must be gated")
  end)

  it("is unlocked by cindra-science, gated behind the signature aluminium", function()
    local tech = prototypes.technology[TECH]
    assert.is_not_nil(tech, "the cindra-science technology must exist")
    assert.is_true(tech.valid, "the tech must load (icon + prerequisites resolve)")

    local unlocked = {}
    for _, e in pairs(tech.effects) do
      if e.type == "unlock-recipe" then unlocked[e.recipe] = true end
    end
    assert.is_true(unlocked[PACK], "the tech unlocks the science-pack recipe")

    -- Gated behind the signature apex -> you cannot make Cindra science until you
    -- already command BOTH fire (lava) and ice, via the aluminium tech (which
    -- requires cindra-lava, and thus transitively the Cindra-discovery-gated ice
    -- chain that supplies its calcite).
    assert.is_not_nil(tech.prerequisites["cindra-aluminium"],
      "gated behind the signature aluminium (which itself needs both lava and ice)")

    -- Researched with BROUGHT packs, never the Cindra pack itself: paying for the
    -- pack-unlock with the pack would be a soft-lock (§15-13).
    local unit = {}
    for _, ing in pairs(tech.research_unit_ingredients) do unit[ing.name] = true end
    assert.is_nil(unit[PACK],
      "the pack-unlock tech must NOT cost the Cindra pack itself (bootstrap: no soft-lock)")
  end)

  it("folds orbital launch into the tree: it needs cindra-science AND costs the pack", function()
    local tech = prototypes.technology["cindra-orbital-launch"]
    assert.is_not_nil(tech, "the launch tech must exist")

    -- Under APS the discovery prereq is stripped, but the science prereq is not:
    -- either way, launch is now downstream of the headline science.
    assert.is_not_nil(tech.prerequisites["cindra-science"],
      "orbital launch is now an ADVANCED unlock, gated behind the Cindra science pack tech")

    local unit = {}
    for _, ing in pairs(tech.research_unit_ingredients) do unit[ing.name] = true end
    assert.is_true(unit[PACK] == true,
      "and researching it COSTS the Cindra science pack -- the fold made real")
  end)
end)

describe("cindra science pack: a lab actually accepts it as research input", function()
  it("a lab accepts the Cindra pack and rejects a non-pack item", function()
    local s = H.cindra_surface()
    local lab = s.create_entity({ name = "lab", position = { 0, 0 }, force = "player" })
    assert.is_not_nil(lab, "a lab must place on the Cindra surface")

    -- A lab's input inventory only accepts items in its `inputs` list. Inserting
    -- the Cindra pack must succeed (proving the append to lab inputs worked);
    -- inserting a plain item that is not a science pack must be refused.
    local accepted = lab.insert({ name = PACK, count = 1 })
    assert.are.equal(1, accepted, "the lab must accept the Cindra science pack as a valid input")

    local refused = lab.insert({ name = "iron-plate", count = 1 })
    assert.are.equal(0, refused, "the lab must refuse a non-science-pack item (sanity: it really filters)")

    lab.destroy()
  end)
end)

describe("cindra science pack runtime: a stock assembler crafts it, and it needs power", function()
  -- A powered vanilla assembling machine on a clean Cindra surface, the pack recipe
  -- set, ingredients for a single craft loaded. Proves the pack really crafts in a
  -- stock machine (no bespoke crafting machine) AND still costs power to make.
  local ASSEMBLER = "assembling-machine-3"
  local function make_assembler(powered)
    local s = H.cindra_surface()
    s.create_entity({ name = "substation", position = { 2, 2 }, force = "player" })
    if powered then
      local power = s.create_entity({
        name = "electric-energy-interface", position = { 4, 0 }, force = "player",
      })
      power.power_production = 100000000 -- 100 MW: ample headroom
      power.electric_buffer_size = 100000000
      power.energy = 100000000
    end

    game.forces["player"].recipes[PACK].enabled = true

    local m = s.create_entity({ name = ASSEMBLER, position = { 0, 0 }, force = "player" })
    assert.is_not_nil(m, "a stock assembling machine must be placeable on Cindra")
    m.set_recipe(PACK)
    m.insert({ name = ALUMINIUM, count = 1 })
    m.insert({ name = VOLATILES, count = 3 })
    m.insert({ name = "calcite", count = 4 })
    return m
  end

  it("with power, a stock assembler crafts the pack (progresses and consumes the native inputs)", function()
    local m = make_assembler(true)
    async(720)
    after_ticks(600, function()
      assert.is_true(m.valid)
      assert.is_true(m.crafting_progress > 0,
        "a powered stock assembler must make crafting progress on the pack recipe")
      assert.are.equal(0, m.get_item_count(ALUMINIUM),
        "the native inputs are consumed once the craft starts (proving real production)")
      m.destroy()
      done()
    end)
  end)

  it("with NO power, it cannot craft (no progress) -- the pack still costs power", function()
    local m = make_assembler(false)
    async(720)
    after_ticks(600, function()
      assert.is_true(m.valid)
      assert.are.equal(0, m.crafting_progress,
        "an unpowered assembler makes zero progress -- the pack genuinely consumes power")
      m.destroy()
      done()
    end)
  end)
end)
