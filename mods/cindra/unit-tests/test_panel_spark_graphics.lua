-- Plain-Lua unit test for the overload effect's ART (prototypes/panel-spark.lua,
-- ci-sz8q). Run:
--   cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_panel_spark_graphics.lua
--
-- THE CHANGE (ci-sz8q): playtest called the original overload visual (ci-clf's
-- hot-tinted `sparks-0x.png` electric-arc sheets, and the ci-vx3ge
-- accumulator-CHARGE / Fulgora-lightning direction that superseded it) bad. The
-- effect is now the vanilla ACCUMULATOR DISCHARGE glow, the game's own visual for
-- "too much power moving through this building".
--
-- The Factorio runtime API exposes NO graphics accessor on LuaEntityPrototype, so
-- the in-engine test (tests/test_power_prototypes.lua) can only assert the
-- prototype's type/hidden flags. This test closes that gap: it stubs the data
-- stage, requires the real prototype module, and asserts the effect draws the
-- discharge sheet -- and that NONE of the rejected art survives anywhere in it.

package.path = package.path .. ";./?.lua;./?/init.lua"

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

-- === Stub the Factorio data stage ==========================================

local registry = {}
local data = { raw = {} }
function data:extend(list)
  for _, proto in ipairs(list) do
    registry[proto.type] = registry[proto.type] or {}
    registry[proto.type][proto.name] = proto
  end
end
_G.data = data

require("prototypes.panel-spark")

local C = require("scripts.flare-config")

local DISCHARGE_PNG = "__base__/graphics/entity/accumulator/accumulator-discharge.png"
-- The art the playtest rejected: the arc sheets (ci-clf) and the accumulator
-- CHARGE glow / Fulgora lightning direction (ci-vx3ge), superseded by ci-sz8q.
local REJECTED = {
  "graphics/entity/sparks/",
  "accumulator-charge.png",
  "lightning",
}

-- Recursively true if any string value under `t` contains `substr`.
local function has_filename(t, substr)
  if type(t) ~= "table" then return false end
  for _, v in pairs(t) do
    if type(v) == "string" and v:find(substr, 1, true) then return true end
    if type(v) == "table" and has_filename(v, substr) then return true end
  end
  return false
end

local spark = (registry["explosion"] or {})[C.PANEL_SPARK]

test("the overload effect is registered as a self-reaping explosion", function()
  assert_true(spark, C.PANEL_SPARK .. " must be registered")
  assert_eq("explosion", spark.type, "the effect must be an explosion (plays once, reaps itself)")
  assert_true(spark.hidden, "the effect must be hidden (purely cosmetic)")
end)

test("it draws the vanilla ACCUMULATOR DISCHARGE glow", function()
  assert_true(spark.animations, "the effect must have an animation")
  assert_true(has_filename(spark.animations, DISCHARGE_PNG),
    "the overload effect must draw " .. DISCHARGE_PNG)
end)

test("the discharge animation keeps the vanilla sheet's frame geometry", function()
  -- The sheet is 6 frames per row over 24 frames at half scale; a mismatch here
  -- tears the animation in-game, which no runtime assertion can catch.
  local anim = spark.animations[1]
  assert_eq(24, anim.frame_count, "discharge sheet has 24 frames")
  assert_eq(6, anim.line_length, "discharge sheet is 6 frames per row")
  assert_eq(174, anim.width, "discharge frame width")
  assert_eq(214, anim.height, "discharge frame height")
  assert_eq(0.5, anim.scale, "the sheet is high-res: drawn at half scale")
  assert_true(anim.draw_as_glow, "the discharge reads as a glow over the panel")
end)

test("it is the discharge EFFECT only -- no accumulator body drawn over the panel", function()
  assert_false(has_filename(spark.animations, "accumulator/accumulator.png"),
    "the effect must not draw the accumulator building itself on top of the panel")
end)

for _, art in ipairs(REJECTED) do
  test("the rejected art '" .. art .. "' is gone", function()
    assert_false(has_filename(spark, art),
      "the superseded overload art (" .. art .. ") must not survive anywhere in the prototype")
  end)
end

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
