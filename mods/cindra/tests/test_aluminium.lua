-- Proof: manufactured aluminium is Cindra's ruinous-power material (ci-txh; the
-- line reshaped to acid leaching + O2-emitting electrolysis by ci-6vj S2, DESIGN
-- §8 recipes #5/#6). The claims, matching the bead:
--   1. THE CHAIN is petrochemical-free EXCEPT the honest acid input:
--        20 stone + sulfuric-acid + water -> alumina + 14 stone + sulfur;
--        4 alumina -> [power] -> 2 aluminium + 30 O2.
--   2. MATTER HONESTY: the leach is net stone-NEGATIVE (20 in, 14 back) at 0% AND
--      at the +300% productivity cap -- the 14-stone + 2-sulfur returns are
--      ignored_by_productivity and productivity is OFF, so mining is a real top-up.
--   3. O2: electrolysis emits 30 cindra-oxygen (ignored_by_productivity) through
--      the cell's output fluid box -- the O2 economy's dominant source (§8.4).
--   4. POWER IS THE COST: the electrolysis cell has a huge electric draw (a bigger
--      single-building sink than the lava foundry) and the recipe a long craft
--      time. Productivity is ON for aluminium (intermediate reward, per lava).
--   5. GATED: recipes off by default; the tech unlocks all three and sits behind
--      the lava spine (which unlocks the acid the leach needs).
--   6. DEMAND EXISTS: the flare capacitor consumes aluminium (a downstream use),
--      so aluminium is not a dead-end.
-- Plus the never-mutate-other-planets guard (the shared electric furnace is
-- deep-copied, not mutated) and a runtime proof (a powered cell smelts aluminium).

local H = require("tests.helpers")

local ALUMINA = "cindra-alumina"
local ALUMINIUM = "cindra-aluminium"
local CELL = "cindra-electrolysis-cell"
local CATEGORY = "cindra-electrolysis"
local TECH = "cindra-aluminium"
local OXYGEN = "cindra-oxygen"

-- The engine's hard productivity cap (+300%): the ceiling of ANY module config.
local MAX_CONCEIVABLE_PROD = 3.0

-- Petrochemistry / off-world chemistry that Cindra forbids (DESIGN.md §1). NOTE:
-- sulfuric-acid is NOT here -- ci-6vj S2 makes acid the leach's intended input (a
-- real, native chemical made from Cindra's own sulfur), and sulfur is a leach
-- BYPRODUCT. Oil/coal/plastic stay forbidden: those are the petrochemistry Cindra
-- has none of.
local FORBIDDEN = {
  ["plastic-bar"] = true,
  ["petroleum-gas"] = true, ["light-oil"] = true, ["heavy-oil"] = true,
  ["crude-oil"] = true, ["coal"] = true, ["lubricant"] = true,
}

local function amount_of(list, name)
  for _, e in pairs(list) do
    if e.name == name then return e.amount end
  end
  return nil
end

-- Pull the full product table (so callers can read ignored_by_productivity etc.).
local function product_of(list, name)
  for _, e in pairs(list) do
    if e.name == name then return e end
  end
  return nil
end

local function in_category(recipe_name, category)
  local cats = prototypes.recipe[recipe_name].categories
  if cats[category] then return true end
  for _, v in pairs(cats) do
    if v == category then return true end
  end
  return false
end

