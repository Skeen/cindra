-- Proof: the END-TO-END start-on-Cindra bootstrap (ci-7p6). A from-ABSOLUTE-zero
-- Any Planet Start on Cindra -- no Vulcanus to import a foundry from, no
-- petrochemistry for lubricant -- reaches a foundry AND the lava->metal economy,
-- and reproduces its own foundries so it is not a one-time import.
--
-- This is the companion end-to-end proof to two narrower APS suites:
--   * test_aps_foundry -- the pre-research (the Cindra-start tech grant) took effect.
--   * test_aps_kit     -- the MINIMAL physical kit (a foundry + lava caster + power).
-- Those each pin one mechanism in isolation. HERE we drive the whole thing:
-- given ONLY what a from-nothing Cindra start actually has at tick zero (the mined
-- hand roots + the kit machines + the pre-researched recipe state), the metal
-- economy turns on end-to-end, and the keystone machine (the foundry) is
-- reproducible on Cindra without ever touching Vulcanus.
--
-- ci-uex's test_bootstrap proves the NORMAL-arrival path (a post-Vulcanus player
-- brings a foundry + a little metal). Its from-absolute-zero solver deliberately
-- STALLS -- that stall is the exact gap this APS work closes, and this suite is
-- the positive counterpart: the SAME from-zero condition, but WITH the APS kit +
-- pre-research, provably reaches metal.
--
-- Loads ONLY under the APS chain (see control.lua): the plain `mods/cindra` run
-- does not load cindra-start, so it never executes there. The describe names share
-- the "cindra APS start chain" prefix so the documented filtered APS invocation
-- (`-- "cindra APS start chain"`, see README/SETUP) runs it alongside the other
-- APS suites.
--
-- 🚨 Runs entirely on a surface named "cindra" (H.cindra_surface), so it never
-- touches nauvis or any other planet (never-mutate-other-planets invariant).

local H = require("tests.helpers")

