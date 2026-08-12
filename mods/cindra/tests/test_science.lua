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
--   5. PLANET-LOCKED (ci-gk4u) -- like every vanilla planet pack, it can only be
--      made ON its own planet: shipping the (all exportable) inputs home buys you
--      nothing. Asserted as behaviour -- a player holding every ingredient is
--      refused off Cindra and served on it -- plus a live coverage guard over
--      every planet in the game.

local H = require("tests.helpers")

local PACK = "cindra-science-pack"
local TECH = "cindra-science"
local ALUMINIUM = "cindra-aluminium"
-- The nightside input is `ice` (ci-ml1), now MINED directly from the ice field
-- (ci-9l6): the field drops a fixed ice+calcite mix, so `ice` is a raw mining
-- yield again. Frozen volatiles are gone; ice is the petrochemical-free cold-edge
-- feedstock that replaces them.
local ICE = "ice"
-- The nightside resource the science pack's ice + calcite are mined from (ci-9l6).
local ICE_FIELD = "cindra-ice"

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
-- ice field mines ice + calcite and the melt turns ice to water; the ribbon mines
-- stone). This allowlist is
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
    assert.is_true((names[ICE] or 0) > 0,
      "and the deep-nightside ice -- both lethal edges in one pack")
  end)

  it("sources its ice + calcite from the ice field's mined mix (ci-9l6)", function()
    -- ci-ml1 removed frozen volatiles and pointed the science pack's cold-edge
    -- input at `ice`; ci-9l6 makes `ice` (and `calcite`) a RAW MINING YIELD again --
    -- the nightside ice field drops a fixed mix of BOTH. Prove the pack's two
    -- nightside-derived inputs are obtainable straight from the field:
    -- (1) the field is a real minable resource, (2) mining it yields BOTH ice and
    -- calcite, (3) neither product is petrochemical, and (4) it is reachable with no
    -- tech gate (mining needs no research; melting ice to water hangs off discovery).
    local field = prototypes.entity[ICE_FIELD]
    assert.is_not_nil(field, "the cindra-ice field resource must exist")
    assert.are.equal("resource", field.type, "the ice field is a minable resource")

    local yields = {}
    for _, p in ipairs(field.mineable_properties.products) do
      yields[p.name] = (p.amount or p.amount_max or 1)
      assert.is_nil(PETROCHEMICAL[p.name],
        "ice-field product '" .. p.name .. "' must be petrochemical-free")
    end
    assert.is_true((yields[ICE] or 0) > 0,
      "mining the ice field must yield the ice item directly (ci-9l6)")
    assert.is_true((yields["calcite"] or 0) > 0,
      "mining the ice field must ALSO yield calcite -- the fixed mix (ci-9l6)")

    -- Mining is not research-gated, so ice + calcite are available as soon as the
    -- player can drill the cold cap -- well before the pack tech (cindra-science ->
    -- cindra-aluminium) is reachable. No chicken-and-egg; the pack stays craftable
    -- end-to-end. The one gated step, ice -> water, is the vanilla ice-melting recipe
    -- unlocked by planet-discovery-cindra (asserted in test_ice_processing.lua).
    local discovery = prototypes.technology["planet-discovery-cindra"]
    assert.is_not_nil(discovery, "the Cindra discovery tech must exist")
    local unlocks_melt = false
    for _, e in pairs(discovery.effects) do
      if e.type == "unlock-recipe" and e.recipe == "ice-melting" then unlocks_melt = true end
    end
    assert.is_true(unlocks_melt,
      "planet-discovery-cindra must unlock ice-melting (ice -> water, the one gated ice step)")
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
    m.insert({ name = ICE, count = 5 })
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

-- ===========================================================================
-- PLANET LOCK (ci-gk4u): the pack can only be made ON Cindra.
--
-- Every vanilla planet pack is surface-gated to its own planet, which is what
-- forces "run a factory on that planet" instead of shipping the intermediates
-- home. Cindra's inputs (aluminium, ice, calcite) are all exportable items, so
-- without a gate the headline pack could be crafted anywhere -- breaking both the
-- vanilla convention and the premise that you cannot make it without commanding
-- both lethal edges.
--
-- The load-bearing claim here is BEHAVIOURAL and lives in the runtime block below:
-- a player carrying every ingredient is REFUSED off Cindra and served on Cindra.
-- The prototype assertions that follow are the coverage guard over the class --
-- every planet in the game, so a planet added later cannot quietly slip inside the
-- gate.
-- ===========================================================================
describe("cindra science pack: PLANET-LOCKED to Cindra (ci-gk4u)", function()
  -- A surface property as the ENGINE sees it: the value the surface declares, or
  -- the property's default when it declares none (that fallback is exactly why
  -- Nauvis, which declares nothing, still reads solar-power 100).
  local function property_of(props, name)
    local v = props and props[name]
    if v ~= nil then return v end
    return prototypes.surface_property[name].default_value
  end

  -- Would a surface with these properties be allowed to craft the pack?
  local function admits(props)
    for _, c in pairs(prototypes.recipe[PACK].surface_conditions or {}) do
      local v = property_of(props, c.property)
      if c.min and v < c.min then return false end
      if c.max and v > c.max then return false end
    end
    return true
  end

  it("carries a surface condition, pinned exactly -- the vanilla planet-pack idiom", function()
    local conditions = prototypes.recipe[PACK].surface_conditions
    assert.is_not_nil(conditions, "the pack recipe must carry a surface condition (it is planet-locked)")
    assert.is_true(#conditions > 0, "the surface-condition list must not be empty")

    -- Vanilla pins its pack gates EXACTLY (min == max) so a merely-similar planet
    -- cannot drift inside a one-sided bound. Match that.
    for _, c in pairs(conditions) do
      assert.is_not_nil(c.min, "condition on '" .. c.property .. "' must have a lower bound")
      assert.is_not_nil(c.max, "condition on '" .. c.property .. "' must have an upper bound")
      assert.are.equal(c.min, c.max,
        "condition on '" .. c.property .. "' must be pinned exactly, like every vanilla pack gate")
    end
  end)

  it("admits Cindra: the gate matches the planet's own surface properties", function()
    -- The gate must never lock the pack out of its OWN planet -- that would make
    -- it uncraftable anywhere. Measured against the real planet prototype, so a
    -- (tune) of Cindra's surface properties that forgot the gate fails here.
    local cindra = game.planets["cindra"]
    assert.is_not_nil(cindra, "the cindra planet must exist")
    assert.is_true(admits(cindra.prototype.surface_properties),
      "Cindra itself must satisfy the pack's surface conditions")
  end)

  it("excludes EVERY other planet in the game (live coverage guard)", function()
    -- Enumerated live from game.planets, not from a hand-written list: a planet
    -- added by a later Cindra change (or a mod loaded alongside) is measured
    -- without anyone remembering to add it here.
    local checked = 0
    for name, planet in pairs(game.planets) do
      if name ~= "cindra" then
        checked = checked + 1
        assert.is_false(admits(planet.prototype.surface_properties),
          "planet '" .. name .. "' also satisfies the pack's gate -- the pack must be Cindra-only")
      end
    end
    assert.is_true(checked >= 4,
      "the guard must actually have measured the vanilla planets (checked " .. checked .. ")")

    -- And a space platform, the other place a player can run assemblers.
    local platform = prototypes.surface["space-platform"]
    assert.is_not_nil(platform, "the space-platform surface prototype must exist")
    assert.is_false(admits(platform.surface_properties),
      "a space platform must not be able to craft the pack either")
  end)
end)

describe("cindra science pack runtime: it CANNOT be crafted off Cindra (ci-gk4u)", function()
  -- HOW A SURFACE GATE IS OBSERVED. The engine enforces `surface_conditions` where
  -- a recipe is CHOSEN -- the recipe picker, and hand-crafting -- not inside the
  -- crafting tick. A recipe forced onto a machine by script bypasses it and crafts
  -- happily; measured in-engine, VANILLA's own space-science-pack (gravity 0/0)
  -- behaves exactly the same way on a gravity-10 surface. So the gate is measured
  -- here through the player's own hands, which is a path the engine really checks,
  -- and every claim is run alongside that vanilla pack as a CONTROL: if the harness
  -- ever stopped detecting a real gate, the control fails too and the Cindra
  -- assertions cannot false-green.
  local VANILLA_LOCKED = "space-science-pack" -- locked to a platform (gravity 0/0)

  -- Stock the player with enough of everything for one of each pack, wherever they
  -- are standing. Ingredients are never the reason a craft is refused.
  local PROVISIONS = {
    { name = ALUMINIUM, count = 4 }, { name = ICE, count = 20 }, { name = "calcite", count = 20 },
    { name = "iron-plate", count = 10 }, { name = "carbon", count = 10 },
  }
  local function provision(player)
    game.forces["player"].recipes[PACK].enabled = true
    game.forces["player"].recipes[VANILLA_LOCKED].enabled = true
    for _, stack in ipairs(PROVISIONS) do player.insert(stack) end
  end
  local function unprovision(player)
    for _, stack in ipairs(PROVISIONS) do player.remove_item(stack) end
  end

  it("a player holding every ingredient CANNOT make the pack anywhere but Cindra", function()
    local player = game.players[1]
    assert.is_not_nil(player, "the test scenario must have a player to craft with")
    assert.is_not_nil(player.character, "the player must have a character (hand-crafting needs one)")

    local off = H.offworld_surface()
    player.teleport({ 0, 20 }, off)
    assert.are.equal(off.name, player.surface.name, "the player must actually be off Cindra")
    provision(player)

    -- The CONTROL: a vanilla planet-locked pack, refused here for the same reason.
    assert.are.equal(0, player.begin_crafting({ count = 1, recipe = VANILLA_LOCKED, silent = true }),
      "control: vanilla's own surface-locked pack must be refused here, or this test proves nothing")

    -- The claim: you shipped the aluminium, ice and calcite home, and it bought you
    -- nothing. The pack cannot be made off Cindra.
    assert.are.equal(0, player.begin_crafting({ count = 1, recipe = PACK, silent = true }),
      "the Cindra pack must be uncraftable off Cindra even with every ingredient in hand")

    -- ...and back on Cindra the very same player, with the very same items, makes
    -- it. The gate admits Cindra exactly: it locks the pack IN, it does not kill it.
    local cindra = H.cindra_surface()
    player.teleport({ 0, 20 }, cindra)
    assert.are.equal(cindra.name, player.surface.name)
    assert.are.equal(1, player.begin_crafting({ count = 1, recipe = PACK, silent = true }),
      "on Cindra the same player with the same items must be able to craft the pack")

    -- Cindra is a planet, not a platform: the vanilla platform pack stays refused
    -- here too, so "on Cindra everything is craftable" is not what was measured.
    assert.are.equal(0, player.begin_crafting({ count = 1, recipe = VANILLA_LOCKED, silent = true }),
      "control: the platform-locked vanilla pack is still refused on Cindra")

    -- Leave the player as we found them: drop the queued craft (which refunds its
    -- ingredients) and take the provisions back out.
    local queue = player.crafting_queue
    if queue then
      for i = #queue, 1, -1 do
        player.cancel_crafting({ index = queue[i].index, count = queue[i].count })
      end
    end
    unprovision(player)
  end)
end)
