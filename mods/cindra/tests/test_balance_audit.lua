-- BALANCE PASS (§15-14, ci-63d): the mandatory THROUGHPUT / RATIO audit.
--
-- The user hit an absurd case earlier (lava at 5/16s vs a foundry's 500-lava
-- batch => ~100 lava machines per foundry), fixed by the dedicated
-- lava-manufacturer (ci-e8a / ci-095). This suite makes that whole CLASS of bug a
-- standing guard: for EVERY production edge it computes, LIVE from the shipped
-- prototypes, how many feeder machines one downstream machine needs at full tilt,
-- and asserts none needs a double-digit bank. It also checks craft times / batch
-- sizes give sane rates, that the energy apex ordering holds, and that the
-- EXPORTABLE buildings stay situational-not-strictly-better (§12).
--
-- Everything is derived from `prototypes.*` (no hard-coded rates), so it tracks
-- the real recipes and re-derives if a value is retuned -- a regression that
-- reintroduces a 100:1 ratio fails HERE before it ships.
--
-- Companion coverage: tests/test_lava.lua owns the canonical lava->foundry
-- single-digit proof (re-asserted here for a complete audit); tests/test_plastics
-- owns the methanol-rocket-fuel energy-negativity guard; tests/test_power_prototypes
-- + tests/test_heater own the per-building §12 specs (this file adds the single
-- cross-cutting "no exportable building is strictly-better" invariant).

local C = require("scripts.flare-config")

-- Representative crafting machine for each recipe's category (the machine a player
-- actually runs it in). Ratios between two same-category recipes are speed-
-- independent; cross-category ratios use these live speeds.
local LM = "cindra-lava-manufacturer"     -- private cindra-lava-manufacturing
local EC = "cindra-electrolysis-cell"     -- private cindra-electrolysis
local CF = "cindra-carbothermic-furnace"  -- private cindra-carbothermic
local FOUNDRY = "foundry"                 -- vanilla metallurgy
local CP = "chemical-plant"               -- vanilla chemistry / crafting-with-fluid
local AM = "assembling-machine-3"         -- vanilla crafting / crafting-with-fluid
local DRIVER = "cindra-mass-driver"       -- the reskinned rocket-silo

-- The double-digit line: no single downstream machine may need a bank of ten or
-- more feeders at full tilt (the "~100 machines per foundry" class the pass exists
-- to kill). Single-digit feeder counts are healthy factory ratios.
local ABSURD_FEEDERS = 10

local function amount_of(list, name)
  for _, e in pairs(list) do
    if e.name == name then return e.amount end
  end
  return nil
end

-- Units of `name` a machine produces (or consumes) per second running `recipe`:
-- batch * crafting_speed / energy_required. Reads everything LIVE.
local function rate(recipe_name, machine_name, list_key, name)
  local r = prototypes.recipe[recipe_name]
  assert.is_not_nil(r, "recipe must exist: " .. recipe_name)
  local m = prototypes.entity[machine_name]
  assert.is_not_nil(m, "machine must exist: " .. machine_name)
  local batch = amount_of(r[list_key], name)
  assert.is_not_nil(batch, name .. " must be in " .. recipe_name .. "." .. list_key)
  return batch * m.get_crafting_speed() / r.energy
end

local function out_rate(recipe_name, machine_name, name)
  return rate(recipe_name, machine_name, "products", name)
end
local function in_rate(recipe_name, machine_name, name)
  return rate(recipe_name, machine_name, "ingredients", name)
end

