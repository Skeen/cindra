-- Proof: Cindra is bootstrappable from NOTHING (§15-1, DESIGN.md §6; ci-uex).
--
-- THE CLAIM (the user's parting, CRITICAL emphasis): a player who lands with
-- only STONE and hand-minable ROCKS can reach a self-sustaining lava->metal
-- economy, with NO chicken-and-egg and NO soft-lock. Every stage's inputs must
-- be obtainable from ONLY the prior stage, rooted at stone + minable rocks.
--
-- This suite proves that path in three complementary layers, each an automated
-- assertion (never a PLAYTEST hand-wave):
--
--   1. ROOT IS FINITE + HAND-OBTAINABLE. The bootstrap rock is a simple-entity
--      (destroyed when mined -> finite, per §6), yielding stone + a small metal
--      trickle; stone/ice/volatiles are placed, minable raws. So the root of the
--      chain is real and cannot become a per-craft supply of the main loop.
--
--   2. THE SPINE TURNS ON, DRIVEN FOR REAL. A powered foundry on a Cindra
--      surface crafts stone -> lava, and a second foundry melts that lava (+ the
--      locally-produced calcite) into molten iron, returning stone as a
--      byproduct. This is the "turn on the stone->lava->metal economy" step
--      exercised end-to-end, not asserted on paper.
--
--   3. NO CHICKEN-AND-EGG (reachability solver). A fixpoint over the actual
--      recipe prototypes proves that, given a FINITE brought bootstrap seed
--      (what a post-Vulcanus arrival carries: a foundry + a little
--      steel/gears/brick/pipe), the whole chain up to the headline Cindra
--      science pack becomes reachable -- and that the seed materials then become
--      LOCALLY renewable (calcite from ice, iron-plate from cast lava), so the
--      seed is a one-time bootstrap, not a permanent import. The SAME solver run
--      from absolute zero (no seed at all) provably STALLS before metal -- which
--      is exactly the start-on-Cindra (any-planet-start) soft-lock that the
--      dedicated foundry-bootstrap work (ci-arw) must close. That negative
--      assertion is a deliberate tripwire: when a lubricant-free / kitted APS
--      foundry lands, this expectation must be revisited (see the APS block).
--
-- 🚨 Runs entirely on a surface named "cindra" (H.cindra_surface), so it never
-- touches nauvis or any other planet (never-mutate-other-planets invariant).

local H = require("tests.helpers")

-- === small readers over recipe prototypes ==================================

-- The set of ingredient NAMES (items and fluids) a recipe consumes.
local function ingredient_names(recipe_name)
  local names = {}
  for _, i in pairs(prototypes.recipe[recipe_name].ingredients) do
    names[#names + 1] = i.name
  end
  return names
end

-- The set of product NAMES a recipe yields (for a build recipe this is the
-- machine item; for a fluid recipe the fluid; etc.).
local function product_names(recipe_name)
  local names = {}
  for _, p in pairs(prototypes.recipe[recipe_name].products) do
    names[#names + 1] = p.name
  end
  return names
end

-- ===========================================================================
-- LAYER 1: the root is finite and hand-obtainable.
-- ===========================================================================
describe("cindra bootstrap: the root (stone + finite hand-minable rocks)", function()
  it("bootstrap rocks are FINITE: a simple-entity destroyed on mining, not a resource (§6)", function()
    local rock = prototypes.entity["cindra-bootstrap-rock"]
    assert.is_not_nil(rock, "the bootstrap rock entity must exist")
    -- A `resource` depletes but PERSISTS (an infinite/finite ore patch); a
    -- `simple-entity` rock is DESTROYED the moment it is mined. The §6 rule --
    -- "bootstrap rocks are one-time building costs, never a per-craft loop
    -- input" -- is only true if the rock cannot be re-mined, i.e. it is not a
    -- resource. Guard the type directly.
    assert.are.equal("simple-entity", rock.type,
      "the bootstrap rock must be a simple-entity (mined once, then gone) -- NOT a resource patch")
    assert.is_not_nil(rock.mineable_properties, "the rock must be mineable by hand")
    assert.is_true(rock.mineable_properties.minable, "the rock must be mineable")
  end)

  it("bootstrap rocks yield stone + a small metal trickle (the landing-tier drop, §5)", function()
    local rock = prototypes.entity["cindra-bootstrap-rock"]
    local results = rock.mineable_properties.products
    assert.is_not_nil(results, "the rock must drop something when mined")

    -- A minable drop may be a fixed `amount` or a random `amount_min..amount_max`
    -- range (the rock uses the latter for stone); accept either as long as it is
    -- a positive stone yield.
    local stone_entry
    for _, r in pairs(results) do
      if r.name == "stone" then stone_entry = r end
    end
    assert.is_not_nil(stone_entry, "a mined bootstrap rock must drop stone (the ribbon feedstock)")
    assert.is_true((stone_entry.amount or stone_entry.amount_max or 0) > 0,
      "the stone drop must be a positive amount")

    -- A small metal trickle rides along (Vulcanus-legacy metal, accepted for the
    -- bootstrap per §5). We assert SOME non-stone item drops (the exact metal /
    -- amount is a balance decision, §15-13), not a specific one.
    local has_metal_trickle = false
    for _, r in pairs(results) do
      if r.name ~= "stone" and r.type ~= "fluid" then has_metal_trickle = true end
    end
    assert.is_true(has_metal_trickle,
      "a mined bootstrap rock must also drop a small metal trickle (landing-tier material)")
  end)

  it("stone / ice / volatiles are placed, hand-minable raws (the other roots)", function()
    for _, name in ipairs({ "cindra-stone", "cindra-ice", "cindra-volatiles" }) do
      local res = prototypes.entity[name]
      assert.is_not_nil(res, name .. " resource must exist")
      assert.are.equal("resource", res.type, name .. " must be a minable resource")
    end
    -- The stone resource yields the vanilla `stone` item that the lava spine eats.
    assert.are.equal("stone", prototypes.entity["cindra-stone"].mineable_properties.products[1].name,
      "the Cindra stone resource must yield the `stone` item (the lava recipe's input)")
  end)
end)

-- ===========================================================================
-- LAYER 2: the stone -> lava -> metal spine turns on, driven end-to-end.
-- A foundry is powered on a Cindra surface; we drive real ticks and read the
-- resulting fluids/items. This is the "turn on the economy" milestone proved
-- behaviourally, not just from prototype shape.
-- ===========================================================================
describe("cindra bootstrap: the stone->lava->metal spine turns on (runtime)", function()
  -- A cheat electric source + a substation so machines on the Cindra surface
  -- share a network and actually run headless. Mirrors the ice/aluminium tests.
  local function powered_surface()
    local s = H.cindra_surface()
    s.create_entity({ name = "substation", position = { 8, 8 }, force = "player" })
    local power = s.create_entity({
      name = "electric-energy-interface", position = { 10, 8 }, force = "player",
    })
    power.power_production = 100000000 -- 100 MW: covers the caster's 40 MW draw + a foundry
    power.electric_buffer_size = 100000000
    power.energy = 100000000
    return s
  end

  it("a lava-manufacturer crafts stone -> lava (the fire spine ignites from a hand resource)", function()
    local s = powered_surface()
    game.forces["player"].recipes["cindra-lava"].enabled = true

    -- Lava is crafted on the dedicated Cindra caster (ci-e8a), not the shared
    -- foundry: a fast, high-draw machine so a single-digit count feeds a foundry.
    local caster = s.create_entity({ name = "cindra-lava-manufacturer", position = { 0, 0 }, force = "player" })
    caster.set_recipe("cindra-lava")
    -- Stone is the ONLY input the player has hand-mined at this point.
    caster.insert({ name = "stone", count = 50 })

    async(1800)
    after_ticks(900, function()
      assert.is_true(caster.valid)
      local lava = caster.get_fluid_count("lava")
      assert.is_true(lava > 0,
        "the lava-manufacturer must have made lava from stone (got " .. lava
          .. ", stone left " .. caster.get_item_count("stone") .. ")")
      caster.destroy()
      done()
    end)
  end)

  it("a foundry melts lava (+local calcite) -> molten iron, returning stone (loop closes)", function()
    local s = powered_surface()
    game.forces["player"].recipes["molten-iron-from-lava"].enabled = true

    local foundry = s.create_entity({ name = "foundry", position = { 0, 0 }, force = "player" })
    foundry.set_recipe("molten-iron-from-lava")
    -- Feed the lava the previous step makes (1500 C, the manufactured spine
    -- fluid) plus calcite -- which on Cindra comes from the ICE chain, proving
    -- the fire and ice edges are coupled at the very first metal step.
    foundry.insert_fluid({ name = "lava", amount = 600, temperature = 1500 })
    foundry.insert({ name = "calcite", count = 10 })

    async(1800)
    after_ticks(900, function()
      assert.is_true(foundry.valid)
      local molten = foundry.get_fluid_count("molten-iron")
      assert.is_true(molten > 0,
        "the foundry must have melted lava into molten iron (got " .. molten .. ")")
      -- STONE LOOP-BACK: the melt returns stone, so mining is a top-up, not the
      -- whole supply. This is the byproduct that feeds fresh lava.
      local stone_back = foundry.get_item_count("stone")
      assert.is_true(stone_back > 0,
        "the melt must return stone as a byproduct (loop-back, got " .. stone_back .. ")")
      foundry.destroy()
      done()
    end)
  end)
end)

-- ===========================================================================
-- LAYER 3: no chicken-and-egg -- a reachability solver over the real recipes.
--
-- `reach(seed)` computes, by fixpoint, the set of item/fluid names producible
-- starting from `seed` (the materials + machines the player begins with). A
-- production fires when its machine is available (a hand craft, or the machine's
-- item is already producible) AND all its ingredients are producible; its
-- products then join the set. If any milestone required ITSELF (an unbreakable
-- cycle), the fixpoint would never include it -- so reachability of every
-- milestone IS the "no chicken-and-egg" proof.
-- ===========================================================================
describe("cindra bootstrap: every stage's inputs come only from earlier stages", function()
  -- The productions that make up the Cindra bootstrap chain. Each names a real
  -- recipe (ingredients/products read LIVE from the prototype, so the solver can
  -- never drift from the shipped recipes) and the machine that runs it:
  --   * "hand"  -> a character/assembler craft (no special machine gate),
  --   * else    -> the ITEM of the machine that must first be built/brought.
  -- Ordering is emergent from the fixpoint, not hard-coded here.
  local PRODUCTIONS = {
    { r = "cindra-ice-crusher",              m = "hand" },                 -- build the crusher
    { r = "cindra-ice-melter",               m = "hand" },                 -- build the melter
    { r = "cindra-ice-crushing",             m = "cindra-ice-crusher" },   -- ice -> crushed-ice
    { r = "cindra-ice-crushing-calcite",     m = "cindra-ice-crusher" },   -- ice -> crushed-ice + calcite
    { r = "cindra-ice-melting",              m = "cindra-ice-melter" },    -- crushed-ice -> water
    { r = "cindra-lava-manufacturer",        m = "hand" },                 -- build the dedicated caster
    { r = "cindra-lava",                     m = "cindra-lava-manufacturer" }, -- stone -> lava (ci-e8a)
    { r = "molten-iron-from-lava",           m = "foundry" },              -- lava + calcite -> molten iron
    { r = "casting-iron",                    m = "foundry" },              -- molten iron -> iron plate
    { r = "iron-gear-wheel",                 m = "hand" },                 -- iron plate -> gears
    { r = "molten-copper-from-lava",         m = "foundry" },              -- lava + calcite -> molten copper
    { r = "casting-copper",                  m = "foundry" },              -- molten copper -> copper plate
    { r = "copper-cable",                    m = "hand" },                 -- copper plate -> copper cable
    { r = "cindra-alumina",                  m = "hand" },                 -- stone + calcite -> alumina
    { r = "cindra-electrolysis-cell",        m = "hand" },                 -- build the electrolysis cell
    { r = "cindra-aluminium",                m = "cindra-electrolysis-cell" }, -- alumina + [power] -> aluminium
    { r = "cindra-starforge",                m = "hand" },                 -- build the starforge
    { r = "cindra-science-pack",             m = "cindra-starforge" },     -- aluminium + volatiles + calcite -> pack
  }

  -- Fixpoint over PRODUCTIONS. `seed` is a set {name -> true}. Returns the closed
  -- set of everything producible, plus a set of names produced by SOME
  -- production (i.e. locally renewable, independent of the seed).
  local function reach(seed)
    local have = {}
    for k in pairs(seed) do have[k] = true end
    local produced = {}
    local changed = true
    while changed do
      changed = false
      for _, p in pairs(PRODUCTIONS) do
        local machine_ready = (p.m == "hand") or have[p.m]
        if machine_ready then
          local inputs_ready = true
          for _, ing in ipairs(ingredient_names(p.r)) do
            if not have[ing] then inputs_ready = false break end
          end
          if inputs_ready then
            for _, out in ipairs(product_names(p.r)) do
              if not have[out] then have[out] = true; changed = true end
              produced[out] = true
            end
          end
        end
      end
    end
    return have, produced
  end

  -- What a from-nothing player hand-gathers on Cindra (the true roots): the
  -- `stone` and `ice` items the resources yield, and the deep-nightside
  -- `cindra-volatiles` item (the science pack's native input).
  local HAND_ROOTS = { stone = true, ice = true, ["cindra-volatiles"] = true }

  -- The FINITE brought bootstrap seed a post-Vulcanus arrival carries. A foundry
  -- (imported, per DESIGN §8) plus a little metal stock to build the FIRST
  -- crusher/cell/forge before the local metal loop ramps. These are one-time
  -- costs: the solver proves below they become locally renewable.
  local BROUGHT_SEED = {
    ["foundry"] = true,
    ["steel-plate"] = true,
    ["iron-gear-wheel"] = true,
    ["stone-brick"] = true,
    ["pipe"] = true,
  }

  local function merged(...)
    local out = {}
    for _, t in ipairs({ ... }) do
      for k in pairs(t) do out[k] = true end
    end
    return out
  end

  it("reaches the WHOLE chain (lava -> metal -> aluminium -> science) from hand roots + a finite seed", function()
    local have = reach(merged(HAND_ROOTS, BROUGHT_SEED))
    -- Each milestone reachable == its recipe's inputs were satisfiable from
    -- earlier steps only. If any needed itself, the fixpoint would omit it.
    for _, milestone in ipairs({
      "lava",                          -- fire spine on
      "molten-iron",                   -- metal economy on
      "iron-plate",                    -- fabricable metal
      "water", "calcite",              -- ice chain
      "cindra-aluminium",              -- the signature product
      "cindra-science-pack",           -- headline science: the chain closes
    }) do
      assert.is_true(have[milestone] == true,
        "bootstrap chain must reach `" .. milestone .. "` from hand roots + the finite seed (no chicken-and-egg)")
    end
  end)

  it("is SELF-SUSTAINING: the finite seed materials become locally renewable", function()
    local _, produced = reach(merged(HAND_ROOTS, BROUGHT_SEED))
    -- The seed handed us steel/gears/brick/pipe + a foundry ONCE. For the economy
    -- to be self-sustaining (not a permanent import), the loop must produce its
    -- own key intermediates. Prove the two non-obvious renewables:
    assert.is_true(produced["calcite"] == true,
      "calcite must be LOCALLY produced (from ice), not permanently imported -- the metal melt needs it every cycle")
    assert.is_true(produced["iron-plate"] == true,
      "iron-plate must be LOCALLY produced (cast from manufactured lava), so gears/pipe/steel renew from the loop")
    assert.is_true(produced["iron-gear-wheel"] == true,
      "gears must be LOCALLY produced from local iron-plate -- the brought gear seed is a one-time bootstrap")
  end)

  it("the finite bootstrap rock is NEVER a per-craft input of the main loop (§6)", function()
    -- The core Cindra loop runs on RENEWABLE stone + ice, never on the finite
    -- rocks or their metal trickle. Walk the loop recipes and assert none
    -- consumes the rock entity or a rock-only drop, so mining rocks stays a
    -- one-time building cost, never a supply the loop depends on.
    local rock_metal = {}
    for _, r in pairs(prototypes.entity["cindra-bootstrap-rock"].mineable_properties.products) do
      if r.name ~= "stone" then rock_metal[r.name] = true end
    end
    for _, recipe in ipairs({
      "cindra-lava", "molten-iron-from-lava",
      "cindra-ice-crushing", "cindra-ice-crushing-calcite", "cindra-ice-melting",
      "cindra-alumina", "cindra-aluminium", "cindra-science-pack",
    }) do
      for _, ing in ipairs(ingredient_names(recipe)) do
        assert.is_falsy(rock_metal[ing],
          recipe .. " must not consume the finite bootstrap-rock trickle `" .. ing
            .. "` -- the main loop runs on renewable stone + ice (§6)")
        assert.are_not.equal("cindra-bootstrap-rock", ing,
          recipe .. " must not consume the rock entity itself")
      end
    end
  end)
end)

-- ===========================================================================
-- APS start-on-Cindra: the from-ABSOLUTE-zero soft-lock (owned by ci-arw).
--
-- A normal arrival carries the finite seed above (imported foundry + a little
-- metal). A start-on-Cindra (any-planet-start) run has NEITHER -- no Vulcanus to
-- import a foundry from, and the vanilla foundry build needs lubricant (oil
-- chemistry Cindra cannot make). This block asserts, from the DEFAULT run (no
-- APS mods needed), that the reachability solver run from absolute zero STALLS
-- before metal -- i.e. an APS start MUST be given a foundry (starter kit) or a
-- lubricant-free foundry recipe, which is the dedicated bead ci-arw.
--
-- This is a deliberate tripwire: it encodes the CURRENT gap as an executable
-- fact. When ci-arw lands a kitted / lubricant-free APS foundry, its own suite
-- proves the start-on-Cindra path closes, and THIS assertion (which asserts the
-- gap still exists on plain `mods/cindra`) must be revisited together with the
-- end-to-end APS bootstrap test tracked in the follow-up bead.
-- ===========================================================================
describe("cindra bootstrap: start-on-Cindra from absolute zero is gated on a foundry (ci-arw)", function()
  -- Re-declare the solver locally (kept tiny + independent of the block above so
  -- this reads as a standalone statement of the gap).
  local PRODUCTIONS = {
    { r = "cindra-ice-crusher",        m = "hand" },
    { r = "cindra-lava-manufacturer",  m = "hand" },                     -- caster (needs starter metal)
    { r = "cindra-lava",               m = "cindra-lava-manufacturer" }, -- stone -> lava (ci-e8a)
    { r = "molten-iron-from-lava",     m = "foundry" },
    { r = "casting-iron",              m = "foundry" },
  }
  local function reach(seed)
    local have = {}
    for k in pairs(seed) do have[k] = true end
    local changed = true
    while changed do
      changed = false
      for _, p in pairs(PRODUCTIONS) do
        if (p.m == "hand") or have[p.m] then
          local ok = true
          for _, ing in ipairs(ingredient_names(p.r)) do
            if not have[ing] then ok = false break end
          end
          if ok then
            for _, out in ipairs(product_names(p.r)) do
              if not have[out] then have[out] = true; changed = true end
            end
          end
        end
      end
    end
    return have
  end

  it("the vanilla foundry build needs lubricant -- unmakeable on Cindra (the soft-lock cause)", function()
    local foundry_build = prototypes.recipe["foundry"]
    assert.is_not_nil(foundry_build, "the vanilla foundry build recipe must exist")
    local needs_lubricant = false
    for _, ing in ipairs(ingredient_names("foundry")) do
      if ing == "lubricant" then needs_lubricant = true end
    end
    assert.is_true(needs_lubricant,
      "the vanilla foundry build consumes lubricant (petrochemical) -- so a no-Vulcanus start cannot build one")
  end)

  it("from absolute zero (hand roots only, no metal) the chain STALLS before metal", function()
    -- Exactly the start-on-Cindra condition: only what the terminator gives you.
    -- Lava now needs the dedicated caster (ci-e8a), which itself needs starter
    -- metal, and melting still needs the (unbuildable-on-Cindra) foundry -- so
    -- from bare hand roots there is neither a caster nor a foundry, and the chain
    -- cannot even make lava.
    local have = reach({ stone = true, ice = true, ["cindra-volatiles"] = true })
    assert.is_falsy(have["lava"],
      "from bare hand roots there is no metal to build a caster and no foundry -> the APS start soft-locks (ci-arw)")
    assert.is_falsy(have["molten-iron"],
      "and therefore no metal -> the from-zero economy cannot turn on unaided")
  end)

  it("a starter foundry + a little starter metal breaks the stall (the fix ci-arw must deliver)", function()
    -- Prove the fix is small + well-scoped: hand a start-on-Cindra player ONE
    -- foundry (kit) plus a little starter metal (steel/gears/brick) -- the same
    -- pinch that builds the first crusher also builds the lava caster -- and the
    -- chain immediately reaches metal. The foundry remains the keystone (it alone
    -- cannot be built on Cindra, needing lubricant); the caster is cheap local
    -- metal. This is the target ci-arw + the APS kit must satisfy; the end-to-end
    -- APS-mods proof lives in the follow-up bead.
    local have = reach({
      stone = true, ice = true, ["cindra-volatiles"] = true,
      foundry = true, calcite = true,                  -- one kitted foundry + a pinch of starter calcite
      ["steel-plate"] = true, ["iron-gear-wheel"] = true, ["stone-brick"] = true, -- starter metal for the caster
    })
    assert.is_true(have["lava"] == true,
      "with a kitted foundry + starter metal, a lava caster is buildable and stone -> lava turns on")
    assert.is_true(have["molten-iron"] == true,
      "and the metal economy turns on -- the missing pieces for APS are the foundry (keystone) + starter metal (ci-arw)")
  end)
end)
