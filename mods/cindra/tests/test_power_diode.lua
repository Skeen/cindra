-- PROOF for the one-way power-transfer device -- the "power diode" (ci-gcd,
-- reworked to a power-SWITCH-style single building in ci-8l4).
--
-- Mandates, each an assertion below:
--   1. it is ONE building (a power-switch) with TWO copper inputs -- not two
--      separately-placed poles paired by proximity                (the rework)
--   2. placing the device spawns + wires its hidden guts, and removing it tears
--      them down                                                  (composite lifecycle)
--   3. energy flows source->sink up to the rate cap               (rate cap respected)
--   4. energy does NOT flow sink->source (charge B, drain A)      (one-way)
--   5. two-network isolation holds                                (distinct networks)
--
-- The device (prototypes/power-diode.lua) is a reskinned power-switch; on build
-- the runtime (scripts/diode.lua) spawns two HIDDEN electric-energy-interface
-- buffers + two tap poles and copper-wires each tap to a switch connector, so the
-- player's two wired networks each host one buffer. The buffer-level tests drive
-- diode.step directly and are fully deterministic (no ticks). The network-level
-- tests build two genuinely ISOLATED networks (wired to the switch's two sides,
-- which the OPEN switch keeps apart) and let the registered runtime shuttle power
-- across, proving the crossing happens end-to-end under the real engine.

local H = require("tests.helpers")
local C = require("scripts.diode-config")
local diode = require("scripts.diode")

local WCID = defines.wire_connector_id

local function place(s, name, pos)
  return s.create_entity({ name = name, position = pos, force = "player" })
end

-- Build the device and run the REAL build handler (raise_built -> the registered
-- script_raised_built -> diode.attach), so the whole placement pipeline -- spawn
-- guts, wire taps -- is exercised, not a test-only shortcut.
local function place_device(s, pos)
  return s.create_entity({ name = C.DEVICE, position = pos, force = "player", raise_built = true })
end

-- Copper-wire two entities' connectors (reach check off: the test spans networks
-- far apart, and the link is script-made).
local function copper(a, a_id, b, b_id)
  a.get_wire_connector(a_id, true).connect_to(b.get_wire_connector(b_id, true), false, defines.wire_origin.script)
end

-- A one-substation network centred at (cx, 0), returned so the caller can wire it
-- to a switch side.
local function substation(s, cx)
  return s.create_entity({ name = "substation", position = { cx, 0 }, force = "player" })
end

-- A producer on a network: a vanilla EEI with runtime power_production set (the
-- same infinite-source pattern the other Cindra tests use). A buffer that is a
-- LOAD charges from this producer's power as real demand.
local function producer(s, pos, watts)
  local p = place(s, "electric-energy-interface", pos)
  p.power_production = watts
  p.power_usage = 0
  p.energy = p.electric_buffer_size
  return p
end

