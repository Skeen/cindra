-- PROOF (ci-m96z): the mod-wide POWER-ECONOMY CONSERVATION invariants -- the
-- player-observable "no free energy" rules EVERY Cindra power entity must obey.
--
-- WHY THIS FILE EXISTS. A fully green suite once shipped a power diode that drew
-- a flat 10 MW forever AND generated 10 MW from nothing (ci-76if), because the
-- tests asserted the IMPLEMENTATION MODEL (energy_usage == X, buffer == Y) instead
-- of the invariant a player can actually observe: energy does not appear out of
-- thin air. Restating the code can never catch a wrong model. Measuring the grid
-- can. So the assertions here read ONLY live engine energy -- what the player
-- would see on their power graph -- and never a constant the code also declares.
--
-- The invariants (from the bead), applied to every custom power entity:
--   1. energy OUT <= energy IN + legitimate generation. Nothing mints energy.
--   2. source empty / disconnected -> downstream receives ZERO (no free generation).
--   3. an OFF / gated device -> zero transfer AND zero draw.
--   4. an idle downstream -> ~zero source draw (no parasitic constant consumption).
-- Legitimate generation on Cindra is SUNLIGHT ONLY (solar panels on a lit sky):
-- turn the sun off and the whole planet's power economy must go to exactly zero.
--
-- WHERE EACH ONE IS PINNED. (1) and (2) are the suites below -- they apply to every
-- power entity, so they are enforced mod-wide here. (3) and (4) only mean anything
-- for a device that GATES or METERS a transfer, which on Cindra is the power diode
-- alone (storage tiers and the dissipator have no gate and no upstream to spare):
-- they live with it in tests/test_power_diode.lua ("OFF: transfers nothing and draws
-- nothing" and "ON + satisfied/idle far side draws ~0"), and the COVERED table below
-- names them so the coverage guard stays honest about what is pinned where.
--
-- The first test is a COVERAGE GUARD: it discovers every Cindra power prototype
-- live and fails if one is not declared covered here. A new power entity therefore
-- cannot land without a conservation case -- the policy enforces itself instead of
-- relying on a reviewer remembering it. See AGENTS.md "Definition of Done".

local H = require("tests.helpers")
local C = require("scripts.flare-config")
local DC = require("scripts.diode-config")
local diode = require("scripts.diode")
local flare = require("scripts.flare")
local panel_solar = require("scripts.panel-solar")

local WCID = defines.wire_connector_id
local HEATER = "cindra-electric-heater"

-- Deterministic flare anchor (same convention as the other power suites): the
-- telegraph starts at WS, so PEAK_TICK lands on the plateau -- the sunniest moment
-- Cindra ever has, and therefore the harshest test of "nothing mints energy".
local WS = 600
local PEAK_TICK = WS + C.WARNING_TICKS + C.RAMP_TICKS + 10

-- ===========================================================================
-- Coverage guard
-- ===========================================================================

-- Prototype types that can PUT energy on an electric network or hold/shuttle it --
-- i.e. power INFRASTRUCTURE, the class of entity where "did it mint joules?" is a
-- live question. Ordinary consumers (assembling machines, furnaces, the electric
-- heater's reactor) are excluded: they can only ever draw. Electric POLES are
-- excluded too -- a pole is an inert conductor with no energy of its own (the
-- diode's hidden tap poles are exactly that).
local POWER_TYPES = {
  ["accumulator"] = true,
  ["solar-panel"] = true,
  ["electric-energy-interface"] = true,
  ["power-switch"] = true,
  ["generator"] = true,
  ["burner-generator"] = true,
  ["fusion-generator"] = true,
  ["lightning-attractor"] = true,
}

-- Every power entity Cindra owns, and the conservation case that pins it. Adding a
-- power prototype WITHOUT adding an entry here fails the guard below.
local COVERED = {
  [C.PANEL] = "vanilla panel reused on Cindra: sun off -> zero output (below); "
    .. "magnitudes in test_solar_magnitude, position bands in test_panel_solar",
  [C.CAPACITOR] = "never mints on a generator-free grid (below); leak-only upkeep in test_storage",
  [C.BATTERY] = "never mints on a generator-free grid (below); leak-only upkeep in test_storage",
  [C.DISSIPATOR] = "pure sink: what it swallows never returns to the grid (below); "
    .. "rated draw measured live in test_storage",
  [C.MEASURE_SINK] = "test-only measuring accumulator (factorio-test builds only); "
    .. "used AS the ledger instrument below, never shipped",
  [DC.DEVICE] = "cross-network ledger: delivered <= drawn; dead/unwired source -> zero (below); "
    .. "OFF -> zero transfer + zero draw and idle -> ~zero draw in test_power_diode",
  [DC.INPUT] = "load-only buffer: can never feed its network back (below)",
  [DC.OUTPUT] = "source-only buffer: can never soak power out of its network (below)",
}
-- The reduced sunward bands are real solar panels: same rule as the full band.
for _, f in ipairs(panel_solar.BANDS) do
  COVERED[panel_solar.name_for_band(f)] = "reduced solar band: sun off -> zero output (below)"
end

-- Every Cindra-owned power prototype the game actually loaded. Ownership is by
-- name prefix, the mod's own convention for "unmistakably a Cindra prototype"
-- (scripts/flare-config.lua) -- the runtime API cannot report which mod added a
-- prototype. C.PANEL (the vanilla panel Cindra reuses wholesale) is checked
-- separately since it carries no prefix.
local function cindra_power_prototypes()
  local found = {}
  for name, proto in pairs(prototypes.entity) do
    if POWER_TYPES[proto.type] and string.sub(name, 1, 7) == "cindra-" then
      found[#found + 1] = name
    end
  end
  table.sort(found)
  return found
end

describe("power economy - coverage guard (ci-m96z)", function()
  it("every Cindra power entity is declared covered by a conservation case", function()
    local missing = {}
    for _, name in ipairs(cindra_power_prototypes()) do
      if not COVERED[name] then missing[#missing + 1] = name end
    end
    assert.are.equal(0, #missing,
      "power prototype(s) with NO conservation case -- add one here and list them in "
        .. "COVERED (Definition of Done, AGENTS.md): " .. table.concat(missing, ", "))
  end)

  it("the guard actually discovers the known power entities (not vacuous)", function()
    -- A self-test, mirroring tests/no-orphan-suites.test.sh: if the discovery ever
    -- goes empty (a renamed prefix, a changed type set) the guard above would pass
    -- unconditionally and give false assurance. Pin the core set it MUST find.
    local found = {}
    for _, name in ipairs(cindra_power_prototypes()) do found[name] = true end
    for _, name in ipairs({ C.CAPACITOR, C.BATTERY, C.DISSIPATOR, DC.DEVICE, DC.INPUT, DC.OUTPUT }) do
      assert.is_true(found[name] == true,
        "discovery must find the known power entity " .. name .. " -- the guard is vacuous otherwise")
    end
    -- ...and at least one reduced solar band (the panel variants are power too).
    assert.is_true(found[panel_solar.name_for_band(0.05)] == true,
      "discovery must find the reduced solar bands")
    -- The vanilla panel Cindra reuses carries no cindra- prefix, so it is covered
    -- by name rather than by discovery. Make sure that entry stays honest.
    assert.is_not_nil(COVERED[C.PANEL], "the reused vanilla panel must be declared covered")
    assert.is_not_nil(prototypes.entity[C.PANEL], "the reused vanilla panel must exist")
  end)
end)

-- ===========================================================================
-- No free energy: the grid-level ledger
-- ===========================================================================

local function place(s, name, pos)
  return s.create_entity({ name = name, position = pos, force = "player" })
end

-- Park the surface in real NIGHT: the engine's solar factor is 0 between evening
-- and morning, so no panel anywhere on this surface can produce. Frozen, so the
-- clock cannot drift back into daylight mid-window. This is the "legitimate
-- generation = 0" condition every no-free-energy test needs.
local function sun_off(s)
  s.freeze_daytime = true
  local evening = s.evening or 0.45
  local morning = s.morning or 0.55
  s.daytime = (evening + morning) / 2
end

describe("power economy - no entity mints energy (ci-m96z)", function()
  it("a grid of Cindra power gear with NO generator stays at exactly zero -- even at flare peak", function()
    -- The headline invariant, and the one that would have caught the ci-76if diode:
    -- put every non-generating Cindra power building on one grid, hold the sky at
    -- the flare plateau (the most energy the planet ever offers), and give the grid
    -- NO way to harvest it -- no panel, no producer. A player watching this grid
    -- sees a dead network. If anything reads above zero, something minted joules.
    local s = H.cindra_surface()
    H.power_reset()
    flare.set_schedule(WS)
    H.grid(s, 0, 24)

    local cap = H.capacitor(s, { -6, 0 })
    local bat = H.battery(s, { -6, 6 })
    local diss = H.dissipator(s, { -6, 12 })
    local heater = place(s, HEATER, { -7, 18 })
    local acc = place(s, "accumulator", { 6, 0 })
    for _, e in ipairs({ cap, bat, diss, acc }) do e.energy = 0 end

    flare.apply(s, PEAK_TICK) -- blazing sky, nothing on this grid to catch it

    async(600)
    after_ticks(300, function()
      assert.are.equal(0, cap.energy, "capacitor must not charge itself: " .. cap.energy)
      assert.are.equal(0, bat.energy, "molten-salt battery must not charge itself: " .. bat.energy)
      assert.are.equal(0, diss.energy, "dissipator must not fill itself: " .. diss.energy)
      assert.are.equal(0, acc.energy, "the grid must deliver nothing to an accumulator: " .. acc.energy)
      assert.is_true(heater.valid and heater.temperature <= 16,
        "the electric heater must stay cold on a dead grid: " .. tostring(heater.temperature))
      done()
    end)
  end)

  it("on a generator-free grid, stored energy only ever falls (a load spends it; nothing refills it)", function()
    -- The same rule with energy actually present: one fixed store, one real load.
    -- Total stored joules across the whole grid may fall (the dissipator burns
    -- them) but must NEVER rise -- Cindra's storage tiers move and lose energy,
    -- they do not create it.
    local s = H.cindra_surface()
    H.power_reset()
    sun_off(s)
    H.grid(s, 0, 18)

    local store = H.measure_sink(s, { -6, 0 }) -- the grid's entire energy supply
    store.energy = 200e6
    local cap = H.capacitor(s, { -6, 6 })
    local bat = H.battery(s, { -6, 12 })
    local acc = place(s, "accumulator", { 6, 0 })
    for _, e in ipairs({ cap, bat, acc }) do e.energy = 0 end
    H.dissipator(s, { 6, 12 }) -- a 20 MW load, the only way energy may leave

    local function total()
      return store.energy + cap.energy + bat.energy + acc.energy
    end
    local total0 = total()

    async(900)
    after_ticks(240, function()
      local total1 = total()
      assert.is_true(total1 <= total0,
        "stored energy must never grow on a generator-free grid: " .. total0 .. " -> " .. total1)
      -- Liveness: the grid really is connected and running (the load spent power),
      -- so the assertion above is measuring something, not an inert scene.
      assert.is_true(total1 < total0,
        "the load must actually consume from the store (test would be vacuous otherwise): "
          .. total0 .. " -> " .. total1)
      done()
    end)
  end)

  it("with the sun off, every panel band delivers exactly nothing", function()
    -- Solar is Cindra's ONLY legitimate generation, and it is genuinely solar: no
    -- sun, no watts. This is the invariant that makes every "energy in" bound above
    -- meaningful -- and it holds for the reduced sunward bands too, which are real
    -- panels rather than scripted producers.
    local s = H.cindra_surface()
    H.power_reset()
    sun_off(s)
    H.grid(s, 0, 24)

    local y = 0
    for _, f in ipairs(panel_solar.BANDS) do
      place(s, panel_solar.name_for_band(f), { 6, y })
      y = y + 4
    end
    local sink = H.measure_sink(s, { -6, 0 }) -- absorbs anything the panels emit
    sink.energy = 0

    async(600)
    after_ticks(240, function()
      assert.are.equal(0, sink.energy,
        "a sunless sky must yield zero solar output from every band: " .. sink.energy)
      done()
    end)
  end)

  it("a dissipator is a one-way waste sink: what it swallows never returns to the grid", function()
    -- The dissipator is the disposal floor. If it could feed its buffer back it
    -- would be a battery with infinite intake -- and the flare's whole disposal
    -- pressure would evaporate. Charge its buffer, then watch the grid: nothing
    -- else may gain a single joule from it.
    local s = H.cindra_surface()
    H.power_reset()
    sun_off(s)
    H.grid(s, 0, 12)

    local diss = H.dissipator(s, { -6, 0 })
    diss.energy = diss.electric_buffer_size -- a full 1 MJ buffer to give back
    local cap = H.capacitor(s, { -6, 6 })
    local acc = place(s, "accumulator", { 6, 0 })
    cap.energy, acc.energy = 0, 0

    async(600)
    after_ticks(240, function()
      assert.are.equal(0, acc.energy,
        "a dissipator must never feed the grid it drains: accumulator got " .. acc.energy)
      assert.are.equal(0, cap.energy,
        "a dissipator must never feed the grid it drains: capacitor got " .. cap.energy)
      done()
    end)
  end)
end)

-- ===========================================================================
-- The power diode: the ci-76if pin, measured as a two-network energy ledger
-- ===========================================================================

local function copper(a, a_id, b, b_id)
  a.get_wire_connector(a_id, true).connect_to(b.get_wire_connector(b_id, true), false, defines.wire_origin.script)
end

local function substation(s, cx)
  return s.create_entity({ name = "substation", position = { cx, 0 }, force = "player" })
end

-- A wired diode between two isolated networks. `wire_source` false leaves the
-- source side unwired (the "unplugged" case). Returns the device's registry entry.
local function wired_diode(s, wire_source)
  local dev = s.create_entity({ name = DC.DEVICE, position = { 0, 0 }, force = "player", raise_built = true })
  if wire_source ~= false then
    copper(substation(s, -30), WCID.pole_copper, dev, WCID.power_switch_left_copper)
  end
  copper(substation(s, 30), WCID.pole_copper, dev, WCID.power_switch_right_copper)
  return dev, diode.registry()[dev.unit_number]
end

describe("power economy - the diode moves energy, never makes it (ci-m96z / ci-76if)", function()
  it("delivers no more than it drew: a closed ledger across the two networks", function()
    -- THE conservation test for a transfer device. The source network's ONLY energy
    -- is one fixed store, so its drop IS everything the diode took; the sink
    -- network's only store is empty, so its gain IS everything the diode delivered.
    -- A player wiring this up sees the far side rise only as fast as the near side
    -- falls. delivered <= drawn, and never faster than the rated 10 MW.
    local s = H.cindra_surface()
    H.power_reset(); diode.reset()
    sun_off(s)
    local _, d = wired_diode(s)
    local src = H.measure_sink(s, { -30, 6 })  -- fixed 5 GJ store, no producer
    src.energy = src.electric_buffer_size
    local dst = H.measure_sink(s, { 30, 6 })   -- unlimited-appetite far side
    dst.energy = 0

    async(1800)
    after_ticks(240, function()
      -- Let the networks form and the controller ramp, then measure a clean window.
      -- The device's own output buffer is energy IN TRANSIT (already drawn, not yet
      -- delivered), so a closed ledger has to sample it alongside the two stores.
      local src0, dst0, transit0 = src.energy, dst.energy, d.output.energy
      local WINDOW = 600
      after_ticks(WINDOW, function()
        assert.is_not.equal(d.input.electric_network_id, d.output.electric_network_id,
          "setup must produce two isolated networks")
        local drawn = src0 - src.energy
        local delivered = dst.energy - dst0
        local from_transit = transit0 - d.output.energy -- transit drained into the sink
        -- One sweep's worth of rated transfer: the most the device can have in
        -- flight between the two stores at a window boundary. Everything beyond
        -- drawn + transit + that is energy nobody supplied.
        local slack = DC.RATE_W / 60 * DC.TICK_INTERVAL
        -- Non-vacuous: energy really is crossing during the measured window.
        assert.is_true(delivered > 0, "the diode must actually deliver power: " .. delivered)
        -- CONSERVATION: the far side cannot gain more than the near side lost
        -- (plus whatever was already in transit when the window opened).
        assert.is_true(delivered <= drawn + from_transit + slack,
          "the diode must never deliver more than it drew: delivered=" .. delivered
            .. " drawn=" .. drawn .. " transit=" .. from_transit)
        -- The overshoot really is a boundary artifact, not a trickle of minting:
        -- it stays within that single in-flight sweep, not a fraction of the flow.
        assert.is_true(delivered - drawn <= slack,
          "delivery must track the draw within one in-flight sweep: delivered=" .. delivered
            .. " drawn=" .. drawn)
        -- ...and the crossing respects the rated 10 MW, so it cannot amplify either.
        local cap_j = DC.RATE_W / 60 * WINDOW
        assert.is_true(delivered <= cap_j * 1.05,
          "the diode must not exceed its rated transfer: delivered=" .. delivered .. " cap=" .. cap_j)
        done()
      end)
    end)
  end)

  it("a source network with no energy delivers nothing downstream", function()
    -- "Source network empty -> downstream receives 0." The source side is wired and
    -- live but has nothing to give; the far side is hungry. A diode that manufactures
    -- power from a dead source is exactly the ci-76if bug.
    local s = H.cindra_surface()
    H.power_reset(); diode.reset()
    sun_off(s)
    local _, d = wired_diode(s)
    local src = place(s, "accumulator", { -30, 6 })
    src.energy = 0 -- the source network is wired, live, and utterly empty
    local dst = place(s, "accumulator", { 30, 6 })
    dst.energy = 0

    async(900)
    after_ticks(600, function()
      assert.is_not.equal(d.input.electric_network_id, d.output.electric_network_id,
        "setup must produce two isolated networks")
      assert.are.equal(0, dst.energy, "an empty source must deliver nothing: " .. dst.energy)
      assert.are.equal(0, d.output.energy, "the output buffer must stay empty: " .. d.output.energy)
      done()
    end)
  end)

  it("an unwired source side delivers nothing downstream", function()
    -- "Source disconnected -> downstream receives 0." Same rule, harsher: there is
    -- no source network at all. Unplug the near side and the far side goes dark.
    local s = H.cindra_surface()
    H.power_reset(); diode.reset()
    sun_off(s)
    local _, d = wired_diode(s, false) -- only the SINK side is wired
    local dst = place(s, "accumulator", { 30, 6 })
    dst.energy = 0

    async(900)
    after_ticks(600, function()
      assert.are.equal(0, dst.energy, "a disconnected source must deliver nothing: " .. dst.energy)
      assert.are.equal(0, d.output.energy, "the output buffer must stay empty: " .. d.output.energy)
      done()
    end)
  end)

  it("the diode's hidden buffers are one-way even with the script asleep", function()
    -- Belt-and-braces: the buffers' own flow limits carry the directionality, so
    -- even an UNREGISTERED pair (no sweep touching them) cannot leak. The input
    -- buffer sits full on a grid that wants power and gives none back; the output
    -- buffer sits empty on a grid awash with power and soaks none up.
    local s = H.cindra_surface()
    H.power_reset(); diode.reset()
    sun_off(s)
    H.grid(s, 0, 12)

    local input = place(s, DC.INPUT, { -6, 0 })
    input.energy = input.electric_buffer_size -- a full load-only buffer
    local output = place(s, DC.OUTPUT, { -6, 6 })
    output.energy = 0                          -- an empty source-only buffer
    local acc = place(s, "accumulator", { 6, 0 })
    acc.energy = 0
    local store = H.measure_sink(s, { 6, 6 })  -- plenty of power on this grid
    store.energy = 200e6

    async(900)
    after_ticks(300, function()
      assert.are.equal(0, acc.energy,
        "the input buffer must never feed its network (output_flow_limit 0): " .. acc.energy)
      assert.are.equal(0, output.energy,
        "the output buffer must never draw from its network (input_flow_limit 0): " .. output.energy)
      assert.is_true(input.energy > 0, "sanity: the full input buffer is still there")
      done()
    end)
  end)
end)
