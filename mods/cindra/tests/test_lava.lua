-- Proof: manufactured lava is the central economy spine (§15-5; DESIGN.md §2,
-- §5, §7), rescaled for usability (ci-e8a) WITHOUT cheapening the power cost.
-- Claims, matching the bead + the mayor's resolution:
--   1. THE RECIPE:  1 stone + [power] -> 5 lava, ratio + energy FIXED, gated.
--   2. THE MACHINE: a dedicated high-speed / high-draw Cindra lava-manufacturer
--      crafts it in a PRIVATE category -- the shared Vulcanus foundry does not.
--   3. USABILITY:   a SINGLE-DIGIT count of manufacturers sustains one melting
--      foundry (the old ~100 was the user complaint).
--   4. POWER STAYS RUINOUS: energy-per-lava is UNCHANGED from the pre-rescale
--      foundry value, and feeding one melt is still a serious electric sink.
--   5. DISTINCT TINT on the recipe icon, never on the shared lava fluid.
--   6. FOUNDRY INTEGRATION + STONE LOOP-BACK: the vanilla molten recipes still
--      consume this lava and hand stone back, unmodified (never-mutate guard).

local H = require("tests.helpers")
local lava_icon = require("prototypes.lava-icon")

local RECIPE = "cindra-lava"
local MACHINE = "cindra-lava-manufacturer"
local CATEGORY = "cindra-lava-manufacturing"

-- Pull the amount of a named ingredient/product out of a recipe prototype's
-- {type,name,amount} array. Returns nil if absent.
local function amount_of(list, name)
  for _, e in pairs(list) do
    if e.name == name then return e.amount end
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

-- Nominal lava produced per second by ONE manufacturer (no modules): the batch
-- size times the machine speed over the craft time. (crafting_speed is a method
-- in 2.x because quality can scale it; base quality is what we want here.)
local function lava_per_second(recipe, machine)
  return amount_of(recipe.products, "lava") * machine.get_crafting_speed() / recipe.energy
end

-- Nominal lava consumed per second by ONE melting foundry running the vanilla
-- molten recipe.
local function melt_lava_per_second()
  local melt = prototypes.recipe["molten-iron-from-lava"]
  local foundry = prototypes.entity["foundry"]
  return amount_of(melt.ingredients, "lava") * foundry.get_crafting_speed() / melt.energy
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
  return draw_w(machine) * craft_time / amount_of(recipe.products, "lava")
end

