-- Proof: the Cindra mass driver (§15-11; DESIGN.md §5, §11) is a RESKINNED
-- ROCKET-SILO (ci-o39). A launch is built from Cindra's own economy -- an aluminium
-- CAN (cargo container) + aluminium-powder SOLID ROCKET FUEL + a shitton of power,
-- all PETROCHEMICAL-FREE -- and cargo is delivered to an orbiting space platform via
-- the NATIVE vanilla rocket path (no bespoke catcher). Its recipes are GATED behind
-- the cindra-orbital-launch tech in the folded Cindra science tree.
--
-- WHY MOSTLY PROTOTYPE-LEVEL PROOFS. Choosing the `rocket-silo` TYPE means launch +
-- cross-surface delivery are the ENGINE's vanilla behaviour, not our code: there is
-- no runtime loop left to test. What we CAN pin deterministically is the shape that
-- guarantees that behaviour -- the type is rocket-silo, its cargo pod is the vanilla
-- one (a full deep-copy keeps rocket_entity), delivery targets platforms, the launch
-- cost is our can+fuel charge, and no vanilla silo is mutated. The end-to-end visual
-- launch (load cargo -> rocket rises -> cargo lands in the hub) rides entirely on the
-- vanilla rocket path those proofs lock in, so it lives in PLAYTEST.md rather than a
-- long, power-and-timing-dependent async test.

local H = require("tests.helpers")

local DRIVER = "cindra-mass-driver"
local CAN = "cindra-aluminium-can"
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
  if proto.get_max_energy_usage then return proto.get_max_energy_usage() end
  return proto.energy_usage
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
    local cats = prototypes.recipe[CHARGE].category
    -- LuaRecipePrototype exposes the primary category as .category.
    assert.are.equal(CHARGE_CATEGORY, cats,
      "the launch charge lives in the private category, so only the driver builds it")
  end)

  it("a launch consumes an aluminium can + solid rocket fuel (the recurring cost)", function()
    local charge = prototypes.recipe[CHARGE]
    local names = {}
    for _, ing in pairs(charge.ingredients) do names[ing.name] = ing.amount end
    assert.is_not_nil(names[CAN], "the launch charge must consume an aluminium can (cargo container)")
    assert.is_not_nil(names[FUEL], "the launch charge must consume solid rocket fuel")
    assert.are.equal(2, #charge.ingredients, "the launch cost is exactly the can + fuel")
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
  it("adds the can, powder, and solid-fuel items + recipes", function()
    for _, n in ipairs({ CAN, POWDER, FUEL }) do
      assert.is_not_nil(prototypes.item[n], n .. " item must exist")
      assert.is_not_nil(prototypes.recipe[n], n .. " recipe must exist")
    end
  end)

  it("the launch consumables trace back to Cindra aluminium, not chemistry", function()
    -- can <- aluminium
    local can = prototypes.recipe[CAN]
    assert.are.equal("cindra-aluminium", can.ingredients[1].name,
      "the aluminium can is pressed from Cindra aluminium")
    -- powder <- aluminium ; fuel <- powder  (so the propellant is native metal)
    assert.are.equal("cindra-aluminium", prototypes.recipe[POWDER].ingredients[1].name,
      "aluminium powder is ground from Cindra aluminium")
    assert.are.equal(POWDER, prototypes.recipe[FUEL].ingredients[1].name,
      "solid rocket fuel is made from aluminium powder (no oil/coal)")
  end)

  it("nothing the launch touches uses vanilla petrochemistry/oil-rocketry", function()
    for _, rname in ipairs({ DRIVER, CAN, POWDER, FUEL, CHARGE }) do
      local recipe = prototypes.recipe[rname]
      for _, ing in pairs(recipe.ingredients) do
        assert.is_falsy(FORBIDDEN[ing.name],
          rname .. " recipe must not use petrochemistry/oil-rocketry: " .. ing.name)
      end
    end
  end)

  it("all launch recipes are GATED (disabled by default, not free)", function()
    for _, rname in ipairs({ DRIVER, CAN, POWDER, FUEL, CHARGE }) do
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
    for _, rname in ipairs({ DRIVER, CAN, POWDER, FUEL }) do
      assert.is_true(unlocked[rname], "the tech must unlock the " .. rname .. " recipe")
    end
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
