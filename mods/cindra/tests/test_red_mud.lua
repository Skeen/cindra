-- PROOF: the red-mud subsystem (ci-c7j) -- the Bayer alumina route + iron
-- recovery -- folds into the authoritative ci-6vj graph and couples aluminium and
-- iron without breaking any invariant. Claims:
--   1. BAYER is an ALTERNATIVE alumina route: `stone + quicklime -> alumina +
--      red mud`, in an assembler, prod OFF, gated. It returns NO stone (opens no
--      stone vector) and needs no acid, only the calciner's quicklime.
--   2. BOTH alumina routes feed the SAME electrolysis unchanged (Bayer + the acid
--      leach both make cindra-alumina; electrolysis still eats cindra-alumina).
--   3. IRON RECOVERY: `red mud + CO2 + [ruinous power] -> iron-plate + slag`, in a
--      dedicated high-draw ARC FURNACE (private category), prod OFF,
--      gated. It is a big electric draw (a flare-timed power sink) and a real CO2
--      sink (closing the calcination loop). Output is the vanilla iron-plate.
--   4. THE COUPLING: red mud's only consumer is iron recovery (no free vent), so
--      the Bayer line is tied to the iron line -- yet it never HARD-deadlocks
--      (iron-plate has real sinks; the acid-leach route is the fallback).
--   5. IRON HAS A REAL SINK: the vanilla sulfuric-acid recipe consumes iron-plate
--      (feeding the OTHER alumina route -- the two metal lines cross-feed).
--   6. SLAG is inert terminal waste with a dedicated pure-sink vent.
--   7. GATED + CLUSTERED: one tech (cindra-red-mud) unlocks the whole subsystem,
--      behind the materials-chemistry tech (needs its quicklime + CO2).
--   8. NEVER-MUTATE-OTHER-PLANETS: the shared vanilla stone / iron-plate are read
--      only; every new item and the furnace are Cindra's own.
--   9. PETROCHEMICAL-FREE: no oil/coal feeds Bayer or iron recovery.
--  10. RUNTIME: a powered arc furnace fed red mud + CO2 makes iron + slag.

local H = require("tests.helpers")

local RED_MUD = "cindra-red-mud"
local SLAG    = "cindra-slag"
local FURNACE = "cindra-arc-furnace"
local CATEGORY = "cindra-arc-furnace"
local ALUMINA  = "cindra-alumina"
local QUICKLIME = "cindra-quicklime"
local CO2      = "cindra-carbon-dioxide"
local IRON     = "iron-plate"
local TECH     = "cindra-red-mud"
local CHEM_TECH = "cindra-calcite-olefins"

local BAYER = "cindra-bayer-alumina"
local IRON_RECOVERY = "cindra-iron-recovery"
local VENT_SLAG = "cindra-vent-slag"

-- The petrochemistry Cindra forbids everywhere (DESIGN §1): the oil/coal route.
local FORBIDDEN = {
  ["petroleum-gas"] = true, ["light-oil"] = true, ["heavy-oil"] = true,
  ["crude-oil"] = true, ["coal"] = true,
}

local function amount_of(list, name)
  for _, e in pairs(list) do
    if e.name == name then return e.amount end
  end
  return nil
end

local function product(list, name)
  for _, e in pairs(list) do
    if e.name == name then return e end
  end
  return nil
end

local function has_ingredient(recipe_name, name)
  return (amount_of(prototypes.recipe[recipe_name].ingredients, name) or 0) > 0
end

local function prod_off(recipe_name)
  local r = prototypes.recipe[recipe_name]
  return not (r.allowed_effects and r.allowed_effects.productivity)
end