describe("cindra manufactured lava", function()
  it("is 1 stone + power -> 5 lava (ratio + energy fixed per spec, §7)", function()
    local recipe = prototypes.recipe[RECIPE]
    assert.is_not_nil(recipe, "cindra-lava recipe must exist")

    -- Exactly one ingredient, and it is stone: the material cost is a single
    -- rock, so power is the real cost.
    local n_ingredients = 0
    for _ in pairs(recipe.ingredients) do n_ingredients = n_ingredients + 1 end
    assert.are.equal(1, n_ingredients, "the only ingredient is stone -- no fuel, no carrier")
    assert.are.equal(1, amount_of(recipe.ingredients, "stone"), "1 stone in (spec ratio)")

    -- One product: 5 lava fluid. The rescale (ci-e8a) does NOT change this -- the
    -- ratio stays 1:5; usability comes from the machine, not from batching or
    -- cheapening the recipe.
    assert.are.equal(5, amount_of(recipe.products, "lava"), "5 lava out (spec ratio, unchanged)")
  end)

  it("makes power the lever, and allows productivity as an intermediate reward", function()
    local recipe = prototypes.recipe[RECIPE]
    -- energy_required is a real, nontrivial time so the machine's electric draw
    -- dominates (ruinous power).
    assert.is_true(recipe.energy >= 10,
      "lava must cost real crafting time (the power lever), got " .. tostring(recipe.energy))
    -- Productivity is allowed: lava is the central intermediate + ruinous power
    -- cost, so a prod bonus is a fair reward and matches vanilla intermediate
    -- conventions (the downstream molten recipes allow it too).
    assert.is_true(recipe.allowed_effects.productivity,
      "productivity must be ON: lava is an intermediate; a prod bonus is a fair reward")
    assert.is_true(prototypes.recipe["molten-iron-from-lava"].allowed_effects.productivity,
      "sanity: the downstream melt also allows productivity (consistent intermediate convention)")
  end)

  it("is crafted in the dedicated Cindra lava-manufacturer, NOT the shared foundry", function()
    -- The rescale routes lava onto OUR machine, in a PRIVATE category, so the
    -- shared Vulcanus foundry never crafts it (we own our building; we never
    -- touch theirs -- the never-mutate-other-planets invariant).
    local recipe = prototypes.recipe[RECIPE]
    assert.is_true(contains(recipe.categories, CATEGORY),
      "cindra-lava lives in the private " .. CATEGORY .. " category")
    assert.is_false(contains(recipe.categories, "metallurgy"),
      "cindra-lava must NOT be a metallurgy recipe any more -- it left the shared foundry")

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

  it("has a DISTINCT tint on the recipe icon, never on the shared lava fluid", function()
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

    -- The tint lives on the RECIPE only: the recipe still outputs the shared
    -- vanilla `lava` fluid (no retinted Cindra fluid clone -- that would leak
    -- onto Vulcanus). Guard both halves of that.
    assert.is_not_nil(amount_of(prototypes.recipe[RECIPE].products, "lava"),
      "the recipe outputs the shared vanilla `lava` fluid, tint or not")
    assert.is_nil(prototypes.fluid["cindra-lava"],
      "there must be NO cindra-specific lava fluid -- we tint the recipe icon, never the fluid")
  end)

  it("is gated: disabled by default, unlocked only by its own tech (recipe + machine)", function()
    local recipe = prototypes.recipe[RECIPE]
    assert.is_false(recipe.enabled, "the recipe is not free -- research unlocks it")
    assert.is_false(prototypes.recipe[MACHINE].enabled, "the machine recipe is not free either")

    local tech = prototypes.technology[RECIPE]
    assert.is_not_nil(tech, "cindra-lava technology must exist")
    assert.is_true(tech.valid, "the tech must load (its icon is present)")

    -- The tech unlocks BOTH the recipe and the machine that crafts it.
    local unlocks_recipe, unlocks_machine = false, false
    for _, effect in pairs(tech.effects) do
      if effect.type == "unlock-recipe" and effect.recipe == RECIPE then unlocks_recipe = true end
      if effect.type == "unlock-recipe" and effect.recipe == MACHINE then unlocks_machine = true end
    end
    assert.is_true(unlocks_recipe, "the tech must unlock the cindra-lava recipe")
    assert.is_true(unlocks_machine, "the tech must unlock the lava-manufacturer that crafts it")

    -- Gated behind the foundry (you need the Vulcanus metal path lava feeds) AND
    -- Cindra discovery (so it is Cindra-progression content).
    assert.is_not_nil(tech.prerequisites["foundry"],
      "gated behind the foundry -- the Vulcanus metal chain manufactured lava feeds")
    assert.is_not_nil(tech.prerequisites["planet-discovery-cindra"],
      "gated behind Cindra discovery -- Cindra-progression content")
  end)

  it("feeds the foundry chain: molten recipes consume this lava, unmodified", function()
    -- BROUGHT, NOT RE-UNLOCKED: the Vulcanus molten recipes are untouched and
    -- still eat the `lava` fluid this recipe produces. That IS the integration.
    for _, name in ipairs({ "molten-iron-from-lava", "molten-copper-from-lava" }) do
      local r = prototypes.recipe[name]
      assert.is_not_nil(r, name .. " must exist (brought from Vulcanus)")
      assert.are.equal(500, amount_of(r.ingredients, "lava"),
        name .. " still consumes 500 lava (unmodified Vulcanus value)")
      assert.are.equal(1, amount_of(r.ingredients, "calcite"),
        name .. " still consumes 1 calcite (unmodified Vulcanus value)")
    end
  end)

  it("loops stone back: the molten recipes return stone as a byproduct", function()
    -- The stone loop-back is the foundry's own byproduct feeding fresh lava, so
    -- mining is a top-up, not the whole supply. These are OUTPUT stone, proving
    -- the loop closes with cindra-lava's stone input.
    assert.are.equal(10, amount_of(prototypes.recipe["molten-iron-from-lava"].products, "stone"),
      "molten iron returns 10 stone (loop-back byproduct, unmodified Vulcanus value)")
    assert.are.equal(15, amount_of(prototypes.recipe["molten-copper-from-lava"].products, "stone"),
      "molten copper returns 15 stone (loop-back byproduct, unmodified Vulcanus value)")
  end)

  it("does not mutate the shared molten recipes (never-mutate-other-planets)", function()
    -- Guard the invariant directly: the Vulcanus recipes keep their canonical
    -- 250-molten output. If a future change clones-not-mutates went wrong, this
    -- fails before it can leak onto Vulcanus.
    assert.are.equal(250, amount_of(prototypes.recipe["molten-iron-from-lava"].products, "molten-iron"),
      "molten iron still yields 250 (Vulcanus value intact)")
    assert.are.equal(250, amount_of(prototypes.recipe["molten-copper-from-lava"].products, "molten-copper"),
      "molten copper still yields 250 (Vulcanus value intact)")
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
