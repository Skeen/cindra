-- Plain-Lua unit test for the native-freeze constants + geometry (scripts/freeze.lua).
-- Run: cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_freeze.lua
--
-- freeze.lua is the pure single source of truth for the engine's MEASURED
-- heat-emitter reach (exact inclusive Chebyshev 100), the tight 2R+1 emitter
-- spacing, and the deterministic placement lattice. This proves the pure maths;
-- the factorio-test guard (tests/test_freeze.lua) proves the ENGINE actually
-- behaves this way against the real Cindra emitter prototype. Keep the two in sync.

package.path = package.path .. ";./?.lua;./?/init.lua"
local freeze = require("scripts.freeze")

local passed, failed = 0, 0

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
    print("ok - " .. name)
  else
    failed = failed + 1
    print("not ok - " .. name .. ": " .. tostring(err))
  end
end

local function assert_eq(a, b, msg)
  if a ~= b then error((msg or "values differ") .. " (" .. tostring(a) .. " ~= " .. tostring(b) .. ")", 2) end
end

local function assert_true(x, msg)
  if not x then error(msg or "expected true", 2) end
end

local function assert_false(x, msg)
  if x then error(msg or "expected false", 2) end
end

test("the exact measured constants are pinned", function()
  assert_eq(100, freeze.EMITTER_HEATING_RADIUS, "the heat-pipe prototype heating_radius")
  assert_eq(101, freeze.FREEZE_REACH, "measured inclusive Chebyshev reach (radius + 1)")
  assert_eq(freeze.EMITTER_HEATING_RADIUS + 1, freeze.FREEZE_REACH, "reach = radius + 1 (measured)")
end)

test("spacing is 2R+1, DERIVED from the reach (not hardcoded)", function()
  assert_eq(203, freeze.EMITTER_SPACING, "2*101+1 = 203")
  assert_eq(2 * freeze.FREEZE_REACH + 1, freeze.EMITTER_SPACING, "spacing tracks the reach")
end)

test("covers() is an INCLUSIVE Chebyshev square (thawed at R, frozen at R+1)", function()
  local R = freeze.FREEZE_REACH
  -- On-axis seam: last thawed R, first frozen R+1 (the measured seam).
  assert_true(freeze.covers(R, 0), "|dx|=R is thawed (inclusive)")
  assert_false(freeze.covers(R + 1, 0), "|dx|=R+1 is frozen")
  assert_true(freeze.covers(0, R), "|dy|=R is thawed (inclusive)")
  assert_false(freeze.covers(0, R + 1), "|dy|=R+1 is frozen")
  -- The diagonal CORNER is thawed (square, not disc): (R,R) is Chebyshev R.
  assert_true(freeze.covers(R, R), "the (R,R) corner is thawed -- a square, not a disc")
  assert_false(freeze.covers(R + 1, R + 1), "(R+1,R+1) is frozen")
  -- Past the box on one axis only -> frozen even well inside the other.
  assert_false(freeze.covers(R + 1, 0), "past the box in one axis freezes")
  assert_true(freeze.covers(-R, -R), "negative offsets: symmetric")
end)

