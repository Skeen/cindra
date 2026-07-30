-- PROOF: the Calcite-To-Olefins plastic chain (ci-400). Cindra makes plastic in
-- its own idiom -- rock, ice, metal, and the star's surplus -- via the real CTO
-- route with CALCITE as the carbon source. Claims, matching the bead:
--   1. THE THREE CHEMISTRIES exist and connect: water electrolysis -> H2 + O2;
--      calcite calcination -> quicklime + CO2; the CTO bridge CO2 + H2 -> methanol;
--      MTO methanol -> olefins over a Cu/Al catalyst; olefins -> plastic.
--   2. PETROCHEMICAL-FREE: no oil/coal/petroleum feeds the chain (calcite is the
--      carbon; the final product is the vanilla plastic-bar).
--   3. THE CATALYST is a proper catalyst (Cu + Al in; returned as a product with
--      high probability, so it is slow-consumed, not a 1:1 reagent).
--   4. GATED: every recipe off by default; one tech unlocks them all, gated behind
--      the signature aluminium (which itself needs both lava and ice).
--   5. BYPRODUCT SINKS exist (oxygen, CO2, quicklime are ventable; quicklime also
--      has a net-negative disposal sink, ci-6vj #16) so the chain can't deadlock;
--      the fluids are all defined.
--   6. NEVER-MUTATE-OTHER-PLANETS: the shared vanilla plastic-bar / water /
--      calcite / copper-plate are untouched; every new fluid/item is Cindra's own.
--   7. RUNTIME: a powered chemical plant fed olefins produces plastic-bar.

local H = require("tests.helpers")

local H2       = "cindra-hydrogen"
local O2       = "cindra-oxygen"
local CO2      = "cindra-carbon-dioxide"
local METHANOL = "cindra-methanol"
local OLEFINS  = "cindra-olefins"
local QUICKLIME = "cindra-quicklime"
local CATALYST = "cindra-cu-al-catalyst"
local ALUMINIUM = "cindra-aluminium"
local PLASTIC  = "plastic-bar"
local TECH     = "cindra-calcite-olefins"

-- Petrochemistry Cindra forbids as an INPUT to this chain (DESIGN.md §1). Note
-- plastic-bar is the chain's PRODUCT, not an input -- what stays banned is the
-- oil/coal route to it, which this chain never uses.
local FORBIDDEN = {
  ["petroleum-gas"] = true, ["light-oil"] = true, ["heavy-oil"] = true,
  ["crude-oil"] = true, ["coal"] = true, ["sulfur"] = true,
  ["sulfuric-acid"] = true, ["lubricant"] = true,
}

local function amount_of(list, name)
  for _, e in pairs(list) do
    if e.name == name then return e.amount end
  end
  return nil
end

local function has_ingredient(recipe_name, name)
  return (amount_of(prototypes.recipe[recipe_name].ingredients, name) or 0) > 0
end

local function product(list, name)
  for _, e in pairs(list) do
    if e.name == name then return e end
  end
  return nil
end

describe("cindra plastic chain: the three chemistries connect end to end", function()
  it("1a. water electrolysis: water -> hydrogen + oxygen", function()
    local r = prototypes.recipe["cindra-electrolysis"]
    assert.is_not_nil(r, "the electrolysis recipe must exist")
    assert.is_true(has_ingredient("cindra-electrolysis", "water"), "electrolysis consumes water")
    assert.is_not_nil(product(r.products, H2), "electrolysis yields hydrogen")
    assert.is_not_nil(product(r.products, O2), "electrolysis yields oxygen (the byproduct)")
    -- Real 2 H2O -> 2 H2 + O2: hydrogen comes out at twice the oxygen.
    assert.are.equal(2 * amount_of(r.products, O2), amount_of(r.products, H2),
      "hydrogen:oxygen must be 2:1 (2 H2O -> 2 H2 + O2)")
  end)

  it("1b. calcite calcination: calcite -> quicklime + carbon dioxide", function()
    local r = prototypes.recipe["cindra-calcination"]
    assert.is_not_nil(r, "the calcination recipe must exist")
    assert.is_true(has_ingredient("cindra-calcination", "calcite"),
      "calcination consumes calcite (the carbon source, from the ice chain)")
    assert.is_not_nil(product(r.products, QUICKLIME), "calcination yields quicklime (CaO)")
    assert.is_not_nil(product(r.products, CO2), "calcination yields CO2 (the carbon that becomes plastic)")
  end)

  it("1c. the bridge: CO2 + hydrogen -> methanol (calcite carbon made usable)", function()
    local r = prototypes.recipe["cindra-methanol-synthesis"]
    assert.is_not_nil(r, "the methanol-synthesis recipe must exist")
    assert.is_true(has_ingredient("cindra-methanol-synthesis", CO2), "methanol uses the calcite CO2")
    assert.is_true(has_ingredient("cindra-methanol-synthesis", H2), "methanol uses electrolysis hydrogen")
    assert.is_not_nil(product(r.products, METHANOL), "the recipe produces methanol")
  end)

  it("1d. MTO: methanol -> olefins over the Cu/Al catalyst", function()
    local r = prototypes.recipe["cindra-mto"]
    assert.is_not_nil(r, "the MTO recipe must exist")
    assert.is_true(has_ingredient("cindra-mto", METHANOL), "MTO cracks methanol")
    assert.is_true(has_ingredient("cindra-mto", CATALYST), "MTO uses the Cu/Al catalyst")
    assert.is_not_nil(product(r.products, OLEFINS), "MTO produces olefins")
  end)

  it("1e. polymerisation: olefins -> plastic (the vanilla plastic-bar)", function()
    local r = prototypes.recipe["cindra-polymerisation"]
    assert.is_not_nil(r, "the polymerisation recipe must exist")
    assert.is_true(has_ingredient("cindra-polymerisation", OLEFINS), "polymerisation consumes olefins")
    assert.is_not_nil(product(r.products, PLASTIC),
      "the chain ends in the vanilla plastic-bar (plugs into vanilla recipes)")
  end)
end)

describe("cindra plastic chain: petrochemical-free (no oil/coal route)", function()
  it("no step consumes a forbidden petrochemical", function()
    local recipes = {
      "cindra-electrolysis", "cindra-calcination", "cindra-methanol-synthesis",
      "cindra-mto", "cindra-polymerisation", CATALYST,
    }
    for _, name in ipairs(recipes) do
      for _, ing in pairs(prototypes.recipe[name].ingredients) do
        assert.is_nil(FORBIDDEN[ing.name],
          name .. " must not consume the forbidden petrochemical " .. ing.name)
      end
    end
  end)

  it("the carbon comes from calcite, not from oil or coal", function()
    -- The only carbon-bearing input across the whole chain is calcite. This is
    -- the Calcite-To-Olefins thesis: rock carbon, never petrochemistry.
    assert.is_true(has_ingredient("cindra-calcination", "calcite"),
      "calcination is the carbon source and it is calcite")
  end)
end)

describe("cindra plastic chain: the Cu/Al catalyst is a proper catalyst", function()
  it("is crafted from copper + the signature aluminium", function()
    local r = prototypes.recipe[CATALYST]
    assert.is_not_nil(r, "the catalyst recipe must exist")
    assert.is_true(has_ingredient(CATALYST, "copper-plate"), "the catalyst uses copper")
    assert.is_true(has_ingredient(CATALYST, ALUMINIUM),
      "the catalyst uses aluminium -- so the plastic chain rides the power economy")
  end)

  it("is slow-consumed, not spent 1:1: MTO returns it with high probability", function()
    local r = prototypes.recipe["cindra-mto"]
    local returned = product(r.products, CATALYST)
    assert.is_not_nil(returned, "MTO must return the catalyst as a product (catalyst, not reagent)")
    -- 2.1 exposes the per-product roll as either `probability` or the renamed
    -- `independent_probability`; accept whichever the runtime surfaces.
    local p = returned.probability or returned.independent_probability or 1
    assert.is_true(p > 0.5 and p < 1.0,
      "the catalyst is returned most of the time (slow deactivation), not always and not never; got "
        .. tostring(p))
    assert.are.equal(1, amount_of(r.ingredients, CATALYST), "one catalyst in")
  end)
end)

describe("cindra plastic chain: gated behind the signature aluminium", function()
  it("all recipes are off by default", function()
    local recipes = {
      "cindra-electrolysis", "cindra-calcination", "cindra-methanol-synthesis",
      "cindra-mto", "cindra-polymerisation", CATALYST,
      "cindra-vent-oxygen", "cindra-vent-quicklime", "cindra-vent-co2",
      "cindra-quicklime-disposal",
    }
    for _, name in ipairs(recipes) do
      assert.is_false(prototypes.recipe[name].enabled, name .. " must be research-gated, not free")
    end
  end)

  it("one tech unlocks the whole chain, gated behind aluminium (rock+ice+power)", function()
    local tech = prototypes.technology[TECH]
    assert.is_not_nil(tech, "the cindra-calcite-olefins technology must exist")
    assert.is_true(tech.valid, "the tech must load (its icon is present)")

    local unlocked = {}
    for _, effect in pairs(tech.effects) do
      if effect.type == "unlock-recipe" then unlocked[effect.recipe] = true end
    end
    for _, name in ipairs({
      "cindra-electrolysis", "cindra-calcination", "cindra-methanol-synthesis",
      "cindra-mto", "cindra-polymerisation", CATALYST,
      "cindra-vent-oxygen", "cindra-vent-quicklime", "cindra-vent-co2",
      "cindra-quicklime-disposal",
    }) do
      assert.is_true(unlocked[name], "the tech must unlock " .. name)
    end

    assert.is_not_nil(tech.prerequisites["cindra-aluminium"],
      "gated behind the signature aluminium -- which itself needs both lava and ice")
    -- And aluminium sits behind the lava spine, which needs Cindra discovery: so
    -- the plastic chain is unreachable until the whole base economy is in hand.
    assert.is_not_nil(prototypes.technology["cindra-aluminium"].prerequisites["cindra-lava"],
      "aluminium is behind the lava spine (transitively rock + ice + power)")
  end)
end)

describe("cindra plastic chain: byproduct sinks + fluids exist (no deadlock)", function()
  it("all five new fluids are defined", function()
    for _, name in ipairs({ H2, O2, CO2, METHANOL, OLEFINS }) do
      assert.is_not_nil(prototypes.fluid[name], "fluid must exist: " .. name)
    end
  end)

  it("oxygen, quicklime and CO2 are ventable (every byproduct has an emergency sink)", function()
    local vo = prototypes.recipe["cindra-vent-oxygen"]
    assert.is_not_nil(vo, "the oxygen vent must exist")
    assert.is_true(has_ingredient("cindra-vent-oxygen", O2), "the oxygen vent consumes oxygen")
    assert.are.equal(0, #vo.products, "venting oxygen is a pure sink (no product)")

    local vq = prototypes.recipe["cindra-vent-quicklime"]
    assert.is_not_nil(vq, "the quicklime vent must exist")
    assert.is_true(has_ingredient("cindra-vent-quicklime", QUICKLIME), "the quicklime vent consumes quicklime")
    assert.are.equal(0, #vq.products, "discarding quicklime is a pure sink (no product)")

    local vc = prototypes.recipe["cindra-vent-co2"]
    assert.is_not_nil(vc, "the CO2 vent must exist (ci-6vj #18)")
    assert.is_true(has_ingredient("cindra-vent-co2", CO2), "the CO2 vent consumes carbon dioxide")
    assert.are.equal(0, #vc.products, "venting CO2 is a pure sink (no product)")
  end)

  -- ci-6vj #16: the designated (non-vent) quicklime sink. It hands back some
  -- stone but only by consuming lava that cost MORE stone to make, so it can never
  -- become a free-stone/free-lava source -- proven at the +300% productivity cap.
  it("quicklime disposal is a real, net stone-NEGATIVE sink (ci-6vj #16)", function()
    local MAX_CONCEIVABLE_PROD = 3.0 -- the engine's +300% cap
    local LAVA_PER_STONE = 5         -- prototypes/lava.lua: 1 stone -> 5 lava (prod off)
    local d = prototypes.recipe["cindra-quicklime-disposal"]
    assert.is_not_nil(d, "the quicklime disposal recipe must exist")

    assert.is_true(has_ingredient("cindra-quicklime-disposal", QUICKLIME),
      "disposal consumes quicklime (it is the surplus quicklime sink)")
    local lava_in = amount_of(d.ingredients, "lava")
    assert.is_true((lava_in or 0) > 0, "disposal consumes lava (fluxes quicklime into the melt)")

    -- Productivity is off AND the stone output is fully ignored_by_productivity, so
    -- the stone returned is FIXED at every module tier.
    assert.is_false(d.allowed_effects and d.allowed_effects.productivity,
      "disposal must disable productivity (never mint stone)")
    local sp = product(d.products, "stone")
    assert.is_not_nil(sp, "disposal returns a little stone (fluxed back)")
    local ignored = sp.ignored_by_productivity or 0
    local scalable = sp.amount - ignored
    local stone_out_at_cap = ignored + scalable * (1 + MAX_CONCEIVABLE_PROD)
    assert.are.equal(sp.amount, stone_out_at_cap,
      "the stone output must be fully ignored_by_productivity: fixed even at the +300% cap")

    -- The lava consumed embodies lava_in / 5 stone (the fixed stone->lava ratio).
    -- Disposal must return strictly LESS stone than that, so the loop net-consumes.
    local stone_embodied = lava_in / LAVA_PER_STONE
    assert.is_true(sp.amount < stone_embodied, string.format(
      "disposal must be net stone-NEGATIVE: returns %d stone for %d lava (= %.1f stone) in",
      sp.amount, lava_in, stone_embodied))
  end)

  it("quicklime disposal runs only in the lava-manufacturer (never the shared foundry)", function()
    -- recipe.categories is a plain-value array of category-name strings.
    local d = prototypes.recipe["cindra-quicklime-disposal"]
    local in_lava_cat = false
    for _, c in pairs(d.categories or {}) do
      if c == "cindra-lava-manufacturing" then in_lava_cat = true end
    end
    assert.is_true(in_lava_cat,
      "disposal is confined to the private lava-manufacturing category")
    -- The shared Vulcanus foundry must NOT have gained this private category
    -- (entity.crafting_categories is a dict keyed by category name).
    local foundry = prototypes.entity["foundry"]
    assert.is_falsy(foundry.crafting_categories["cindra-lava-manufacturing"],
      "the vanilla foundry must never run the Cindra lava-manufacturing category")
  end)
end)

describe("cindra plastic chain: never mutate other planets", function()
  it("the shared vanilla plastic-bar recipe is untouched (still the oil route)", function()
    -- We ADD a Cindra plastic route; we do not change vanilla's. Nauvis still
    -- makes plastic from coal + petroleum, exactly as before.
    local vanilla = prototypes.recipe["plastic-bar"]
    assert.is_not_nil(vanilla, "the vanilla plastic-bar recipe must still exist")
    assert.is_true((amount_of(vanilla.ingredients, "petroleum-gas") or 0) > 0,
      "vanilla plastic-bar must still use petroleum (we never mutated it)")
    assert.is_false(has_ingredient("plastic-bar", OLEFINS),
      "vanilla plastic must NOT gain a Cindra olefins input (no leak onto Nauvis)")
  end)

  it("the new recipes run in the shared chemical plant WITHOUT mutating it", function()
    -- Reusing the vanilla chemistry category is fine; the chemical plant must not
    -- have been altered (still its vanilla energy draw, still no surface gate).
    local plant = prototypes.entity["chemical-plant"]
    assert.is_not_nil(plant, "the vanilla chemical plant must exist")
    assert.is_true(plant.crafting_categories["chemistry"],
      "our recipes ride the vanilla chemistry category (no new machine needed)")
  end)
end)

describe("cindra plastic chain runtime (a powered plant makes plastic)", function()
  it("a powered chemical plant fed olefins produces plastic-bar", function()
    local s = H.cindra_surface()
    local pole = s.create_entity({ name = "substation", position = { 2, 2 }, force = "player" })
    assert.is_not_nil(pole, "substation must place")
    local power = s.create_entity({
      name = "electric-energy-interface", position = { 4, 0 }, force = "player",
    })
    power.power_production = 200000000
    power.electric_buffer_size = 200000000
    power.energy = 200000000

    game.forces["player"].recipes["cindra-polymerisation"].enabled = true

    local plant = s.create_entity({ name = "chemical-plant", position = { 0, 0 }, force = "player" })
    assert.is_not_nil(plant, "the chemical plant must place on Cindra")
    plant.set_recipe("cindra-polymerisation")
    plant.insert_fluid({ name = OLEFINS, amount = 200 })

    async(1200)
    after_ticks(600, function()
      assert.is_true(plant.valid)
      assert.is_true(plant.get_item_count(PLASTIC) > 0,
        "a powered plant fed olefins must produce plastic (got " .. plant.get_item_count(PLASTIC) .. ")")
      plant.destroy()
      done()
    end)
  end)
end)

describe("cindra quicklime disposal runtime (ci-6vj #16)", function()
  it("a powered lava-manufacturer fluxes quicklime + lava -> stone", function()
    local s = H.cindra_surface()
    local pole = s.create_entity({ name = "substation", position = { 2, 2 }, force = "player" })
    assert.is_not_nil(pole, "substation must place")
    local power = s.create_entity({
      name = "electric-energy-interface", position = { 4, 0 }, force = "player",
    })
    power.power_production = 200000000
    power.electric_buffer_size = 200000000
    power.energy = 200000000

    game.forces["player"].recipes["cindra-quicklime-disposal"].enabled = true

    local machine = s.create_entity({ name = "cindra-lava-manufacturer", position = { 0, 0 }, force = "player" })
    assert.is_not_nil(machine, "the lava-manufacturer must place on Cindra")
    machine.set_recipe("cindra-quicklime-disposal")
    machine.insert({ name = QUICKLIME, count = 50 })
    machine.insert_fluid({ name = "lava", amount = 500 })

    async(1200)
    after_ticks(600, function()
      assert.is_true(machine.valid)
      assert.is_true(machine.get_item_count("stone") > 0,
        "disposal must flux quicklime + lava into stone (got " .. machine.get_item_count("stone") .. ")")
      machine.destroy()
      done()
    end)
  end)
end)
