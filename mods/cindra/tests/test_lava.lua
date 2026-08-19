-- Proof: manufactured lava is the central economy spine (§15-5; DESIGN.md §2,
-- §5, §7), a SINGLE vanilla-lava fluid whose stone loop-back can never
-- self-sustain (ci-9yg REDO of ci-a0y + ci-4ee). Claims:
--   1. ONE FLUID: there is NO `cindra-lava` fluid; the lava recipe outputs
--      vanilla `lava`, and Cindra casts it through the vanilla molten recipes.
--   2. THE RECIPE:  1 stone -> 5 lava (nerfed from 1:10), cast as a 64:320
--      batch, gated, with productivity DISABLED.
--   3. THE MACHINE: a dedicated Cindra lava-manufacturer at a calm crafting_speed
--      (~1-2, the ci-4ee spazz fix) and a big draw crafts it in a PRIVATE
--      category -- the shared Vulcanus foundry does not.
--   4. USABILITY:   a SINGLE-DIGIT count of manufacturers sustains one melting
--      foundry, and per-machine throughput is unchanged by the spazz fix.
--   5. POWER STAYS RUINOUS: feeding one melt is a serious multi-MW electric sink.
--   6. STONE-NEGATIVITY (ci-9yg, mandatory): across stone->lava->iron and
--      ->copper the loop NET-CONSUMES stone at 0% AND at the +300% productivity
--      cap -- pure recipe math, on all surfaces. The vanilla lava fluid + molten
--      recipes are left untouched (never-mutate guard).

local H = require("tests.helpers")

local RECIPE = "cindra-lava"          -- the stone->lava recipe (name unchanged)
local MACHINE = "cindra-lava-manufacturer"
local CATEGORY = "cindra-lava-manufacturing"
local LAVA_FLUID = "lava"             -- ci-9yg: the ONE lava fluid is vanilla
local CAST_IRON = "molten-iron-from-lava"   -- vanilla cast, reused unmodified
local CAST_COPPER = "molten-copper-from-lava"

-- The engine's hard productivity cap (+300%): the ceiling of ANY module config.
-- The worst case for the loop -- the most stone a cast can ever hand back.
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

-- Nominal lava produced per second by ONE manufacturer: the batch size times the
-- machine speed over the craft time. Productivity is disabled, so this is the
-- true rate at every module tier. (crafting_speed is a method in 2.x because
-- quality can scale it; base quality is what we want here.)
local function lava_per_second(recipe, machine)
  return amount_of(recipe.products, LAVA_FLUID) * machine.get_crafting_speed() / recipe.energy
end

-- Nominal lava consumed per second by ONE melting foundry running the vanilla cast.
local function melt_lava_per_second()
  local melt = prototypes.recipe[CAST_IRON]
  local foundry = prototypes.entity["foundry"]
  return amount_of(melt.ingredients, LAVA_FLUID) * foundry.get_crafting_speed() / melt.energy
end

-- Count of manufacturers needed to sustain one melting foundry (nominal).
local function sustaining_count()
  return melt_lava_per_second() / lava_per_second(prototypes.recipe[RECIPE], prototypes.entity[MACHINE])
end

-- Grid Watts a machine draws (energy_usage is Joule per TICK; * 60 -> Watts).
local function draw_w(machine)
  return machine.energy_usage * 60
end

-- Nominal grid energy spent per unit of lava when `machine` crafts `recipe`:
-- draw * craft_time / batch. This is the "energy-per-lava" the design pins ruinous.
local function energy_per_lava(recipe, machine)
  local craft_time = recipe.energy / machine.get_crafting_speed()
  return draw_w(machine) * craft_time / amount_of(recipe.products, LAVA_FLUID)
end

-- ci-9yg stone accounting for ONE cast (500 lava -> 250 molten + byproduct) at a
-- given cast-recipe productivity. Returns stone-consumed (to make the 500 lava)
-- and stone-returned (the loop-back byproduct).
--   * stone-in: the lava recipe DISALLOWS productivity, so lava-per-craft is
--     FIXED and the stone spent to make the cast's 500 lava never falls. This is
--     the load-bearing fact: no module tier can cheapen the stone-in floor.
--   * stone-out: the cast's stone byproduct scales with the cast recipe's
--     productivity (up to the +300% cap), minus any `ignored_by_productivity`.
local function chain_stone(cast_recipe_name, p_cast)
  local lava_recipe = prototypes.recipe[RECIPE]
  local cast = prototypes.recipe[cast_recipe_name]

  local lava_needed = amount_of(cast.ingredients, LAVA_FLUID)
  local lava_per_craft = amount_of(lava_recipe.products, LAVA_FLUID) -- prod OFF: fixed
  local stone_per_lava_craft = amount_of(lava_recipe.ingredients, "stone")
  local stone_in = (lava_needed / lava_per_craft) * stone_per_lava_craft

  local sp = product_of(cast.products, "stone")
  local ignored = sp.ignored_by_productivity or 0
  local scalable = sp.amount - ignored
  local stone_out = ignored + scalable * (1 + p_cast)

  return stone_in, stone_out
