-- Proof: Cindra sources sulfur -> sulfuric acid from its stone (ci-eat).
--
-- Route (Overseer's preferred lean): the melt IS the roast. The stone->lava
-- recipe (`cindra-lava`) also liberates a SMALL sulfur byproduct, and the same
-- tech unlocks the VANILLA `sulfur + water -> sulfuric-acid` recipe (run in the
-- chemical plant Cindra already uses for ice-melting). Claims:
--   1. THE BYPRODUCT: cindra-lava yields sulfur, SMALL next to its lava, and
--      fully `ignored_by_productivity` -- combined with the recipe's disabled
--      productivity, sulfur is FIXED at every module tier (no free-sulfur exploit,
--      respecting ci-669 + the ci-9yg/ci-a0y stone economy).
--   2. LAVA STAYS THE MAIN PRODUCT: `main_product = lava`, and the recipe still
--      has exactly ONE ingredient (stone) -- the byproduct adds no cost/carrier.
--   3. THE CHAIN CLOSES: the vanilla sulfuric-acid recipe consumes sulfur + water
--      and outputs sulfuric-acid, and the cindra-lava tech UNLOCKS it.
--   4. NEVER-MUTATE: the shared vanilla sulfuric-acid recipe keeps its canonical
--      shape (we only unlock it, never edit it) -- Vulcanus/other planets safe.
--   5. RUNTIME: the manufacturer still accepts cindra-lava with its new solid
--      output, and a chemical plant on Cindra accepts the sulfuric-acid recipe.

local H = require("tests.helpers")

local RECIPE = "cindra-lava"
local MACHINE = "cindra-lava-manufacturer"
local TECH = "cindra-lava"
local LAVA_FLUID = "lava"
local SULFUR = "sulfur"
local ACID_RECIPE = "sulfuric-acid"
local ACID_FLUID = "sulfuric-acid"
local WATER = "water"

-- The engine's hard productivity cap (+300%): the worst case a module config can
-- ever reach. Sulfur must not grow even here.
local MAX_CONCEIVABLE_PROD = 3.0

local function amount_of(list, name)
  for _, e in pairs(list) do
    if e.name == name then return e.amount end
  end
  return nil
end

local function product_of(list, name)
  for _, e in pairs(list) do
    if e.name == name then return e end
  end
  return nil
end

-- The runtime recipe `categories` may be an array OR a set keyed by name; mirror
-- the check used across the other Cindra recipe tests.
local function in_category(recipe, category)
  local cats = recipe.categories
  if cats[category] then return true end
  for _, v in pairs(cats) do
    if v == category then return true end
  end
  return false
end

describe("cindra sulfur from roasting crushed stone (ci-eat)", function()
  it("cindra-lava yields sulfur as a byproduct", function()
    local recipe = prototypes.recipe[RECIPE]
    assert.is_not_nil(recipe, "the cindra-lava recipe must exist")
    local sulfur_out = amount_of(recipe.products, SULFUR)
    assert.is_not_nil(sulfur_out, "cindra-lava must output sulfur (the roast byproduct)")
    assert.is_true(sulfur_out > 0, "the sulfur byproduct must be positive, got " .. tostring(sulfur_out))
  end)

  it("keeps sulfur SMALL: lava is clearly the main product", function()
    local recipe = prototypes.recipe[RECIPE]
    local lava_out = amount_of(recipe.products, LAVA_FLUID)
    local sulfur_out = amount_of(recipe.products, SULFUR)
    -- A genuine byproduct, not a co-product: far less sulfur than lava, so nobody
    -- reads this recipe as "the sulfur recipe".
    assert.is_true(sulfur_out * 10 <= lava_out,
      "sulfur must be a SMALL byproduct (<=10% of lava), got sulfur=" .. tostring(sulfur_out)
        .. " lava=" .. tostring(lava_out))
    -- The recipe still reads as "Lava" (single named product in the UI).
    assert.are.equal(LAVA_FLUID, recipe.main_product and recipe.main_product.name,
      "main_product must stay lava so the recipe reads as 'Lava', not 'Sulfur'")
  end)

  it("adds NO new ingredient: the only input is still stone (no carrier/cost)", function()
    -- The byproduct must not smuggle in a cost knob: roasting the SAME stone into
    -- lava is what liberates the sulfur. Guards the ci-9yg "only ingredient is
    -- stone" shape against a sulfur-driven regression.
    local recipe = prototypes.recipe[RECIPE]
    local n = 0
    for _ in pairs(recipe.ingredients) do n = n + 1 end
    assert.are.equal(1, n, "cindra-lava must still take exactly one ingredient (stone)")
    assert.is_not_nil(amount_of(recipe.ingredients, "stone"), "that ingredient is stone")
  end)

  it("pins sulfur against ANY productivity: no free-sulfur exploit (ci-669/ci-9yg)", function()
    local recipe = prototypes.recipe[RECIPE]
    -- Belt: productivity is disabled on the whole recipe (the ci-9yg invariant),
    -- so no prod bonus can ever apply to sulfur.
    assert.is_false(recipe.allowed_effects.productivity,
      "productivity must stay DISABLED on cindra-lava (fixes both lava and sulfur)")

    -- Suspenders: the sulfur result is fully ignored_by_productivity, so even if a
    -- future edit re-enabled productivity, sulfur output would not move. Compute
    -- the effective sulfur at the +300% cap and assert it equals the base amount.
    local sp = product_of(recipe.products, SULFUR)
    local ignored = sp.ignored_by_productivity or 0
    local scalable = sp.amount - ignored
    local at_cap = ignored + scalable * (1 + MAX_CONCEIVABLE_PROD)
    assert.are.equal(sp.amount, at_cap,
      "sulfur must be fully ignored_by_productivity: fixed at the +300% cap (got "
        .. tostring(at_cap) .. " vs base " .. tostring(sp.amount) .. ")")
  end)

  it("the cindra-lava tech UNLOCKS the vanilla sulfuric-acid recipe", function()
    local tech = prototypes.technology[TECH]
    assert.is_not_nil(tech, "the cindra-lava tech must exist")
    local unlocks = {}
    for _, effect in pairs(tech.effects) do
      if effect.type == "unlock-recipe" then unlocks[effect.recipe] = true end
    end
    assert.is_true(unlocks[ACID_RECIPE],
      "the tech must unlock the sulfuric-acid recipe -- the sulfur byproduct feeds it")
  end)

  it("the sulfuric-acid chain closes with Cindra resources (sulfur + water -> acid)", function()
    local acid = prototypes.recipe[ACID_RECIPE]
    assert.is_not_nil(acid, "the vanilla sulfuric-acid recipe must exist")
    -- Consumes the sulfur the roast produces and the water the ice chain melts...
    assert.is_true((amount_of(acid.ingredients, SULFUR) or 0) > 0,
      "sulfuric-acid must consume sulfur (Cindra's roast byproduct)")
    assert.is_true((amount_of(acid.ingredients, WATER) or 0) > 0,
      "sulfuric-acid must consume water (Cindra's ice-melt output)")
    -- ...and yields the sulfuric-acid fluid vanilla recipes expect.
    assert.is_true((amount_of(acid.products, ACID_FLUID) or 0) > 0,
      "sulfuric-acid must produce the sulfuric-acid fluid")
  end)

  it("never mutates the shared vanilla sulfuric-acid recipe (only unlocks it)", function()
    -- We add sulfuric-acid as a Cindra UNLOCK, never an edit. Guard the canonical
    -- vanilla shape directly so a future 'adapt the recipe' change can't silently
    -- leak onto Vulcanus/other planets. Vanilla: 5 sulfur + 1 iron-plate +
    -- 100 water -> 50 sulfuric-acid, in the shared `chemistry` category.
    local acid = prototypes.recipe[ACID_RECIPE]
    assert.are.equal(5, amount_of(acid.ingredients, SULFUR),
      "vanilla sulfuric-acid still takes 5 sulfur (unmutated)")
    assert.are.equal(1, amount_of(acid.ingredients, "iron-plate"),
      "vanilla sulfuric-acid still takes 1 iron-plate (unmutated)")
    assert.are.equal(100, amount_of(acid.ingredients, WATER),
      "vanilla sulfuric-acid still takes 100 water (unmutated)")
    assert.are.equal(50, amount_of(acid.products, ACID_FLUID),
      "vanilla sulfuric-acid still yields 50 acid (unmutated)")
    assert.is_true(in_category(acid, "chemistry"),
      "sulfuric-acid stays a chemistry recipe (runs in the chemical plant)")
  end)

  it("the manufacturer still accepts cindra-lava with its new solid output", function()
    -- Adding a solid item byproduct alongside the fluid must not break machine
    -- routing: a foundry (this machine's chassis) has an item result slot, so the
    -- lava-manufacturer accepts the recipe with lava (fluid) + sulfur (item).
    local s = H.cindra_surface()
    game.forces["player"].recipes[RECIPE].enabled = true

    local machine = s.create_entity({ name = MACHINE, position = { 0, 0 }, force = "player" })
    assert.is_not_nil(machine, "the lava-manufacturer must be placeable on Cindra")
    machine.set_recipe(RECIPE)
    assert.are.equal(RECIPE, machine.get_recipe().name,
      "the manufacturer accepts cindra-lava with a fluid + solid output")
    machine.destroy()
  end)

  it("a chemical plant on Cindra accepts the sulfuric-acid recipe", function()
    local s = H.cindra_surface()
    game.forces["player"].recipes[ACID_RECIPE].enabled = true

    local plant = s.create_entity({ name = "chemical-plant", position = { 0, 0 }, force = "player" })
    assert.is_not_nil(plant, "a chemical plant must be placeable on Cindra")
    plant.set_recipe(ACID_RECIPE)
    assert.are.equal(ACID_RECIPE, plant.get_recipe().name,
      "the chemical plant accepts sulfuric-acid on Cindra (sulfur + water -> acid)")
    plant.destroy()
  end)
end)
