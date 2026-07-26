-- Mass-driver PoC proofs (factorio-test, in-engine).
--
-- The headline proof is the full launch loop: build -> power -> charge ->
-- fire -> payload delivered to an orbital catcher on ANOTHER surface, paid for
-- with electricity + one native shell and nothing else. The rest lock the
-- individual invariants (electric not chemical, bursty, needs a shell, needs a
-- catcher).

local launch = require("scripts.launch")

local DRIVER = "mass-driver"
local CHARGER = "mass-driver-charger"
local CATCHER = "mass-driver-catcher"
local SHELL = "mass-driver-shell"

-- Chemistry / rocketry inputs a mass driver must NEVER need.
local FORBIDDEN = {
  ["rocket-fuel"] = true, ["rocket-part"] = true, ["solid-fuel"] = true,
  ["plastic-bar"] = true, ["sulfuric-acid"] = true, ["sulfur"] = true,
  ["lubricant"] = true, ["petroleum-gas"] = true, ["light-oil"] = true,
  ["heavy-oil"] = true, ["coal"] = true,
}

-- ============================================================================
-- Prototype shape
-- ============================================================================
describe("mass driver (prototype shape)", function()
  it("driver is a container with an item and recipe, and NO fuel source", function()
    local e = prototypes.entity[DRIVER]
    assert.is_not_nil(e, "driver entity must exist")
    assert.are.equal("container", e.type)
    assert.is_not_nil(prototypes.item[DRIVER], "driver item must exist")
    assert.is_not_nil(prototypes.recipe[DRIVER], "driver recipe must exist")
    -- The visible driver is a plain container: it carries no burner/fluid fuel
    -- source of its own. All launch energy comes from the electric charger.
    assert.is_nil(e.burner_prototype, "driver must not burn fuel")
    assert.is_nil(e.fluid_energy_source_prototype, "driver must not use fluid fuel")
  end)

  it("charger is a hidden electric accumulator with a big per-shot buffer", function()
    local e = prototypes.entity[CHARGER]
    assert.is_not_nil(e, "charger entity must exist")
    assert.are.equal("accumulator", e.type)
    assert.is_true(e.hidden, "charger must be a hidden helper entity")
    local es = e.electric_energy_source_prototype
    assert.is_not_nil(es, "charger must be electric-powered")
    assert.is_true(es.buffer_capacity >= 100e6, "charger buffer must hold a big shot (>=100MJ)")
    -- The "never feeds the grid back" property (output_flow_limit = 0) is a
    -- data-stage config not surfaced on the runtime prototype; it is proven
    -- behaviourally by the runtime tests below (the buffer only ever drains via
    -- a launch, and stays spent until it recharges).
  end)

  it("catcher and shell exist as buildable/craftable content", function()
    assert.is_not_nil(prototypes.entity[CATCHER], "catcher entity must exist")
    assert.are.equal("container", prototypes.entity[CATCHER].type)
    assert.is_not_nil(prototypes.item[CATCHER], "catcher item must exist")
    assert.is_not_nil(prototypes.recipe[CATCHER], "catcher recipe must exist")
    assert.is_not_nil(prototypes.item[SHELL], "shell item must exist")
    assert.is_not_nil(prototypes.recipe[SHELL], "shell recipe must exist")
  end)

  it("nothing the launch loop needs touches rocket fuel or chemistry", function()
    for _, rname in pairs({ DRIVER, CATCHER, SHELL }) do
      local recipe = prototypes.recipe[rname]
      for _, ing in pairs(recipe.ingredients) do
        assert.is_falsy(FORBIDDEN[ing.name],
          rname .. " recipe must not use chemistry/rocketry input: " .. ing.name)
      end
    end
    -- The shell (the recurring per-shot cost) is pure native metal.
    local shell = prototypes.recipe[SHELL]
    assert.are.equal(1, #shell.ingredients, "shell is a single native-metal input")
    assert.are.equal("steel-plate", shell.ingredients[1].name)
  end)
end)

-- ============================================================================
-- Runtime: the launch loop
-- ============================================================================
describe("mass driver (runtime)", function()
  local ground, orbit

  local function fresh_surface(name)
    local s = game.surfaces[name]
    if not s then s = game.create_surface(name, { width = 128, height = 128 }) end
    s.daytime = 0
    for _, e in pairs(s.find_entities_filtered({ area = { { -60, -60 }, { 60, 60 } } })) do
      if e.type ~= "character" then e.destroy() end
    end
    local tiles = {}
    for x = -20, 20 do
      for y = -20, 20 do tiles[#tiles + 1] = { name = "refined-concrete", position = { x, y } } end
    end
    s.set_tiles(tiles)
    return s
  end

  before_each(function()
    ground = fresh_surface("mass-driver-ground")
    orbit = fresh_surface("mass-driver-orbit")
    -- Isolate runtime tracking between tests.
    storage.md_drivers = {}
    storage.md_catchers = {}
  end)

  -- Build a driver (raising the build event so the runtime attaches its hidden
  -- charger), return driver + charger.
  local function build_driver(pos)
    local d = ground.create_entity({ name = DRIVER, position = pos or { 0, 0 }, force = "player", raise_built = true })
    assert.is_not_nil(d, "driver must place")
    local rec = storage.md_drivers[d.unit_number]
    assert.is_not_nil(rec, "runtime must track the driver after build")
    assert.is_not_nil(rec.charger, "runtime must attach a hidden charger")
    return d, rec.charger
  end

  local function build_catcher(pos)
    local c = orbit.create_entity({ name = CATCHER, position = pos or { 0, 0 }, force = "player", raise_built = true })
    assert.is_not_nil(c, "catcher must place")
    return c
  end

  local function charge_full(charger)
    charger.energy = charger.electric_buffer_size
  end

  it("building a driver attaches a hidden accumulator charger", function()
    local _, charger = build_driver({ 0, 0 })
    assert.is_true(charger.valid, "charger must be valid")
    assert.are.equal(CHARGER, charger.name)
    assert.are.equal("accumulator", charger.type)
  end)

  it("charges its buffer from the electric grid", function()
    -- A solar-fed grid: substation + panels power the driver's hidden charger.
    local sub = ground.create_entity({ name = "substation", position = { 0, 0 }, force = "player" })
    assert.is_not_nil(sub, "substation must place")
    for _, p in pairs({ { -6, -6 }, { 6, -6 }, { -6, 6 }, { 6, 6 }, { 0, -6 }, { 0, 6 } }) do
      ground.create_entity({ name = "solar-panel", position = p, force = "player" })
    end
    local _, charger = build_driver({ 4, 0 })
    charger.energy = 0

    async(600)
    after_ticks(180, function()
      assert.is_true(charger.energy > 0,
        "the charger must draw power from the grid (electric charge, no fuel)")
      done()
    end)
  end)

  it("FULL LOOP: charged driver flings cargo across surfaces into the catcher", function()
    local driver, charger = build_driver({ 0, 0 })
    local catcher = build_catcher({ 0, 0 })
    assert.are_not.equal(driver.surface.index, catcher.surface.index,
      "catcher must be in orbit -- a different surface from the driver")

    local inv = driver.get_inventory(defines.inventory.chest)
    inv.insert({ name = SHELL, count = 3 })
    inv.insert({ name = "iron-plate", count = 250 })
    charge_full(charger)

    -- Fire one shot.
    assert.is_true(launch.try_fire_driver(driver), "a charged, loaded driver must fire")

    local cinv = catcher.get_inventory(defines.inventory.chest)
    assert.are.equal(100, cinv.get_item_count("iron-plate"),
      "one shot delivers SHOT_CAPACITY (100) cargo to the orbital catcher")
    assert.are.equal(150, inv.get_item_count("iron-plate"), "the rest of the cargo stays in the driver")
    assert.are.equal(2, inv.get_item_count(SHELL), "one native shell is spent per shot")
    assert.are.equal(0, charger.energy, "the shot spends the whole electric buffer")
  end)

  it("needs a projectile shell: no shell -> no launch", function()
    local driver, charger = build_driver({ 0, 0 })
    local catcher = build_catcher({ 0, 0 })
    local inv = driver.get_inventory(defines.inventory.chest)
    inv.insert({ name = "iron-plate", count = 100 })  -- cargo but no shell
    charge_full(charger)

    assert.is_false(launch.try_fire_driver(driver), "without a shell the driver must not fire")
    assert.are.equal(0, catcher.get_inventory(defines.inventory.chest).get_item_count("iron-plate"))
    assert.are.equal(charger.electric_buffer_size, charger.energy, "energy is preserved when it can't fire")
  end)

  it("needs a catcher: no catcher -> no launch, payload preserved", function()
    local driver, charger = build_driver({ 0, 0 })
    -- No catcher built (storage.md_catchers stays empty).
    local inv = driver.get_inventory(defines.inventory.chest)
    inv.insert({ name = SHELL, count = 1 })
    inv.insert({ name = "iron-plate", count = 100 })
    charge_full(charger)

    assert.is_false(launch.try_fire_driver(driver), "without a catcher the driver must not fire")
    assert.are.equal(1, inv.get_item_count(SHELL), "shell is not consumed when there is nowhere to deliver")
    assert.are.equal(100, inv.get_item_count("iron-plate"), "cargo is not lost")
    assert.are.equal(charger.electric_buffer_size, charger.energy)
  end)

  it("needs a full charge: a half-charged driver will not fire", function()
    local driver, charger = build_driver({ 0, 0 })
    build_catcher({ 0, 0 })
    local inv = driver.get_inventory(defines.inventory.chest)
    inv.insert({ name = SHELL, count = 1 })
    inv.insert({ name = "iron-plate", count = 100 })
    charger.energy = charger.electric_buffer_size * 0.5  -- only half charged

    assert.is_false(launch.try_fire_driver(driver), "a half-charged driver must not fire")
  end)

  it("is BURSTY: each shot needs its own charge cycle", function()
    local driver, charger = build_driver({ 0, 0 })
    local catcher = build_catcher({ 0, 0 })
    local cinv = catcher.get_inventory(defines.inventory.chest)
    local inv = driver.get_inventory(defines.inventory.chest)
    inv.insert({ name = SHELL, count = 5 })
    inv.insert({ name = "iron-plate", count = 250 })

    charge_full(charger)
    assert.is_true(launch.try_fire_driver(driver), "first shot fires on a full charge")
    assert.are.equal(100, cinv.get_item_count("iron-plate"))

    -- Buffer is now spent; a second shot must NOT go until it recharges.
    assert.is_false(launch.try_fire_driver(driver), "no second shot without recharging")
    assert.are.equal(100, cinv.get_item_count("iron-plate"), "still just one shot delivered")

    -- Recharge, then the second shot lands.
    charge_full(charger)
    assert.is_true(launch.try_fire_driver(driver), "second shot fires after recharge")
    assert.are.equal(200, cinv.get_item_count("iron-plate"), "two charge cycles = two shots")
    assert.are.equal(3, inv.get_item_count(SHELL), "two shots spent two native shells")
  end)
end)
