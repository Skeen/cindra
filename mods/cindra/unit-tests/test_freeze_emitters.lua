-- Plain-Lua unit test for the native-freeze emitter PLACEMENT geometry
-- (scripts/freeze-emitters.lua). Run:
--   cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_freeze_emitters.lua
--
-- freeze-emitters.lua derives the warm band from the live ribbon zone geometry and
-- turns each chunk into the exact set of emitter world positions to place. The
-- position maths is PURE (positions_in_area takes an explicit orientation, no game.*),
-- so BOTH ribbon orientations are provable here -- the engine test (tests/test_freeze)
-- only ever runs the one startup orientation. The engine test asserts the RESULTING
-- thaw/freeze against the real emitter; keep the two in sync.

package.path = package.path .. ";./?.lua;./?/init.lua"
local emitters = require("scripts.freeze-emitters")
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

-- Chunk-shaped tile box helper.
local function area(x0, y0, x1, y1)
  return { left_top = { x = x0, y = y0 }, right_bottom = { x = x1, y = y1 } }
end

test("warm_band spans the safe MIDDLE cold edge (onset) to the lava sea edge", function()
  -- Default ci-wly widths: middle [-60,60], hot_ocean [200,400]. Onset = middle.lo.
  local lo, hi = emitters.warm_band()
  assert_eq(-60, lo, "onset = the habitable middle's cold edge")
  assert_eq(200, hi, "sunward limit = the lava sea edge")
end)

test("the warm band needs TWO rows and its onset sits exactly on -60", function()
  local rows = emitters.rows()
  assert_eq(2, #rows, "260-tile band > one 203-tile row -> two rows")
  assert_eq(41, rows[1], "nightward row centred so its cold edge is the onset (-60 + R)")
  assert_eq(244, rows[2], "sunward row one 2R+1 step further (abutting)")
  assert_eq(-60, emitters.onset(), "freeze ONSET is exactly the middle's cold edge")
end)

test("positions_in_area places the nightward row (vertical): perp 41 -> x = -41", function()
  -- A chunk holding x in [-64,-32] (perp 32..64, so row 41 is inside) and the y=0
  -- lattice point. Vertical: perp = -x, long = y -> emitter at (-41, 0).
  local pos = emitters.positions_in_area(area(-64, -16, -32, 16), "vertical")
  assert_eq(1, #pos, "one emitter (row 41, lattice 0) in this chunk")
  assert_eq(-41, pos[1].x, "row perp 41 maps to x = -41 (hot = west)")
  assert_eq(0, pos[1].y, "lattice long 0 maps to y = 0")
end)

test("positions_in_area places the nightward row (horizontal): perp 41 -> y = -41", function()
  -- Mirror chunk for the quarter-turned ribbon: perp = -y, long = x, fire at the TOP
  -- (ci-65p) -> the row sits at y = -41, so the chunk holding y in [-64,-32] is the
  -- one that gets the emitter.
  local pos = emitters.positions_in_area(area(-16, -64, 16, -32), "horizontal")
  assert_eq(1, #pos, "one emitter (row 41, lattice 0) in this chunk")
  assert_eq(0, pos[1].x, "lattice long 0 maps to x = 0")
  assert_eq(-41, pos[1].y, "row perp 41 maps to y = -41 (hot = the TOP)")
end)

test("a chunk straddling BOTH rows + one lattice point yields both emitters", function()
  -- Vertical chunk wide enough in x to cover perp 41 AND 244 is impossible in 32
  -- tiles; instead prove the per-row filtering directly with a tall synthetic box.
  local pos = emitters.positions_in_area(area(-260, -16, -30, 16), "vertical")
  local xs = {}
  for _, p in ipairs(pos) do xs[p.x] = p.y end
  assert_true(xs[-41] ~= nil, "row 41 (x=-41) placed")
  assert_true(xs[-244] ~= nil, "row 244 (x=-244) placed")
  assert_eq(0, xs[-41], "both on the y=0 lattice point")
  assert_eq(0, xs[-244], "both on the y=0 lattice point")
end)

test("a chunk containing NO lattice point along the long axis places nothing", function()
  -- Long span [50,82] contains no multiple of 201, so no emitter regardless of rows.
  local pos = emitters.positions_in_area(area(-64, 50, -32, 82), "vertical")
  assert_eq(0, #pos, "no long-axis lattice point in this chunk -> no emitter")
end)

test("cfg overrides the zone widths, moving the onset + rows deterministically", function()
  -- Shrink the middle so the whole warm band fits one row -> a single fire-edge row.
  -- middle 20 wide -> [-10,10]; hot_ocean stays at 200 default. onset = -10.
  local cfg = { middle = 20, hot_ocean = 10, hot_inner = 5, hot_outer = 5,
    cold_outer = 5, cold_inner = 5, cold_ocean = 10 }
  -- With these widths total = 60, hot_ocean band lo shifts; just assert internal
  -- consistency: onset = warm_band lo, rows anchored on it.
  local lo, hi = emitters.warm_band(cfg)
  local rows = emitters.rows(cfg)
  assert_eq(lo, rows[1] - freeze.FREEZE_REACH, "onset tracks the cfg-derived band lo")
  assert_true(rows[#rows] + freeze.FREEZE_REACH >= hi, "rows still cover the sunward edge")
end)

-- ci-i4z: the world-gen-screen zone sliders stretch the habitable band in WORLD tiles,
-- and an emitter's heating radius is a PHYSICAL distance -- so a wider band needs more
-- rows or the far end of it freezes. The warm band is therefore read in world tiles.
test("the emitter line follows the world-gen-screen zone sliders (ci-i4z)", function()
  local zone_scale = require("scripts.zone-scale")
  local sc = zone_scale.default_scales()
  sc.middle = 3 -- a 360-tile habitable band instead of 120

  local base_lo, base_hi = emitters.warm_band()
  local lo, hi = emitters.warm_band(nil, sc)
  assert_true(lo < base_lo, "the onset moves out with the widened band (" .. lo .. " < " .. base_lo .. ")")
  assert_true(hi > base_hi, "and so does the sunward limit (" .. hi .. " > " .. base_hi .. ")")

  local rows = emitters.rows(nil, sc)
  assert_true(#rows > #emitters.rows(), "a wider band needs MORE emitter rows (" .. #rows .. ")")
  -- Every tile of the widened warm band is within some row's reach: no frozen seam and
  -- no frozen far end (the whole point of the line).
  for p = lo, hi, 5 do
    local covered = false
    for _, row in ipairs(rows) do
      if math.abs(p - row) <= freeze.FREEZE_REACH then covered = true break end
    end
    assert_true(covered, "world tile " .. p .. " of the widened band is heated")
  end
  assert_eq(lo, emitters.onset(nil, sc), "the freeze onset is the nightward edge of that band")
  -- And the emitter positions land on the stretched rows, not the nominal ones.
  local pos = emitters.positions_in_area(
    { left_top = { x = -math.floor(rows[#rows]) - 8, y = -16 },
      right_bottom = { x = -math.floor(rows[#rows]) + 8, y = 16 } }, "vertical", nil, sc)
  assert_true(#pos > 0, "the sunward-most row is placed where the stretched world put it")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
