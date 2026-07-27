-- Proof: the Cindra mass driver (§15-11; DESIGN.md §5, §11) is a RESKINNED
-- ROCKET-SILO (ci-o39, ci-loa). It SUPPORTS PRODUCTIVITY MODULES and assembles its
-- launch vehicle INTERNALLY from RAW MATERIALS fed straight in -- raw aluminium (NO
-- pre-crafted can) + VANILLA rocket-fuel minted from aluminium by the "Solid rocket
-- fuel" recipe (ci-519) + a shitton of power, all PETROCHEMICAL-FREE -- and cargo is
-- delivered to an orbiting space platform via the NATIVE vanilla rocket path (no
-- bespoke catcher). Its recipes are GATED behind the cindra-orbital-launch tech in
-- the folded Cindra science tree.
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
local ALUMINIUM = "cindra-aluminium"
local CAN = "cindra-aluminium-can"  -- the REMOVED pre-crafted can (ci-loa): must no longer exist
local POWDER = "cindra-aluminium-powder"
-- ci-519: NO custom fuel item. The launch propellant IS vanilla rocket-fuel, minted
-- from aluminium by the "Solid rocket fuel" recipe (recipe name below != its product).
local ROCKET_FUEL = "rocket-fuel"
local FUEL_RECIPE = "cindra-solid-rocket-fuel"
local CHARGE = "cindra-launch-charge"
local CHARGE_CATEGORY = "cindra-mass-driver-charge"
local TECH = "cindra-orbital-launch"

