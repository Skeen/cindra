-- NATIVE FREEZE integration proof (§ freeze, ci-bvk).
--
-- Cindra's planet carries `entities_require_heating = true`, so every freezable
-- entity FREEZES for real (frost, stopped machines, native pipe/fluid freeze) unless
-- a hot heat source is in reach. This suite proves, against the ACTUAL Cindra
-- prototypes on the real Cindra surface:
--   1. the pinned engine constants (scripts/freeze.lua) hold against the real emitter:
--      inclusive Chebyshev reach exactly 100, a tight 2R+1=201 seam (no gap at 201, a
--      frozen gap at 202) -- the step-1/step-2 measurements, re-guarded here;
--   2. the real worldgen emitter line keeps the habitable band thawed and freezes the
--      nightside past the onset (machine AND pipe) -- the step-3 split;
--   3. the ci-f5l electric heater composes with native freeze as a heat source,
--      extending a thawed pocket into the frozen band -- the step-4 heater check;
--   4. no other planet is ever touched: nauvis entities are not freezable and get no
--      lava-heat emitter -- the cross-cutting invariant.
-- Both ORIENTATIONS are proved by the pure placement unit tests (test_axis /
-- test_freeze_emitters); the engine runs the one startup orientation (vertical).
--
-- RELIABILITY (learned in the ci-b5i PoC): a hot heat source warms the ground TILES
-- in reach and they DO NOT COOL on any test timescale, so two measurements that share
-- ground contaminate each other. Every manual-emitter measurement therefore sits on
-- FRESH, never-heated ground handed out by a monotonic cursor that is never rewound.

local H = require("tests.helpers")
local freeze = require("scripts.freeze")
local emitters = require("scripts.freeze-emitters")
local axis = require("scripts.axis")