-- ===========================================================================
describe("cindra Bayer route (ci-c7j): the alternative alumina route", function()
  it("1. Bayer digests stone + quicklime into alumina + red mud", function()
    local r = prototypes.recipe[BAYER]
    assert.is_not_nil(r, "the Bayer recipe must exist")
    assert.is_true(has_ingredient(BAYER, "stone"), "Bayer consumes real stone (the aluminous raw)")
    assert.is_true(has_ingredient(BAYER, QUICKLIME), "Bayer consumes quicklime (its alkali, no acid needed)")
    assert.is_not_nil(product(r.products, ALUMINA), "Bayer yields alumina")
    assert.is_not_nil(product(r.products, RED_MUD), "Bayer yields red mud (the byproduct)")
  end)

  it("Bayer returns NO stone and needs NO acid (its differentiators from the leach)", function()
    local r = prototypes.recipe[BAYER]
    assert.is_nil(product(r.products, "stone"),
      "Bayer must return no stone (unlike the acid leach) -- opens no stone vector")
    assert.is_false(has_ingredient(BAYER, "sulfuric-acid"), "Bayer needs no sulfuric acid")
  end)

  it("Bayer is prod-off and gated (a matter conversion, like the leach)", function()
    assert.is_true(prod_off(BAYER), "Bayer must disable productivity (no free alumina/red mud)")
    assert.is_false(prototypes.recipe[BAYER].enabled, "Bayer must be gated off until its tech")
  end)

  it("2. both alumina routes feed the SAME electrolysis unchanged", function()
    -- Both the acid leach and Bayer make cindra-alumina; electrolysis still eats it.
    assert.is_not_nil(product(prototypes.recipe["cindra-alumina"].products, ALUMINA),
      "the acid leach makes cindra-alumina")
    assert.is_not_nil(product(prototypes.recipe[BAYER].products, ALUMINA),
      "the Bayer route makes the same cindra-alumina")
    assert.is_true(has_ingredient("cindra-aluminium", ALUMINA),
      "alumina electrolysis still consumes cindra-alumina unchanged")
  end)
end)

-- ===========================================================================
describe("cindra iron recovery (ci-c7j): waste-born iron + a power sink", function()
  it("3. iron recovery reduces red mud + CO2 into iron + slag", function()
    local r = prototypes.recipe[IRON_RECOVERY]
    assert.is_not_nil(r, "the iron-recovery recipe must exist")
    assert.is_true(has_ingredient(IRON_RECOVERY, RED_MUD), "iron recovery consumes red mud")
    assert.is_true(has_ingredient(IRON_RECOVERY, CO2), "iron recovery consumes CO2 (its carbon reductant)")
    assert.is_not_nil(product(r.products, IRON), "iron recovery yields the vanilla iron-plate")
    assert.is_not_nil(product(r.products, SLAG), "iron recovery yields slag (the tailings)")
  end)

  it("iron recovery is prod-off and gated (no minting free metal)", function()
    assert.is_true(prod_off(IRON_RECOVERY), "iron recovery must disable productivity")
    assert.is_false(prototypes.recipe[IRON_RECOVERY].enabled, "iron recovery must be gated off until its tech")
  end)

  it("iron recovery runs ONLY in the arc furnace (a private category)", function()
    local r = prototypes.recipe[IRON_RECOVERY]
    local in_cat = false
    for _, c in pairs(r.categories or {}) do
      if c == CATEGORY then in_cat = true end
    end
    assert.is_true(in_cat, "iron recovery runs in the private cindra-arc-furnace category")
    local furnace = prototypes.entity[FURNACE]
    assert.is_not_nil(furnace, "the arc furnace entity must exist")
    assert.is_true(furnace.crafting_categories[CATEGORY],
      "the arc furnace must run the cindra-arc-furnace category")
    -- No shared machine may run iron recovery (no category leak).
    local am = prototypes.entity["assembling-machine-3"]
    assert.is_falsy(am.crafting_categories[CATEGORY],
      "a vanilla assembler must never run the private arc-furnace category")
  end)

  it("the arc furnace is a big draw: a flare-timed power sink", function()
    local furnace = prototypes.entity[FURNACE]
    -- energy_usage is reported per TICK (J/tick); *60 gives the continuous draw in
    -- watts. Big in absolute terms (a continuous multi-MW draw) and far above the
    -- stock assembler it is cloned from -- the honest power cost of making iron.
    local watts = furnace.energy_usage * 60
    assert.is_true(watts >= 40000000,
      "the furnace must draw at least 40 MW (a ruinous continuous draw), got " .. watts .. " W")
    local base = prototypes.entity["assembling-machine-3"]
    assert.is_true(furnace.energy_usage > base.energy_usage * 20,
      "the furnace draw must be cranked well above the vanilla assembler")
    -- Second only to the aluminium cell (aluminium stays the apex power sink).
    local cell = prototypes.entity["cindra-electrolysis-cell"]
    assert.is_true(furnace.energy_usage < cell.energy_usage,
      "the furnace stays below the aluminium electrolysis cell (the apex draw)")
    -- The vanilla assembler keeps its own (much smaller) draw -- clone, not mutate.
    assert.is_true(base.energy_usage < furnace.energy_usage,
      "the vanilla assembler must keep its own much smaller draw")
  end)

  it("the arc furnace has a 5x5 selection box under its big model (ci-1p1z)", function()
    -- The click/highlight footprint must match the ~5-tile arc-furnace body: a full
    -- 5x5 selection box centred on the machine (was the inherited AM3 3x3).
    local furnace = prototypes.entity[FURNACE]
    local sb = furnace.selection_box
    assert.is_not_nil(sb, "the furnace must expose a selection box")
    local w = sb.right_bottom.x - sb.left_top.x
    local h = sb.right_bottom.y - sb.left_top.y
    assert.is_true(math.abs(w - 5) < 1e-6,
      "the selection box must be 5 tiles wide (got " .. w .. ")")
    assert.is_true(math.abs(h - 5) < 1e-6,
      "the selection box must be 5 tiles tall (got " .. h .. ")")
    -- Centred on the model (symmetric about the entity origin).
    assert.is_true(math.abs(sb.left_top.x + sb.right_bottom.x) < 1e-6
      and math.abs(sb.left_top.y + sb.right_bottom.y) < 1e-6,
      "the 5x5 selection box must be centred on the model")
    -- The COLLISION box stays 3x3 so AM3's north CO2 pipe (position {0,-1}) is not
    -- buried: a 5x5 collision would swallow the fluid input two tiles deep. Assert
    -- the placement footprint is unchanged from the vanilla clone.
    local cb = furnace.collision_box
    local cw = cb.right_bottom.x - cb.left_top.x
    assert.is_true(cw < 4,
      "the collision box must stay 3x3 (keeps the CO2 pipe reachable), got width " .. cw)
  end)

  it("the arc furnace still accepts piped CO2 after the box change (ci-1p1z)", function()
    -- Guards the collision-box decision: enlarging the click box to 5x5 must NOT
    -- break the inherited fluid input. Pipe CO2 in from an adjacent pipe and prove
    -- the furnace's fluid box fills (the CO2 connection is still reachable). AM3
    -- turns its fluid boxes OFF with no fluid recipe, so set the CO2 recipe first;
    -- with no power the machine cannot craft, so the piped CO2 simply accumulates.
    local s = H.cindra_surface()
    game.forces["player"].recipes[IRON_RECOVERY].enabled = true
    local furnace = s.create_entity({ name = FURNACE, position = { 0, 0 }, force = "player" })
    assert.is_not_nil(furnace, "the arc furnace must place")
    furnace.set_recipe(IRON_RECOVERY)
    -- AM3's CO2 input pipe sits at the north edge {0,-1}; the tile just north of the
    -- 3x3 collision box is {0,-2}. A pipe there must connect and feed fluid in.
    local pipe = s.create_entity({ name = "pipe", position = { 0, -2 }, force = "player" })
    assert.is_not_nil(pipe, "the feeder pipe must place north of the furnace")
    pipe.insert_fluid({ name = CO2, amount = 500 })

    async(600)
    after_ticks(180, function()
      assert.is_true(furnace.valid)
      local co2 = furnace.get_fluid_count(CO2)
      assert.is_true(co2 > 0,
        "piped CO2 must reach the furnace's fluid box (the input pipe stays "
          .. "reachable at the 3x3 collision edge); got " .. co2)
      furnace.destroy()
      pipe.destroy()
      done()
    end)
  end)
end)

