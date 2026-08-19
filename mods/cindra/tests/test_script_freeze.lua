-- SCRIPT FREEZE proof (ci-de55): the buildings the ENGINE refuses to freeze
-- freeze anyway, they stop working for real, and the player can see it.
--
-- WHY THIS SUITE EXISTS. ci-qha1 measured that Factorio honours `heating_energy`
-- on only some prototype types, and that an accumulator, a solar panel and an
-- electric-energy-interface are on none of them: the field is accepted at the data
-- stage and silently discarded, `is_freezable` stays false, and the entity never
-- freezes. So Cindra's capacitor, molten-salt battery, sunward solar bands and
-- dissipator kept working in the deep dark -- the exact immunity the human ruling
-- ("It should not be immune, I don't think anything should be") rejected. ci-de55
-- makes Cindra freeze them itself (scripts/script-freeze.lua).
--
-- WHAT A TEST HERE IS ALLOWED TO ASSERT. Only what a PLAYER OBSERVES. "The sweep
-- swapped the prototype" is an implementation detail and is never the point of an
-- assertion here; what the player sees is that a battery bank on the nightside
-- stops giving them power, that a frozen panel makes none however bright the sky,
-- that a frozen dissipator stops drawing, that every joule is still there when the
-- heat comes back -- and that something told them. Those are the assertions.
--
-- THE HARDEST ONE IS AGREEMENT. A scripted freeze reimplements a rule the engine
-- already owns, so the failure mode nobody would notice is DISAGREEMENT: a
-- machine thawed and the battery beside it frozen, at the same distance from the
-- same heat source. That is a bug report, not a mechanic. So the boundary tests
-- below never assert a distance we chose -- they put a natively-freezable machine
-- through the identical geometry and require the engine's own verdict and ours to
-- match, at the reach boundary and one tile past it, for both a tiny heat source
-- and the 101-tile worldgen emitter.
--
-- RELIABILITY (the ci-b5i / ci-qha1 lesson): a hot heat source warms the ground
-- TILES in reach and they DO NOT COOL on any test timescale, so measurements that
-- share ground contaminate each other -- and the worldgen lava-heat emitter's
-- reach is a 101-tile Chebyshev SQUARE, far wider than it looks. Every row here
-- takes its own FRESH, never-heated ground from a monotonic cursor, and the rows
-- that use the big emitter are spaced past its full reach.

local H = require("tests.helpers")
local C = require("scripts.flare-config")
local audit = require("scripts.frost-audit")
local flare = require("scripts.flare")
local freeze = require("scripts.freeze")
local sf = require("scripts.script-freeze")

-- Fresh-ground cursor, parked far from tests/test_freeze.lua (100000+) and
-- tests/test_frost.lua (300000+). Never rewound.
local cursor = 900000
local function ground(gap)
  local y = cursor
  cursor = cursor + (gap or 600)
  return y
end