-- Monotonic FRESH-ground cursor along the ribbon's long axis, parked FAR from the
-- origin work area (and every other suite's) so nothing shares heated tiles.
local cursor = 100000
local GAP = 600

-- Generate + pave a flat, never-heated slab covering world [x0,x1] x [y0,y1] so
-- probes never collide with generated lava/ice/void. (Script set_tiles is not the
-- player/robot tile-build no-paving.lua guards, so refined-concrete stays put.)
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

-- A hot cindra-lava-heat emitter at world `pos`. Set hot once; the driver's reheat
-- sweep (scripts/freeze-emitters.lua) keeps every emitter pinned hot as ticks advance.
local function emitter(s, pos)
  local e = s.create_entity({ name = freeze.EMITTER_NAME, position = pos, force = "player" })
  assert(e, "failed to create lava-heat emitter")
  e.temperature = freeze.EMITTER_TEMPERATURE
  return e
end

local function probe(s, pos, name)
  local e = s.create_entity({ name = name or "assembling-machine-1", position = pos, force = "player" })
  assert(e, "failed to create probe at " .. pos[1] .. "," .. pos[2])
  return e
end

describe("native freeze (§ freeze, ci-bvk)", function()
  it("wires the lava-heat emitter as a radius-honouring 1x1 heat source", function()
    -- The mechanism hinges on picking an entity that ACTUALLY honours heating_radius.
    -- A heat-interface silently ignores it (warms only its own tile); a heat-pipe
    -- honours it AND is a single tile, so the pinned reach geometry holds.
    local pr = prototypes.entity[freeze.EMITTER_NAME]
    assert.is_not_nil(pr, "the lava-heat emitter prototype exists")
    assert.are.equal("heat-pipe", pr.type, "it is a heat-pipe (honours heating_radius, 1x1)")
    assert.are.equal(freeze.EMITTER_HEATING_RADIUS, pr.heating_radius,
      "its heating_radius is the pinned value")
    -- The whole-surface freeze flag itself is proved BEHAVIOURALLY below (machines
    -- past the onset freeze on Cindra; a nauvis machine never does) -- the runtime
    -- LuaPlanetPrototype exposes no entities_require_heating accessor to read directly.
  end)

  it("re-guards the pinned constants against the REAL emitter: reach inclusive, seam tight", function()
    local s = H.cindra_surface()
    storage.cindra_freeze_autoplace = false -- hand-place; no worldgen line on this ground
    local R = freeze.FREEZE_REACH
    local S = freeze.EMITTER_SPACING

    -- (a) REACH: a single emitter; a machine at Chebyshev R thaws, R+1 freezes, on the
    --     axis AND the diagonal corner (a square, not a disc) -- the measured seam.
    local rb = cursor; cursor = cursor + GAP
    slab(s, -4, R + 6, rb - 4, rb + R + 6)
    emitter(s, { 0, rb })
    local a_reach  = probe(s, { R, rb })                      -- dx=R   -> thawed (inclusive)
    local a_edge   = probe(s, { R + 1, rb })                  -- dx=R+1 -> frozen
    local a_corner = probe(s, { R, rb + R })                  -- (R,R)  -> thawed (square)
    local a_beyond = probe(s, { R + 1, rb + R + 1 })          -- (R+1,R+1) -> frozen

    -- (b) SEAM at spacing S=2R+1: two emitters S apart leave ZERO frozen tiles between.
    local sb = cursor; cursor = cursor + GAP
    slab(s, -4, 4, sb - 4, sb + S + 4)
    emitter(s, { 0, sb }); emitter(s, { 0, sb + S })
    local seam_lo = probe(s, { 0, sb + R })                   -- dy=R   from A -> thawed
    local seam_hi = probe(s, { 0, sb + R + 1 })               -- dy=R   from B -> thawed

    -- (c) GAP at spacing S+1: the tile between two emitters S+1 apart FREEZES (proving
    --     S is a TIGHT bound, not padded).
    local gb = cursor; cursor = cursor + GAP
    slab(s, -4, 4, gb - 4, gb + S + 6)
    emitter(s, { 0, gb }); emitter(s, { 0, gb + S + 1 })
    local gap_tile = probe(s, { 0, gb + R + 1 })              -- dy=R+1 from both -> frozen

    assert.is_true(a_reach.is_freezable, "a machine must be freezable on the Cindra surface")

    async(6000)
    after_ticks(5000, function()
      -- reach is an INCLUSIVE Chebyshev SQUARE of exactly R
      assert.is_false(a_reach.frozen, "reach R on-axis is THAWED (inclusive)")
      assert.is_true(a_edge.frozen, "reach R+1 on-axis is FROZEN")
      assert.is_false(a_corner.frozen, "the (R,R) corner is THAWED (a square, not a disc)")
      assert.is_true(a_beyond.frozen, "the (R+1,R+1) corner is FROZEN")
      -- seam: S=2R+1 abuts with no frozen tile; S+1 opens a one-tile frozen gap
      assert.is_false(seam_lo.frozen, "spacing S: the seam tile (R from A) is thawed")
      assert.is_false(seam_hi.frozen, "spacing S: the seam tile (R from B) is thawed")
      assert.is_true(gap_tile.frozen, "spacing S+1: the between tile (R+1 from both) FREEZES")
      done()
    end)
  end)

  it("the real worldgen line thaws the habitable band and freezes the nightside", function()
    local s = H.cindra_surface()
    storage.cindra_freeze_autoplace = true -- the actual lava-heat line

    -- Anchor the region on a lattice multiple so the emitter line is dense here, and
    -- generate wide enough that both perp rows (x = -40 and x = -241) exist nearby.
    local Lc = math.floor(cursor / freeze.EMITTER_SPACING) * freeze.EMITTER_SPACING
    cursor = Lc + 2 * GAP
    slab(s, -260, 96, Lc - 260, Lc + 160)

    -- WARM: a machine in the habitable band (perp 0 = the middle). world(long, perp):
    -- perp 0 -> x 0. FROZEN: perp -80 (x 80) sits past the onset (-60), in cold_outer.
    local warm  = probe(s, { 0, Lc })
    local frost = probe(s, { 80, Lc + 20 })
    local pipe  = probe(s, { 80, Lc + 40 }, "pipe") -- native PIPE/FLUID freeze

    -- HEATER POCKET: a hot ci-f5l electric heater in the frozen band thaws a machine
    -- immediately beside it, though it sits far past the onset (heaters carry warmth
    -- into the cold). Held hot directly (its fuel/power path is test_heater's job).
    local heater = s.create_entity({ name = "cindra-electric-heater", position = { 80, Lc + 90 }, force = "player" })
    assert(heater, "electric heater must place")
    heater.temperature = 600
    local pocket = probe(s, { 83, Lc + 90 }) -- adjacent to the heater, deep in the cold

    -- Cross-cutting: a machine on nauvis (no freeze flag) NEVER freezes on the same
    -- ticks -- the mod must not touch another planet.
    local nauvis = game.surfaces["nauvis"]
    local off_world = nauvis.create_entity({ name = "assembling-machine-1", position = { 0, 0 }, force = "player" })

    assert.is_true(warm.is_freezable, "the probe is freezable on Cindra")
    assert.is_true(pipe.is_freezable, "a pipe is freezable (native fluid freeze)")

    async(6000)
    after_ticks(5000, function()
      assert.is_false(warm.frozen, "a machine in the habitable band stays THAWED (the lava line)")
      assert.is_true(frost.frozen, "a machine past the onset FREEZES (the reachable frozen nightside)")
      assert.is_true(pipe.frozen, "a pipe past the onset FREEZES natively (fluid freeze)")
      assert.is_false(pocket.frozen, "a machine beside a hot electric heater THAWS deep in the cold")
      assert.is_false(off_world.frozen, "a nauvis machine NEVER freezes (no other-planet mutation)")
      off_world.destroy()
      done()
    end)
  end)

  it("never places the lava-heat emitter on another planet", function()
    local nauvis = game.surfaces["nauvis"]
    emitters.place_all(nauvis) -- explicit: a no-op off Cindra (gated on surface.name)
    local found = nauvis.find_entities_filtered({ name = freeze.EMITTER_NAME })
    assert.are.equal(0, #found, "no lava-heat emitter may ever exist on nauvis")
  end)
end)