end

describe("cindra manufactured lava", function()
  it("is 1 stone -> 5 lava (ci-9yg nerf), cast as a 64:320 batch, into VANILLA lava", function()
    local recipe = prototypes.recipe[RECIPE]
    assert.is_not_nil(recipe, "cindra-lava recipe must exist")

    -- Exactly one ingredient, and it is stone: the material cost is rock, so
    -- power is the real cost.
    local n_ingredients = 0
    for _ in pairs(recipe.ingredients) do n_ingredients = n_ingredients + 1 end
    assert.are.equal(1, n_ingredients, "the only ingredient is stone -- no fuel, no carrier")

    -- The nerfed ratio: 1 stone -> 5 lava (a 64:320 batch). The batch size keeps
    -- the animation calm at crafting_speed 2; the RATIO is what makes the loop
    -- stone-negative.
    local stone_in = amount_of(recipe.ingredients, "stone")
    local lava_out = amount_of(recipe.products, LAVA_FLUID)
    assert.is_true(stone_in > 0 and lava_out > 0, "the recipe must turn stone into lava")
    assert.are.equal(5, lava_out / stone_in,
      "ci-9yg nerf: 1 stone -> 5 lava (was 1:10), got " .. tostring(lava_out / stone_in))

    -- It outputs the ONE vanilla lava fluid, never a separate `cindra-lava` one.
    assert.is_not_nil(lava_out, "the recipe must output vanilla `lava`")
  end)

  it("has NO separate lava fluid: there is exactly one 'Lava' (ci-9yg)", function()
    -- The whole point of the REDO: the invisible second fluid is GONE. Only the
    -- vanilla `lava` prototype may exist; `cindra-lava` as a fluid must not.
    assert.is_not_nil(prototypes.fluid["lava"], "the one vanilla lava fluid must exist")
    assert.is_nil(prototypes.fluid["cindra-lava"],
      "the separate `cindra-lava` fluid must NOT exist -- Cindra uses vanilla lava end-to-end")
  end)

  it("DISABLES productivity on the lava recipe, so stone-in per cast is fixed (ci-9yg)", function()
    -- The load-bearing invariant knob: a prod bonus on stone->lava would cut the
    -- stone spent per unit lava and could let the cast's returned stone overtake
    -- it (the old self-sustain). Productivity must be OFF here.
    local recipe = prototypes.recipe[RECIPE]
    assert.is_false(recipe.allowed_effects.productivity,
      "productivity must be DISABLED on stone->lava (fixed stone-in -- the ci-9yg invariant)")
    -- energy_required is a real, nontrivial time so the machine's electric draw
    -- dominates (ruinous power is the true cost).
    assert.is_true(recipe.energy >= 10,
      "lava must cost real crafting time (the power lever), got " .. tostring(recipe.energy))
  end)

  it("is crafted in the dedicated Cindra lava-manufacturer, NOT the shared foundry", function()
    -- Lava is routed onto OUR machine, in a PRIVATE category, so the shared
    -- Vulcanus foundry never crafts it (we own our building; we never touch
    -- theirs -- the never-mutate-other-planets invariant). This is machine
    -- routing, NOT a fluid gate.
    local recipe = prototypes.recipe[RECIPE]
    assert.is_true(contains(recipe.categories, CATEGORY),
      "cindra-lava lives in the private " .. CATEGORY .. " category")
    assert.is_false(contains(recipe.categories, "metallurgy"),
      "cindra-lava must NOT be a metallurgy recipe -- it does not run in the shared foundry")

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

  it("runs at a CALM crafting_speed (~1-2), fixing the spazz (ci-4ee)", function()
    -- The animation + working sound scale with crafting_speed; at 64 the machine
    -- spazzed. A speed of ~1-2 plays them at a normal rate.
    local machine = prototypes.entity[MACHINE]
    local speed = machine.get_crafting_speed()
    assert.is_true(speed >= 1 and speed <= 2,
      "crafting_speed must be ~1-2 to avoid the animation/sound spazz, got " .. tostring(speed))
  end)

  it("preserves per-machine throughput through the spazz fix (batch scaled with speed)", function()
    -- The spazz fix drops crafting_speed but scales the recipe batch by the same
    -- factor, so lava/second per machine is unchanged. Pin it against the
    -- pre-fix rate (10 lava at speed 64 over 30 energy = 21.33 lava/s).
    local lps = lava_per_second(prototypes.recipe[RECIPE], prototypes.entity[MACHINE])
    assert.is_true(math.abs(lps - (10 * 64 / 30)) < 0.5,
      "per-machine lava/s must match the pre-spazz-fix rate (~21.3), got " .. string.format("%.2f", lps))
  end)

  it("keeps energy-per-lava RUINOUS (power is the real cost, not the rock)", function()
    -- The grid energy spent per unit lava must stay large: lava is bought with
    -- the star's surplus, not cheap stone. Pin it against the pre-fix value
    -- (40 MW * (30/64)s / 10 lava = 1,875,000 J = 1875 kJ/lava, in Joules), which
    -- the batch rescale keeps.
    local epl = energy_per_lava(prototypes.recipe[RECIPE], prototypes.entity[MACHINE])
    assert.is_true(math.abs(epl - 1875000) < 50000,
      "energy-per-lava must stay ~1875 kJ (ruinous, unchanged by the spazz fix), got "
        .. string.format("%.0f kJ", epl / 1000))
  end)

  it("a SINGLE-DIGIT count of manufacturers sustains one melting foundry", function()
    -- Usability: a handful of manufacturers, not ~100, keep one melting foundry
    -- fed. Computed LIVE from the shipped prototypes so it tracks the real recipes.
    local n = sustaining_count()
    assert.is_true(n >= 1 and n <= 9,
      "a single-digit manufacturer count must sustain one melt (got " .. string.format("%.2f", n) .. ")")
  end)

  it("keeps power RUINOUS: feeding one melt is a serious electric sink (§7, §10)", function()
    -- The aggregate draw to feed ONE melting foundry must remain many MW,
    -- dwarfing baseline solar (§10). Read the draw + the vanilla panel output LIVE.
    local n = sustaining_count()
    local total_w = n * draw_w(prototypes.entity[MACHINE])
    assert.is_true(total_w >= 10e6,
      "feeding one melt must draw >=10 MW of manufacturers (ruinous power), got "
        .. string.format("%.1f MW", total_w / 1e6))

    local panel_w = prototypes.entity["solar-panel"].get_max_energy_production() * 60
    assert.is_true(total_w >= 50 * panel_w,
      "one melt's lava draw must exceed >=50 vanilla solar panels' output, got "
        .. string.format("%.0f panels", total_w / panel_w))
  end)

  it("is gated: recipe + machine disabled, unlocked only by its own tech", function()
    assert.is_false(prototypes.recipe[RECIPE].enabled, "the recipe is not free -- research unlocks it")
    assert.is_false(prototypes.recipe[MACHINE].enabled, "the machine recipe is not free either")

    local tech = prototypes.technology[RECIPE]
    assert.is_not_nil(tech, "cindra-lava technology must exist")
    assert.is_true(tech.valid, "the tech must load (its icon is present)")

    -- The tech unlocks the lava recipe AND the machine that crafts it. It does
    -- NOT need to unlock the casts: those are the VANILLA molten recipes, handed
    -- by the `foundry` tech (a prerequisite here).
    local unlocks = {}
    for _, effect in pairs(tech.effects) do
      if effect.type == "unlock-recipe" then unlocks[effect.recipe] = true end
    end
    assert.is_true(unlocks[RECIPE], "the tech must unlock the cindra-lava recipe")
    assert.is_true(unlocks[MACHINE], "the tech must unlock the lava-manufacturer that crafts it")

    -- Gated behind the foundry (the Vulcanus metal path + the vanilla casts lava
    -- feeds) AND Cindra discovery (so it is Cindra-progression content).
    assert.is_not_nil(tech.prerequisites["foundry"],
      "gated behind the foundry -- the Vulcanus casts + metal chain lava feeds")
    -- ...AND Cindra discovery, in the world that has one. On an APS Cindra start the
    -- player is already there, so the helper asserts that half instead (ci-r7w4).
    H.assert_behind_cindra_discovery(tech.name,
      "gated behind Cindra discovery -- Cindra-progression content")
  end)

  it("casts through the UNMODIFIED vanilla molten recipes (they eat vanilla lava)", function()
    -- ci-9yg: Cindra reuses the vanilla casts as-is -- no Cindra clone. They eat
    -- the same vanilla lava the manufacturer now makes.
    for _, spec in ipairs({
      { name = CAST_IRON, molten = "molten-iron" },
      { name = CAST_COPPER, molten = "molten-copper" },
    }) do
      local r = prototypes.recipe[spec.name]
      assert.is_not_nil(r, spec.name .. " must exist (the vanilla cast Cindra reuses)")
      assert.are.equal(500, amount_of(r.ingredients, LAVA_FLUID),
        spec.name .. " consumes 500 vanilla lava")
      assert.are.equal(250, amount_of(r.products, spec.molten),
        spec.name .. " yields the vanilla 250 " .. spec.molten)
    end
  end)

  it("does not mutate the shared vanilla lava fluid OR molten recipes (never-mutate)", function()
    -- Guard the invariant DIRECTLY: the shared Vulcanus recipes + fluid keep their
    -- canonical values. If a future change mutated-not-cloned, this fails before it
    -- can leak onto Vulcanus.
    assert.are.equal(500, amount_of(prototypes.recipe["molten-iron-from-lava"].ingredients, "lava"),
      "vanilla molten iron still consumes 500 lava (Vulcanus value intact)")
    assert.are.equal(500, amount_of(prototypes.recipe["molten-copper-from-lava"].ingredients, "lava"),
      "vanilla molten copper still consumes 500 lava (Vulcanus value intact)")
    assert.are.equal(250, amount_of(prototypes.recipe["molten-iron-from-lava"].products, "molten-iron"),
      "vanilla molten iron still yields 250 (Vulcanus value intact)")
    assert.are.equal(250, amount_of(prototypes.recipe["molten-copper-from-lava"].products, "molten-copper"),
      "vanilla molten copper still yields 250 (Vulcanus value intact)")
    assert.are.equal(10, amount_of(prototypes.recipe["molten-iron-from-lava"].products, "stone"),
      "vanilla molten iron keeps its 10-stone byproduct (unmutated)")
    assert.are.equal(15, amount_of(prototypes.recipe["molten-copper-from-lava"].products, "stone"),
      "vanilla molten copper keeps its 15-stone byproduct (unmutated)")
    -- The shared fluid keeps its vanilla colour.
    local vanilla = prototypes.fluid["lava"]
    assert.is_true(math.abs(vanilla.base_color.r - 1.0) < 0.01
        and math.abs(vanilla.base_color.g - 0.4) < 0.01
        and math.abs(vanilla.base_color.b - 0.1) < 0.01,
      "the shared vanilla lava fluid keeps its canonical base_color (unmutated)")
  end)

  -- ===== ci-9yg STONE-NEGATIVITY (mandatory) ================================
  -- The core acceptance test: the loop stone -> lava -> (iron OR copper) ->
  -- metal + stone(byproduct) NET-CONSUMES stone at 0% AND at the +300% cap, on
  -- all surfaces (pure recipe math). 500 lava per cast = 100 stone in (fixed,
  -- prod off); the vanilla casts return at most 10*4=40 (iron) / 15*4=60 (copper)
  -- at the cap, both below 100.
  describe("ci-9yg: the stone loop-back is net-NEGATIVE at every productivity", function()
    for _, spec in ipairs({
      { name = CAST_IRON, label = "iron" },
      { name = CAST_COPPER, label = "copper" },
    }) do
      it("net-consumes stone at 0% productivity on the lava->" .. spec.label .. " chain", function()
        local stone_in, stone_out = chain_stone(spec.name, 0)
        assert.is_true(stone_out < stone_in,
          string.format("0%% must net-consume stone (in %.2f, back %.2f)", stone_in, stone_out))
      end)

      it("net-consumes stone at the +300%% productivity cap on lava->" .. spec.label, function()
        -- The worst case: max productivity on the cast (max returned stone). With
        -- prod off on stone->lava the 100 stone-in floor cannot move, so even here
        -- the loop must net-CONSUME. This is the "no module config self-sustains"
        -- guard the whole REDO turns on.
        local stone_in, stone_out = chain_stone(spec.name, MAX_CONCEIVABLE_PROD)
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

  it("a foundry on Cindra accepts the vanilla lava cast (metallurgy + lava input)", function()
    -- The brought-not-re-unlocked foundry crafts the vanilla cast on Cindra: it
    -- eats the vanilla lava the manufacturer makes -> molten iron.
    local s = H.cindra_surface()
    game.forces["player"].recipes[CAST_IRON].enabled = true

    local foundry = s.create_entity({ name = "foundry", position = { 0, 0 }, force = "player" })
    foundry.set_recipe(CAST_IRON)
    assert.are.equal(CAST_IRON, foundry.get_recipe().name,
      "the foundry casts vanilla lava into molten iron on Cindra")
    foundry.destroy()
  end)

  it("rejects a productivity bonus on the lava recipe in-machine (prod is off)", function()
    -- Prove the disabled-productivity flag reaches the machine: with the lava
    -- recipe set, the manufacturer reports no productivity bonus even though the
    -- foundry chassis it is cloned from has module slots.
    local s = H.cindra_surface()
    game.forces["player"].recipes[RECIPE].enabled = true

    local machine = s.create_entity({ name = MACHINE, position = { 0, 0 }, force = "player" })
    machine.set_recipe(RECIPE)

    local effects = machine.effects
    local prod = effects and effects.productivity or 0
    assert.are.equal(0, prod,
      "the manufacturer must report NO productivity bonus on the lava recipe (prod disabled)")
    machine.destroy()
  end)
end)
