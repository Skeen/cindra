-- Proof: manufactured lava is the central economy spine (§15-5; DESIGN.md §2,
-- §5, §7). Three claims, matching the bead:
--   1. THE RECIPE:  1 stone + [power] -> 5 lava, crafted in the foundry, gated.
--   2. FOUNDRY INTEGRATION (brought, not re-unlocked): the vanilla molten
--      recipes still consume this lava fluid, unmodified.
--   3. STONE LOOP-BACK: those molten recipes hand stone back as a byproduct.
-- Plus the never-mutate-other-planets guard: the shared Vulcanus recipes keep
-- their canonical values (we cloned nothing, mutated nothing).

local H = require("tests.helpers")

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
  it("is 1 stone + power -> 5 lava (ratio fixed per spec, §7)", function()
    local recipe = prototypes.recipe[RECIPE]
    assert.is_not_nil(recipe, "cindra-lava recipe must exist")

    -- Exactly one ingredient, and it is stone: the material cost is a single
    -- rock, so power (below) is the real cost.
    local n_ingredients = 0
    for _ in pairs(recipe.ingredients) do n_ingredients = n_ingredients + 1 end
    assert.are.equal(1, n_ingredients, "the only ingredient is stone -- no fuel, no carrier")
    assert.are.equal(1, amount_of(recipe.ingredients, "stone"), "1 stone in (spec ratio)")

    -- One product: 5 lava fluid.
    assert.are.equal(5, amount_of(recipe.products, "lava"), "5 lava out (spec ratio)")
  end)

  it("makes power the lever: nontrivial energy cost, no productivity shortcut", function()
    local recipe = prototypes.recipe[RECIPE]
    -- energy_required is the whole cost knob; it must be a real, nontrivial time
    -- so the foundry's electric draw dominates (ruinous power).
    assert.is_true(recipe.energy >= 10,
      "lava must cost real crafting time (the power lever), got " .. tostring(recipe.energy))
    -- Productivity is disabled: a prod bonus would mint free lava and undo the
    -- "power is the honest cost" identity. (Contrast molten-iron-from-lava, which
    -- allows productivity -- proving this is a deliberate, recipe-specific off.)
    assert.is_false(recipe.allowed_effects.productivity,
      "productivity must be OFF: power, not a prod bonus, is what lava costs")
    assert.is_true(prototypes.recipe["molten-iron-from-lava"].allowed_effects.productivity,
      "sanity: the downstream melt DOES allow productivity, so lava's off is deliberate")
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
end)
