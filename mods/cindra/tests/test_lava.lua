-- Proof: manufactured lava is the central economy spine (§15-5; DESIGN.md §2,
-- §5, §7). Three claims, matching the bead:
--   1. THE RECIPE:  1 stone + [power] -> 5 lava, crafted in the foundry, gated.
--   2. FOUNDRY INTEGRATION (brought, not re-unlocked): the vanilla molten
--      recipes still consume this lava fluid, unmodified.
--   3. STONE LOOP-BACK: those molten recipes hand stone back as a byproduct.
-- Plus the never-mutate-other-planets guard: the shared Vulcanus recipes keep
-- their canonical values (we cloned nothing, mutated nothing).

local H = require("tests.helpers")
local lava_icon = require("prototypes.lava-icon")

local RECIPE = "cindra-lava"

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

describe("cindra manufactured lava", function()
  it("is stone + power -> lava at the fixed 1:5 ratio, BATCHED (§7, ci-e8a rescale)", function()
    local recipe = prototypes.recipe[RECIPE]
    assert.is_not_nil(recipe, "cindra-lava recipe must exist")

    -- Exactly one ingredient, and it is stone: the material cost is only rock,
    -- so power (below) is the real cost.
    local n_ingredients = 0
    for _ in pairs(recipe.ingredients) do n_ingredients = n_ingredients + 1 end
    assert.are.equal(1, n_ingredients, "the only ingredient is stone -- no fuel, no carrier")

    local stone = amount_of(recipe.ingredients, "stone")
    local lava = amount_of(recipe.products, "lava")
    assert.is_not_nil(stone, "stone is the input")
    assert.is_not_nil(lava, "lava is the output")

    -- THE RATIO IS FIXED PER SPEC: exactly 1 stone : 5 lava, whatever the batch.
    assert.are.equal(stone * 5, lava,
      "ratio must stay 1 stone : 5 lava (got " .. stone .. ":" .. lava .. ")")

    -- BATCHED UP (the rescale): one craft yields a foundry-relevant amount, so it
    -- is NOT the old tiny 5-lava batch that forced ~100 machines per foundry.
    assert.is_true(lava >= 500,
      "one craft must yield a foundry-relevant batch (>=500 lava = one melt's feed), got " .. lava)
  end)

  it("makes power the lever, and allows productivity as an intermediate reward", function()
    local recipe = prototypes.recipe[RECIPE]
    -- energy_required is the dominant cost knob; it must be a real, nontrivial time
    -- so the foundry's electric draw dominates (ruinous power). A batched craft is
    -- a multi-second cast, not an instant tap.
    assert.is_true(recipe.energy >= 60,
      "lava must cost real crafting time (the power lever), got " .. tostring(recipe.energy))
    -- Productivity is allowed: lava is the central intermediate + ruinous power
    -- cost, so a prod bonus is a fair reward and matches vanilla intermediate
    -- conventions (the downstream molten recipes allow it too).
    assert.is_true(recipe.allowed_effects.productivity,
      "productivity must be ON: lava is an intermediate; a prod bonus is a fair reward")
    assert.is_true(prototypes.recipe["molten-iron-from-lava"].allowed_effects.productivity,
      "sanity: the downstream melt also allows productivity (consistent intermediate convention)")
  end)

  it("a SINGLE-DIGIT count of lava foundries sustains one melting foundry (ci-e8a)", function()
    -- THE user complaint: pre-rescale it took ~100 lava foundries to keep one
    -- melting foundry fed (unusable). Compute the sustaining count LIVE from the
    -- shipped prototypes so the assertion tracks the real recipes, not a guess.
    --
    -- Both recipes run on the same foundry, so its crafting speed cancels:
    --   lava produced / s   = LAVA_OUT       / lava_energy   * speed
    --   lava consumed / s   = lava_per_melt  / melt_energy   * speed
    --   N = consumed / produced = (lava_per_melt * lava_energy)
    --                             / (melt_energy   * LAVA_OUT)
    local lava = prototypes.recipe[RECIPE]
    local melt = prototypes.recipe["molten-iron-from-lava"]

    local lava_out = amount_of(lava.products, "lava")
    local lava_energy = lava.energy
    local lava_per_melt = amount_of(melt.ingredients, "lava")
    local melt_energy = melt.energy

    local n = (lava_per_melt * lava_energy) / (melt_energy * lava_out)
    assert.is_true(n >= 1 and n <= 9,
      "a single-digit lava-foundry count must sustain one melt (got " .. string.format("%.2f", n) .. ")")
    -- And it is a real fix, not a marginal trim off ~100.
    assert.is_true(n < 20,
      "must be far below the pre-rescale ~100 machines (got " .. string.format("%.2f", n) .. ")")
  end)

  it("keeps power RUINOUS: feeding one melt is still a serious electric sink (§7)", function()
    -- Power stays the real cost. The aggregate draw of the lava foundries needed
    -- to feed ONE melting foundry must remain a serious sink -- many MW, so at
    -- base scale lava rivals/exceeds baseline solar (§10). Read the foundry's
    -- draw live rather than hard-coding 2.5 MW.
    local lava = prototypes.recipe[RECIPE]
    local melt = prototypes.recipe["molten-iron-from-lava"]
    local foundry = prototypes.entity["foundry"]

    local lava_out = amount_of(lava.products, "lava")
    local lava_per_melt = amount_of(melt.ingredients, "lava")
    local n = (lava_per_melt * lava.energy) / (melt.energy * lava_out)

    -- energy_usage is per-TICK Joules; * 60 ticks/s -> Watts (foundry = 2.5 MW).
    assert.is_not_nil(foundry.energy_usage, "the foundry must report an electric draw")
    local draw_w = foundry.energy_usage * 60
    assert.is_true(n * draw_w >= 10e6,
      "feeding one melt must draw >=10 MW of lava foundries (ruinous power), got "
        .. string.format("%.1f MW", n * draw_w / 1e6))
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

  it("is gated: disabled by default, unlocked only by its own tech", function()
    local recipe = prototypes.recipe[RECIPE]
    assert.is_false(recipe.enabled, "the recipe is not free -- research unlocks it")

    local tech = prototypes.technology[RECIPE]
    assert.is_not_nil(tech, "cindra-lava technology must exist")
    assert.is_true(tech.valid, "the tech must load (its icon is present)")

    local unlocks = false
    for _, effect in pairs(tech.effects) do
      if effect.type == "unlock-recipe" and effect.recipe == RECIPE then unlocks = true end
    end
    assert.is_true(unlocks, "the tech must unlock the cindra-lava recipe")

    -- Gated behind the foundry (you need the machine + the Vulcanus metal path)
    -- AND Cindra discovery (so it is Cindra-progression content, not a stray
    -- option a Vulcanus-only player can reach).
    assert.is_not_nil(tech.prerequisites["foundry"],
      "gated behind the foundry -- the machine that crafts lava and its molten chain")
    assert.is_not_nil(tech.prerequisites["planet-discovery-cindra"],
      "gated behind Cindra discovery -- Cindra-progression content")
  end)

  it("is crafted in the brought Vulcanus foundry (metallurgy category)", function()
    local recipe = prototypes.recipe[RECIPE]
    assert.is_true(contains(recipe.categories, "metallurgy"),
      "cindra-lava is a metallurgy recipe -- the foundry's category")

    -- The foundry (no new building) can therefore craft it.
    local foundry = prototypes.entity["foundry"]
    assert.is_not_nil(foundry, "the foundry must exist (brought from Vulcanus)")
    assert.is_not_nil(foundry.crafting_categories["metallurgy"],
      "the foundry crafts metallurgy recipes, so it crafts manufactured lava")
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

  it("a foundry on Cindra accepts the lava recipe (fluid output + category fit)", function()
    local s = H.cindra_surface()
    game.forces["player"].recipes[RECIPE].enabled = true

    local foundry = s.create_entity({ name = "foundry", position = { 0, 0 }, force = "player" })
    assert.is_not_nil(foundry, "the foundry must be placeable on Cindra")

    foundry.set_recipe(RECIPE)
    local set = foundry.get_recipe()
    assert.is_not_nil(set, "the foundry must accept a recipe")
    assert.are.equal(RECIPE, set.name,
      "the foundry accepts cindra-lava: metallurgy category + a fluid-output box for lava")
    foundry.destroy()
  end)

  it("accepts a productivity module in-machine: the bonus actually applies", function()
    local s = H.cindra_surface()
    game.forces["player"].recipes[RECIPE].enabled = true

    local foundry = s.create_entity({ name = "foundry", position = { 0, 0 }, force = "player" })
    foundry.set_recipe(RECIPE)

    -- Insert a productivity module and confirm the machine reports a live
    -- productivity bonus. This only happens when the recipe allows productivity,
    -- so it proves the flag reaches the machine, not just the prototype.
    local modules = foundry.get_module_inventory()
    assert.is_not_nil(modules, "the foundry must have a module inventory")
    local inserted = modules.insert({ name = "productivity-module", count = 1 })
    assert.are.equal(1, inserted, "a productivity module must go into the foundry")

    local effects = foundry.effects
    assert.is_not_nil(effects, "the foundry must report module effects with a recipe set")
    assert.is_not_nil(effects.productivity, "the productivity effect must be present")
    assert.is_true(effects.productivity > 0,
      "the productivity bonus must be live (recipe allows productivity)")
    foundry.destroy()
  end)
end)