describe("cindra aluminium chain (acid leaching + electrolysis, DESIGN §8)", function()
  it("leaches alumina from stone with acid + water (§8 recipe #5)", function()
    local r = prototypes.recipe[ALUMINA]
    assert.is_not_nil(r, "the alumina recipe must exist")
    -- Inputs: stone (the ribbon raw) + sulfuric-acid + water, all reachable.
    assert.is_true((amount_of(r.ingredients, "stone") or 0) > 0, "the leach consumes stone (the ribbon raw)")
    assert.is_true((amount_of(r.ingredients, "sulfuric-acid") or 0) > 0,
      "the leach consumes sulfuric-acid -- the honest chemical input (from the acid the lava tech unlocks)")
    assert.is_true((amount_of(r.ingredients, "water") or 0) > 0, "the leach consumes water (from ice-melting)")
    -- Runs in a chemical plant: the "chemistry" category, so it has the fluid
    -- boxes the acid + water need and no new building is introduced.
    assert.is_true(in_category(ALUMINA, "chemistry"),
      "alumina leaching runs in the vanilla chemical plant (chemistry category)")
    -- Products: alumina (the feedstock) + a fixed stone + sulfur return.
    assert.is_true((amount_of(r.products, ALUMINA) or 0) > 0, "the leach produces alumina")
    assert.is_true((amount_of(r.products, "stone") or 0) > 0, "the leach returns some stone (net-negative, see below)")
    assert.is_true((amount_of(r.products, "sulfur") or 0) > 0, "the leach emits sulfur (a second acid-loop source)")
  end)

  it("the leach is net stone-NEGATIVE at 0% AND at the +300% prod cap (§8.6)", function()
    local r = prototypes.recipe[ALUMINA]
    local stone_in = amount_of(r.ingredients, "stone")
    local sp = product_of(r.products, "stone")
    assert.is_not_nil(stone_in, "the leach must consume stone")
    assert.is_not_nil(sp, "the leach must return stone")

    -- Productivity is OFF on the leach, so stone-in is fixed. The returned stone
    -- is ignored_by_productivity (fixed regardless of prod), so even at the hard
    -- +300% cap the return can never scale to overtake the input.
    assert.is_false(r.allowed_effects.productivity,
      "productivity must be OFF on the leach so stone-in per craft is fixed")
    local ignored = sp.ignored_by_productivity or 0
    assert.are.equal(sp.amount, ignored,
      "the whole returned-stone amount must be ignored_by_productivity (fixed at every module tier)")

    -- Worst case (most stone ever handed back): the non-ignored part scales with
    -- prod; the ignored part is fixed. Here the ignored part IS the whole return.
    local worst_return = ignored + (sp.amount - ignored) * (1 + MAX_CONCEIVABLE_PROD)
    assert.is_true(stone_in > worst_return,
      "the leach must NET-CONSUME stone even at +300% prod: in=" .. stone_in
        .. " worst-return=" .. worst_return)
  end)

  it("electrolyses aluminium from alumina alone, emitting O2 (§8 recipe #6)", function()
    local r = prototypes.recipe[ALUMINIUM]
    assert.is_not_nil(r, "the aluminium recipe must exist")
    assert.are.equal(1, #r.ingredients, "aluminium is smelted from a single item feedstock")
    assert.are.equal(ALUMINA, r.ingredients[1].name, "that feedstock is alumina")
    assert.is_true((amount_of(r.products, ALUMINIUM) or 0) > 0, "the recipe produces aluminium")

    -- The O2 byproduct: 30 cindra-oxygen, ignored_by_productivity (the dominant O2
    -- source, §8.4). Fixed at every module tier so a prod bonus never mints gas.
    local o2 = product_of(r.products, OXYGEN)
    assert.is_not_nil(o2, "electrolysis must emit cindra-oxygen (the O2 economy's dominant source)")
    assert.are.equal(30, o2.amount, "electrolysis emits 30 O2 per craft")
    assert.are.equal(o2.amount, o2.ignored_by_productivity or 0,
      "the O2 byproduct must be ignored_by_productivity (fixed -- prod can never mint free gas)")
  end)

  it("the chain is petrochemical-free except the honest acid input (no oil/coal/plastic)", function()
    for _, name in ipairs({ ALUMINA, ALUMINIUM, CELL }) do
      for _, ing in pairs(prototypes.recipe[name].ingredients) do
        assert.is_nil(FORBIDDEN[ing.name],
          name .. " must not consume the forbidden petrochemical " .. ing.name)
      end
    end
    -- Positive guard: sulfuric-acid IS allowed now, but ONLY as the leach input --
    -- assert the chain reads acid and never oil/coal/plastic (which stay forbidden).
    assert.is_true((amount_of(prototypes.recipe[ALUMINA].ingredients, "sulfuric-acid") or 0) > 0,
      "acid is the intended leach input (the one relaxation), not oil/coal/plastic")
  end)
end)

describe("cindra aluminium: power is the ruinous cost", function()
  it("the electrolysis cell draws far more than the lava foundry (a big sink)", function()
    local cell = prototypes.entity[CELL]
    assert.is_not_nil(cell, "the electrolysis cell must exist")
    assert.is_not_nil(cell.electric_energy_source_prototype, "the cell is electric")

    -- The cell is a bigger single-building power sink than the foundry that makes
    -- lava, so aluminium genuinely competes with lava manufacture for flare power.
    local foundry = prototypes.entity["foundry"]
    assert.is_true(cell.energy_usage > foundry.energy_usage,
      "the cell must out-draw the foundry: cell=" .. cell.energy_usage
        .. " foundry=" .. foundry.energy_usage)

    -- And far above the vanilla electric furnace it is cloned from (the draw is
    -- cranked deliberately; also a canary that we did not mutate the shared base).
    local base = prototypes.entity["electric-furnace"]
    assert.is_true(cell.energy_usage >= base.energy_usage * 20,
      "the cell draw must be cranked well above the vanilla electric furnace")
  end)

  it("the electrolysis recipe costs real crafting time, and allows productivity", function()
    local r = prototypes.recipe[ALUMINIUM]
    assert.is_true(r.energy >= 10,
      "aluminium must cost real crafting time (the power lever), got " .. tostring(r.energy))
    -- Productivity ON: aluminium is an intermediate (a plate-analog), so a prod
    -- bonus is a fair reward and matches vanilla intermediate conventions (the
    -- same rule manufactured lava keeps). Power stays the dominant cost.
    assert.is_true(r.allowed_effects.productivity,
      "productivity must be ON: aluminium is an intermediate; a prod bonus is a fair reward")
  end)

  it("does not mutate the shared electric furnace (never-mutate-other-planets)", function()
    -- The vanilla electric furnace keeps a modest draw; if a clone-not-mutate went
    -- wrong and we cranked the shared prototype, this fails before it leaks.
    local base = prototypes.entity["electric-furnace"]
    assert.is_true(base.energy_usage < prototypes.entity[CELL].energy_usage,
      "the vanilla electric furnace must keep its own (much smaller) draw")
    assert.is_nil(base.crafting_categories[CATEGORY],
      "the vanilla electric furnace must NOT gain the private electrolysis category")
  end)
end)

describe("cindra aluminium: private category + gating", function()
  it("electrolysis lives in a private category (no vanilla smelting leak)", function()
    local cell = prototypes.entity[CELL]
    assert.is_true(cell.crafting_categories[CATEGORY],
      "the cell crafts in the private cindra-electrolysis category")
    assert.is_nil(cell.crafting_categories["smelting"],
      "the cell must NOT share the vanilla smelting category (no recipe leak)")
    assert.is_true(in_category(ALUMINIUM, CATEGORY),
      "the aluminium recipe lives in the private category")
    assert.is_false(in_category(ALUMINIUM, "smelting"),
      "the aluminium recipe must not live in the vanilla smelting category")
  end)

  it("all recipes are gated off by default", function()
    for _, name in ipairs({ ALUMINA, ALUMINIUM, CELL }) do
      assert.is_false(prototypes.recipe[name].enabled,
        name .. " must be research-gated, not free")
    end
  end)

  it("is unlocked by cindra-aluminium, gated behind BOTH rock and ice chains", function()
    local tech = prototypes.technology[TECH]
    assert.is_not_nil(tech, "the cindra-aluminium technology must exist")
    assert.is_true(tech.valid, "the tech must load (its icon is present)")

    local unlocked = {}
    for _, effect in pairs(tech.effects) do
      if effect.type == "unlock-recipe" then unlocked[effect.recipe] = true end
    end
    assert.is_true(unlocked[ALUMINA], "the tech unlocks the alumina recipe")
    assert.is_true(unlocked[ALUMINIUM], "the tech unlocks the aluminium recipe")
    assert.is_true(unlocked[CELL], "the tech unlocks the electrolysis-cell build recipe")

    -- The chain needs power+metal (lava) AND calcite. Calcite is a MINED resource
    -- now (ci-9l6): it drops from the ice field, needing no tech at all. So the only
    -- real gate is the lava spine; cindra-lava requires planet-discovery-cindra
    -- (reaching Cindra), so aluminium stays behind both rock and the planet itself.
    assert.is_not_nil(tech.prerequisites["cindra-lava"],
      "gated behind the lava spine -- the metal economy + the power to electrolyse")
    assert.is_not_nil(prototypes.technology["cindra-lava"].prerequisites["planet-discovery-cindra"],
      "cindra-lava requires Cindra discovery -- so aluminium is unreachable until the player commands both rock and the planet (calcite is mined, no crush tech)")
  end)

  it("has an item that places the cell", function()
    local item = prototypes.item[CELL]
    assert.is_not_nil(item, "the electrolysis-cell item must exist")
    assert.is_not_nil(item.place_result, "the item must place an entity")
    assert.are.equal(CELL, item.place_result.name, "the item places the cell")
    assert.is_not_nil(prototypes.item[ALUMINA], "the alumina item must exist")
    assert.is_not_nil(prototypes.item[ALUMINIUM], "the aluminium item must exist")
  end)
end)

describe("cindra aluminium: demand exists (not a dead-end)", function()
  it("the flare capacitor consumes aluminium (a real downstream use)", function()
    local cap = prototypes.recipe["cindra-capacitor"]
    assert.is_not_nil(cap, "the capacitor recipe must exist")
    assert.is_true((amount_of(cap.ingredients, ALUMINIUM) or 0) > 0,
      "the capacitor must consume aluminium -- so aluminium has demand")
  end)
end)

describe("cindra aluminium runtime (a powered cell smelts it)", function()
  it("a powered electrolysis cell turns alumina into aluminium", function()
    local s = H.cindra_surface()
    local pole = s.create_entity({ name = "substation", position = { 2, 2 }, force = "player" })
    assert.is_not_nil(pole, "substation must place")
    local power = s.create_entity({
      name = "electric-energy-interface", position = { 4, 0 }, force = "player",
    })
    -- The cell draws ~50 MW; feed it well above that so it never starves.
    power.power_production = 200000000
    power.electric_buffer_size = 200000000
    power.energy = 200000000

    game.forces["player"].recipes[ALUMINIUM].enabled = true

    local cell = s.create_entity({ name = CELL, position = { 0, 0 }, force = "player" })
    assert.is_not_nil(cell, "the electrolysis cell must be placeable on Cindra")
    -- A furnace auto-selects the private-category recipe from its input item.
    cell.insert({ name = ALUMINA, count = 100 })

    async(2400)
    after_ticks(1800, function()
      assert.is_true(cell.valid)
      assert.is_true(cell.get_item_count(ALUMINIUM) > 0,
        "a powered cell fed alumina must produce aluminium (got "
          .. cell.get_item_count(ALUMINIUM) .. ")")
      cell.destroy()
      done()
    end)
  end)
end)
