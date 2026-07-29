-- Proof: manufactured lava is the central economy spine (§15-5; DESIGN.md §2,
-- §5, §7), rescaled for usability (ci-e8a) and balanced so the stone loop-back can
-- never self-sustain (ci-669). Claims:
--   1. THE RECIPE:  1 stone + [power] -> 10 lava (ci-669 ratio), gated, outputting
--      the Cindra-exclusive `cindra-lava` fluid.
--   2. THE MACHINE: a dedicated high-speed / high-draw Cindra lava-manufacturer
--      crafts it in a PRIVATE category -- the shared Vulcanus foundry does not.
--   3. USABILITY:   a SINGLE-DIGIT count of manufacturers sustains one melting
--      foundry (the old ~100 was the user complaint).
--   4. POWER STAYS RUINOUS: energy-per-lava is UNCHANGED from the pre-rescale
--      foundry value, and feeding one melt is still a serious electric sink.
--   5. DISTINCT TINT on both the recipe icon and the Cindra-exclusive fluid.
--   6. CINDRA CASTING TIER (ci-669): Cindra-exclusive `cindra-molten-iron/copper-
--      from-lava` consume `cindra-lava` and return a SMALL, productivity-immune
--      stone byproduct. The shared vanilla lava fluid + molten recipes are left
--      untouched (never-mutate guard).
--   7. STONE INVARIANT (ci-669): across the full stone->lava->molten chains the
--      loop net-consumes stone at no-modules AND legendary prod (returned <= ~1/3
--      of consumed at legendary), and NO module tier makes it stone-neutral.

local H = require("tests.helpers")
local lava_icon = require("prototypes.lava-icon")

local RECIPE = "cindra-lava"
local MACHINE = "cindra-lava-manufacturer"
local CATEGORY = "cindra-lava-manufacturing"
local LAVA_FLUID = "cindra-lava" -- the Cindra-exclusive fluid, not shared `lava`
local CAST_IRON = "cindra-molten-iron-from-lava"
local CAST_COPPER = "cindra-molten-copper-from-lava"

-- Legendary productivity module 3 grants +25% each (base prod-3 +10% * 2.5 quality).
local LEGENDARY_PROD_PER_MODULE = 0.25
-- The engine's hard productivity cap (+300%): the ceiling of ANY module config.
local MAX_CONCEIVABLE_PROD = 3.0

-- Pull the amount of a named ingredient/product out of a recipe prototype's
-- {type,name,amount} array. Returns nil if absent.
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

-- True if a plain-value array (e.g. recipe.categories) contains `v`.
local function contains(list, v)
  for _, e in pairs(list) do
    if e == v then return true end
  end
  return false
end

-- A machine's base productivity (the inherent foundry bonus, module-free).
local function base_productivity(machine)
  local er = machine.effect_receiver
  if er and er.base_effect and er.base_effect.productivity then
    return er.base_effect.productivity
  end
  return 0
end

-- The productivity a machine reaches with all module slots filled with legendary
-- productivity modules (the "legendary prod" scenario the bead names).
local function legendary_productivity(machine)
  return base_productivity(machine) + (machine.module_inventory_size or 0) * LEGENDARY_PROD_PER_MODULE
end

-- Nominal lava produced per second by ONE manufacturer (no modules): the batch
-- size times the machine speed over the craft time. (crafting_speed is a method
-- in 2.x because quality can scale it; base quality is what we want here.)
local function lava_per_second(recipe, machine)
  return amount_of(recipe.products, LAVA_FLUID) * machine.get_crafting_speed() / recipe.energy
end

-- Nominal lava consumed per second by ONE melting foundry running the Cindra cast.
local function melt_lava_per_second()
  local melt = prototypes.recipe[CAST_IRON]
  local foundry = prototypes.entity["foundry"]
  return amount_of(melt.ingredients, LAVA_FLUID) * foundry.get_crafting_speed() / melt.energy
end

-- Count of manufacturers needed to sustain one melting foundry (nominal, no
-- productivity -- a conservative UPPER bound; the inherited base productivity
-- only lowers it in play).
local function sustaining_count()
  return melt_lava_per_second() / lava_per_second(prototypes.recipe[RECIPE], prototypes.entity[MACHINE])
end

-- Grid Watts a machine draws (energy_usage is Joule per TICK; * 60 -> Watts).
local function draw_w(machine)
  return machine.energy_usage * 60
end