test("line_coords snaps to the fixed global lattice (multiples of spacing)", function()
  local S = freeze.EMITTER_SPACING
  local coords = freeze.line_coords(-30, 30)
  assert_true(#coords >= 1, "at least one emitter covers the origin band")
  for _, c in ipairs(coords) do
    assert_eq(0, c % S, "every emitter sits on a multiple of the spacing (idempotent lattice): " .. c)
  end
end)

test("line_coords covers the whole range with no gap (contiguous cover)", function()
  local R = freeze.FREEZE_REACH
  -- A range spanning several lattice cells; every integer point in [lo,hi] must
  -- lie within R of at least one returned emitter (no frozen gap on the line).
  local lo, hi = -250, 500
  local coords = freeze.line_coords(lo, hi)
  for p = lo, hi do
    local covered = false
    for _, c in ipairs(coords) do
      if math.abs(p - c) <= R then covered = true break end
    end
    assert_true(covered, "point " .. p .. " on the emitter line must be within R of an emitter")
  end
end)

test("line_coords is deterministic + idempotent (same lattice regardless of chunk order)", function()
  -- Two overlapping chunks: their emitter sets must AGREE on the shared lattice
  -- points, so re-generating in any order asks for the same world positions.
  local a = freeze.line_coords(0, 400)
  local b = freeze.line_coords(200, 600)
  local set_a = {}
  for _, c in ipairs(a) do set_a[c] = true end
  for _, c in ipairs(b) do
    if c >= 0 and c <= 400 then
      assert_true(set_a[c], "shared-range emitter " .. c .. " must appear in both chunks' sets")
    end
  end
end)

test("the emitter identity constants are pinned", function()
  assert_eq("cindra-lava-heat", freeze.EMITTER_NAME, "the ambient lava-heat emitter name")
  assert_eq(1000, freeze.EMITTER_TEMPERATURE, "held-hot temperature")
  assert_eq(freeze.EMITTER_HEATING_RADIUS + 1, freeze.FREEZE_REACH, "measured reach = heat-pipe radius + 1")
end)

test("lattice_coords CONTAINS (not covers): only lattice points inside [lo,hi]", function()
  local S = freeze.EMITTER_SPACING
  -- A chunk-sized window that straddles NO lattice point returns nothing (the
  -- emitter for the nearby lattice point is placed by ITS OWN chunk, not this one).
  local none = freeze.lattice_coords(50, 82) -- 0 and 203 both lie outside [50,82]
  assert_eq(0, #none, "a window containing no lattice point places no emitter")
  -- A window straddling exactly one lattice point returns just that point.
  local one = freeze.lattice_coords(-16, 16) -- contains 0 only
  assert_eq(1, #one, "one lattice point inside")
  assert_eq(0, one[1], "and it is the origin lattice point")
  -- Every returned coord is a lattice multiple AND inside the window.
  for _, c in ipairs(freeze.lattice_coords(-500, 500)) do
    assert_eq(0, c % S, "lattice multiple: " .. c)
    assert_true(c >= -500 and c <= 500, "inside the window: " .. c)
  end
end)

test("lattice_coords tiles the long axis with NO double-count across abutting chunks", function()
  -- Adjacent 32-wide chunks partition [-320, 320): each lattice emitter must appear
  -- in EXACTLY one chunk, so per-chunk placement creates it once (idempotent).
  local seen = {}
  for c0 = -320, 288, 32 do
    for _, c in ipairs(freeze.lattice_coords(c0, c0 + 31)) do
      assert_false(seen[c], "lattice point " .. c .. " must fall in only one chunk")
      seen[c] = true
    end
  end
  -- And the union is exactly the lattice points in range (0, +/-203, ...).
  assert_true(seen[0] and seen[203] and seen[-203], "the in-range lattice points were all placed")
end)

test("perp_rows anchors the ONSET on lo and steps 2R+1 until hi is covered", function()
  local R, S = freeze.FREEZE_REACH, freeze.EMITTER_SPACING
  -- The live ci-wly habitable+hot band [-60, 200] needs two rows.
  local rows = freeze.perp_rows(-60, 200)
  assert_eq(2, #rows, "a 260-tile band exceeds one 203-tile row -> two rows")
  assert_eq(-60 + R, rows[1], "first row centre = lo + R (its cold edge lands on lo)")
  assert_eq(rows[1] + S, rows[2], "rows step by exactly the 2R+1 spacing (boxes abut)")
  -- ONSET is exactly lo: the nightward edge of the nightward-most row.
  assert_eq(-60, freeze.onset(rows), "freeze onset sits exactly on the band's cold edge")
  -- The sunward-most row covers hi.
  assert_true(rows[#rows] + R >= 200, "the last row reaches the sunward edge")
end)

test("perp_rows leaves NO frozen seam between adjacent rows (abutting boxes)", function()
  local R = freeze.FREEZE_REACH
  local lo, hi = -60, 200
  local rows = freeze.perp_rows(lo, hi)
  -- Every integer perp coordinate in [onset, hi] is within R of some row centre.
  for p = freeze.onset(rows), hi do
    local covered = false
    for _, c in ipairs(rows) do
      if math.abs(p - c) <= R then covered = true break end
    end
    assert_true(covered, "perp " .. p .. " between the rows must be thawed (no seam)")
  end
  -- ...and just NIGHTWARD of the onset is NOT covered (the band is a tight bound).
  assert_false(freeze.covers(freeze.onset(rows) - 1 - rows[1], 0),
    "one tile past the onset is frozen (tight nightward bound)")
end)

test("a narrow band needs only ONE row (single-row reduces cleanly)", function()
  -- If the warm band fits in 2R+1, perp_rows degenerates to a single fire-edge row.
  local rows = freeze.perp_rows(0, 150) -- 150 < 203
  assert_eq(1, #rows, "a <=203-tile band is one row")
  assert_eq(freeze.FREEZE_REACH, rows[1], "anchored so its cold edge is the onset (0)")
end)

-- ===========================================================================
-- HEAT COVERAGE (ci-de55): the geometry the SCRIPT freeze decides on
-- ===========================================================================
-- The engine answers "is this thawed?" for the entity types it can freeze. For
-- the types it refuses (accumulators, solar panels, electric-energy-interfaces)
-- Cindra has to answer it itself, and the answer has to be the SAME one -- a
-- machine thawed beside a frozen battery is a bug report, not a mechanic. The
-- in-engine agreement is measured in tests/test_script_freeze.lua; this half
-- proves the arithmetic, including the boundary, where an off-by-one lives.

-- A tile box from a world bounding box, the way LuaEntity.selection_box reads.
local function boxof(x0, y0, x1, y1)
  return freeze.tile_box({ left_top = { x = x0, y = y0 }, right_bottom = { x = x1, y = y1 } })
end

test("tile_box takes the tiles an entity's footprint actually occupies", function()
  -- A 3x3 building sits on a tile CENTRE, so its box runs corner to corner and
  -- covers exactly three tiles per axis.
  local b = boxof(2, 5, 5, 8)
  assert_eq(2, b.x0); assert_eq(5, b.x1)
  assert_eq(5, b.y0); assert_eq(8, b.y1)
  -- A 1x1 emitter on a tile centre occupies its single tile.
  local e = boxof(0, 0, 1, 1)
  assert_eq(0, e.x0); assert_eq(1, e.x1)
end)

test("a heat source thaws its own tiles GROWN BY heating_radius (the measured rule)", function()
  -- MEASURED IN-ENGINE, both ends of the scale (ci-de55):
  --   a 1x1 emitter of radius 100 thawed a 3x3 machine at Chebyshev centre
  --   distance 101 and froze it at 102;
  --   a 3x3 reactor of radius 1 thawed a 3x3 machine at distance 3 (touching) and
  --   froze it at 4 (one tile of clear ground).
  -- Both are reproduced here from the tile arithmetic alone.
  local emitter = freeze.heated_region(boxof(0, 0, 1, 1), 100)
  local at_reach = boxof(100, -1, 103, 2)  -- 3x3 centred 101 tiles away
  local past = boxof(101, -1, 104, 2)      -- ...and 102 tiles away
  assert_true(freeze.tiles_overlap(at_reach, emitter), "reach 101 is THAWED (measured)")
  assert_false(freeze.tiles_overlap(past, emitter), "reach 102 is FROZEN (measured)")

  local reactor = freeze.heated_region(boxof(-1, -1, 2, 2), 1) -- 3x3, radius 1
  assert_true(freeze.tiles_overlap(boxof(2, -1, 5, 2), reactor),
    "a machine TOUCHING a radius-1 reactor is thawed (measured)")
  assert_false(freeze.tiles_overlap(boxof(3, -1, 6, 2), reactor),
    "one tile of clear ground past it is frozen (measured)")
end)

test("coverage is a SQUARE: the diagonal corner behaves like the axis", function()
  -- The reach shape is load-bearing for the ribbon: a straight LINE of emitters
  -- yields a straight freeze front only because each box is bounded per axis.
  local r = freeze.heated_region(boxof(0, 0, 1, 1), 100)
  assert_true(freeze.tiles_overlap(boxof(100, 100, 103, 103), r), "the (R,R) corner is thawed")
  assert_false(freeze.tiles_overlap(boxof(101, 101, 104, 104), r), "the (R+1,R+1) corner is frozen")
  -- ...and one axis alone is enough to freeze it.
  assert_false(freeze.tiles_overlap(boxof(0, 101, 3, 104), r), "far on ONE axis is frozen")
end)

test("the coverage index gives the same answers as testing every region by hand", function()
  -- The index is a PERFORMANCE structure, so the only thing that matters about it
  -- is that it changes no answer. Checked against the brute-force oracle over a
  -- scatter of regions and probes, at three different cell sizes.
  local regions = {}
  for i = 0, 9 do
    regions[#regions + 1] = freeze.heated_region(boxof(i * 60, i * 37, i * 60 + 1, i * 37 + 1), 20)
  end
  for _, cell in ipairs({ 16, 128, 1024 }) do
    local index = freeze.coverage_index(regions, cell)
    for x = -40, 600, 7 do
      for y = -40, 380, 11 do
        local probe = boxof(x, y, x + 3, y + 3)
        local brute = false
        for _, r in ipairs(regions) do
          if freeze.tiles_overlap(probe, r) then brute = true break end
        end
        assert_eq(brute, freeze.covered_by_index(index, probe),
          "cell " .. cell .. " disagreed with the oracle at " .. x .. "," .. y)
      end
    end
  end
end)

test("an empty index covers nothing (no heat = everything freezes)", function()
  local index = freeze.coverage_index({})
  assert_false(freeze.covered_by_index(index, boxof(0, 0, 3, 3)), "no heat source, no thaw")
end)

test("the index costs sources + buildings, NOT sources x buildings", function()
  -- The ci-de55 ruling's UPS condition, pinned deterministically rather than by
  -- wall clock: "a freeze sweep that tanks UPS on a large save is a regression even
  -- if it is correct." The naive sweep compares every building against every heat
  -- source, which a played-in ribbon (hundreds of worldgen emitters) times a real
  -- solar farm (hundreds of panels) turns into tens of thousands of comparisons
  -- every sweep. Counting the comparisons is exact and machine-independent, which a
  -- timing assertion could never be.
  local SOURCES, PROBES = 200, 400
  local regions = {}
  for i = 1, SOURCES do
    -- Spread along a line, the way the ribbon's emitter lattice really lies.
    regions[#regions + 1] = freeze.heated_region(boxof(i * 203, 0, i * 203 + 1, 1), 100)
  end
  local index = freeze.coverage_index(regions)

  local real_overlap, calls = freeze.tiles_overlap, 0
  freeze.tiles_overlap = function(a, b) calls = calls + 1 return real_overlap(a, b) end
  for i = 1, PROBES do
    freeze.covered_by_index(index, boxof(i * 100, 3000, i * 100 + 3, 3003))
  end
  freeze.tiles_overlap = real_overlap

  local naive = SOURCES * PROBES
  assert_true(calls < naive / 10,
    "the coverage index must not degenerate to the naive scan: " .. calls
      .. " comparisons for " .. PROBES .. " buildings over " .. SOURCES
      .. " heat sources (naive would be " .. naive .. ")")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