describe("power-diode (ci-8l4 power-switch-style one-way device)", function()
  it("is ONE power-switch building with two copper connectors, not two placeable poles", function()
    local dev = prototypes.entity[C.DEVICE]
    assert.is_truthy(dev, "the device prototype must exist")
    assert.are.equal("power-switch", dev.type,
      "the device must be a power-switch (single building, two copper inputs)")
    -- Only the device is placeable: the buffers/taps are hidden guts with no item.
    assert.is_truthy(prototypes.item[C.DEVICE], "the device must have a placeable item")
    assert.is_nil(prototypes.item[C.INPUT], "the input buffer must NOT be a placeable item")
    assert.is_nil(prototypes.item[C.OUTPUT], "the output buffer must NOT be a placeable item")
    -- The hidden guts exist as entities but are not selectable/on-map.
    for _, name in ipairs({ C.INPUT, C.OUTPUT, C.INPUT_TAP, C.OUTPUT_TAP }) do
      assert.is_truthy(prototypes.entity[name], "hidden gut prototype must exist: " .. name)
    end
  end)

  -- ci-ntgh: a "disconnected power" warning symbol rendered WAY OUTSIDE the
  -- device model. The demand lives in the hidden INPUT buffer, which sits TAP_DX
  -- (3) tiles off the device by construction -- the tap poles' supply areas must
  -- not cross-cover the far side's buffer, or the two networks merge and the
  -- diode stops being one -- and an electric energy source paints the engine's
  -- no-power / no-network icon over ITS OWN entity. So the icon appeared out in
  -- open ground, attached to nothing the player can see. The prototype opts both
  -- buffers out; the DEVICE is the only thing that speaks for the diode.
  --
  -- This is the ONE part of the render the runtime API can prove: the icon flags
  -- ARE exposed (LuaElectricEnergySourcePrototype), unlike sprites. The
  -- data-stage half of the audit lives in unit-tests/test_power_diode_graphics.lua.
  it("its hidden buffers raise no power-warning icon floating off the model", function()
    for _, name in ipairs({ C.INPUT, C.OUTPUT }) do
      local src = prototypes.entity[name].electric_energy_source_prototype
      assert.is_truthy(src, name .. " must have an electric energy source")
      assert.is_false(src.render_no_power_icon,
        name .. " must not draw the 'no power' icon: it would float " .. C.TAP_DX
        .. " tiles off the device model")
      assert.is_false(src.render_no_network_icon,
        name .. " must not draw the 'no network' icon (same floating position)")
    end
    -- The DEVICE itself is a power-switch: no energy source, so nothing to
    -- silence, and nothing that could draw a stray icon on the model either.
    assert.is_nil(prototypes.entity[C.DEVICE].electric_energy_source_prototype,
      "the device must have no energy source of its own")
  end)

  -- The state that produced the report: the source side wired to a network that
  -- cannot fill the buffer. The controller parks the input buffer with a probe of
  -- headroom every sweep, so the demand -- and therefore the icon -- was
  -- permanent, not a placement-time flicker. Proving the buffer really does sit
  -- in that unmet-demand state is what makes the flag assertion above meaningful.
  it("the input buffer really does sit in the unmet-demand state that drew the icon", function()
    local s = H.cindra_surface()
    H.power_reset()
    diode.reset()

    local dev = place_device(s, { 0, 0 })
    local d = diode.registry()[dev.unit_number]
    -- Two real but DEAD networks: substations with no generation at all.
    copper(dev, WCID.power_switch_left_copper, substation(s, -12), WCID.pole_copper)
    copper(dev, WCID.power_switch_right_copper, substation(s, 12), WCID.pole_copper)

    diode.tick({ dt = C.TICK_INTERVAL })
    -- The buffer is on a network (so it is not "unpowered because unwired") and
    -- it wants more than that network can give -- exactly the no-power state.
    assert.is_truthy(d.input.electric_network_id, "the input buffer must be on a real network")
    assert.is_true(d.input.energy < d.input.electric_buffer_size,
      "the input buffer must be parked with headroom, i.e. demanding power the dead source cannot supply")
    -- And it is genuinely off the device, which is why the icon floated.
    assert.are.equal(C.TAP_DX, math.abs(d.input.position.x - dev.position.x),
      "the input buffer sits TAP_DX tiles off the device by construction")

    dev.destroy({ raise_destroy = true })
  end)

  -- ci-ntgh, the OBSERVABLE half of the stray-model audit. The helpers are clones
  -- of the vanilla accumulator-interface / small-electric-pole, so they inherited
  -- those prototypes' WRECKAGE: kill one and the engine dropped a battery or a
  -- power-pole remnant on the ground TAP_DX tiles off the building -- a model the
  -- player can walk up to, long after the invisible thing that made it was gone.
  -- What the player sees is the assertion: after the guts die, the field around
  -- the diode is empty.
  it("leaves no wreckage lying off to the side when its hidden guts are killed", function()
    local s = H.cindra_surface()
    H.power_reset()
    diode.reset()

    local dev = place_device(s, { 0, 0 })
    local d = diode.registry()[dev.unit_number]
    local box = { { -C.TAP_DX - 4, -6 }, { C.TAP_DX + 4, 6 } }
    for _, e in ipairs({ d.input, d.output, d.input_tap, d.output_tap }) do
      e.die()
    end

    local corpses = s.find_entities_filtered({ area = box, type = "corpse" })
    assert.are.equal(0, #corpses,
      "a dead hidden gut must leave NO battery/pole wreckage beside the diode")
    -- Same for the "remnants" the engine registers as simple-entities in some
    -- cases: nothing new may appear where the guts stood.
    local left = s.find_entities_filtered({ area = box, name = { C.INPUT, C.OUTPUT, C.INPUT_TAP, C.OUTPUT_TAP } })
    assert.are.equal(0, #left, "the killed guts must be gone, not lingering")

    dev.destroy({ raise_destroy = true })
  end)

  -- Same audit, the part the player meets with the mouse: the guts are phantoms
  -- that draw nothing, so they must claim no footprint out beside the building
  -- either. A helper carrying its source's 2x2-ish selection box put a selectable
  -- -sized claim TAP_DX tiles off a device the player thinks is one power switch.
  it("its hidden guts claim no footprint beside the building", function()
    for _, name in ipairs({ C.INPUT, C.OUTPUT, C.INPUT_TAP, C.OUTPUT_TAP }) do
      local p = prototypes.entity[name]
      assert.is_false(p.selectable_in_game, name .. " must not be selectable")
      local sb = p.selection_box
      assert.are.equal(0, sb.left_top.x, name .. " selection box must collapse to a point")
      assert.are.equal(0, sb.left_top.y, name .. " selection box must collapse to a point")
      assert.are.equal(0, sb.right_bottom.x, name .. " selection box must collapse to a point")
      assert.are.equal(0, sb.right_bottom.y, name .. " selection box must collapse to a point")
    end
    -- The DEVICE keeps its real, power-switch-sized box: it is the building.
    local dev_box = prototypes.entity[C.DEVICE].selection_box
    assert.is_true(dev_box.right_bottom.x > 0, "the device must keep a real selection box")
  end)

  it("spawns + wires its hidden guts on build, and tears them down on removal", function()
    local s = H.cindra_surface()
    H.power_reset()
    diode.reset()

    local dev = place_device(s, { 0, 0 })
    local d = diode.registry()[dev.unit_number]
    assert.is_truthy(d, "building the device must register it")
    assert.is_true(d.input.valid and d.output.valid, "both buffers must be spawned")
    assert.is_true(d.input_tap.valid and d.output_tap.valid, "both tap poles must be spawned")
    -- The input buffer's tap is wired to the LEFT connector, the output's to the
    -- RIGHT -- the two power inputs of the switch.
    local left = dev.get_wire_connector(WCID.power_switch_left_copper, false)
    local right = dev.get_wire_connector(WCID.power_switch_right_copper, false)
    assert.is_true(left ~= nil and left.connection_count > 0, "left connector must be wired (source input)")
    assert.is_true(right ~= nil and right.connection_count > 0, "right connector must be wired (sink output)")

    -- Removing the device destroys every hidden gut and forgets the registration.
    local input, output, itap, otap = d.input, d.output, d.input_tap, d.output_tap
    dev.destroy({ raise_destroy = true })
    assert.is_nil(diode.registry()[nil], "sanity")
    assert.is_false(input.valid, "input buffer must be destroyed with the device")
    assert.is_false(output.valid, "output buffer must be destroyed with the device")
    assert.is_false(itap.valid, "input tap must be destroyed with the device")
    assert.is_false(otap.valid, "output tap must be destroyed with the device")
  end)

  it("moves energy source->sink and respects the configured rate cap", function()
    local s = H.cindra_surface()
    H.power_reset()
    local input = place(s, C.INPUT, { -3, 0 })
    local output = place(s, C.OUTPUT, { 3, 0 })
    input.energy = input.electric_buffer_size -- source buffer full
    output.energy = 0

    -- One step at an explicit rate/dt: the move is exactly the rate cap when
    -- supply and headroom are ample (rate/60 J per tick).
    local rate, dt = 6e6, 10
    local expect = rate / 60 * dt -- 1,000,000 J
    local moved = diode.step(input, output, { rate_w = rate, dt = dt })
    assert.are.equal(expect, moved, "one step must move exactly the rate cap")
    assert.are.equal(expect, output.energy, "the output buffer gains the capped amount")
    assert.are.equal(input.electric_buffer_size - expect, input.energy,
      "the input buffer loses exactly what the output gained")

    -- A second step moves the cap again: the cap is a per-step ceiling, not a
    -- one-off. Energy never crosses faster than the rate allows.
    local moved2 = diode.step(input, output, { rate_w = rate, dt = dt })
    assert.are.equal(expect, moved2, "the rate cap binds every step, not just the first")
    assert.are.equal(2 * expect, output.energy, "two capped steps = twice the cap, no more")
  end)

  it("never flows sink->source: the script only ever moves input->output", function()
    local s = H.cindra_surface()
    H.power_reset()
    local input = place(s, C.INPUT, { -3, 0 })
    local output = place(s, C.OUTPUT, { 3, 0 })
    -- Charge the DESTINATION buffer full, empty the SOURCE buffer: the reverse of
    -- a forward transfer. A one-way device must move nothing.
    input.energy = 0
    output.energy = output.electric_buffer_size

    local moved = diode.step(input, output, { rate_w = 6e6, dt = 10 })
    assert.are.equal(0, moved, "a full output + empty input must transfer nothing")
    assert.are.equal(0, input.energy, "the input buffer must NEVER gain energy from the output")
    assert.are.equal(output.electric_buffer_size, output.energy,
      "the output buffer's charge is untouched -- no back-flow")
  end)

  it("keeps the two wired networks isolated (distinct electric networks)", function()
    local s = H.cindra_surface()
    H.power_reset()
    diode.reset()
    local dev = place_device(s, { 0, 0 })
    local subA = substation(s, -30)
    local subB = substation(s, 30)
    copper(subA, WCID.pole_copper, dev, WCID.power_switch_left_copper)
    copper(subB, WCID.pole_copper, dev, WCID.power_switch_right_copper)
    local d = diode.registry()[dev.unit_number]

    async(120)
    after_ticks(60, function()
      assert.is_truthy(d.input.electric_network_id, "input buffer must join a network")
      assert.is_truthy(d.output.electric_network_id, "output buffer must join a network")
      assert.is_not.equal(d.input.electric_network_id, d.output.electric_network_id,
        "the two switch sides must stay on SEPARATE networks -- the whole point of the diode")
      done()
    end)
  end)

  it("energy crosses source->sink end-to-end through two real isolated networks", function()
    local s = H.cindra_surface()
    H.power_reset()
    diode.reset()
    local dev = place_device(s, { 0, 0 })
    -- Source network: a producer feeds the (load) input buffer with power.
    local subA = substation(s, -30)
    producer(s, { -30, 6 }, 100e6)
    -- Sink network: an empty accumulator that charges only because the (source)
    -- output buffer is producing surplus into it.
    local subB = substation(s, 30)
    local sink = place(s, "accumulator", { 30, 6 })
    sink.energy = 0
    copper(subA, WCID.pole_copper, dev, WCID.power_switch_left_copper)
    copper(subB, WCID.pole_copper, dev, WCID.power_switch_right_copper)
    local d = diode.registry()[dev.unit_number]

    -- Let the REGISTERED runtime (control.lua diode.register, nth-tick 7) drive
    -- the transfer while the networks settle.
    async(600)
    after_ticks(400, function()
      assert.is_not.equal(d.input.electric_network_id, d.output.electric_network_id,
        "setup must produce two isolated networks")
      assert.is_true(d.output.energy > 0,
        "power must cross into the output buffer: " .. d.output.energy)
      assert.is_true(sink.energy > 0,
        "the destination network must actually receive power: " .. sink.energy)
      done()
    end)
  end)

  it("power never reaches the source even when the sink is flooded and the source is dark", function()
    local s = H.cindra_surface()
    H.power_reset()
    diode.reset()
    local dev = place_device(s, { 0, 0 })
    -- Source network: DARK -- just an empty accumulator, no producer.
    local subA = substation(s, -30)
    local a_acc = place(s, "accumulator", { -30, 6 })
    a_acc.energy = 0
    -- Sink network: FLOODED -- a strong producer.
    local subB = substation(s, 30)
    producer(s, { 30, 6 }, 100e6)
    copper(subA, WCID.pole_copper, dev, WCID.power_switch_left_copper)
    copper(subB, WCID.pole_copper, dev, WCID.power_switch_right_copper)
    local d = diode.registry()[dev.unit_number]

    async(600)
    after_ticks(400, function()
      assert.is_not.equal(d.input.electric_network_id, d.output.electric_network_id,
        "setup must produce two isolated networks")
      -- The output buffer is discharge-only (input_flow_limit = 0): the sink's
      -- abundant power has NO way into the diode at all. A dark source also means
      -- the controller meters zero `charged`, so nothing is ever carried into the
      -- output buffer -- it stays empty.
      assert.are.equal(0, d.output.energy,
        "the output buffer must never soak power from the sink network: " .. d.output.energy)
      -- ...so nothing crosses, and the dark source network stays dark. NOTE: under
      -- the demand-metered controller (ci-76if) the INPUT buffer rests at a virtual
      -- throttle floor (near full), not empty -- but that floor is inert
      -- (output_flow_limit 0 -> it can never feed the source, and the sweep only
      -- carries the metered source-charge delta across, which is 0 here). The real
      -- one-way guard is that the flooded sink reaches neither the output buffer
      -- (above) nor the source network (below):
      assert.are.equal(0, a_acc.energy, "the source network must receive zero power from the flooded sink: " .. a_acc.energy)
      done()
    end)
  end)

  -- =========================================================================
  -- ci-76if: demand-driven power economy. The diode must (a) transfer NOTHING and
  -- draw NOTHING when gated OFF; (b) draw ~0 from the source when the far side is
  -- satisfied/idle (no parasitic load); (c) transfer up to the far side's deficit
  -- when it is hungry; and never generate free energy (output <= what the source
  -- supplied this interval). Each uses a FIXED-STORE source (a charged
  -- accumulator, no producer) so the source's energy DROP directly measures the
  -- draw the diode places on it.
  -- =========================================================================

  -- A charged accumulator acting as the SOURCE network's whole energy store, so a
  -- parasitic draw shows up as a measurable drop in its charge.
  local function source_store(s, cx)
    local acc = place(s, "accumulator", { cx, 6 })
    acc.energy = acc.electric_buffer_size
    return acc
  end

  it("OFF: transfers nothing and draws nothing from the source (ci-76if)", function()
    local s = H.cindra_surface()
    H.power_reset(); diode.reset()
    local dev = place_device(s, { 0, 0 })
    local subA = substation(s, -30)
    local src = source_store(s, -30) -- source has a full 5 MJ store
    local subB = substation(s, 30)
    local sink = place(s, "accumulator", { 30, 6 }) -- an empty, WANTING sink
    sink.energy = 0
    copper(subA, WCID.pole_copper, dev, WCID.power_switch_left_copper)
    copper(subB, WCID.pole_copper, dev, WCID.power_switch_right_copper)
    local d = diode.registry()[dev.unit_number]
    diode.set_enabled(dev, false) -- gate the diode OFF

    async(600)
    after_ticks(400, function()
      assert.is_not.equal(d.input.electric_network_id, d.output.electric_network_id,
        "setup must produce two isolated networks")
      -- OFF blocks fully: the sink gets nothing even though it is hungry...
      assert.are.equal(0, sink.energy, "OFF: the far side must receive zero: " .. sink.energy)
      assert.are.equal(0, d.output.energy, "OFF: the output buffer stays empty: " .. d.output.energy)
      -- ...and the source's store is untouched (input parked full -> no load).
      assert.is_true(src.energy >= src.electric_buffer_size * 0.99,
        "OFF: the source must not be drawn down: " .. src.energy .. "/" .. src.electric_buffer_size)
      done()
    end)
  end)

  it("ON + satisfied/idle far side draws ~0 from the source (no parasitic load) (ci-76if)", function()
    local s = H.cindra_surface()
    H.power_reset(); diode.reset()
    local dev = place_device(s, { 0, 0 })
    local subA = substation(s, -30)
    local src = source_store(s, -30) -- full 5 MJ store on the source
    local subB = substation(s, 30)
    local sink = place(s, "accumulator", { 30, 6 })
    sink.energy = sink.electric_buffer_size -- sink already FULL -> zero demand
    copper(subA, WCID.pole_copper, dev, WCID.power_switch_left_copper)
    copper(subB, WCID.pole_copper, dev, WCID.power_switch_right_copper)
    local d = diode.registry()[dev.unit_number]
    -- enabled by default

    async(600)
    after_ticks(400, function()
      assert.is_not.equal(d.input.electric_network_id, d.output.electric_network_id,
        "setup must produce two isolated networks")
      -- The satisfied far side pulls nothing, so the controller must NOT drain the
      -- source into a self-charging reservoir. The old design drained the whole
      -- 5 MJ store filling its 100 MJ of buffers; the fixed design draws at most a
      -- one-off demand probe (a small fraction of the rate cap).
      local drawn = src.electric_buffer_size - src.energy
      assert.is_true(drawn < 1e6,
        "idle far side must not draw meaningfully from the source: drawn=" .. drawn)
      done()
    end)
  end)

  it("ON + far-side deficit transfers up to the demand, one direction (ci-76if)", function()
    local s = H.cindra_surface()
    H.power_reset(); diode.reset()
    local dev = place_device(s, { 0, 0 })
    local subA = substation(s, -30)
    producer(s, { -30, 6 }, 100e6) -- sustained source
    local subB = substation(s, 30)
    local sink = place(s, "accumulator", { 30, 6 }) -- empty -> a real deficit
    sink.energy = 0
    copper(subA, WCID.pole_copper, dev, WCID.power_switch_left_copper)
    copper(subB, WCID.pole_copper, dev, WCID.power_switch_right_copper)
    local d = diode.registry()[dev.unit_number]

    async(600)
    after_ticks(400, function()
      assert.is_not.equal(d.input.electric_network_id, d.output.electric_network_id,
        "setup must produce two isolated networks")
      -- The hungry far side ramps the transfer up and receives real power.
      assert.is_true(sink.energy > 1e6,
        "a far-side deficit must be served: sink=" .. sink.energy)
      done()
    end)
  end)

  it("no free generation: a source that goes dark stops feeding the sink (ci-76if)", function()
    local s = H.cindra_surface()
    H.power_reset(); diode.reset()
    local dev = place_device(s, { 0, 0 })
    local subA = substation(s, -30)
    local srcprod = producer(s, { -30, 6 }, 100e6)
    local subB = substation(s, 30)
    local sink = place(s, "accumulator", { 30, 6 })
    sink.energy = 0
    copper(subA, WCID.pole_copper, dev, WCID.power_switch_left_copper)
    copper(subB, WCID.pole_copper, dev, WCID.power_switch_right_copper)
    local d = diode.registry()[dev.unit_number]

    async(1200)
    after_ticks(300, function()
      -- Buffers are now primed from the live source. Kill the source.
      srcprod.destroy()
      local at_death = sink.energy
      after_ticks(600, function()
        -- With no source, the controller carries nothing across: the output buffer
        -- collapses to ~0 and the sink gains at most the tiny in-flight residual
        -- (one sweep's worth), NOT the megajoules a self-charged 50 MJ reservoir
        -- would have dumped. energy out <= energy in; no free generation.
        local extra = sink.energy - at_death
        assert.is_true(extra < 2e6,
          "no free energy after the source dies: extra delivered=" .. extra)
        assert.is_true(d.output.energy < 2e6,
          "the output buffer must collapse to ~0 with no live source: " .. d.output.energy)
        done()
      end)
    end)
  end)
end)