-- Nominal grid energy spent per unit of lava when `machine` crafts `recipe`:
-- draw * craft_time / batch. This is the "energy-per-lava" the mayor pins fixed.
local function energy_per_lava(recipe, machine)
  local craft_time = recipe.energy / machine.get_crafting_speed()
  return draw_w(machine) * craft_time / amount_of(recipe.products, LAVA_FLUID)
end

-- ci-669 stone accounting for ONE cast (500 lava -> 250 molten + byproduct), at a
-- given lava-recipe productivity and cast-recipe productivity. Returns
-- stone-consumed (to make the lava) and stone-returned (the loop-back byproduct).
--   * stone-in: productivity boosts lava-per-craft, so fewer crafts (less stone).
--   * stone-out: the byproduct's `ignored_by_productivity` portion is fixed; only
--     the remainder scales with the cast recipe's productivity.
local function chain_stone(cast_recipe_name, p_lava, p_cast)
  local lava_recipe = prototypes.recipe[RECIPE]
  local cast = prototypes.recipe[cast_recipe_name]

  local lava_needed = amount_of(cast.ingredients, LAVA_FLUID)
  local lava_per_craft = amount_of(lava_recipe.products, LAVA_FLUID) * (1 + p_lava)
  local stone_per_lava_craft = amount_of(lava_recipe.ingredients, "stone")
  local stone_in = (lava_needed / lava_per_craft) * stone_per_lava_craft

  local sp = product_of(cast.products, "stone")
  local ignored = sp.ignored_by_productivity or 0
  local scalable = sp.amount - ignored
  local stone_out = ignored + scalable * (1 + p_cast)

  return stone_in, stone_out
end