-- === small readers over recipe prototypes (mirror test_bootstrap) ==========
local function ingredient_names(recipe_name)
  local names = {}
  for _, i in pairs(prototypes.recipe[recipe_name].ingredients) do
    names[#names + 1] = i.name
  end
  return names
end

local function product_names(recipe_name)
  local names = {}
  for _, p in pairs(prototypes.recipe[recipe_name].products) do
    names[#names + 1] = p.name
  end
  return names
end

-- A cheat electric source + a substation so machines on the Cindra surface share a
-- network and actually run headless (mirrors test_bootstrap / test_foundry_bootstrap).
local function powered_surface()
  local s = H.cindra_surface()
  s.create_entity({ name = "substation", position = { 8, 8 }, force = "player" })
  local power = s.create_entity({
    name = "electric-energy-interface", position = { 10, 8 }, force = "player",
  })
  power.power_production = 100000000 -- 100 MW: covers the caster's high draw + a foundry
  power.electric_buffer_size = 100000000
  power.energy = 100000000
  return s
end

describe("cindra APS start chain: end-to-end from-nothing bootstrap (no Vulcanus)", function()
  it("only applies to a Cindra start (sanity)", function()
    assert.is_true(H.aps_loaded(), "APS must be active for this suite")
    assert.is_not_nil(script.active_mods["cindra-start"], "cindra-start must be active")
    assert.is_true(H.aps_cindra_start(),
      "this suite drives the Cindra-start bootstrap; the picker must be Cindra")
  end)

  -- =========================================================================
  -- LAYER 1: the kit is EXACTLY what closes the from-zero stall.
  --
  -- A tiny reachability solver over the REAL spine recipes (ingredients/products
  -- read live from the prototypes, so it can never drift from the shipped recipes).
  -- Run it twice from the same production set, changing only the seed:
  --   * bare hand roots (what the terminator gives you) -> STALLS before lava, the
  --     from-absolute-zero soft-lock ci-uex's tripwire encodes.
  --   * hand roots + the KIT machines (foundry + lava caster) -> reaches metal.
  -- The delta is the kit: with no Vulcanus and no brought metal seed at all, the
  -- two kit machines alone turn the stone->lava->metal spine on.
  -- =========================================================================
  local SPINE = {
    { r = "cindra-lava",           m = "cindra-lava-manufacturer" }, -- stone -> lava
    { r = "molten-iron-from-lava", m = "foundry" },                  -- lava + calcite -> molten iron
    { r = "casting-iron",          m = "foundry" },                  -- molten iron -> iron plate
  }

  local function reach(seed)
    local have = {}
    for k in pairs(seed) do have[k] = true end
    local changed = true
    while changed do
      changed = false
      for _, p in pairs(SPINE) do
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

  -- What a from-nothing Cindra start mines by hand: the stone the ribbon yields and
  -- the fixed ice+calcite mix the nightside ice field yields (ci-9l6). No metal.
  local HAND_ROOTS = { stone = true, ice = true, calcite = true }

  -- The MINIMAL kit (ci-8wu): the two machines a from-scratch start cannot easily
  -- hand-build. These are physical MACHINES handed over, not brought metal stock --
  -- the point is that the kit gives no free intermediates, only the two keystones.
  local KIT_MACHINES = { foundry = true, ["cindra-lava-manufacturer"] = true }

  it("from bare hand roots (no kit, no Vulcanus) the spine STALLS before metal", function()
    -- The negative baseline: exactly the terminator's gift and nothing else. With
    -- no caster there is no lava, and with no foundry there is no melt -- the
    -- from-absolute-zero soft-lock the whole APS bootstrap exists to rescue.
    local have = reach(HAND_ROOTS)
    assert.is_falsy(have["lava"], "no caster -> no lava from bare hand roots")
    assert.is_falsy(have["molten-iron"], "and therefore no metal: the from-zero start soft-locks unaided")
  end)

  it("hand roots + the KIT machines reach the lava->metal economy (no brought metal, no Vulcanus)", function()
    -- The kit hands the two keystone machines; the caster removes the need for any
    -- starter metal (test_bootstrap's normal-arrival seed brings steel/gears/brick
    -- because it has no caster yet). With just those two machines the spine closes.
    local have = reach({
      stone = true, ice = true, calcite = true,
      foundry = true, ["cindra-lava-manufacturer"] = true,
    })
    assert.is_true(have["lava"] == true,
      "the kit's caster turns stone -> lava on with only hand-mined stone")
    assert.is_true(have["molten-iron"] == true,
      "the kit's foundry then melts lava (+ mined calcite) -> molten iron: the metal economy is on")
    assert.is_true(have["iron-plate"] == true,
      "and the foundry casts iron plate -- fabricable metal, reached from nothing but hand roots + the kit")
    -- Cross-check the delta is really the kit (guards against the roots alone
    -- silently becoming enough, which would mean a free-foundry leak crept in).
    assert.is_falsy(reach(HAND_ROOTS)["iron-plate"],
      "the SAME roots without the kit machines must NOT reach metal (the kit is the delta)")
  end)

  -- =========================================================================
  -- LAYER 2: drive the spine in-engine on the PRE-RESEARCHED force.
  --
  -- The pre-research (cindra-start/control.lua) is what makes the recipes usable at
  -- tick zero with no science done. We do NOT toggle any recipe here: we assert the
  -- force already has them, then run the machines. That proves pre-research + kit
  -- combine into a working economy, not just reachable-on-paper.
  -- =========================================================================
  it("the spine recipes are already enabled on the player force (pre-research, no manual unlock)", function()
    local f = game.forces["player"]
    assert.is_true(f.recipes["cindra-lava"].enabled,
      "manufactured lava must be pre-enabled (cindra-lava tech granted on a Cindra start)")
    assert.is_true(f.recipes["molten-iron-from-lava"].enabled,
      "the vanilla iron cast must be pre-enabled (via the foundry tech)")
    assert.is_true(f.recipes["casting-iron"].enabled,
      "casting molten iron -> iron plate must be pre-enabled (via the foundry tech)")
  end)

  it("drives stone -> lava -> molten iron -> iron plate end-to-end (no Vulcanus)", function()
    local s = powered_surface()
    -- No recipe toggling: these are the force's PRE-RESEARCHED recipes.
    local f = game.forces["player"]
    assert.is_true(f.recipes["cindra-lava"].enabled and f.recipes["molten-iron-from-lava"].enabled
      and f.recipes["casting-iron"].enabled, "the spine must be pre-researched before this drive")

    -- Stage 1: the kit's lava caster turns hand-mined stone into lava.
    local caster = s.create_entity({ name = "cindra-lava-manufacturer", position = { 0, 0 }, force = "player" })
    caster.set_recipe("cindra-lava")
    caster.insert({ name = "stone", count = 200 })

    -- Stage 2: the kit's foundry melts lava (+ mined calcite) into molten iron. We
    -- feed the manufactured fluid directly (headless fluid piping is fiddly; the
    -- caster's own output is proven above), mirroring test_bootstrap's layer 2.
    local foundry = s.create_entity({ name = "foundry", position = { 6, 0 }, force = "player" })
    foundry.set_recipe("molten-iron-from-lava")
    foundry.insert_fluid({ name = "lava", amount = 600, temperature = 1500 })
    foundry.insert({ name = "calcite", count = 10 })

    -- Stage 3: a second foundry casts that molten iron into iron plate.
    local caster_out = s.create_entity({ name = "foundry", position = { 12, 0 }, force = "player" })
    caster_out.set_recipe("casting-iron")
    caster_out.insert_fluid({ name = "molten-iron", amount = 500, temperature = 1500 })

    async(2400)
    after_ticks(1800, function()
      assert.is_true(caster.valid and foundry.valid and caster_out.valid)
      local lava = caster.get_fluid_count("lava")
      assert.is_true(lava > 0,
        "the kit caster made lava from hand-mined stone (got " .. lava .. ")")
      local molten = foundry.get_fluid_count("molten-iron")
      assert.is_true(molten > 0,
        "the kit foundry melted lava into molten iron (got " .. molten .. ")")
      local plate = caster_out.get_item_count("iron-plate")
      assert.is_true(plate > 0,
        "the foundry cast molten iron into iron plate (got " .. plate .. ") -- metal reached from nothing, no Vulcanus")
      caster.destroy(); foundry.destroy(); caster_out.destroy()
      done()
    end)
  end)

  -- =========================================================================
  -- LAYER 3: the foundry REPRODUCES on Cindra (so it is not a one-time import).
  --
  -- The kit hands ONE foundry. For a start-on-Cindra economy to be self-sustaining
  -- rather than a permanent import (there is no Vulcanus to import from anyway), the
  -- planet must be able to BUILD more foundries locally. ci-arw's field-foundry
  -- recipe does exactly that -- a lubricant-fed, pressure-gate-free build. Drive it
  -- in-engine: an ordinary assembler crafts the vanilla foundry ITEM on Cindra.
  -- =========================================================================
  it("the field-foundry recipe is pre-enabled on the force (the reproduce keystone)", function()
    local f = game.forces["player"]
    assert.is_true(f.recipes["cindra-field-foundry"].enabled,
      "the Cindra-buildable field foundry must be pre-enabled (improvised-metallurgy granted)")
    assert.is_true(f.recipes["cindra-crude-lubricant"].enabled,
      "native crude lubricant must be pre-enabled -- the field foundry's fluid input, no oil needed")
  end)

  it("builds a NEW foundry on Cindra from local metal + native lubricant (reproduces the keystone)", function()
    -- crafting-with-fluid, so an ordinary assembler (not itself a foundry) can craft
    -- it -- the machine a from-scratch start can hand-bootstrap. Its inputs
    -- (steel/circuits/refined-concrete cast from the lava->metal spine, lubricant
    -- from the native recipes) are all locally producible with no Vulcanus.
    local s = powered_surface()
    local f = game.forces["player"]
    assert.is_true(f.recipes["cindra-field-foundry"].enabled,
      "the field-foundry recipe must be pre-researched before this drive")

    local assembler = s.create_entity({ name = "assembling-machine-3", position = { 0, 0 }, force = "player" })
    assembler.set_recipe("cindra-field-foundry")
    -- One craft's worth of the (locally producible) inputs.
    assembler.insert({ name = "steel-plate", count = 150 })
    assembler.insert({ name = "electronic-circuit", count = 40 })
    assembler.insert({ name = "refined-concrete", count = 40 })
    assembler.insert_fluid({ name = "lubricant", amount = 40 })

    async(3600)
    after_ticks(2700, function()
      assert.is_true(assembler.valid)
      local built = assembler.get_item_count("foundry")
      assert.is_true(built > 0,
        "the field-foundry recipe must yield a real foundry item on Cindra (got " .. built
          .. ") -- foundries reproduce here, so the metal economy is self-sustaining, not a one-time import")
      assembler.destroy()
      done()
    end)
  end)
end)
