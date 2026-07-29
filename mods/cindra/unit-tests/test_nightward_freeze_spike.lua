-- SPIKE (ci-p7z): can Aquilo's freezing mechanic run on ONLY the nightward half
-- of the ribbon? This isolated, no-Factorio prototype proves the FEASIBLE path.
-- Run: cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_nightward_freeze_spike.lua
--
-- VERDICT (see the bead findings for the full write-up):
--   * NATIVE Aquilo freezing is NOT positional. `entities_require_heating` is a
--     single whole-planet PlanetPrototype boolean; the runtime `LuaEntity::frozen`
--     / `is_freezable` are READ-ONLY (no write_type in the API), and the only
--     writable "freeze" in the whole runtime API is `LuaSurface::freeze_daytime`
--     (day/night TIME lock, unrelated). So you cannot make the engine freeze only
--     half a surface, and turning it on whole-surface would freeze Cindra's
--     temperate ribbon AND its hot sunward half too (breaks the fire/ice thesis).
--   * The FEASIBLE approach is script-driven positional cold semantics keyed to
--     the ribbon axis (scripts/ribbon.lua) - exactly what scripts/building-heat.lua
--     already does with `cindra-cold` damage. This test isolates and proves the
--     load-bearing claim of that approach: the freeze predicate is a pure function
--     of the PERPENDICULAR (sunward-nightward) coordinate, so it fires ONLY
--     nightward, never sunward or temperate, and is orientation-independent.
--
-- This file requires ONLY ribbon.lua's stable public contract (temperature(y)),
-- and does NOT touch building-heat.lua (owned by worldgen-v2, ci-i8a / radrat).
-- The freeze_temp value and the perpendicular-axis projection are modelled here
-- so the proof stands alone, independent of the in-flight worldgen-v2 refactor.

package.path = package.path .. ";./?.lua;./?/init.lua"
local ribbon = require("scripts.ribbon")
local zones = require("scripts.zones")

-- ci-a35: the temperate reference is the SAND-band centre (`ref`), not the world
-- origin, and the reaches to each edge are asymmetric. Points are expressed
-- RELATIVE to ref so the invariant (freeze only nightward of temperate) is what is
-- actually proven, independent of the concrete zone widths.
local REF = zones.geometry().ref

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

local function assert_true(x, msg)
  if not x then error(msg or "expected true", 2) end
end

local function assert_false(x, msg)
  if x then error(msg or "expected false", 2) end
end

-- The nightside freeze threshold, mirroring building-heat.lua's DEFAULT_FREEZE_TEMP
-- (-30 C). Kept local so this spike stays isolated from the worldgen-v2-owned file.
local FREEZE_TEMP = -30

-- The load-bearing predicate: a machine at perpendicular-axis coordinate `perp`
-- freezes (takes cold pressure) iff the ribbon axis temperature there is at/below
-- the freeze threshold. Pure function of `perp` alone -> positional by construction.
local function freezes_at(perp)
  return ribbon.temperature(perp) <= FREEZE_TEMP
end

-- Orientation abstraction (what worldgen-v2 / ci-i8a will own): map a world point
-- to the perpendicular (sunward<->nightward) coordinate. The freeze predicate reads
-- ONLY this projection, so it is correct in BOTH ribbon orientations.
--   "east-west"  : ribbon runs along X, perpendicular axis is Y  -> perp = y
--   "north-south": ribbon runs along Y, perpendicular axis is X  -> perp = x
local function perp_of(point, orientation)
  if orientation == "north-south" then return point.x end
  return point.y -- east-west (default)
end

test("temperate ribbon does NOT freeze (spawn centre and inner band)", function()
  for _, off in ipairs({ 0, -10, 10, 20 }) do
    assert_false(freezes_at(REF + off), "ref" .. off .. " must stay thawed (temperate)")
  end
end)

test("sunward half NEVER freezes (hot side is not cold at any depth)", function()
  for _, off in ipairs({ 24, 30, 60, 96, 127 }) do
    assert_false(freezes_at(REF + off), "ref+" .. off .. " sunward must never freeze")
  end
end)

test("nightward half DOES freeze past the threshold, deepening outward", function()
  for _, off in ipairs({ -30, -60, -96 }) do
    assert_true(freezes_at(REF + off), "ref" .. off .. " nightward must freeze")
  end
end)

test("the freeze boundary sits nightward of the spawn, on the nightward side only", function()
  -- Freeze begins some tiles nightward of the sand spawn (temperature crosses -30
  -- there) and the mirror-image sunward point is warm. This is the "only half the
  -- planet" proof: the SAME offset freezes nightward but not sunward.
  assert_true(freezes_at(REF - 30), "nightward ref-30 frozen")
  assert_false(freezes_at(REF + 30), "sunward ref+30 (mirror) NOT frozen")
  assert_false(freezes_at(REF - 10), "just nightward of the spawn stays thawed")
end)

test("positional freeze is orientation-independent (east-west AND north-south)", function()
  -- Model the same three physical situations in both orientations. The freeze
  -- result must depend ONLY on the perpendicular coordinate, never on which world
  -- axis the ribbon runs along. The far-away along-axis coordinate is irrelevant.
  local cases = {
    -- { east_west point, north_south point, expect_frozen, label }
    { { x = 9999, y = REF - 80 }, { x = REF - 80, y = 9999 }, true, "deep nightward" },
    { { x = 9999, y = REF + 80 }, { x = REF + 80, y = 9999 }, false, "deep sunward" },
    { { x = 9999, y = REF }, { x = REF, y = 9999 }, false, "temperate centre" },
  }
  for _, c in ipairs(cases) do
    local ew, ns, want, label = c[1], c[2], c[3], c[4]
    local got_ew = freezes_at(perp_of(ew, "east-west"))
    local got_ns = freezes_at(perp_of(ns, "north-south"))
    assert_true(got_ew == want, label .. ": east-west orientation")
    assert_true(got_ns == want, label .. ": north-south orientation")
    assert_true(got_ew == got_ns, label .. ": orientations must agree")
  end
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