-- Vanilla petrochemistry / oil-rocketry inputs a Cindra launch must NEVER need
-- (the whole point of §11: zero oil/coal footprint). rocket-fuel is NOT here: it is
-- the vanilla item, but Cindra MAKES it from aluminium (ci-519), so it is a legal,
-- petrochemical-free product/ingredient -- what stays banned is the oil route to it
-- (solid-fuel) and the rest of the vanilla oil-rocketry chain.
local FORBIDDEN = {
  ["rocket-part"] = true, ["solid-fuel"] = true,
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

  it("a launch is built from RAW aluminium + vanilla rocket-fuel -- NO pre-made can (ci-loa)", function()
    local charge = prototypes.recipe[CHARGE]
    local names = {}
    for _, ing in pairs(charge.ingredients) do names[ing.name] = ing.amount end
    -- The launch vehicle is assembled INSIDE the silo from raw materials fed straight
    -- in, exactly as a vanilla silo builds its rocket -- not from a pre-pressed can.
    assert.is_not_nil(names[ALUMINIUM],
      "the launch charge must consume RAW aluminium (the vehicle body, assembled internally)")
    assert.is_nil(names[CAN],
      "the launch charge must NOT consume a pre-crafted aluminium can (ci-loa)")
    assert.is_not_nil(names[ROCKET_FUEL],
      "the launch charge must consume vanilla rocket-fuel (Cindra's aluminium-made propellant, ci-519)")
    assert.are.equal(2, #charge.ingredients, "the launch cost is exactly raw aluminium + rocket-fuel")
  end)

  it("SUPPORTS PRODUCTIVITY MODULES: module slots + productivity allowed (ci-loa)", function()
    local e = prototypes.entity[DRIVER]
    -- A real rocket-silo keeps its module bay: the driver must have module slots.
    assert.is_true(e.module_inventory_size ~= nil and e.module_inventory_size > 0,
      "the mass driver must have module slots (it is a rocket-silo), got "
        .. tostring(e.module_inventory_size))
    -- Productivity must be an allowed effect on the entity.
    assert.is_not_nil(e.allowed_effects, "the driver must declare allowed module effects")
    assert.is_true(e.allowed_effects["productivity"],
      "the mass driver must ALLOW productivity modules (ci-loa)")
    -- And the internal launch-vehicle build must accept a productivity bonus (the
    -- runtime exposes a recipe's permitted module effects as `allowed_effects`).
    local charge_effects = prototypes.recipe[CHARGE].allowed_effects
    assert.is_not_nil(charge_effects, "the launch-charge recipe must permit module effects")
    assert.is_true(charge_effects["productivity"],
      "the launch-charge recipe must allow productivity so prod modules actually apply")
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
  it("adds the powder item and the powder/fuel recipes", function()
    -- Item: powder is Cindra-exclusive. There is deliberately NO custom fuel item
    -- (the propellant is the vanilla rocket-fuel item) and NO can item (ci-loa: raw
    -- aluminium is fed straight into the silo's internal launch-vehicle build).
    assert.is_not_nil(prototypes.item[POWDER], POWDER .. " item must exist")
    assert.is_not_nil(prototypes.recipe[POWDER], POWDER .. " recipe must exist")
    assert.is_not_nil(prototypes.recipe[FUEL_RECIPE], "the Solid rocket fuel recipe must exist")
    assert.is_not_nil(prototypes.item[ROCKET_FUEL], "vanilla rocket-fuel item must exist")
  end)

  it("has NO aluminium-can item or recipe -- raw materials only (ci-loa)", function()
    assert.is_nil(prototypes.item[CAN],
      "the pre-crafted aluminium-can item must be gone -- the silo builds from raw materials")
    assert.is_nil(prototypes.recipe[CAN],
      "the aluminium-can recipe must be gone -- no intermediate cargo container is pressed")
  end)

  -- === ci-519: the core requirement ==========================================
  it("the 'Solid rocket fuel' recipe PRODUCES vanilla rocket-fuel from aluminium", function()
    local fuel = prototypes.recipe[FUEL_RECIPE]
    assert.is_not_nil(fuel, "the Solid rocket fuel recipe must exist")

    -- Output is the VANILLA rocket-fuel item, not a custom one.
    local makes_vanilla = false
    for _, p in pairs(fuel.products) do
      if p.name == ROCKET_FUEL then makes_vanilla = true end
    end
    assert.is_true(makes_vanilla,
      "the Solid rocket fuel recipe must output vanilla rocket-fuel (ci-519)")

    -- Input traces back to Cindra aluminium: fuel <- powder <- aluminium.
    assert.are.equal(POWDER, fuel.ingredients[1].name,
      "Solid rocket fuel is made from aluminium powder (Cindra's route to rocket fuel)")
    assert.are.equal("cindra-aluminium", prototypes.recipe[POWDER].ingredients[1].name,
      "aluminium powder is ground from Cindra aluminium (so rocket fuel traces to aluminium)")
  end)

  it("NO custom solid-fuel item prototype exists (ci-519)", function()
    -- The earlier design added a `cindra-solid-rocket-fuel` ITEM. It must be gone:
    -- the name now belongs only to the RECIPE, producing the vanilla item.
    assert.is_nil(prototypes.item["cindra-solid-rocket-fuel"],
      "no custom solid-rocket-fuel item type may exist -- rocket fuel is the vanilla item")
    assert.is_not_nil(prototypes.recipe["cindra-solid-rocket-fuel"],
      "cindra-solid-rocket-fuel is now a RECIPE (producing vanilla rocket-fuel), not an item")
  end)

  it("the launch consumables trace back to Cindra aluminium, not chemistry", function()
    -- The launch charge takes raw aluminium directly (the vehicle body, ci-loa).
    local charge_uses_aluminium = false
    for _, ing in pairs(prototypes.recipe[CHARGE].ingredients) do
      if ing.name == ALUMINIUM then charge_uses_aluminium = true end
    end
    assert.is_true(charge_uses_aluminium,
      "the launch charge is built from raw Cindra aluminium (fed straight in)")
    -- powder <- aluminium ; fuel <- powder  (so the propellant is native metal)
    assert.are.equal("cindra-aluminium", prototypes.recipe[POWDER].ingredients[1].name,
      "aluminium powder is ground from Cindra aluminium")
    assert.are.equal(POWDER, prototypes.recipe[FUEL_RECIPE].ingredients[1].name,
      "rocket fuel is made from aluminium powder (no oil/coal)")
  end)

  it("nothing the launch touches uses vanilla petrochemistry/oil-rocketry", function()
    for _, rname in ipairs({ DRIVER, POWDER, FUEL_RECIPE, CHARGE }) do
      local recipe = prototypes.recipe[rname]
      for _, ing in pairs(recipe.ingredients) do
        assert.is_falsy(FORBIDDEN[ing.name],
          rname .. " recipe must not use petrochemistry/oil-rocketry: " .. ing.name)
      end
    end
  end)

  it("all launch recipes are GATED (disabled by default, not free)", function()
    for _, rname in ipairs({ DRIVER, POWDER, FUEL_RECIPE, CHARGE }) do
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
    -- fixed_recipe -- auto-crafted, so it is NOT and need NOT be a tech unlock; the
    -- launch vehicle's raw aluminium is unlocked by the aluminium tech, not here).
    for _, rname in ipairs({ DRIVER, POWDER, FUEL_RECIPE }) do
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

  it("accepts a productivity module in-machine: the bonus actually applies (ci-loa)", function()
    -- Beyond the prototype-shape proof, drive the real building: insert a
    -- productivity module into the placed silo and confirm it reports a LIVE
    -- productivity bonus. A rocket-silo always runs its fixed_recipe (the launch
    -- charge), so the effect only appears when that recipe allows productivity --
    -- proving the flag reaches the machine, not just the prototype.
    local ground = H.cindra_surface()
    local d = ground.create_entity({ name = DRIVER, position = { 0, 0 }, force = "player" })
    local modules = d.get_module_inventory()
    assert.is_not_nil(modules, "the mass driver must have a module inventory")
    local inserted = modules.insert({ name = "productivity-module", count = 1 })
    assert.are.equal(1, inserted, "a productivity module must go into the mass driver")

    local effects = d.effects
    assert.is_not_nil(effects, "the silo must report module effects (its fixed_recipe is always set)")
    assert.is_not_nil(effects.productivity, "the productivity effect must be present")
    assert.is_true(effects.productivity > 0,
      "the productivity bonus must be live (the launch-charge recipe allows productivity)")
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
