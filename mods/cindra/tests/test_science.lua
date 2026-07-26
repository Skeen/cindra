-- Proof: Cindra's HEADLINE science pack (§15-12; DESIGN.md §2 checklist, §5).
--
-- The bead's MANDATORY assertions, plus the tech-tree fold:
--   1. PETROCHEMICAL-FREE, NATIVE INPUTS ONLY -- no oil/coal/plastic/sulfur/etc.
--      anywhere in the recipe; every ingredient is a Cindra material.
--   2. A SIGNIFICANT POWER SINK -- a high crafting-time (energy_required) run in a
--      dedicated machine whose electric DRAW dwarfs a normal assembler, and which
--      genuinely consumes power to produce (crafting only progresses when powered).
--   3. A REAL SCIENCE PACK -- a `tool` a lab will actually accept as research input.
--   4. THE FOLDED TREE -- the pack has a real downstream unlock: orbital launch now
--      branches off `cindra-science` and is researched WITH the Cindra pack.

local H = require("tests.helpers")

local PACK = "cindra-science-pack"
local FORGE = "cindra-starforge"
local CATEGORY = "cindra-science"
local TECH = "cindra-science"
local ALLOY = "cindra-cryo-hardened-alloy"
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
-- ice chain makes water + calcite; the ribbon mines stone/ice). This allowlist is
-- deliberately narrow so a future (tune) that swapped in a petrochemical would
-- fail here even if it slipped the blacklist above.
local NATIVE_NON_CINDRA = {
  ["calcite"] = true, ["water"] = true, ["ice"] = true, ["stone"] = true,
}

local function is_native(name)
  return name:sub(1, 7) == "cindra-" or NATIVE_NON_CINDRA[name] == true
end

local function energy_usage_of(proto)
  -- Field name differs across API surfaces; take whichever resolves.
  if proto.get_max_energy_usage then return proto.get_max_energy_usage() end
  return proto.energy_usage
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

  it("is built on the SIGNATURE product (fire+ice) -- the planet's identity distilled", function()
    local names = {}
    for _, ing in pairs(prototypes.recipe[PACK].ingredients) do names[ing.name] = ing.amount end
    assert.is_true((names[ALLOY] or 0) > 0,
      "the headline science must consume the signature cryo-hardened alloy")
    assert.is_true((names[VOLATILES] or 0) > 0,
      "and the deep-nightside volatiles -- both lethal edges in one pack")
  end)

  it("produces a real science-pack item (in the science-pack subgroup)", function()
    local item = prototypes.item[PACK]
    assert.is_not_nil(item, "the cindra-science-pack item must exist")
    assert.are.equal("science-pack", item.subgroup.name,
      "it must live in the science-pack subgroup, like every vanilla pack")
  end)
end)

describe("cindra science pack: a significant POWER SINK", function()
  it("costs a large amount of crafting time (the energy lever)", function()
    local r = prototypes.recipe[PACK]
    -- energy_required is the crafting time; long time x high draw = a big energy
    -- cost per pack, so research scales with captured flare/baseline power.
    assert.is_true(r.energy >= 45,
      "the pack recipe must cost real crafting time (got " .. tostring(r.energy) .. "s)")
  end)

  it("is crafted in a dedicated ELECTRIC machine that draws far more than a normal assembler", function()
    local forge = prototypes.entity[FORGE]
    assert.is_not_nil(forge, "the starforge entity must exist")
    assert.is_not_nil(forge.electric_energy_source_prototype,
      "the starforge must be electric -- it eats power to make science")

    local mine = energy_usage_of(forge)
    local vanilla = energy_usage_of(prototypes.entity["assembling-machine-3"])
    assert.is_true(mine > vanilla * 5,
      "the starforge's active draw (" .. tostring(mine) .. " W) must dwarf a normal assembler's ("
        .. tostring(vanilla) .. " W): running it is a deliberate power sink")
  end)

  it("runs the pack recipe in a PRIVATE category (no leak to/from vanilla assemblers)", function()
    local forge = prototypes.entity[FORGE]
    assert.is_true(forge.crafting_categories[CATEGORY],
      "the starforge crafts in the private cindra-science category")
    assert.is_nil(prototypes.entity["assembling-machine-3"].crafting_categories[CATEGORY],
      "vanilla assemblers must NOT gain the Cindra science category (no cross-planet leak)")

    assert.is_true(recipe_in_category(PACK, CATEGORY), "the pack recipe lives in the private category")
    assert.is_false(recipe_in_category(PACK, "crafting"),
      "and NOT in the generic vanilla crafting category")
  end)
end)

