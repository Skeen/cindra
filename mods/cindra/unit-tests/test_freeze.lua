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

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
