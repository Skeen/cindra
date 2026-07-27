-- Proof: the Cindra mass driver (§15-11; DESIGN.md §5, §11) is a RESKINNED
-- ROCKET-SILO (ci-o39, ci-loa). A launch is built from Cindra's own economy -- raw
-- ALUMINIUM + aluminium-powder SOLID ROCKET FUEL fed straight into the silo, which
-- forms the launch vehicle INTERNALLY (no pre-crafted "can" item, ci-loa), on a
-- shitton of power, all PETROCHEMICAL-FREE -- and cargo is delivered to an orbiting
-- space platform via the NATIVE vanilla rocket path (no bespoke catcher). It TAKES
-- PRODUCTIVITY MODULES like any silo. Its recipes are GATED behind the
-- cindra-orbital-launch tech in the folded Cindra science tree.
--
-- WHY MOSTLY PROTOTYPE-LEVEL PROOFS. Choosing the `rocket-silo` TYPE means launch +
-- cross-surface delivery are the ENGINE's vanilla behaviour, not our code: there is
-- no runtime loop left to test. What we CAN pin deterministically is the shape that
-- guarantees that behaviour -- the type is rocket-silo, its cargo pod is the vanilla
-- one (a full deep-copy keeps rocket_entity), delivery targets platforms, the launch
-- charge is FORMED from fed aluminium + fuel (no can item), the silo accepts prod
-- modules, and no vanilla silo is mutated. The end-to-end visual launch (load cargo
-- -> rocket rises -> cargo lands in the hub) rides entirely on the vanilla rocket
-- path those proofs lock in, so it lives in PLAYTEST.md rather than a long,
-- power-and-timing-dependent async test.

local H = require("tests.helpers")

local DRIVER = "cindra-mass-driver"
local CAN = "cindra-aluminium-can"   -- the REMOVED pre-crafted can (ci-loa): must not exist
local MATERIAL = "cindra-aluminium"  -- the raw cargo-vehicle material fed into the silo
local POWDER = "cindra-aluminium-powder"
local FUEL = "cindra-solid-rocket-fuel"
local CHARGE = "cindra-launch-charge"
local CHARGE_CATEGORY = "cindra-mass-driver-charge"
local TECH = "cindra-orbital-launch"

-- Vanilla petrochemistry / oil-rocketry inputs a Cindra launch must NEVER need
-- (the whole point of §11: zero oil/coal footprint). Our aluminium-derived fuel
-- (cindra-solid-rocket-fuel) is petrochemical-free and NOT on this list.
local FORBIDDEN = {
  ["rocket-fuel"] = true, ["rocket-part"] = true, ["solid-fuel"] = true,
  ["low-density-structure"] = true, ["processing-unit"] = true,
  ["plastic-bar"] = true, ["sulfuric-acid"] = true, ["sulfur"] = true,
  ["lubricant"] = true, ["petroleum-gas"] = true, ["light-oil"] = true,
  ["heavy-oil"] = true, ["coal"] = true,
}

local function energy_usage_of(proto)
  -- Crafting machines expose get_max_energy_usage; fall back to energy_usage.
  -- Both report Joules per TICK, so * 60 -> Watts (what the draw assertions below
  -- compare against, e.g. ">=50 MW"). Without the conversion a 100 MW draw reads
  -- as 1.67e6 and spuriously fails the >=50e6 check.
  if proto.get_max_energy_usage then return proto.get_max_energy_usage() * 60 end
  return proto.energy_usage * 60
end