-- Feeder machines one downstream machine needs at full tilt for `carrier`:
-- (downstream consumption rate) / (one feeder's production rate).
local function feeders(producer, consumer, carrier)
  return in_rate(consumer.recipe, consumer.machine, carrier)
    / out_rate(producer.recipe, producer.machine, carrier)
end

local function draw_w(machine_name)
  return prototypes.entity[machine_name].energy_usage * 60
end

describe("balance audit (ci-63d): production-chain throughput ratios", function()
  -- Each edge: how many PRODUCER machines one CONSUMER machine needs for `carrier`.
  -- The comment records the expected count (derived from the shipped numbers) so a
  -- drift is legible; the assertion only pins the single-digit ceiling.
  local EDGES = {
    { label = "lava-manufacturers per foundry (lava)", carrier = "lava",
      producer = { recipe = "cindra-lava", machine = LM },
      consumer = { recipe = "molten-iron-from-lava", machine = FOUNDRY } }, -- ~6
    { label = "calciners per methanol synthesis (CO2)", carrier = "cindra-carbon-dioxide",
      producer = { recipe = "cindra-calcination", machine = LM },
      consumer = { recipe = "cindra-methanol-synthesis", machine = CP } }, -- ~0.33
    { label = "water-electrolysers per methanol synthesis (H2)", carrier = "cindra-hydrogen",
      producer = { recipe = "cindra-electrolysis", machine = CP },
      consumer = { recipe = "cindra-methanol-synthesis", machine = CP } }, -- ~1
    { label = "methanol-synths per MTO (methanol)", carrier = "cindra-methanol",
      producer = { recipe = "cindra-methanol-synthesis", machine = CP },
      consumer = { recipe = "cindra-mto-polymerisation", machine = CP } }, -- ~2
    { label = "acid-leachers per electrolysis cell (alumina)", carrier = "cindra-alumina",
      producer = { recipe = "cindra-alumina", machine = CP },
      consumer = { recipe = "cindra-aluminium", machine = EC } }, -- ~0.2
    { label = "Bayer plants per electrolysis cell (alumina)", carrier = "cindra-alumina",
      producer = { recipe = "cindra-bayer-alumina", machine = AM },
      consumer = { recipe = "cindra-aluminium", machine = EC } }, -- ~0.16
    { label = "electrolysis cells per powder assembler (aluminium)", carrier = "cindra-aluminium",
      producer = { recipe = "cindra-aluminium", machine = EC },
      consumer = { recipe = "cindra-aluminium-powder", machine = AM } }, -- ~5
    { label = "electrolysis cells per science assembler (aluminium)", carrier = "cindra-aluminium",
      producer = { recipe = "cindra-aluminium", machine = EC },
      consumer = { recipe = "cindra-science-pack", machine = AM } }, -- ~0.08
    { label = "Bayer plants per iron-recovery furnace (red-mud)", carrier = "cindra-red-mud",
      producer = { recipe = "cindra-bayer-alumina", machine = AM },
      consumer = { recipe = "cindra-iron-recovery", machine = CF } }, -- ~0.67
    { label = "calciners per iron-recovery furnace (CO2)", carrier = "cindra-carbon-dioxide",
      producer = { recipe = "cindra-calcination", machine = LM },
      consumer = { recipe = "cindra-iron-recovery", machine = CF } }, -- ~0.1
    { label = "powder assemblers per ALICE-fuel assembler (powder)", carrier = "cindra-aluminium-powder",
      producer = { recipe = "cindra-aluminium-powder", machine = AM },
      consumer = { recipe = "cindra-solid-rocket-fuel", machine = AM } }, -- ~0.33
    { label = "ALICE-fuel assemblers per mass driver (rocket-fuel)", carrier = "rocket-fuel",
      producer = { recipe = "cindra-solid-rocket-fuel", machine = AM },
      consumer = { recipe = "cindra-launch-charge", machine = DRIVER } }, -- ~0.8
  }

  for _, e in ipairs(EDGES) do
    it("no double-digit feeder bank: " .. e.label, function()
      local n = feeders(e.producer, e.consumer, e.carrier)
      assert.is_true(n > 0, e.label .. ": feeder count must be positive; got " .. tostring(n))
      assert.is_true(n < ABSURD_FEEDERS, string.format(
        "%s: one downstream machine needs %.2f feeders -- a double-digit bank is the "
          .. "'~100 machines per foundry' imbalance this pass exists to prevent", e.label, n))
    end)
  end

  it("re-affirms the lava->foundry single-digit ratio (test_lava owns the canonical proof)", function()
    local n = feeders(
      { recipe = "cindra-lava", machine = LM },
      { recipe = "molten-iron-from-lava", machine = FOUNDRY }, "lava")
    assert.is_true(n >= 1 and n <= 9,
      "a single-digit lava-manufacturer count must sustain one melting foundry; got "
        .. string.format("%.2f", n))
  end)
end)

describe("balance audit (ci-63d): craft times and rates are sane", function()
  -- Every Cindra conversion recipe must cost real, bounded crafting time: never 0
  -- (free/instant) and never absurdly long. The power lever lives in the machine
  -- draw x craft time, so a sane time keeps rates believable.
  local CONVERSION = {
    "cindra-lava", "cindra-calcination", "cindra-electrolysis", "cindra-methanol-synthesis",
    "cindra-mto-polymerisation", "cindra-alumina", "cindra-aluminium", "cindra-bayer-alumina",
    "cindra-iron-recovery", "cindra-science-pack", "cindra-aluminium-powder",
    "cindra-solid-rocket-fuel", "cindra-methanol-rocket-fuel",
  }
  it("all conversion recipes cost bounded crafting time (0.5s..120s)", function()
    for _, name in ipairs(CONVERSION) do
      local r = prototypes.recipe[name]
      assert.is_not_nil(r, "recipe must exist: " .. name)
      assert.is_true(r.energy >= 0.5 and r.energy <= 120, string.format(
        "%s craft time must be 0.5s..120s (real power lever, not instant); got %.2fs", name, r.energy))
    end
  end)

  it("the science pack is DELIBERATELY expensive: a long craft (>=30s)", function()
    -- Research is the planet's largest standing activity; the pack pays in a long
    -- craft (aluminium + ice + calcite), so its aluminium demand per assembler is a
    -- trickle (one electrolysis cell feeds many science assemblers, proven above).
    local r = prototypes.recipe["cindra-science-pack"]
    assert.is_true(r.energy >= 30,
      "the science pack must be a long, expensive craft (>=30s); got " .. string.format("%.0fs", r.energy))
  end)

  it("the energy apex ordering holds: electrolysis cell >= carbothermic furnace (DESIGN §8.1)", function()
    -- The continuous single-building draws are ordered by design: the electrolysis
    -- cell (aluminium, the apex, 50 MW) out-draws the carbothermic furnace (45 MW),
    -- which sits above the electric heater (40 MW). Both furnaces are multi-tens-of-MW
    -- flare-timed power sinks. (The heater is a reactor-type clone whose draw is not a
    -- crafting-machine energy_usage, so it is anchored by the >= 40 MW floor below
    -- rather than read directly.)
    local ec, cf = draw_w(EC), draw_w(CF)
    assert.is_true(ec >= cf, string.format(
      "electrolysis cell must out-draw the carbothermic furnace: %.0f MW vs %.0f MW", ec / 1e6, cf / 1e6))
    assert.is_true(cf >= 40e6, string.format(
      "the carbothermic furnace must stay a multi-tens-of-MW flare sink (>= the 40 MW heater); got %.0f MW",
      cf / 1e6))
  end)
end)

describe("balance audit (ci-63d): exportable buildings are situational-not-strictly-better (§12)", function()
  -- The three buildings a player can carry off-world (capacitor, molten-salt
  -- battery, electric heater) must each be strictly WORSE than their vanilla analog
  -- on at least one axis, so none is a free upgrade off Cindra. Per-building upside
  -- (flow / cost / electric-vs-fuel) is covered in test_power_prototypes + test_heater;
  -- this pins the single cross-cutting invariant: no exportable building dominates.
  it("the capacitor is strictly worse than a vanilla accumulator on buffer", function()
    local cap = prototypes.entity["cindra-capacitor"].electric_energy_source_prototype.buffer_capacity
    local acc = prototypes.entity["accumulator"].electric_energy_source_prototype.buffer_capacity
    assert.is_true(cap < acc,
      "capacitor buffer must be below a vanilla accumulator's (its upside is flow, not storage)")
  end)

  it("the molten-salt battery is strictly worse than a vanilla accumulator on buffer AND flow", function()
    local bat = prototypes.entity["cindra-molten-salt-battery"].electric_energy_source_prototype.buffer_capacity
    local acc = prototypes.entity["accumulator"].electric_energy_source_prototype.buffer_capacity
    assert.is_true(bat < acc,
      "battery buffer must be below a vanilla accumulator's (its upside is a cheap recipe)")
    assert.is_true(C.BATTERY_FLOW_W < 300e3,
      "battery throughput must be below a vanilla accumulator's 300 kW (slow drip)")
  end)

  it("the electric heater is strictly worse than a heating tower on heat ceiling", function()
    local heater = prototypes.entity["cindra-electric-heater"].heat_buffer_prototype.max_temperature
    local tower = prototypes.entity["heating-tower"].heat_buffer_prototype.max_temperature
    assert.is_true(heater < tower, string.format(
      "electric heater heat ceiling (%.0f) must sit below a heating tower's (%.0f); its upside is "
        .. "electric-not-fuel input, not a higher cap", heater, tower))
  end)
end)