local function slab(s, x0, x1, y0, y1)
  local cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
  local rad = math.ceil(math.max(x1 - x0, y1 - y0) / 2 / 32) + 2
  s.request_to_generate_chunks({ cx, cy }, rad)
  s.force_generate_chunk_requests()
  local tiles = {}
  for x = math.floor(x0), math.ceil(x1) do
    for y = math.floor(y0), math.ceil(y1) do
      tiles[#tiles + 1] = { name = "refined-concrete", position = { x, y } }
    end
  end
  s.set_tiles(tiles)
end

-- Everything this suite builds, so teardown() can take it all back down.
--
-- MANDATORY, not tidiness (the ci-qha1 lesson, learned again here): sibling
-- suites count entities SURFACE-WIDE. A rig that places solar bands, capacitors
-- and dissipators and walks away silently breaks tests/test_panel_overload and
-- tests/test_panel_damage_runtime, which then fail describing a bug that does not
-- exist. A measurement rig must not become part of the world it measures.
local built = {}
local hot_pipes = {}

local function place(s, name, pos)
  local e = s.create_entity({ name = name, position = pos, force = "player" })
  assert(e, "failed to place " .. name .. " at " .. pos[1] .. "," .. pos[2])
  built[#built + 1] = e
  return e
end

-- Worldgen furniture that was here before this suite and must stay: the ambient
-- lava-heat emitters, the ribbon's rocks and ore, and the player.
local function is_scenery(e)
  return e.type == "character" or e.type == "resource" or e.type == "simple-entity"
    or e.name == "cindra-lava-heat"
end

-- Destroy everything this suite built. Tracked references are not enough on their
-- own: a freeze SWAPS the entity a test placed for a frozen twin, so the original
-- is already dead and the twin was never in `built`. The suite's whole working
-- band is therefore swept as well -- it is ours alone (every row comes from the
-- monotonic cursor, far past every other suite's ground).
local function teardown(s)
  for _, e in pairs(built) do
    if e and e.valid then e.destroy() end
  end
  built, hot_pipes = {}, {}
  if not (s and s.valid) then return end
  for _, e in pairs(s.find_entities_filtered({
    area = { { -600, 890000 }, { 600, cursor + 3000 } },
  })) do
    if e.valid and not is_scenery(e) then e.destroy() end
  end
end

-- A TIGHT heat source: a vanilla heat pipe held hot. heating_radius 1, so it
-- thaws only what touches it -- which is what makes a boundary measurable on a
-- few tiles of ground instead of the emitter's 200-tile square.
--
-- Every one is remembered so reheat() can hold it hot: a heat pipe is NOT
-- self-generating, and warming the things in its radius DRAINS it -- left alone
-- across a tick window it slides all the way back to its 15 C rest temperature
-- and quietly stops being a heat source. (That is the same reason the shipped
-- worldgen emitters need the driver's own reheat sweep.) A test that let that
-- happen would read as "the thaw is broken".
local function hot_pipe(s, pos)
  local p = place(s, "heat-pipe", pos)
  p.temperature = 1000
  hot_pipes[#hot_pipes + 1] = p
  return p
end

local function reheat()
  for _, p in pairs(hot_pipes) do
    if p.valid then p.temperature = 1000 end
  end
end

-- A hot pipe placed so its tile box TOUCHES `e`'s: the tightest possible thaw.
-- Derived from the entity's own footprint rather than a hand-picked offset,
-- because the class spans 2x2 accumulators and 3x3 panels and a fixed offset
-- lands inside one and outside the other -- which reads as "the thaw is broken"
-- when it is really "the test missed".
local function heat_beside(s, e)
  local box = e.selection_box
  local x = math.floor(box.left_top.x) - 0.5
  local y = math.floor((box.left_top.y + box.right_bottom.y) / 2) + 0.5
  return hot_pipe(s, { x, y })
end

-- Entities of `name` whose footprint sits in the `r`-tile box around `pos`.
-- Position lookups by exact coordinate are unreliable here: the engine SNAPS a
-- placement to the grid its footprint demands (tile centres for a 3x3, tile
-- corners for a 2x2), so the same requested x lands half a tile apart for two
-- members of the same class.
local function at(s, name, pos, r)
  r = r or 3
  return s.find_entities_filtered({
    name = name,
    area = { { pos[1] - r, pos[2] - r }, { pos[1] + r, pos[2] + r } },
  })[1]
end

-- "Is the building standing here frozen?" -- asked WITHOUT naming it. A solar
-- panel's band variant is chosen by its sunward position (scripts/panels.lua), so
-- the b05 a test places may legitimately be a b25 by the time it freezes; a
-- lookup that spelled the name would then report "not frozen" for a building that
-- is plainly under ice. What the player sees is the ice, not the prototype.
local function frozen_at(s, pos, r)
  r = r or 3
  for _, e in pairs(s.find_entities_filtered({
    area = { { pos[1] - r, pos[2] - r }, { pos[1] + r, pos[2] + r } },
  })) do
    if e.valid and audit.is_frozen_name(e.name) then return e end
  end
  return nil
end

-- A self-contained powered island: substations blanketing [y0, y1] at `x`.
-- Poles are one of the types the engine refuses to freeze AND that Cindra
-- deliberately does not script-freeze (an inert conductor has nothing to stop),
-- so the grid itself survives the cold and the measurement is about the buildings
-- on it. tests/test_frost.lua measures that exemption.
local function island(s, x, y0, y1)
  local y = y0
  while y <= y1 do
    place(s, "substation", { x, y })
    y = y + 12
  end
  place(s, "substation", { x, y1 })
end

-- The whole script-frozen class, live from the registry.
local function class()
  return sf.frozen_class()
end

describe("script freeze - the class (ci-de55)", function()
  it("covers every Cindra building the engine refuses to freeze", function()
    -- The coverage guard, checked against the ENGINE's own registry rather than
    -- against data.raw: every Cindra entity of a type Factorio will not freeze is
    -- either script-frozen here or excused, by type or by name, with a written
    -- reason in scripts/frost-audit.lua. There is no third answer, which is what
    -- stops a new accumulator from inheriting immunity the way the glass furnace
    -- once did (ci-6qyk).
    local unhandled = {}
    for name, proto in pairs(prototypes.entity) do
      if name:sub(1, 7) == "cindra-" and audit.UNFREEZABLE_TYPES[proto.type] then
        local handled = audit.SCRIPT_FROZEN_TYPES[proto.type]
          or audit.SCRIPT_FREEZE_EXEMPT_TYPES[proto.type]
        if not handled then unhandled[#unhandled + 1] = name .. " (" .. proto.type .. ")" end
      end
    end
    table.sort(unhandled)
    assert.are.equal("", table.concat(unhandled, ", "),
      "Cindra entity/entities the engine will not freeze and Cindra does not"
      .. " script-freeze either -- immune from both directions at once. Sort each"
      .. " type into SCRIPT_FROZEN_TYPES or SCRIPT_FREEZE_EXEMPT_TYPES in"
      .. " scripts/frost-audit.lua")
  end)

  it("finds the buildings it must (the guard is not vacuous) and gives each a twin", function()
    -- A discovery that silently went empty would make every assertion in this file
    -- pass unconditionally. Pin the set the ci-de55 bead names by hand.
    local found = {}
    for _, name in ipairs(class()) do found[name] = true end
    local expected = { C.CAPACITOR, C.BATTERY, C.DISSIPATOR,
      "cindra-solar-band-b05", "cindra-solar-band-b25", "cindra-solar-band-b40",
      "cindra-solar-band-b60", "cindra-solar-band-b80" }
    for _, name in ipairs(expected) do
      assert.is_true(found[name] == true,
        name .. " must be script-frozen (ci-de55 names it) but the class does not"
        .. " contain it: " .. table.concat(class(), ", "))
      -- ...and each really is a building the ENGINE refuses, so the script freeze
      -- is filling a hole rather than duplicating native behaviour.
      local e = prototypes.entity[name]
      assert.is_not_nil(audit.UNFREEZABLE_TYPES[e.type],
        name .. " is script-frozen but its type '" .. e.type .. "' is not one the"
        .. " engine refuses -- it should freeze natively via heating_energy instead")
      assert.is_not_nil(prototypes.entity[audit.frozen_name(name)],
        name .. " has no frozen twin prototype")
    end
    -- The invisible helpers and the test rig stay out of it.
    assert.is_nil(found[C.MEASURE_SINK], "the test-only measurement sink must not freeze")
    assert.is_nil(found["cindra-power-diode-input"], "the diode's hidden buffers must not freeze")

    -- ...and the exemption list must not rot the other way either: an entry
    -- naming an entity Cindra no longer ships is dead weight that reads as a live
    -- decision (the same staleness check tests/test_frost.lua runs on FREEZE_EXEMPT).
    for name in pairs(audit.SCRIPT_FREEZE_EXEMPT) do
      assert.is_not_nil(prototypes.entity[name],
        "SCRIPT_FREEZE_EXEMPT excuses '" .. name .. "' but no such entity exists any"
        .. " more -- drop the stale exemption")
    end
  end)

  it("a frozen building is never something the player ends up HOLDING", function()
    -- The freeze is a STATE of a building, not a different building. Mining one
    -- must hand back the ordinary item, and a blueprint or pipette must resolve to
    -- it too -- otherwise a player who deconstructs a frozen battery bank gets an
    -- inventory full of items that build nothing.
    for _, name in ipairs(class()) do
      local twin = prototypes.entity[audit.frozen_name(name)]
      local base = prototypes.entity[name]
      if base.mineable_properties and base.mineable_properties.products then
        local want = base.mineable_properties.products[1].name
        local got = twin.mineable_properties and twin.mineable_properties.products
          and twin.mineable_properties.products[1]
        assert.is_not_nil(got, audit.frozen_name(name) .. " must be minable")
        assert.are.equal(want, got.name,
          "mining a frozen " .. name .. " must return the ordinary item, got " .. got.name)
      end
      local place_with = twin.items_to_place_this
      assert.is_not_nil(place_with,
        audit.frozen_name(name) .. " needs placeable_by, or a blueprint over a frozen"
        .. " area drops the building entirely")
      assert.are.equal(base.items_to_place_this[1].name, place_with[1].name,
        "a blueprint/pipette of a frozen " .. name .. " must resolve to the ordinary item")
    end
  end)

  it("the alert icon the player is shown really exists", function()
    -- A SignalID naming an item that does not exist raises at the point of the
    -- alert -- i.e. only ever in the cold, on someone's real save.
    assert.is_not_nil(prototypes.item[sf.ALERT_ICON.name],
      "scripts/script-freeze.lua raises its custom alert with the '"
      .. sf.ALERT_ICON.name .. "' item icon, which is not loaded")
  end)
end)

describe("script freeze - it freezes in the dark and thaws by heat (ci-de55)", function()
  it("EVERY script-frozen building freezes out in the cold and stays working beside heat", function()
    local s = H.cindra_surface()
    storage.cindra_freeze_autoplace = false
    storage.cindra_driver_enabled = false -- the sweep is driven explicitly below

    local names = class()
    assert.is_true(#names >= 8, "the script-frozen class must not shrink: " .. #names)

    local SPACING = 12
    local cold_y = ground()
    slab(s, -8, SPACING * (#names + 1), cold_y - 8, cold_y + 8)
    local warm_y = ground()
    slab(s, -8, SPACING * (#names + 1), warm_y - 8, warm_y + 8)

    for i, name in ipairs(names) do
      local x = SPACING * i
      place(s, name, { x, cold_y })
      -- WARM ROW: its own tight heat source touching each building, so "frozen"
      -- can never be simply always-on.
      heat_beside(s, place(s, name, { x, warm_y }))
    end

    reheat()

    local result = sf.sweep(s)
    assert.are.equal(#names, result.froze,
      "exactly the cold row must have frozen: " .. result.froze .. "/" .. #names)

    for i, name in ipairs(names) do
      local x = SPACING * i
      assert.is_not_nil(at(s, audit.frozen_name(name), { x, cold_y }),
        name .. " must FREEZE on never-heated ground with no heat source in reach -- a"
        .. " Cindra building that keeps working in the dark is exempt from the planet's"
        .. " core mechanic (ci-de55)")
      assert.is_not_nil(at(s, name, { x, warm_y }),
        name .. " must keep working beside a hot heat source (the freeze is not always-on)")
    end

    -- THAW IS SYMMETRIC. Drop a heat source beside each frozen building and the
    -- next sweep gives the player their building back -- same place, same name.
    for i, name in ipairs(names) do
      heat_beside(s, at(s, audit.frozen_name(name), { SPACING * i, cold_y }))
    end
    reheat()
    local back = sf.sweep(s)
    assert.are.equal(#names, back.thawed,
      "every frozen building must thaw when heat returns: " .. back.thawed .. "/" .. #names)
    for i, name in ipairs(names) do
      assert.is_not_nil(at(s, name, { SPACING * i, cold_y }),
        name .. " must come back as itself when heat returns")
    end
    teardown(s)
  end)

  it("a COLD heat source is no heat source", function()
    -- The freeze must key on heat actually being emitted, not on a heat-shaped
    -- building standing nearby. A heat pipe resting at its default temperature
    -- warms nothing -- and the engine agrees, which is the assertion.
    local s = H.cindra_surface()
    storage.cindra_freeze_autoplace = false
    storage.cindra_driver_enabled = false
    local y = ground()
    slab(s, -8, 40, y - 8, y + 8)

    local pipe = place(s, "heat-pipe", { 0, y }) -- left at rest, never heated
    local machine = place(s, "assembling-machine-1", { 3, y })
    local battery = place(s, C.BATTERY, { 8, y })
    assert.are.equal(15, pipe.temperature, "the pipe must start at its rest temperature")

    reheat()

    sf.sweep(s)
    assert.is_not_nil(s.find_entity(audit.frozen_name(C.BATTERY), { 8, y }),
      "a battery beside a COLD heat pipe must freeze -- a cold pipe emits nothing")

    async(6000)
    after_ticks(5000, function()
      assert.is_true(machine.frozen,
        "the engine must agree: a machine beside the same cold pipe freezes too")
      teardown(s)
      done()
    end)
  end)
end)

describe("script freeze - it agrees with the engine's own boundary (ci-de55)", function()
  -- The scripted freeze reimplements a rule the engine owns for other entity
  -- types. If the two disagree by a tile, the player sees a thawed machine and a
  -- frozen battery side by side and reads it as a bug. So the boundary is never
  -- asserted against a number we picked: an assembling machine (natively
  -- freezable, SAME 3x3 footprint as a solar band) walks the identical geometry
  -- and the engine's verdict is the oracle.
  local BAND = "cindra-solar-band-b05"

  it("matches the engine tile for tile around a tight heat source", function()
    -- ONE PROBE PER ROW, and both probes are 3x3, so the machine and the band each
    -- meet a heat source through geometry that is identical down to the tile. Two
    -- details are load-bearing:
    --   * half-tile coordinates: a 3x3 footprint must sit on a tile CENTRE, and
    --     asking for an integer leaves the engine to snap it either way -- which
    --     makes the very boundary this test measures ambiguous by a tile.
    --   * one probe per row: 3x3 probes at consecutive offsets OVERLAP, and
    --     create_entity does not refuse an overlap, so a row of them is a pile
    --     rather than a ruler.
    local s = H.cindra_surface()
    storage.cindra_freeze_autoplace = false
    storage.cindra_driver_enabled = false
    local OFFSETS = { 2, 3, 4 } -- the pipe's single tile reaches one tile out
    local ROW = 10 -- far past a radius-1 source, so rows cannot warm each other

    local base_y = ground(400)
    slab(s, -8, 20, base_y - 8, base_y + ROW * 2 * #OFFSETS + 8)

    local rows, r = {}, 0
    for _, dx in ipairs(OFFSETS) do
      local my = base_y + ROW * r + 0.5; r = r + 1
      hot_pipe(s, { 0.5, my })
      local by = base_y + ROW * r + 0.5; r = r + 1
      hot_pipe(s, { 0.5, by })
      rows[dx] = {
        machine = place(s, "assembling-machine-1", { dx + 0.5, my }),
        band_pos = { dx + 0.5, by },
      }
      place(s, BAND, rows[dx].band_pos)
    end

    async(6000)
    after_ticks(5000, function()
      reheat()
      sf.sweep(s)
      local disagreements = {}
      for _, dx in ipairs(OFFSETS) do
        local engine_says = rows[dx].machine.frozen
        local we_say = frozen_at(s, rows[dx].band_pos, 1) ~= nil
        if engine_says ~= we_say then
          disagreements[#disagreements + 1] = string.format(
            "dx=%d engine=%s script=%s", dx, tostring(engine_says), tostring(we_say))
        end
      end
      assert.are.equal("", table.concat(disagreements, "; "),
        "the scripted freeze must agree with the engine's own boundary at every"
        .. " distance -- a thawed machine beside a frozen battery is a bug report."
        .. " Fix the tile geometry in scripts/freeze.lua (heated_region/tiles_overlap)")
      -- Non-vacuous: the run must actually straddle the boundary, or the loop
      -- above would agree by agreeing about nothing.
      assert.is_false(rows[2].machine.frozen, "dx=2 must be thawed (it touches the pipe)")
      assert.is_true(rows[4].machine.frozen, "dx=4 must be frozen (clear of the pipe)")
      teardown(s)
      done()
    end)
  end)

  it("matches the engine at the worldgen emitter's own 101-tile reach", function()
    -- The case that actually decides play: the ribbon's lava-heat emitters. Their
    -- reach is pinned at scripts/freeze.FREEZE_REACH and measured against the real
    -- emitter in tests/test_freeze.lua; here the SCRIPT has to land on the same
    -- tile. Rows are spaced past the emitter's full square so neither warms the
    -- other.
    local s = H.cindra_surface()
    storage.cindra_freeze_autoplace = false
    storage.cindra_driver_enabled = false
    local R = freeze.FREEZE_REACH
    -- The R and R+1 probes are 3x3 and one tile apart, so they would OVERLAP on a
    -- shared row. They are separated ALONG the ribbon instead: the emitter's reach
    -- is a square, so within its y-span only the x offset decides, and a 40-tile
    -- vertical gap changes nothing about the boundary being measured.
    local DY = 40

    local machine_y = ground(3 * R)
    slab(s, -8, R + 12, machine_y - 8, machine_y + DY + 8)
    place(s, freeze.EMITTER_NAME, { 0.5, machine_y + 0.5 }).temperature =
      freeze.EMITTER_TEMPERATURE
    local at_reach = place(s, "assembling-machine-1", { R + 0.5, machine_y + 0.5 })
    local past_reach = place(s, "assembling-machine-1", { R + 1.5, machine_y + DY + 0.5 })

    local band_y = ground(3 * R)
    slab(s, -8, R + 12, band_y - 8, band_y + DY + 8)
    place(s, freeze.EMITTER_NAME, { 0.5, band_y + 0.5 }).temperature =
      freeze.EMITTER_TEMPERATURE
    local reach_pos = { R + 0.5, band_y + 0.5 }
    local past_pos = { R + 1.5, band_y + DY + 0.5 }
    place(s, BAND, reach_pos)
    place(s, BAND, past_pos)

    async(6000)
    after_ticks(5000, function()
      reheat()
      sf.sweep(s)
      assert.is_false(at_reach.frozen, "engine: a machine at reach R is thawed")
      assert.is_true(past_reach.frozen, "engine: a machine at R+1 is frozen")
      assert.is_nil(frozen_at(s, reach_pos, 1),
        "a solar band at the emitter's reach R must stay working, exactly as the"
        .. " machine at R does")
      assert.is_not_nil(frozen_at(s, past_pos, 1),
        "a solar band one tile past the reach must freeze, exactly as the machine"
        .. " at R+1 does")
      teardown(s)
      done()
    end)
  end)
end)

describe("script freeze - a frozen building really stops working (ci-de55)", function()
  it("a frozen battery bank gives the grid nothing, and thawing gives it all back", function()
    -- THE gameplay bite: the player's night buffer is only theirs while it is warm.
    -- The bank is the grid's ONLY energy and the electric heater is its only
    -- consumer, so what a player sees is simply whether the heater runs. Frozen
    -- bank: the heater stays stone cold and the bank never loses a joule. Thawed:
    -- it heats, on the very same stored charge.
    --
    -- The witness is a HEATER, not another accumulator, because an accumulator
    -- cannot charge from an accumulator (they share the same tertiary priority) --
    -- a meter that reads zero for that reason would read zero whether the freeze
    -- worked or not.
    local s = H.cindra_surface()
    storage.cindra_freeze_autoplace = false
    storage.cindra_driver_enabled = false
    H.power_reset()
    local y = ground()
    slab(s, -30, 40, y - 20, y + 20)
    island(s, 0, y, y + 12)
    place(s, "substation", { -12, y + 6 }) -- carries the grid out to the heater

    local cap = place(s, C.CAPACITOR, { -6, y })
    local bat = place(s, C.BATTERY, { -6, y + 6 })
    cap.energy = cap.electric_buffer_size
    bat.energy = bat.electric_buffer_size
    local stored = cap.energy + bat.energy
    -- Far enough from the bank that the heater's OWN heat (it is a reactor, and a
    -- hot one thaws its neighbours) can never be what thaws them.
    local heater = place(s, "cindra-electric-heater", { -18.5, y + 6.5 })
    assert.are.equal(15, heater.temperature, "the heater must start cold")

    reheat()

    sf.sweep(s)
    async(2400)
    after_ticks(600, function()
      assert.is_true(heater.temperature <= 15,
        "a frozen battery bank must power NOTHING: the heater warmed to "
        .. heater.temperature .. " C off a bank that is supposed to be ice")

      -- Every joule is still in the bank: frozen, not confiscated.
      local fcap = at(s, audit.frozen_name(C.CAPACITOR), { -6, y })
      local fbat = at(s, audit.frozen_name(C.BATTERY), { -6, y + 6 })
      assert.is_not_nil(fcap); assert.is_not_nil(fbat)
      assert.are.equal(stored, fcap.energy + fbat.energy,
        "a frozen store keeps every joule it held (frozen, not drained)")

      -- THAW: heat both, sweep, and the same energy is available again.
      heat_beside(s, fcap); heat_beside(s, fbat)
      reheat()
      sf.sweep(s)
      local warm_cap = at(s, C.CAPACITOR, { -6, y })
      local warm_bat = at(s, C.BATTERY, { -6, y + 6 })
      assert.is_not_nil(warm_cap, "the capacitor must come back when heat returns")
      assert.is_not_nil(warm_bat, "the battery must come back when heat returns")
      assert.are.equal(stored, warm_cap.energy + warm_bat.energy,
        "thawing must hand back exactly what was frozen, no more and no less")

      after_ticks(600, function()
        assert.is_true(heater.temperature > 15,
          "a THAWED battery bank must power the grid again (otherwise the freeze is"
          .. " a one-way trip and the assertion above proves nothing): heater at "
          .. heater.temperature .. " C")
        assert.is_true(warm_cap.energy + warm_bat.energy < stored,
          "...and the power must come out of the BANK, which is the thing that"
          .. " thawed: it still holds " .. (warm_cap.energy + warm_bat.energy))
        teardown(s)
        done()
      end)
    end)
  end)

  it("a frozen solar band makes exactly nothing, at the brightest moment the planet has", function()
    -- Solar is Cindra's only legitimate generation. An iced-over panel is not a
    -- weaker panel: it is not a panel. Measured at the flare plateau, the sunniest
    -- the sky ever gets, so this is the harshest form of "exactly nothing".
    local s = H.cindra_surface()
    storage.cindra_freeze_autoplace = false
    storage.cindra_driver_enabled = false
    H.power_reset()
    local WS = 600
    flare.set_schedule(WS)

    local y = ground()
    slab(s, -20, 40, y - 20, y + 20)
    island(s, 0, y, y + 12)
    local meter = H.measure_sink(s, { -6, y })
    meter.energy = 0

    local bands = { "cindra-solar-band-b80", "cindra-solar-band-b40", "cindra-solar-band-b05" }
    local yy = y
    for _, band in ipairs(bands) do
      place(s, band, { 6.5, yy + 0.5 })
      yy = yy + 4
    end
    reheat()
    sf.sweep(s)
    flare.apply(s, WS + C.WARNING_TICKS + C.RAMP_TICKS + 10) -- blazing sky

    async(1800)
    after_ticks(600, function()
      assert.are.equal(0, meter.energy,
        "frozen panels must deliver exactly zero even at the flare plateau: "
        .. meter.energy .. " J reached the grid")
      -- Non-vacuous: an unfrozen panel on this very grid at this very moment does
      -- deliver, so the zero above is the freeze and not a dead rig.
      heat_beside(s, at(s, audit.frozen_name(bands[1]), { 6.5, y + 0.5 }))
      reheat()
      sf.sweep(s)
      after_ticks(600, function()
        assert.is_true(meter.energy > 0,
          "a thawed panel on the same grid, same sky, must deliver power -- otherwise"
          .. " the zero above measures nothing: " .. meter.energy)
        teardown(s)
        done()
      end)
    end)
  end)

  it("a frozen dissipator draws nothing: it stops being disposal capacity", function()
    -- The dissipator is the panel-damage fuse: its rated draw is counted before any
    -- panel can burn. Frozen, it must stop counting -- and the way a player sees
    -- that is that it stops taking power off their grid.
    local s = H.cindra_surface()
    storage.cindra_freeze_autoplace = false
    storage.cindra_driver_enabled = false
    H.power_reset()
    local y = ground()
    slab(s, -20, 40, y - 20, y + 20)
    island(s, 0, y, y + 12)

    local store = H.measure_sink(s, { -6, y })
    store.energy = 200e6
    place(s, C.DISSIPATOR, { 6, y })
    reheat()
    sf.sweep(s)
    local before = store.energy

    async(1800)
    after_ticks(600, function()
      assert.are.equal(before, store.energy,
        "a frozen dissipator must draw NOTHING from the grid: the store fell by "
        .. (before - store.energy) .. " J")
      -- Non-vacuous: thaw it and the same store drains hard (20 MW).
      heat_beside(s, at(s, audit.frozen_name(C.DISSIPATOR), { 6, y }))
      reheat()
      sf.sweep(s)
      local thawed_from = store.energy
      after_ticks(600, function()
        assert.is_true(store.energy < thawed_from,
          "a thawed dissipator must draw again, or the zero above measures nothing")
        teardown(s)
        done()
      end)
    end)
  end)
end)

describe("script freeze - freezing is not a demolition (ci-de55)", function()
  it("a wired battery keeps its wires across the freeze and the thaw", function()
    -- An accumulator publishes its charge to the circuit network, so a player may
    -- well have one wired into their control logic. The freeze REPLACES the
    -- entity, so without care every wire on it would be quietly cut -- and the
    -- player would find their circuit network rebuilt itself wrong after a cold
    -- night, which is a far worse bug than the immunity being fixed.
    local s = H.cindra_surface()
    storage.cindra_freeze_autoplace = false
    storage.cindra_driver_enabled = false
    local y = ground()
    slab(s, -20, 40, y - 20, y + 20)

    local bat = place(s, C.BATTERY, { 0, y })
    local pole = place(s, "medium-electric-pole", { 4.5, y + 0.5 })
    local RED = defines.wire_connector_id.circuit_red
    bat.get_wire_connector(RED, true).connect_to(
      pole.get_wire_connector(RED, true), false, defines.wire_origin.player)
    assert.are.equal(1, #bat.get_wire_connector(RED, true).connections,
      "the rig must actually be wired, or this measures nothing")

    reheat()
    sf.sweep(s)
    local frozen = at(s, audit.frozen_name(C.BATTERY), { 0, y })
    assert.is_not_nil(frozen, "the battery must freeze")
    assert.are.equal(1, #frozen.get_wire_connector(RED, true).connections,
      "a frozen battery must still be wired to what the player wired it to")

    heat_beside(s, frozen)
    reheat()
    sf.sweep(s)
    local warm = at(s, C.BATTERY, { 0, y })
    assert.is_not_nil(warm, "the battery must thaw")
    assert.are.equal(1, #warm.get_wire_connector(RED, true).connections,
      "and the wire must still be there after it thaws")
    assert.are.equal(1, #pole.get_wire_connector(RED, true).connections,
      "seen from the OTHER end too: the pole is still wired to one thing, not to a"
      .. " pile of dead stubs left by each freeze")
    teardown(s)
  end)
end)

describe("script freeze - the player is told (ci-de55)", function()
  it("raises a map alert for a frozen building, and does not multiply it", function()
    -- The mayor's first condition on ci-de55: the freeze must not be silent. The
    -- frost art says WHAT on screen; the alert says WHERE for a bank the player is
    -- not looking at. The second half of the assertion matters as much: an alert
    -- re-raised every sweep must not stack into a wall of duplicates.
    local s = H.cindra_surface()
    storage.cindra_freeze_autoplace = false
    storage.cindra_driver_enabled = false
    local player = game.players[1]
    assert.is_not_nil(player, "the alert rig needs a player to read alerts from")
    local y = ground()
    slab(s, -20, 40, y - 20, y + 20)

    -- Alerts are reported per surface and per type; count only the custom ones
    -- raised on this surface.
    local function frost_alerts()
      local n = 0
      for _, by_type in pairs(player.get_alerts({ surface = s, type = defines.alert_type.custom })) do
        for _, list in pairs(by_type) do n = n + #list end
      end
      return n
    end

    local before = frost_alerts()
    place(s, C.BATTERY, { 0, y })
    place(s, C.CAPACITOR, { 6, y })
    reheat()
    sf.sweep(s)
    local after_one = frost_alerts()
    assert.are.equal(before + 2, after_one,
      "each newly frozen building must raise its own alert (was " .. before
      .. ", now " .. after_one .. ")")

    reheat()

    sf.sweep(s); sf.sweep(s)
    assert.are.equal(after_one, frost_alerts(),
      "re-sweeping must not stack duplicate alerts for the same frozen buildings")

    -- Thawing clears them: the warning is about NOW, not about history.
    heat_beside(s, at(s, audit.frozen_name(C.BATTERY), { 0, y }))
    heat_beside(s, at(s, audit.frozen_name(C.CAPACITOR), { 6, y }))
    reheat()
    sf.sweep(s)
    assert.are.equal(before, frost_alerts(),
      "thawing a building must clear its frozen alert")
    teardown(s)
  end)
end)

describe("script freeze - it never touches another planet (ci-de55)", function()
  it("a capacitor off Cindra never freezes, however dark and heatless", function()
    -- The cross-cutting invariant. The sweep is gated on surface.name == "cindra";
    -- this measures the gate from the far side, on a surface with no heat source
    -- anywhere -- the condition that freezes everything on Cindra.
    local s = H.offworld_surface()
    local cap = s.create_entity({ name = C.CAPACITOR, position = { 0, 0 }, force = "player" })
    assert.is_not_nil(cap)
    reheat()
    local result = sf.sweep(s)
    assert.are.equal(0, result.froze, "the sweep must do nothing off Cindra")
    assert.is_true(cap.valid and cap.name == C.CAPACITOR,
      "a capacitor on another world must stay exactly what it is")
    sf.sweep_all() -- the real periodic entry point, over every surface
    assert.is_true(cap.valid and cap.name == C.CAPACITOR,
      "the periodic sweep over all surfaces must still leave it alone")
    cap.destroy()
  end)
end)

describe("script freeze - cost (ci-de55)", function()
  it("a big frozen field settles and then costs nothing extra to keep frozen", function()
    -- The ci-de55 ruling requires the sweep cost to be MEASURED and REPORTED, not
    -- asserted: "a freeze sweep that tanks UPS on a large save is a regression even
    -- if it is correct." Lua has no wall clock (deliberately -- it would break
    -- determinism), so the numbers below are LOGGED for the completion note and
    -- what is asserted here is the thing that actually goes wrong: a settled field
    -- must not churn, i.e. steady state must do no work at all beyond looking.
    -- The algorithmic half -- that the coverage index makes a sweep cost
    -- buildings + sources rather than buildings x sources -- is pinned
    -- deterministically in unit-tests/test_freeze.lua, where the comparisons can
    -- be counted instead of timed.
    --
    -- Three numbers are logged, because only their DIFFERENCES mean anything: the
    -- surface scan alone, the scan plus the freeze of a whole field, and the
    -- steady state a real save actually pays every SWEEP_INTERVAL ticks.
    local s = H.cindra_surface()
    storage.cindra_freeze_autoplace = false
    storage.cindra_driver_enabled = false
    local PANELS, SOURCES = 240, 60
    local y = ground(2000)
    slab(s, -8, 4 * PANELS / 8 + 40, y - 8, y + 40)

    local tb = helpers.create_profiler()
    sf.sweep(s)
    tb.stop()
    log({ "", "ci-de55 sweep cost, empty (the surface scan alone): ", tb })

    local built = {}
    for i = 1, PANELS do
      local col, row = i % 30, math.floor(i / 30)
      built[#built + 1] = place(s, "cindra-solar-band-b05", { col * 4 + 0.5, y + row * 4 + 0.5 })
    end
    for i = 1, SOURCES do
      built[#built + 1] = hot_pipe(s, { -4.5, y + (i % 40) + 0.5 })
    end

    local t0 = helpers.create_profiler()
    reheat()
    local result = sf.sweep(s)
    t0.stop()
    log({ "", "ci-de55 sweep cost, freezing (" .. PANELS .. " buildings, " .. SOURCES
      .. " heat sources): ", t0 })
    assert.is_true(result.froze + result.frozen > 0, "the field must actually freeze")

    -- A second sweep with nothing to change is the STEADY-STATE cost -- what a
    -- real save pays every SWEEP_INTERVAL ticks, forever.
    local t1 = helpers.create_profiler()
    reheat()
    local steady = sf.sweep(s)
    t1.stop()
    log({ "", "ci-de55 steady-state sweep cost: ", t1 })
    assert.are.equal(0, steady.froze, "a settled field must not churn every sweep")
    assert.are.equal(0, steady.thawed, "a settled field must not churn every sweep")

    teardown(s)
  end)
end)
