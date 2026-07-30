-- PROOF: Cindra's petrochemical-free PLASTIC chain, reconciled to the
-- authoritative recipe graph (DESIGN §8, ci-6vj S4). Cindra makes plastic in its
-- own idiom -- rock, ice, metal, and the star's surplus -- via the real MTO route
-- with CALCITE as the carbon source, over TWO distinct catalyst systems. Claims:
--   1. THE CHEMISTRIES connect: water electrolysis -> H2 + O2; calcite
--      calcination -> quicklime + CO2 (in the lava manufacturer); methanol
--      synthesis CO2 + H2 -(methanol catalyst)-> methanol; MTO+polymerisation
--      methanol -(zeolite catalyst)-> the vanilla plastic-bar (ONE step).
--   2. PETROCHEMICAL-FREE: no oil/coal/petroleum feeds the chain (calcite is the
--      carbon; the final product is the vanilla plastic-bar).
--   3. TWO TRUE CATALYSTS: methanol synthesis and MTO each take exactly one
--      catalyst and return it 70% intact + 20% spent (independent rolls), so it is
--      slow-consumed, never a 1:1 reagent. Each catalyst is made from the
--      signature alumina, and each spent form reprocesses/regenerates back.
--   4. THE ci-400 SINGLE-CATALYST GRAPH IS GONE: no cindra-olefins fluid, no
--      cindra-cu-al-catalyst item, no separate cindra-mto / cindra-polymerisation.
--   5. GATED: every recipe off by default; one tech unlocks them all, behind the
--      signature aluminium (which itself needs both lava and ice).
--   6. BYPRODUCT SINKS exist (oxygen, CO2, quicklime ventable; quicklime also has
--      a net-negative disposal sink, ci-6vj #16) so the chain can't deadlock.
--   7. NEVER-MUTATE-OTHER-PLANETS: the shared vanilla plastic-bar / water /
--      calcite / copper-plate are untouched; every new fluid/item is Cindra's own.
--   8. RUNTIME: a powered chemical plant fed methanol + the zeolite catalyst
--      produces plastic-bar.

local H = require("tests.helpers")

local H2       = "cindra-hydrogen"
local O2       = "cindra-oxygen"
local CO2      = "cindra-carbon-dioxide"
local METHANOL = "cindra-methanol"
local QUICKLIME = "cindra-quicklime"
local ALUMINA  = "cindra-alumina"
local MCAT       = "cindra-methanol-catalyst"
local MCAT_SPENT = "cindra-spent-methanol-catalyst"
local ZCAT       = "cindra-zeolite-catalyst"
local ZCAT_SPENT = "cindra-spent-zeolite-catalyst"
local PLASTIC  = "plastic-bar"
local TECH     = "cindra-calcite-olefins"

-- The petrochemistry Cindra forbids anywhere in the plastic chain (DESIGN §1):
-- the oil/coal route. (sulfur / sulfuric-acid are NOT petrochemicals -- they come
-- from stone melting per DESIGN §8.3 Option B and legitimately feed catalyst
-- reprocessing -- so they are not on this list.)
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

local function has_ingredient(recipe_name, name)
  return (amount_of(prototypes.recipe[recipe_name].ingredients, name) or 0) > 0
end

local function product(list, name)
  for _, e in pairs(list) do
    if e.name == name then return e end
  end
  return nil
end

-- The per-product independent roll (2.1 exposes it as `probability` or the
-- renamed `independent_probability`); accept whichever the runtime surfaces.
local function roll(p) return (p.probability or p.independent_probability or 1) end

-- Every matter-conversion / catalyst recipe on the chain -- all prod OFF.
local CONVERSION_RECIPES = {
  "cindra-electrolysis", "cindra-calcination", "cindra-methanol-synthesis",
  MCAT, "cindra-methanol-catalyst-reprocessing",
  "cindra-mto-polymerisation", ZCAT, "cindra-zeolite-catalyst-regeneration",
}

describe("cindra plastic chain: the chemistries connect end to end", function()
  it("1a. water electrolysis: water -> hydrogen + oxygen (2:1)", function()
    local r = prototypes.recipe["cindra-electrolysis"]
    assert.is_not_nil(r, "the electrolysis recipe must exist")
    assert.is_true(has_ingredient("cindra-electrolysis", "water"), "electrolysis consumes water")
    assert.is_not_nil(product(r.products, H2), "electrolysis yields hydrogen")
    assert.is_not_nil(product(r.products, O2), "electrolysis yields oxygen (the byproduct)")
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

  -- ci-6vj S3: calcination is a ROAST in the high-heat lava manufacturer.
  it("1b'. calcination roasts in the lava manufacturer, not the chemical plant (ci-6vj S3)", function()
    local r = prototypes.recipe["cindra-calcination"]
    assert.is_not_nil(r, "the calcination recipe must exist")

    local in_lava_cat, in_chem_cat = false, false
    for _, c in pairs(r.categories or {}) do
      if c == "cindra-lava-manufacturing" then in_lava_cat = true end
      if c == "chemistry" then in_chem_cat = true end
    end
    assert.is_true(in_lava_cat,
      "calcination runs in the private lava-manufacturing category (the LM roaster)")
    assert.is_false(in_chem_cat,
      "calcination must NOT run in chemistry -- it is a roast, moved to the LM")

    local lm = prototypes.entity["cindra-lava-manufacturer"]
    assert.is_not_nil(lm, "the lava manufacturer entity must exist")
    assert.is_true(lm.crafting_categories["cindra-lava-manufacturing"],
      "the lava manufacturer must run the lava-manufacturing category (so it can calcine)")
    local foundry = prototypes.entity["foundry"]
    assert.is_falsy(foundry.crafting_categories["cindra-lava-manufacturing"],
      "the vanilla foundry must never run the Cindra lava-manufacturing category")

    assert.is_false(has_ingredient("cindra-calcination", "lava"),
      "calcination uses electric heat, not a lava input")
    assert.is_nil(product(r.products, "stone"),
      "calcination emits no stone (keeps the stone balance proof simple)")

    assert.are.equal(2, amount_of(r.ingredients, "calcite"), "2 calcite in")
    assert.are.equal(2, amount_of(r.products, QUICKLIME), "2 quicklime out")
    assert.are.equal(40, amount_of(r.products, CO2), "40 CO2 out (the carbon feed)")

    assert.is_false(r.allowed_effects and r.allowed_effects.productivity,
      "calcination must disable productivity (no free CO2)")
  end)

  -- DESIGN §8.2 #10: 20 CO2 + 60 H2 + 1 methanol-catalyst -> 20 methanol + 20 water.
  it("1c. methanol synthesis: CO2 + hydrogen + methanol-catalyst -> methanol (+ water)", function()
    local r = prototypes.recipe["cindra-methanol-synthesis"]
    assert.is_not_nil(r, "the methanol-synthesis recipe must exist")
    assert.are.equal(20, amount_of(r.ingredients, CO2), "20 CO2 in (the calcite carbon)")
    assert.are.equal(60, amount_of(r.ingredients, H2), "60 H2 in (electrolysis hydrogen)")
    assert.are.equal(1, amount_of(r.ingredients, MCAT), "1 methanol catalyst in")
    assert.are.equal(20, amount_of(r.products, METHANOL), "20 methanol out")
    assert.are.equal(20, amount_of(r.products, "water"), "20 water recovered (loops back)")
  end)

  -- DESIGN §8.2 #13: 40 methanol + 1 zeolite-catalyst -> 2 plastic-bar + 40 water.
  -- MTO and polymerisation are ONE recipe now (no separate olefins intermediate).
  it("1d. MTO+polymerisation: methanol + zeolite-catalyst -> plastic-bar (+ water), one step", function()
    local r = prototypes.recipe["cindra-mto-polymerisation"]
    assert.is_not_nil(r, "the MTO+polymerisation recipe must exist")
    assert.are.equal(40, amount_of(r.ingredients, METHANOL), "40 methanol in")
    assert.are.equal(1, amount_of(r.ingredients, ZCAT), "1 zeolite catalyst in")
    assert.are.equal(2, amount_of(r.products, PLASTIC),
      "2 vanilla plastic-bar out (plugs straight into vanilla recipes)")
    assert.are.equal(40, amount_of(r.products, "water"), "40 water recovered (loops back)")
  end)
end)

describe("cindra plastic chain: petrochemical-free (no oil/coal route)", function()
  it("no chain recipe consumes a forbidden petrochemical", function()
    for _, name in ipairs(CONVERSION_RECIPES) do
      for _, ing in pairs(prototypes.recipe[name].ingredients) do
        assert.is_nil(FORBIDDEN[ing.name],
          name .. " must not consume the forbidden petrochemical " .. ing.name)
      end
    end
  end)

  it("the carbon comes from calcite, not from oil or coal", function()
    assert.is_true(has_ingredient("cindra-calcination", "calcite"),
      "calcination is the carbon source and it is calcite")
  end)
end)

describe("cindra plastic chain: two TRUE catalyst systems (ci-6vj S4)", function()
  -- A true catalyst: exactly one in; returned ~70% intact + ~20% spent, each on
  -- its own independent roll -- so ~10% net loss per craft, topped up by the make.
  local function assert_true_catalyst(recipe_name, live, spent)
    local r = prototypes.recipe[recipe_name]
    assert.is_not_nil(r, recipe_name .. " must exist")
    assert.are.equal(1, amount_of(r.ingredients, live), "exactly one catalyst in: " .. live)

    local ret = product(r.products, live)
    assert.is_not_nil(ret, recipe_name .. " must return the live catalyst as a product")
    local pr = roll(ret)
    assert.is_true(pr > 0.5 and pr < 1.0,
      "the catalyst is returned most of the time (slow deactivation), got " .. tostring(pr))

    local sp = product(r.products, spent)
    assert.is_not_nil(sp, recipe_name .. " must produce the SPENT catalyst as a product")
    local ps = roll(sp)
    assert.is_true(ps > 0.0 and ps < 0.5,
      "the spent catalyst is the minority roll, got " .. tostring(ps))

    -- Real deactivation: returned + spent must together be < 1 (a net loss/craft).
    assert.is_true(pr + ps < 1.0,
      "return + spent probabilities must sum below 1 (a real make-up feed): got "
        .. tostring(pr + ps))
  end

  it("methanol synthesis uses the methanol catalyst as a real catalyst", function()
    assert_true_catalyst("cindra-methanol-synthesis", MCAT, MCAT_SPENT)
  end)

  it("MTO+polymerisation uses the zeolite catalyst as a real catalyst", function()
    assert_true_catalyst("cindra-mto-polymerisation", ZCAT, ZCAT_SPENT)
  end)

  -- DESIGN §8.2 #11: methanol catalyst = 10 copper + 2 alumina.
  it("the methanol catalyst is made from copper + the signature alumina", function()
    local r = prototypes.recipe[MCAT]
    assert.is_not_nil(r, "the methanol-catalyst make recipe must exist")
    assert.are.equal(10, amount_of(r.ingredients, "copper-plate"), "10 copper in")
    assert.are.equal(2, amount_of(r.ingredients, ALUMINA), "2 alumina in (rides the power economy)")
    assert.are.equal(1, amount_of(r.products, MCAT), "makes one methanol catalyst")
  end)

  -- DESIGN §8.2 #14: zeolite catalyst = 8 stone + 3 alumina + 2 quicklime + 100 steam.
  it("the zeolite catalyst consumes stone + alumina + quicklime + steam", function()
    local r = prototypes.recipe[ZCAT]
    assert.is_not_nil(r, "the zeolite-catalyst make recipe must exist")
    assert.are.equal(8, amount_of(r.ingredients, "stone"), "8 stone in")
    assert.are.equal(3, amount_of(r.ingredients, ALUMINA), "3 alumina in")
    assert.are.equal(2, amount_of(r.ingredients, QUICKLIME),
      "2 quicklime in (the zeolite is the real quicklime consumer)")
    assert.are.equal(100, amount_of(r.ingredients, "steam"), "100 steam in")
    assert.are.equal(1, amount_of(r.products, ZCAT), "makes one zeolite catalyst")
  end)

  -- DESIGN §8.2 #12: reprocess spent methanol catalyst = + 20 sulfuric-acid -> 6 copper + 1 alumina.
  it("the spent methanol catalyst reprocesses back (never a dead item)", function()
    local r = prototypes.recipe["cindra-methanol-catalyst-reprocessing"]
    assert.is_not_nil(r, "the methanol-catalyst reprocessing recipe must exist")
    assert.are.equal(1, amount_of(r.ingredients, MCAT_SPENT), "1 spent methanol catalyst in")
    assert.are.equal(20, amount_of(r.ingredients, "sulfuric-acid"), "20 sulfuric-acid in")
    assert.are.equal(6, amount_of(r.products, "copper-plate"), "6 copper recovered")
    assert.are.equal(1, amount_of(r.products, ALUMINA), "1 alumina recovered")
  end)

  -- DESIGN §8.2 #15: regenerate spent zeolite catalyst = + 20 O2 -> 1 zeolite catalyst.
  it("the spent zeolite catalyst regenerates back (a real O2 sink)", function()
    local r = prototypes.recipe["cindra-zeolite-catalyst-regeneration"]
    assert.is_not_nil(r, "the zeolite-catalyst regeneration recipe must exist")
    assert.are.equal(1, amount_of(r.ingredients, ZCAT_SPENT), "1 spent zeolite catalyst in")
    assert.are.equal(20, amount_of(r.ingredients, O2), "20 oxygen in (burns off the coke)")
    assert.are.equal(1, amount_of(r.products, ZCAT), "regenerates one live zeolite catalyst")
  end)
end)

describe("cindra plastic chain: the ci-400 single-catalyst graph is gone", function()
  it("the cindra-olefins fluid no longer exists", function()
    assert.is_nil(prototypes.fluid["cindra-olefins"],
      "the olefins intermediate is removed -- MTO+polymerisation is one step")
  end)

  it("the cindra-cu-al-catalyst item no longer exists", function()
    assert.is_nil(prototypes.item["cindra-cu-al-catalyst"],
      "the single Cu/Al catalyst is replaced by the methanol + zeolite pair")
  end)

  it("the separate MTO and polymerisation recipes no longer exist", function()
    assert.is_nil(prototypes.recipe["cindra-mto"], "cindra-mto is folded into mto-polymerisation")
    assert.is_nil(prototypes.recipe["cindra-polymerisation"],
      "cindra-polymerisation is folded into mto-polymerisation")
  end)
end)

describe("cindra plastic chain: productivity is OFF on every conversion (matter honesty)", function()
  it("no conversion or catalyst recipe allows productivity", function()
    for _, name in ipairs(CONVERSION_RECIPES) do
      local r = prototypes.recipe[name]
      assert.is_false(r.allowed_effects and r.allowed_effects.productivity,
        name .. " must disable productivity (no minting free carbon/metal/plastic)")
    end
  end)
end)

describe("cindra plastic chain: gated behind the signature aluminium", function()
  local GATED_RECIPES = {
    "cindra-electrolysis", "cindra-calcination", "cindra-methanol-synthesis",
    MCAT, "cindra-methanol-catalyst-reprocessing",
    "cindra-mto-polymerisation", ZCAT, "cindra-zeolite-catalyst-regeneration",
    "cindra-vent-oxygen", "cindra-vent-quicklime", "cindra-vent-co2",
    "cindra-quicklime-disposal",
  }

  it("all recipes are off by default", function()
    for _, name in ipairs(GATED_RECIPES) do
      assert.is_false(prototypes.recipe[name].enabled, name .. " must be research-gated, not free")
    end
  end)

  it("one tech unlocks the whole chain, gated behind aluminium (rock+ice+power)", function()
    local tech = prototypes.technology[TECH]
    assert.is_not_nil(tech, "the materials-chemistry technology must exist")
    assert.is_true(tech.valid, "the tech must load (its icon is present)")

    local unlocked = {}
    for _, effect in pairs(tech.effects) do
      if effect.type == "unlock-recipe" then unlocked[effect.recipe] = true end
    end
    for _, name in ipairs(GATED_RECIPES) do
      assert.is_true(unlocked[name], "the tech must unlock " .. name)
    end

    assert.is_not_nil(tech.prerequisites["cindra-aluminium"],
      "gated behind the signature aluminium -- which itself needs both lava and ice")
    assert.is_not_nil(prototypes.technology["cindra-aluminium"].prerequisites["cindra-lava"],
      "aluminium is behind the lava spine (transitively rock + ice + power)")
  end)
end)

describe("cindra plastic chain: byproduct sinks + fluids exist (no deadlock)", function()
  it("all four new fluids are defined (olefins is gone)", function()
    for _, name in ipairs({ H2, O2, CO2, METHANOL }) do
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

  -- ci-6vj #16: the designated (non-vent) quicklime sink -- net stone-NEGATIVE.
  it("quicklime disposal is a real, net stone-NEGATIVE sink (ci-6vj #16)", function()
    local MAX_CONCEIVABLE_PROD = 3.0 -- the engine's +300% cap
    local LAVA_PER_STONE = 5         -- prototypes/lava.lua: 1 stone -> 5 lava (prod off)
    local d = prototypes.recipe["cindra-quicklime-disposal"]
    assert.is_not_nil(d, "the quicklime disposal recipe must exist")

    assert.is_true(has_ingredient("cindra-quicklime-disposal", QUICKLIME),
      "disposal consumes quicklime (it is the surplus quicklime sink)")
    local lava_in = amount_of(d.ingredients, "lava")
    assert.is_true((lava_in or 0) > 0, "disposal consumes lava (fluxes quicklime into the melt)")

    assert.is_false(d.allowed_effects and d.allowed_effects.productivity,
      "disposal must disable productivity (never mint stone)")
    local sp = product(d.products, "stone")
    assert.is_not_nil(sp, "disposal returns a little stone (fluxed back)")
    local ignored = sp.ignored_by_productivity or 0
    local scalable = sp.amount - ignored
    local stone_out_at_cap = ignored + scalable * (1 + MAX_CONCEIVABLE_PROD)
    assert.are.equal(sp.amount, stone_out_at_cap,
      "the stone output must be fully ignored_by_productivity: fixed even at the +300% cap")

    local stone_embodied = lava_in / LAVA_PER_STONE
    assert.is_true(sp.amount < stone_embodied, string.format(
      "disposal must be net stone-NEGATIVE: returns %d stone for %d lava (= %.1f stone) in",
      sp.amount, lava_in, stone_embodied))
  end)

  it("quicklime disposal runs only in the lava-manufacturer (never the shared foundry)", function()
    local d = prototypes.recipe["cindra-quicklime-disposal"]
    local in_lava_cat = false
    for _, c in pairs(d.categories or {}) do
      if c == "cindra-lava-manufacturing" then in_lava_cat = true end
    end
    assert.is_true(in_lava_cat,
      "disposal is confined to the private lava-manufacturing category")
    local foundry = prototypes.entity["foundry"]
    assert.is_falsy(foundry.crafting_categories["cindra-lava-manufacturing"],
      "the vanilla foundry must never run the Cindra lava-manufacturing category")
  end)
end)

describe("cindra plastic chain: never mutate other planets", function()
  it("the shared vanilla plastic-bar recipe is untouched (still the oil route)", function()
    local vanilla = prototypes.recipe["plastic-bar"]
    assert.is_not_nil(vanilla, "the vanilla plastic-bar recipe must still exist")
    assert.is_true((amount_of(vanilla.ingredients, "petroleum-gas") or 0) > 0,
      "vanilla plastic-bar must still use petroleum (we never mutated it)")
    assert.is_false(has_ingredient("plastic-bar", METHANOL),
      "vanilla plastic must NOT gain a Cindra methanol input (no leak onto Nauvis)")
  end)

  it("the new recipes run in the shared chemical plant WITHOUT mutating it", function()
    local plant = prototypes.entity["chemical-plant"]
    assert.is_not_nil(plant, "the vanilla chemical plant must exist")
    assert.is_true(plant.crafting_categories["chemistry"],
      "our recipes ride the vanilla chemistry category (no new machine needed)")
  end)
end)

describe("cindra plastic chain runtime (a powered plant makes plastic)", function()
  it("a powered chemical plant fed methanol + the zeolite catalyst produces plastic-bar", function()
    local s = H.cindra_surface()
    local pole = s.create_entity({ name = "substation", position = { 2, 2 }, force = "player" })
    assert.is_not_nil(pole, "substation must place")
    local power = s.create_entity({
      name = "electric-energy-interface", position = { 4, 0 }, force = "player",
    })
    power.power_production = 200000000
    power.electric_buffer_size = 200000000
    power.energy = 200000000

    game.forces["player"].recipes["cindra-mto-polymerisation"].enabled = true

    local plant = s.create_entity({ name = "chemical-plant", position = { 0, 0 }, force = "player" })
    assert.is_not_nil(plant, "the chemical plant must place on Cindra")
    plant.set_recipe("cindra-mto-polymerisation")
    plant.insert_fluid({ name = METHANOL, amount = 400 })
    -- A stock of catalysts so a run continues even across the ~30% non-return roll.
    plant.insert({ name = ZCAT, count = 10 })

    async(1200)
    after_ticks(600, function()
      assert.is_true(plant.valid)
      assert.is_true(plant.get_item_count(PLASTIC) > 0,
        "a powered plant fed methanol + zeolite catalyst must produce plastic (got "
          .. plant.get_item_count(PLASTIC) .. ")")
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

-- ci-6vj S3: prove the roast actually runs in the lava manufacturer and, crucially,
-- that the LM can EMIT the CO2 gas (through its unfiltered output fluid box). A
-- powered manufacturer fed calcite must produce both quicklime (item) and CO2 (fluid).
describe("cindra calcination runtime (ci-6vj S3)", function()
  it("a powered lava-manufacturer calcines calcite -> quicklime + CO2", function()
    local s = H.cindra_surface()
    local pole = s.create_entity({ name = "substation", position = { 2, 2 }, force = "player" })
    assert.is_not_nil(pole, "substation must place")
    local power = s.create_entity({
      name = "electric-energy-interface", position = { 4, 0 }, force = "player",
    })
    power.power_production = 200000000
    power.electric_buffer_size = 200000000
    power.energy = 200000000

    game.forces["player"].recipes["cindra-calcination"].enabled = true

    local machine = s.create_entity({ name = "cindra-lava-manufacturer", position = { 0, 0 }, force = "player" })
    assert.is_not_nil(machine, "the lava-manufacturer must place on Cindra")
    machine.set_recipe("cindra-calcination")
    machine.insert({ name = "calcite", count = 50 })

    async(1200)
    after_ticks(600, function()
      assert.is_true(machine.valid)
      assert.is_true(machine.get_item_count(QUICKLIME) > 0,
        "calcination must produce quicklime (got " .. machine.get_item_count(QUICKLIME) .. ")")
      assert.is_true((machine.get_fluid_count(CO2) or 0) > 0,
        "the lava-manufacturer must emit CO2 gas (got " .. (machine.get_fluid_count(CO2) or 0) .. ")")
      machine.destroy()
      done()
    end)
  end)
end)