describe("cindra science pack: the tech tree (headline science + folded unlocks)", function()
  it("recipes are research-gated, not free", function()
    assert.is_false(prototypes.recipe[PACK].enabled, "the pack recipe must be gated")
    assert.is_false(prototypes.recipe[FORGE].enabled, "the starforge recipe must be gated")
  end)

  it("is unlocked by cindra-science, gated behind the signature cryo-quench", function()
    local tech = prototypes.technology[TECH]
    assert.is_not_nil(tech, "the cindra-science technology must exist")
    assert.is_true(tech.valid, "the tech must load (icon + prerequisites resolve)")

    local unlocked = {}
    for _, e in pairs(tech.effects) do
      if e.type == "unlock-recipe" then unlocked[e.recipe] = true end
    end
    assert.is_true(unlocked[PACK], "the tech unlocks the science-pack recipe")
    assert.is_true(unlocked[FORGE], "the tech unlocks the starforge recipe")

    -- Gated behind the signature apex -> you cannot make Cindra science until you
    -- already command BOTH fire (lava) and ice (via the cryo-quench).
    assert.is_not_nil(tech.prerequisites["cindra-cryo-quenching"],
      "gated behind the signature cryo-quench (which itself needs both lava and ice)")

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

describe("cindra starforge runtime: consumes power to produce", function()
  -- A powered starforge on a clean Cindra surface, recipe set, ingredients for a
  -- single craft loaded. Same headless power pattern as the cryo-quench suite.
  local function make_forge(powered)
    local s = H.cindra_surface()
    s.create_entity({ name = "substation", position = { 2, 2 }, force = "player" })
    if powered then
      local power = s.create_entity({
        name = "electric-energy-interface", position = { 4, 0 }, force = "player",
      })
      power.power_production = 100000000 -- 100 MW: ample headroom over the ~10 MW draw
      power.electric_buffer_size = 100000000
      power.energy = 100000000
    end

    game.forces["player"].recipes[PACK].enabled = true

    local m = s.create_entity({ name = FORGE, position = { 0, 0 }, force = "player" })
    assert.is_not_nil(m, "the starforge must be placeable on Cindra")
    m.set_recipe(PACK)
    m.insert({ name = ALLOY, count = 1 })
    m.insert({ name = VOLATILES, count = 3 })
    m.insert({ name = "calcite", count = 4 })
    return m
  end

  it("with power, it begins crafting (progresses and consumes the native inputs)", function()
    local m = make_forge(true)
    async(720)
    after_ticks(600, function()
      assert.is_true(m.valid)
      assert.is_true(m.crafting_progress > 0,
        "a powered starforge must make crafting progress (it is drawing power to craft)")
      assert.are.equal(0, m.get_item_count(ALLOY),
        "the native inputs are consumed once the craft starts (proving real production)")
      m.destroy()
      done()
    end)
  end)

  it("with NO power, it cannot craft (no progress) -- power is genuinely required", function()
    local m = make_forge(false)
    async(720)
    after_ticks(600, function()
      assert.is_true(m.valid)
      assert.are.equal(0, m.crafting_progress,
        "an unpowered starforge makes zero progress -- the pack genuinely consumes power")
      m.destroy()
      done()
    end)
  end)
end)