describe("cindra manufactured lava", function()
  it("is 1 stone + power -> 10 lava (ci-669 ratio) into the Cindra-exclusive fluid", function()
    local recipe = prototypes.recipe[RECIPE]
    assert.is_not_nil(recipe, "cindra-lava recipe must exist")

    -- Exactly one ingredient, and it is stone: the material cost is a single
    -- rock, so power is the real cost.
    local n_ingredients = 0
    for _ in pairs(recipe.ingredients) do n_ingredients = n_ingredients + 1 end
    assert.are.equal(1, n_ingredients, "the only ingredient is stone -- no fuel, no carrier")
    assert.are.equal(1, amount_of(recipe.ingredients, "stone"), "1 stone in (ci-669 ratio)")

    -- One product: 10 lava fluid (ci-669: the user's `1 stone -> 10 lava`), and it
    -- is the Cindra-EXCLUSIVE fluid, never the shared vanilla `lava`.
    assert.are.equal(10, amount_of(recipe.products, LAVA_FLUID), "10 cindra-lava out (ci-669 ratio)")
    assert.is_nil(amount_of(recipe.products, "lava"),
      "the recipe must NOT output the shared vanilla `lava` (that would re-open the exploit)")
  end)

  it("makes power the lever, and allows productivity as an intermediate reward", function()
    local recipe = prototypes.recipe[RECIPE]
    -- energy_required is a real, nontrivial time so the machine's electric draw
    -- dominates (ruinous power). ci-669 doubled it alongside the doubled output.
    assert.is_true(recipe.energy >= 10,
      "lava must cost real crafting time (the power lever), got " .. tostring(recipe.energy))
    -- Productivity is allowed: lava is the central intermediate + ruinous power
    -- cost, so a prod bonus is a fair reward (per prior decision, kept by ci-669).
    assert.is_true(recipe.allowed_effects.productivity,
      "productivity must be ON: lava is an intermediate; a prod bonus is a fair reward")
    assert.is_true(prototypes.recipe[CAST_IRON].allowed_effects.productivity,
      "sanity: the Cindra cast also allows productivity (consistent intermediate convention)")
  end)

  it("is crafted in the dedicated Cindra lava-manufacturer, NOT the shared foundry", function()
    -- The rescale routes lava onto OUR machine, in a PRIVATE category, so the
    -- shared Vulcanus foundry never crafts it (we own our building; we never
    -- touch theirs -- the never-mutate-other-planets invariant).
    local recipe = prototypes.recipe[RECIPE]
    assert.is_true(contains(recipe.categories, CATEGORY),
      "cindra-lava lives in the private " .. CATEGORY .. " category")
    assert.is_false(contains(recipe.categories, "metallurgy"),
      "cindra-lava must NOT be a metallurgy recipe -- it left the shared foundry")

    -- The manufacturer exists and crafts exactly that private category.
    local machine = prototypes.entity[MACHINE]
    assert.is_not_nil(machine, "the cindra-lava-manufacturer entity must exist")
    assert.is_not_nil(machine.crafting_categories[CATEGORY],
      "the manufacturer crafts the private lava category")
    assert.is_nil(machine.crafting_categories["metallurgy"],
      "the manufacturer is a dedicated caster -- it does NOT double as a metallurgy foundry")

    -- The shared foundry CANNOT craft lava, and is otherwise untouched.
    local foundry = prototypes.entity["foundry"]
    assert.is_nil(foundry.crafting_categories[CATEGORY],
      "the shared foundry must NOT gain the private lava category (that would leak/mutate)")
    assert.is_not_nil(foundry.crafting_categories["metallurgy"],
      "the shared foundry keeps its vanilla metallurgy category (unmutated)")
    assert.are.equal(4, foundry.get_crafting_speed(),
      "the shared foundry keeps its vanilla crafting_speed (we cloned, never mutated)")
  end)

  it("keeps energy-per-lava FIXED at the pre-rescale ruinous value (do NOT cheapen lava)", function()
    -- THE hard constraint: the grid energy spent per unit of lava must be the
    -- SAME as when the foundry crafted it. We achieve a single-digit machine
    -- count by concentrating the draw (big machine), NOT by making lava cheaper.
    -- Reference = the same recipe on the foundry; actual = on the manufacturer.
    local recipe = prototypes.recipe[RECIPE]
    local foundry = prototypes.entity["foundry"]
    local machine = prototypes.entity[MACHINE]

    local reference = energy_per_lava(recipe, foundry)
    local actual = energy_per_lava(recipe, machine)
    assert.is_true(math.abs(actual - reference) <= 1,
      "energy-per-lava must equal the pre-rescale foundry value (ruinous, unchanged): got "
        .. string.format("%.0f J vs %.0f J", actual, reference))

    -- Equivalent invariant, stated on the machines directly: draw-per-speed-unit
    -- is matched to the foundry, which is exactly what holds energy-per-lava
    -- fixed while the machine is faster.
    assert.is_true(
      math.abs(draw_w(machine) / machine.get_crafting_speed() - draw_w(foundry) / foundry.get_crafting_speed()) <= 1,
      "the manufacturer's draw-per-speed must match the foundry's (fixed energy-per-lava)")
  end)

  it("a SINGLE-DIGIT count of manufacturers sustains one melting foundry (ci-e8a fix)", function()
    -- THE user complaint: pre-rescale it took ~100 lava foundries to keep one
    -- melting foundry fed (unusable). Compute the sustaining count LIVE from the
    -- shipped prototypes so the assertion tracks the real recipes, not a guess.
    -- ci-669 doubled lava output AND energy together, so the count is unchanged.
    local n = sustaining_count()
    assert.is_true(n >= 1 and n <= 9,
      "a single-digit manufacturer count must sustain one melt (got " .. string.format("%.2f", n) .. ")")
    -- And it is a real fix, not a marginal trim off ~100.
    assert.is_true(n < 20,
      "must be far below the pre-rescale ~100 machines (got " .. string.format("%.2f", n) .. ")")
  end)

  it("keeps power RUINOUS: feeding one melt is still a serious electric sink (§7, §10)", function()
    -- Power stays the real cost. The aggregate draw of the manufacturers needed
    -- to feed ONE melting foundry must remain a serious sink -- many MW, dwarfing
    -- baseline solar (§10). Read the draw + the vanilla panel output LIVE.
    local n = sustaining_count()
    local total_w = n * draw_w(prototypes.entity[MACHINE])
    assert.is_true(total_w >= 10e6,
      "feeding one melt must draw >=10 MW of manufacturers (ruinous power), got "
        .. string.format("%.1f MW", total_w / 1e6))

    -- Relative to baseline solar: worth many, many vanilla panels (§10). A base
    -- runs a solar farm; one melt's lava should rival/exceed a serious slice of it.
    local panel_w = prototypes.entity["solar-panel"].get_max_energy_production() * 60
    assert.is_true(total_w >= 50 * panel_w,
      "one melt's lava draw must exceed >=50 vanilla solar panels' output, got "
        .. string.format("%.0f panels", total_w / panel_w))
  end)

  it("has a DISTINCT tint on the recipe icon AND the Cindra-exclusive fluid", function()
    -- The recipe icon is color-layered so manufactured lava reads distinct from
    -- the natural Vulcanus pour. The runtime API does not expose recipe icons, so
    -- (space-appearance convention) we assert the PURE module the data stage uses.
    local layers = lava_icon.build()
    assert.is_true(#layers >= 2, "icon must be layered (base + a tinted copy)")

    -- Base layer: the vanilla lava sprite, UNtinted -- so it still reads as lava.
    local base = layers[1]
    assert.are.equal(lava_icon.BASE_ICON, base.icon, "base layer is the vanilla lava icon")
    assert.is_nil(base.tint, "base layer stays untinted (readable silhouette)")

    -- A tinted layer exists, and the tint is a REAL colour shift (not neutral
    -- grey/white) and semi-transparent (subtle, not a full recolour).
    local tint
    for i = 2, #layers do
      if layers[i].tint then tint = layers[i].tint end
    end
    assert.is_not_nil(tint, "a tinted layer must exist")
    local spread = math.max(tint.r, tint.g, tint.b) - math.min(tint.r, tint.g, tint.b)
    assert.is_true(spread >= 0.2,
      "the tint must be a real colour (not neutral grey/white), channel spread " .. string.format("%.2f", spread))
    assert.is_true(tint.a ~= nil and tint.a < 1.0,
      "the tint is a semi-transparent overlay so the shift stays subtle/readable")

    -- Since ci-669 the fluid is Cindra-exclusive, so it carries the tint too: its
    -- in-pipe colour is warmed off the vanilla lava base. The shared vanilla `lava`
    -- fluid must be untouched (never-mutate); the Cindra fluid must exist + differ.
    local cindra = prototypes.fluid[LAVA_FLUID]
    assert.is_not_nil(cindra, "the Cindra-exclusive cindra-lava fluid must exist")
    local vanilla = prototypes.fluid["lava"]
    assert.is_not_nil(vanilla, "the shared vanilla lava fluid must still exist, untouched")
    local function differs(a, b)
      return math.abs(a.r - b.r) + math.abs(a.g - b.g) + math.abs(a.b - b.b) > 0.05
    end
    assert.is_true(differs(cindra.base_color, vanilla.base_color),
      "the Cindra fluid's base colour must be tinted distinct from vanilla lava")
  end)

  it("is gated: disabled by default, unlocked only by its own tech (recipe + machine + casts)", function()
    local recipe = prototypes.recipe[RECIPE]
    assert.is_false(recipe.enabled, "the recipe is not free -- research unlocks it")
    assert.is_false(prototypes.recipe[MACHINE].enabled, "the machine recipe is not free either")
    assert.is_false(prototypes.recipe[CAST_IRON].enabled, "the iron cast is not free either")
    assert.is_false(prototypes.recipe[CAST_COPPER].enabled, "the copper cast is not free either")

    local tech = prototypes.technology[RECIPE]
    assert.is_not_nil(tech, "cindra-lava technology must exist")
    assert.is_true(tech.valid, "the tech must load (its icon is present)")

    -- The tech unlocks the recipe, the machine that crafts it, AND both casts.
    local unlocks = {}
    for _, effect in pairs(tech.effects) do
      if effect.type == "unlock-recipe" then unlocks[effect.recipe] = true end
    end
    assert.is_true(unlocks[RECIPE], "the tech must unlock the cindra-lava recipe")
    assert.is_true(unlocks[MACHINE], "the tech must unlock the lava-manufacturer that crafts it")
    assert.is_true(unlocks[CAST_IRON], "the tech must unlock the Cindra iron cast")
    assert.is_true(unlocks[CAST_COPPER], "the tech must unlock the Cindra copper cast")

    -- Gated behind the foundry (you need the Vulcanus metal path lava feeds) AND
    -- Cindra discovery (so the recipe is Cindra-progression content).
    assert.is_not_nil(tech.prerequisites["foundry"],
      "gated behind the foundry -- the Vulcanus metal chain manufactured lava feeds")
    assert.is_not_nil(tech.prerequisites["planet-discovery-cindra"],
      "gated behind Cindra discovery -- Cindra-progression content")
  end)

  it("casts through Cindra-exclusive recipes: they consume cindra-lava -> vanilla molten", function()
    -- ci-669: the Cindra casting tier eats the Cindra-only fluid and yields the
    -- vanilla 250 molten metal (so the downstream casting chain is unchanged).
    for _, spec in ipairs({
      { name = CAST_IRON, molten = "molten-iron" },
      { name = CAST_COPPER, molten = "molten-copper" },
    }) do
      local r = prototypes.recipe[spec.name]
      assert.is_not_nil(r, spec.name .. " must exist (the Cindra casting tier)")
      assert.are.equal(500, amount_of(r.ingredients, LAVA_FLUID),
        spec.name .. " consumes 500 cindra-lava (not the shared fluid)")
      assert.is_nil(amount_of(r.ingredients, "lava"),
        spec.name .. " must NOT consume shared vanilla lava")
      assert.are.equal(1, amount_of(r.ingredients, "calcite"),
        spec.name .. " keeps the 1-calcite cost")
      assert.are.equal(250, amount_of(r.products, spec.molten),
        spec.name .. " yields the vanilla 250 " .. spec.molten .. " (downstream chain unchanged)")
      assert.is_true(contains(r.categories, "metallurgy"),
        spec.name .. " lives in metallurgy so the brought foundry crafts it")
    end
  end)

  it("returns a SMALL, productivity-IMMUNE stone byproduct (the ci-669 loop-back)", function()
    -- The loop-back stone is small and fully `ignored_by_productivity`, so NO
    -- module tier can inflate it -- the mechanism that kills the self-sustain.
    for _, name in ipairs({ CAST_IRON, CAST_COPPER }) do
      local sp = product_of(prototypes.recipe[name].products, "stone")
      assert.is_not_nil(sp, name .. " must still hand some stone back (the loop-back)")
      assert.is_true(sp.amount <= 6,
        name .. " must return only a small stone byproduct, got " .. tostring(sp.amount))
      assert.are.equal(sp.amount, sp.ignored_by_productivity,
        name .. " must fully exclude its stone byproduct from productivity (returned stone is fixed)")
    end
  end)

  it("does not mutate the shared vanilla lava fluid OR molten recipes (never-mutate)", function()
    -- Guard the invariant DIRECTLY: the shared Vulcanus recipes + fluid keep their
    -- canonical values. If a future change mutated-not-cloned, this fails before it
    -- can leak onto Vulcanus.
    assert.are.equal(500, amount_of(prototypes.recipe["molten-iron-from-lava"].ingredients, "lava"),
      "vanilla molten iron still consumes 500 shared lava (Vulcanus value intact)")
    assert.are.equal(500, amount_of(prototypes.recipe["molten-copper-from-lava"].ingredients, "lava"),
      "vanilla molten copper still consumes 500 shared lava (Vulcanus value intact)")
    assert.are.equal(250, amount_of(prototypes.recipe["molten-iron-from-lava"].products, "molten-iron"),
      "vanilla molten iron still yields 250 (Vulcanus value intact)")
    assert.are.equal(250, amount_of(prototypes.recipe["molten-copper-from-lava"].products, "molten-copper"),
      "vanilla molten copper still yields 250 (Vulcanus value intact)")
    assert.are.equal(10, amount_of(prototypes.recipe["molten-iron-from-lava"].products, "stone"),
      "vanilla molten iron keeps its 10-stone byproduct (unmutated)")
    assert.are.equal(15, amount_of(prototypes.recipe["molten-copper-from-lava"].products, "stone"),
      "vanilla molten copper keeps its 15-stone byproduct (unmutated)")
    -- The shared fluid keeps its vanilla colour (we tinted a CLONE, not this).
    local vanilla = prototypes.fluid["lava"]
    assert.is_true(math.abs(vanilla.base_color.r - 1.0) < 0.01
        and math.abs(vanilla.base_color.g - 0.4) < 0.01
        and math.abs(vanilla.base_color.b - 0.1) < 0.01,
      "the shared vanilla lava fluid keeps its canonical base_color (unmutated)")
  end)

  -- ===== ci-669 STONE INVARIANT (mandatory) ================================
  describe("ci-669: the stone loop-back never self-sustains", function()
    for _, spec in ipairs({
      { name = CAST_IRON, label = "iron" },
      { name = CAST_COPPER, label = "copper" },
    }) do
      it("net-consumes stone at NO modules on the lava->" .. spec.label .. " chain", function()
        local manufacturer = prototypes.entity[MACHINE]
        local foundry = prototypes.entity["foundry"]
        -- "No modules" still carries the machines' inherent BASE productivity.
        local stone_in, stone_out =
          chain_stone(spec.name, base_productivity(manufacturer), base_productivity(foundry))
        assert.is_true(stone_out < stone_in,
          string.format("no-modules must net-consume stone (in %.2f, back %.2f)", stone_in, stone_out))
      end)

      it("net-consumes stone, returned <= ~1/3 of consumed, at LEGENDARY prod on lava->"
        .. spec.label, function()
        local manufacturer = prototypes.entity[MACHINE]
        local foundry = prototypes.entity["foundry"]
        local stone_in, stone_out =
          chain_stone(spec.name, legendary_productivity(manufacturer), legendary_productivity(foundry))
        assert.is_true(stone_out < stone_in,
          string.format("legendary must still net-consume stone (in %.2f, back %.2f)", stone_in, stone_out))
        assert.is_true(stone_out <= stone_in / 3 + 1e-9,
          string.format("legendary returned stone must be <= 1/3 of consumed (in %.2f, back %.2f, ratio %.2f)",
            stone_in, stone_out, stone_out / stone_in))
      end)

      it("never goes stone-neutral/positive at ANY module tier on lava->" .. spec.label, function()
        -- The worst case for the loop is the engine's hard productivity cap (+300%)
        -- on BOTH recipes: max lava-per-stone AND max byproduct. Because the
        -- byproduct is ignored_by_productivity it cannot grow, so even here the loop
        -- must net-CONSUME. This is the "no module configuration self-sustains" guard.
        local stone_in, stone_out = chain_stone(spec.name, MAX_CONCEIVABLE_PROD, MAX_CONCEIVABLE_PROD)
        assert.is_true(stone_out < stone_in,
          string.format("even at the +300%% cap the loop must net-consume (in %.2f, back %.2f)",
            stone_in, stone_out))
      end)
    end
  end)

  it("a lava-manufacturer on Cindra accepts the lava recipe (fluid output + category fit)", function()
    local s = H.cindra_surface()
    game.forces["player"].recipes[RECIPE].enabled = true

    local machine = s.create_entity({ name = MACHINE, position = { 0, 0 }, force = "player" })
    assert.is_not_nil(machine, "the lava-manufacturer must be placeable on Cindra")

    machine.set_recipe(RECIPE)
    local set = machine.get_recipe()
    assert.is_not_nil(set, "the manufacturer must accept a recipe")
    assert.are.equal(RECIPE, set.name,
      "the manufacturer accepts cindra-lava: private category + a fluid-output box for lava")
    machine.destroy()
  end)

  it("a foundry on Cindra accepts the Cindra iron cast (metallurgy + cindra-lava input)", function()
    -- The brought-not-re-unlocked foundry crafts the Cindra casting recipe: proves
    -- the metallurgy-category fit + a fluid box that takes cindra-lava.
    local s = H.cindra_surface()
    game.forces["player"].recipes[CAST_IRON].enabled = true

    local foundry = s.create_entity({ name = "foundry", position = { 0, 0 }, force = "player" })
    foundry.set_recipe(CAST_IRON)
    assert.are.equal(CAST_IRON, foundry.get_recipe().name,
      "the foundry casts cindra-lava into molten iron (the Cindra casting tier)")
    foundry.destroy()
  end)

  it("accepts a productivity module in-machine: the bonus actually applies", function()
    local s = H.cindra_surface()
    game.forces["player"].recipes[RECIPE].enabled = true

    local machine = s.create_entity({ name = MACHINE, position = { 0, 0 }, force = "player" })
    machine.set_recipe(RECIPE)

    -- Insert a productivity module and confirm the machine reports a live
    -- productivity bonus. This only happens when the recipe allows productivity,
    -- so it proves the flag reaches the machine, not just the prototype.
    local modules = machine.get_module_inventory()
    assert.is_not_nil(modules, "the manufacturer must have a module inventory")
    local inserted = modules.insert({ name = "productivity-module", count = 1 })
    assert.are.equal(1, inserted, "a productivity module must go into the manufacturer")

    local effects = machine.effects
    assert.is_not_nil(effects, "the manufacturer must report module effects with a recipe set")
    assert.is_not_nil(effects.productivity, "the productivity effect must be present")
    assert.is_true(effects.productivity > 0,
      "the productivity bonus must be live (recipe allows productivity)")
    machine.destroy()
  end)
end)