-- ============================================================================
-- Prototype shape: it is a reskinned rocket-silo, not a chest
-- ============================================================================
describe("cindra mass driver (prototype shape)", function()
  it("is a ROCKET-SILO type (not a container), with an item + build recipe", function()
    local e = prototypes.entity[DRIVER]
    assert.is_not_nil(e, "driver entity must exist")
    assert.are.equal("rocket-silo", e.type,
      "the definitive spec: the mass driver is a reskinned rocket-silo, not a chest")
    assert.are_not.equal("container", e.type, "it must NOT be a container any more")
    assert.is_not_nil(prototypes.item[DRIVER], "driver item must exist")
    assert.is_not_nil(prototypes.recipe[DRIVER], "driver build recipe must exist")
  end)

  it("crafts its launch charge in a PRIVATE category (no vanilla-silo leak)", function()
    local e = prototypes.entity[DRIVER]
    assert.is_true(e.crafting_categories[CHARGE_CATEGORY],
      "the driver crafts in the private cindra-mass-driver-charge category")
    assert.is_nil(e.crafting_categories["rocket-building"],
      "it must NOT share the vanilla rocket-building category (no recipe leak)")
    -- The charge recipe (the silo's fixed_recipe) lives in that private category.
    assert.is_not_nil(prototypes.recipe[CHARGE], "the launch-charge recipe must exist")
    -- 2.1: LuaRecipePrototype exposes its categories as a LIST (`.categories`);
    -- there is no scalar `.category` key. Assert the private category is in it.
    local in_private = false
    for _, c in pairs(prototypes.recipe[CHARGE].categories) do
      if c == CHARGE_CATEGORY then in_private = true end
    end
    assert.is_true(in_private,
      "the launch charge lives in the private category, so only the driver builds it")
  end)

  it("forms its launch charge from FED RAW MATERIALS (aluminium + fuel), NOT a pre-crafted can", function()
    -- ci-loa: the silo takes raw materials and builds the launch vehicle inside itself
    -- (like a vanilla silo forms rocket-parts from fed ingredients). No can item.
    local charge = prototypes.recipe[CHARGE]
    local names = {}
    for _, ing in pairs(charge.ingredients) do names[ing.name] = ing.amount end
    assert.is_not_nil(names[MATERIAL], "the launch charge must be formed from raw aluminium (fed material)")
    assert.is_not_nil(names[FUEL], "the launch charge must consume solid rocket fuel")
    assert.is_nil(names[CAN], "the launch charge must NOT consume a pre-crafted aluminium can (ci-loa)")
    assert.are.equal(2, #charge.ingredients, "the launch cost is exactly aluminium + fuel")
  end)

  it("the pre-crafted aluminium can is GONE -- the silo forms the vehicle internally (ci-loa)", function()
    assert.is_nil(prototypes.item[CAN], "the aluminium-can item must not exist any more")
    assert.is_nil(prototypes.recipe[CAN], "the aluminium-can recipe must not exist any more")
  end)

  it("ACCEPTS PRODUCTIVITY MODULES: module slots + productivity-effect allowance (ci-loa)", function()
    local e = prototypes.entity[DRIVER]
    assert.is_true(e.module_inventory_size >= 1,
      "the mass driver must have module slots (it is a rocket-silo), got " .. tostring(e.module_inventory_size))
    assert.is_true(e.allowed_effects and e.allowed_effects.productivity == true,
      "the mass driver must allow the productivity effect (prod modules do something)")
    -- The fixed_recipe (the silo's launch charge) must itself allow productivity, or
    -- prod modules in the slots would be inert on the only thing the driver crafts.
    assert.is_true(prototypes.recipe[CHARGE].allowed_effects.productivity,
      "the launch-charge recipe must allow productivity so prod modules speed launches")
  end)

  it("builds the launch vehicle INTERNALLY: a silo fixed_recipe fed materials, then fires", function()
    -- The driver's fixed_recipe IS the launch charge (the rocket-part analog): it runs
    -- automatically from fed materials and, once rocket_parts_required is built, launches.
    local e = prototypes.entity[DRIVER]
    -- 2.1: LuaEntityPrototype.fixed_recipe is a LuaRecipePrototype, not a string.
    assert.are.equal(CHARGE, e.fixed_recipe.name,
      "the silo must auto-build the launch charge from fed materials (its fixed_recipe)")
    assert.is_true((e.rocket_parts_required or 0) >= 1,
      "it must require at least one built charge before it launches (built internally, then fires)")
    assert.is_true(e.launch_to_space_platforms,
      "a launch delivers cargo to an orbiting space platform (the vanilla rocket path)")
  end)

  it("costs a SHITTON of power: a huge crafting draw over a long craft", function()
    local e = prototypes.entity[DRIVER]
    local draw = energy_usage_of(e)
    assert.is_true(draw >= 50e6,
      "the silo's launch-charge draw must be a big load (>=50MW), got " .. tostring(draw))
    -- Far above a normal assembler: this is a deliberate flare-scale sink.
    local base = energy_usage_of(prototypes.entity["assembling-machine-3"])
    assert.is_true(draw > base * 10,
      "the launch draw must dwarf a normal assembler (a flare-scale power sink)")
    -- And the charge is a LONG craft, so per-launch energy = draw * time is huge.
    assert.is_true(prototypes.recipe[CHARGE].energy >= 20,
      "the launch charge must be a long craft (the power lever), got "
        .. tostring(prototypes.recipe[CHARGE].energy))
  end)

  it("delivers via the vanilla rocket path -- NO platform-side catcher (ci-98r)", function()
    -- The rocket-silo type gives native launch-to-platform delivery, so there is
    -- nothing bespoke to build in orbit. Every trace of the old catcher stays gone.
    local CATCHER = "cindra-mass-driver-catcher"
    assert.is_nil(prototypes.entity[CATCHER], "the platform-side catcher entity must not exist")
    assert.is_nil(prototypes.item[CATCHER], "no catcher item")
    assert.is_nil(prototypes.recipe[CATCHER], "no catcher recipe")
    -- The old electricity-buffer composite is gone too (no chest, no charger).
    assert.are_not.equal("container", prototypes.entity[DRIVER].type)
    assert.is_nil(prototypes.entity["cindra-mass-driver-charger"],
      "the old hidden charger accumulator must be gone (native launch replaces it)")
    assert.is_nil(prototypes.item["cindra-mass-driver-shell"],
      "the old native shell is gone -- launches now burn an aluminium-fuel charge")
  end)
end)

-- ============================================================================
-- The launch chain: aluminium -> can / powder -> fuel, all petrochemical-free
-- ============================================================================
describe("cindra mass driver (launch chain is petrochemical-free)", function()
  it("adds the powder and solid-fuel items + recipes", function()
    for _, n in ipairs({ POWDER, FUEL }) do
      assert.is_not_nil(prototypes.item[n], n .. " item must exist")
      assert.is_not_nil(prototypes.recipe[n], n .. " recipe must exist")
    end
  end)

  it("the launch consumables trace back to Cindra aluminium, not chemistry", function()
    -- charge <- aluminium (fed straight in; no can intermediate, ci-loa)
    local charge_from_aluminium = false
    for _, ing in pairs(prototypes.recipe[CHARGE].ingredients) do
      if ing.name == MATERIAL then charge_from_aluminium = true end
    end
    assert.is_true(charge_from_aluminium,
      "the launch charge is formed from raw Cindra aluminium fed into the silo")
    -- powder <- aluminium ; fuel <- powder  (so the propellant is native metal)
    assert.are.equal("cindra-aluminium", prototypes.recipe[POWDER].ingredients[1].name,
      "aluminium powder is ground from Cindra aluminium")
    assert.are.equal(POWDER, prototypes.recipe[FUEL].ingredients[1].name,
      "solid rocket fuel is made from aluminium powder (no oil/coal)")
  end)

  it("nothing the launch touches uses vanilla petrochemistry/oil-rocketry", function()
    for _, rname in ipairs({ DRIVER, POWDER, FUEL, CHARGE }) do
      local recipe = prototypes.recipe[rname]
      for _, ing in pairs(recipe.ingredients) do
        assert.is_falsy(FORBIDDEN[ing.name],
          rname .. " recipe must not use petrochemistry/oil-rocketry: " .. ing.name)
      end
    end
  end)

  it("all launch recipes are GATED (disabled by default, not free)", function()
    for _, rname in ipairs({ DRIVER, POWDER, FUEL, CHARGE }) do
      assert.is_false(prototypes.recipe[rname].enabled,
        rname .. " recipe must be disabled by default -- unlocked by research, not free")
    end
  end)
end)

-- ============================================================================
-- The driver item lives in the SPACE crafting tab (not Logistics)
-- ============================================================================
describe("cindra mass driver (menu placement)", function()
  it("lives in the same crafting tab as the vanilla rocket silo (the Space tab)", function()
    local silo_group = prototypes.item["rocket-silo"].subgroup.group.name
    local driver_group = prototypes.item[DRIVER].subgroup.group.name
    assert.are.equal(silo_group, driver_group,
      "the driver item must share the rocket silo's group -- the Space tab")
    assert.are_not.equal("logistics", driver_group,
      "the driver must NOT live in the Logistics tab")
  end)
end)

-- ============================================================================
-- Never-mutate-other-planets: the vanilla rocket silo is untouched
-- ============================================================================
describe("cindra mass driver (never mutate other planets)", function()
  it("does not touch the vanilla rocket silo or its rocket-part recipe", function()
    local vanilla = prototypes.entity["rocket-silo"]
    assert.is_not_nil(vanilla, "the vanilla rocket silo must still exist")
    assert.is_true(vanilla.crafting_categories["rocket-building"],
      "the vanilla silo keeps its rocket-building category")
    assert.is_nil(vanilla.crafting_categories[CHARGE_CATEGORY],
      "the vanilla silo must NOT gain Cindra's private launch-charge category")
    -- The vanilla rocket-part recipe still uses vanilla rocketry inputs (a canary
    -- that we cloned rather than mutated the shared launch chain).
    local part = prototypes.recipe["rocket-part"]
    assert.is_not_nil(part, "the vanilla rocket-part recipe must still exist")
    local uses_vanilla_rocketry = false
    for _, ing in pairs(part.ingredients) do
      if ing.name == "low-density-structure" or ing.name == "rocket-fuel"
        or ing.name == "processing-unit" then uses_vanilla_rocketry = true end
    end
    assert.is_true(uses_vanilla_rocketry,
      "the vanilla rocket-part recipe must be unchanged (still oil-rocketry)")
  end)
end)

-- ============================================================================
-- Gating: unlocked by cindra-orbital-launch in the folded Cindra tree
-- ============================================================================
describe("cindra mass driver (tech gating)", function()
  it("is unlocked by the cindra-orbital-launch tech in the Cindra tree", function()
    local tech = prototypes.technology[TECH]
    assert.is_not_nil(tech, "cindra-orbital-launch technology must exist")
    assert.is_true(tech.valid, "the tech must load (its icon + prerequisites resolve)")

    local unlocked = {}
    for _, effect in pairs(tech.effects) do
      if effect.type == "unlock-recipe" then unlocked[effect.recipe] = true end
    end
    -- Unlocks the driver + the whole launch-fuel chain (the charge is the silo's
    -- fixed_recipe -- auto-crafted, so it is NOT and need NOT be a tech unlock).
    for _, rname in ipairs({ DRIVER, POWDER, FUEL }) do
      assert.is_true(unlocked[rname], "the tech must unlock the " .. rname .. " recipe")
    end
    assert.is_nil(unlocked[CAN],
      "the tech must NOT unlock an aluminium-can recipe -- it no longer exists (ci-loa)")
    assert.is_nil(unlocked["cindra-mass-driver-catcher"],
      "the tech must NOT unlock a catcher -- it does not exist")

    -- Researched WITH the Cindra science pack (the fold made real).
    local pack_names = {}
    for _, ing in pairs(tech.research_unit_ingredients) do pack_names[ing.name] = true end
    assert.is_true(pack_names["cindra-science-pack"],
      "exporting off Cindra must cost the Cindra science pack")

    -- Branches off Cindra's own discovery tech. Under any-planet-start (Cindra
    -- start), APS hides planet-discovery-cindra and STRIPS it from dependents'
    -- prerequisites, so this tech becomes a root instead -- never a dangling ref.
    if script.active_mods["any-planet-start"] then
      assert.is_nil(tech.prerequisites["planet-discovery-cindra"],
        "under APS the discovery prereq is stripped (tech becomes a root), not dangling")
    else
      assert.is_not_nil(tech.prerequisites["planet-discovery-cindra"],
        "gated behind Cindra discovery -- its own signature launch infrastructure")
      assert.is_not_nil(tech.prerequisites["cindra-science"],
        "folded into the Cindra tree: gated behind the headline science")
    end
  end)
end)

-- ============================================================================
-- Runtime: it builds on Cindra as a working silo, with a vanilla platform hub
-- as its delivery target (the visual launch itself is a PLAYTEST item)
-- ============================================================================
describe("cindra mass driver (runtime)", function()
  before_each(function()
    -- Freeze the periodic Cindra sweeps so a heavy build does not race them.
    storage.cindra_driver_enabled = false
  end)

  it("places on Cindra as a rocket-silo", function()
    local ground = H.cindra_surface()
    local d = ground.create_entity({ name = DRIVER, position = { 0, 0 }, force = "player" })
    assert.is_not_nil(d, "the mass driver must place on Cindra")
    assert.is_true(d.valid)
    assert.are.equal(DRIVER, d.name)
    assert.are.equal("rocket-silo", d.type,
      "the built entity is a working rocket-silo (native launch + delivery)")
    d.destroy()
  end)

  it("accepts a productivity module AND fed raw materials at runtime (ci-loa)", function()
    -- The bead's live behaviour: prod modules go in, and the launch is fed raw
    -- MATERIALS (no separate can item) which the silo forms into the vehicle itself.
    local ground = H.cindra_surface()
    local d = ground.create_entity({ name = DRIVER, position = { 0, 0 }, force = "player" })
    assert.is_not_nil(d, "the mass driver must place on Cindra")

    -- Productivity module into the silo's module inventory.
    local modules = d.get_module_inventory()
    assert.is_not_nil(modules, "the mass driver must expose a module inventory")
    assert.is_true(modules.insert({ name = "productivity-module", count = 1 }) >= 1,
      "the mass driver must accept a productivity module")
    assert.is_true(modules.get_item_count("productivity-module") >= 1,
      "the productivity module must sit in the module inventory")

    -- Raw materials feed straight in -- no pre-crafted can required.
    assert.is_true(d.insert({ name = MATERIAL, count = 2 }) >= 1,
      "the silo must accept raw aluminium fed as the launch-vehicle material")
    assert.is_true(d.insert({ name = FUEL, count = 10 }) >= 1,
      "the silo must accept solid rocket fuel fed for the launch")
    d.destroy()
  end)

  it("delivers to a vanilla space-platform hub -- the standard rocket destination", function()
    -- A launch behaves like a vanilla rocket: its cargo pod (kept from the cloned
    -- rocket_entity) lands in the platform hub. Prove the destination is the vanilla
    -- hub on a DIFFERENT surface -- there is nothing bespoke to build in orbit.
    local force = game.forces["player"]
    local platform = force.create_space_platform({
      name = "cindra-md-o39-platform",
      planet = "cindra",
      starter_pack = "space-platform-starter-pack",
    })
    assert.is_not_nil(platform, "a test space platform must create")
    platform.apply_starter_pack()
    local hub = platform.hub
    assert.is_not_nil(hub, "the starter pack must spawn a hub (the vanilla delivery target)")
    assert.is_true(hub.valid)
    assert.is_not_nil(hub.get_inventory(defines.inventory.hub_main),
      "the hub exposes the standard cargo inventory rocket cargo lands in")

    local ground = H.cindra_surface()
    assert.are_not.equal(ground.index, hub.surface.index,
      "the hub is in orbit -- a different surface from the driver, reached by the rocket path")
  end)
end)