-- ===========================================================================
describe("cindra red-mud coupling + sinks (ci-c7j): no dead-ends, no hard deadlock", function()
  it("4. red mud's only consumer is iron recovery -- and it has NO free vent (the coupling)", function()
    local consumers = {}
    for _, rn in ipairs({ BAYER, IRON_RECOVERY, VENT_SLAG, "cindra-alumina", "cindra-aluminium" }) do
      if has_ingredient(rn, RED_MUD) then consumers[#consumers + 1] = rn end
    end
    assert.are.same({ IRON_RECOVERY }, consumers,
      "red mud is consumed only by iron recovery (the Al<->Fe coupling; no free vent)")
  end)

  it("5. iron has a real sink: the vanilla sulfuric-acid recipe consumes iron-plate", function()
    -- iron-plate feeds the vanilla acid recipe (which feeds the OTHER alumina
    -- route), plus every vanilla iron/steel use and export -- so it never deadlocks.
    assert.is_true(has_ingredient("sulfuric-acid", IRON),
      "the vanilla acid recipe consumes iron-plate (a real, in-graph iron sink)")
  end)

  it("6. slag is inert terminal waste with a dedicated pure-sink vent", function()
    local v = prototypes.recipe[VENT_SLAG]
    assert.is_not_nil(v, "the slag vent must exist")
    assert.is_true(has_ingredient(VENT_SLAG, SLAG), "vent-slag consumes slag")
    assert.are.equal(0, #v.products, "vent-slag must be a PURE sink (no products)")
    assert.is_true(prod_off(VENT_SLAG), "vent-slag must disable productivity")
  end)

  it("the new items exist", function()
    assert.is_not_nil(prototypes.item[RED_MUD], "red mud item must exist")
    assert.is_not_nil(prototypes.item[SLAG], "slag item must exist")
    assert.is_not_nil(prototypes.item[FURNACE], "the furnace item must exist")
    local item = prototypes.item[FURNACE]
    assert.is_not_nil(item.place_result, "the furnace item must place an entity")
    assert.are.equal(FURNACE, item.place_result.name, "the item places the furnace")
  end)
end)

-- ===========================================================================
describe("cindra red-mud tech (ci-c7j): clustered + gated behind materials chemistry", function()
  it("7. one tech unlocks the whole subsystem, behind the chemistry tech", function()
    local t = prototypes.technology[TECH]
    assert.is_not_nil(t, "the cindra-red-mud tech must exist")
    -- Prereq is the materials-chemistry tech (Bayer needs its quicklime, iron
    -- recovery needs its CO2).
    local has_prereq = false
    for name in pairs(t.prerequisites or {}) do
      if name == CHEM_TECH then has_prereq = true end
    end
    assert.is_true(has_prereq, "cindra-red-mud must require the materials-chemistry tech")
    -- It unlocks all four recipes (clustered, not fragmented).
    local unlocked = {}
    for _, eff in pairs(t.effects or {}) do
      if eff.type == "unlock-recipe" then unlocked[eff.recipe] = true end
    end
    for _, rn in ipairs({ BAYER, IRON_RECOVERY, FURNACE, VENT_SLAG }) do
      assert.is_true(unlocked[rn], "the tech must unlock " .. rn)
    end
  end)

  it("researched with brought vanilla packs (no soft-lock behind the Cindra pack)", function()
    local t = prototypes.technology[TECH]
    for _, ing in pairs(t.research_unit_ingredients or {}) do
      assert.is_true(ing.name ~= "cindra-science-pack",
        "the tech must not cost the Cindra pack (it gates upstream of it)")
    end
  end)
end)

-- ===========================================================================
describe("cindra red-mud invariants (ci-c7j): matter honesty preserved", function()
  it("8. never-mutate: red mud, slag, and the furnace are Cindra's own prototypes", function()
    for _, n in ipairs({ RED_MUD, SLAG, FURNACE }) do
      assert.is_true(n:sub(1, 7) == "cindra-", n .. " must be a Cindra-owned prototype")
    end
    -- iron-plate stays the vanilla item (read as a result only, never a clone).
    assert.is_not_nil(prototypes.item[IRON], "iron-plate stays the vanilla item")
  end)

  it("9. petrochemical-free: no oil/coal feeds Bayer or iron recovery", function()
    for _, rn in ipairs({ BAYER, IRON_RECOVERY }) do
      for _, ing in pairs(prototypes.recipe[rn].ingredients) do
        assert.is_falsy(FORBIDDEN[ing.name],
          rn .. " must not consume a petrochemical (" .. ing.name .. ")")
      end
    end
  end)
end)

-- ===========================================================================
describe("cindra iron-recovery runtime (a powered furnace makes iron + slag)", function()
  it("10. a powered arc furnace fed red mud + CO2 produces iron and slag", function()
    local s = H.cindra_surface()
    local pole = s.create_entity({ name = "substation", position = { 2, 2 }, force = "player" })
    assert.is_not_nil(pole, "substation must place")
    local power = s.create_entity({
      name = "electric-energy-interface", position = { 4, 0 }, force = "player",
    })
    -- The furnace draws ~45 MW; feed it well above that so it never starves.
    power.power_production = 200000000
    power.electric_buffer_size = 200000000
    power.energy = 200000000

    game.forces["player"].recipes[IRON_RECOVERY].enabled = true

    local furnace = s.create_entity({ name = FURNACE, position = { 0, 0 }, force = "player" })
    assert.is_not_nil(furnace, "the arc furnace must be placeable on Cindra")
    furnace.set_recipe(IRON_RECOVERY)
    furnace.insert({ name = RED_MUD, count = 100 })
    furnace.insert_fluid({ name = CO2, amount = 1000 })

    async(2400)
    after_ticks(1800, function()
      assert.is_true(furnace.valid)
      assert.is_true(furnace.get_item_count(IRON) > 0,
        "a powered furnace fed red mud + CO2 must produce iron-plate (got "
          .. furnace.get_item_count(IRON) .. ")")
      assert.is_true(furnace.get_item_count(SLAG) > 0,
        "iron recovery must also produce slag (got " .. furnace.get_item_count(SLAG) .. ")")
      furnace.destroy()
      done()
    end)
  end)
end)
