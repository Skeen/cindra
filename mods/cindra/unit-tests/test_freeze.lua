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
  assert_eq(100, freeze.FREEZE_REACH, "measured inclusive Chebyshev reach")
  assert_eq(100, freeze.EMITTER_HEATING_RADIUS, "the effective-clamp heating_radius")
end)

test("spacing is 2R+1, DERIVED from the reach (not hardcoded)", function()
  assert_eq(201, freeze.EMITTER_SPACING, "2*100+1 = 201")
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

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
