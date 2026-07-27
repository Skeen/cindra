-- Proof: manufactured aluminium is Cindra's ruinous-power material (ci-txh;
-- DESIGN.md §1, §5, §7). Four claims, matching the bead:
--   1. THE CHAIN is petrochemical-free, native inputs only:
--        stone + calcite -> alumina -> [power] -> aluminium.
--   2. POWER IS THE COST: the electrolysis cell has a huge electric draw (a
--      bigger single-building sink than the lava foundry) and the recipe a long
--      craft time -- so power, not material, is the dominant cost. Productivity
--      is allowed (intermediate reward, per lava); power still dominates.
--   3. GATED: recipes off by default; the tech unlocks all three and sits behind
--      BOTH the lava spine and ice processing (rock AND ice).
--   4. DEMAND EXISTS: the flare capacitor consumes aluminium (a downstream use),
--      so aluminium is not a dead-end.
-- Plus the never-mutate-other-planets guard (the shared electric furnace is
-- deep-copied, not mutated) and a runtime proof (a powered cell smelts aluminium).

local H = require("tests.helpers")

local ALUMINA = "cindra-alumina"
local ALUMINIUM = "cindra-aluminium"
local CELL = "cindra-electrolysis-cell"
local CATEGORY = "cindra-electrolysis"
local TECH = "cindra-aluminium"

-- Petrochemistry / off-world chemistry that Cindra forbids (DESIGN.md §1).
local FORBIDDEN = {
  ["plastic-bar"] = true, ["sulfur"] = true, ["sulfuric-acid"] = true,
  ["petroleum-gas"] = true, ["light-oil"] = true, ["heavy-oil"] = true,
  ["crude-oil"] = true, ["coal"] = true, ["lubricant"] = true,
}

local function amount_of(list, name)
  for _, e in pairs(list) do
    if e.name == name then return e.amount end
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

describe("cindra aluminium chain (native, petrochemical-free)", function()
  it("refines alumina from native rock + ice output only (stone + calcite)", function()
    local r = prototypes.recipe[ALUMINA]
    assert.is_not_nil(r, "the alumina recipe must exist")
    assert.is_true((amount_of(r.ingredients, "stone") or 0) > 0, "alumina uses stone (the ribbon raw)")
    assert.is_true((amount_of(r.ingredients, "calcite") or 0) > 0,
      "alumina uses calcite (from the ice chain) -- pulling demand onto both economies")
    -- Exactly two inputs, both native: no carrier, no chemistry.
    assert.are.equal(2, #r.ingredients, "alumina has exactly two native inputs")
    assert.are.equal(ALUMINA, r.products[1].name, "the recipe produces alumina")
  end)

  it("electrolyses aluminium from alumina alone (single native feedstock)", function()
    local r = prototypes.recipe[ALUMINIUM]
    assert.is_not_nil(r, "the aluminium recipe must exist")
    assert.are.equal(1, #r.ingredients, "aluminium is smelted from a single feedstock")
    assert.are.equal(ALUMINA, r.ingredients[1].name, "that feedstock is alumina")
    assert.are.equal(ALUMINIUM, r.products[1].name, "the recipe produces aluminium")
  end)

  it("the whole chain is petrochemical-free (no plastic/sulfur/oil/coal)", function()
    for _, name in ipairs({ ALUMINA, ALUMINIUM, CELL }) do
      for _, ing in pairs(prototypes.recipe[name].ingredients) do
        assert.is_nil(FORBIDDEN[ing.name],
          name .. " must not consume the forbidden petrochemical " .. ing.name)
      end
    end
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

    -- The chain needs power+metal (lava) AND calcite (ice processing): gate on both.
    assert.is_not_nil(tech.prerequisites["cindra-lava"],
      "gated behind the lava spine -- the metal economy + the power to electrolyse")
    assert.is_not_nil(tech.prerequisites["cindra-ice-processing"],
      "gated behind ice processing -- the calcite the refine step needs")
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
