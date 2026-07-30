-- Plain-Lua unit test for the pure bootstrap-rock stone tint (scripts/rock_tint.lua).
-- Run: cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_rock_tint.lua
--
-- scripts/rock_tint.lua is deliberately pure (no game.* / prototypes.*), so its
-- whole surface is reachable here. It carries the warm "vanilla stone" tint the
-- rock entity (prototypes/resources.lua) lays over its sprite variations (ci-jvc)
-- and the pure function that applies it. The engine render (does the tint LOOK
-- like stone against the terminator soil) is the one thing a test cannot judge --
-- that lives in PLAYTEST.md.

package.path = package.path .. ";./?.lua;./?/init.lua"
local rock_tint = require("scripts.rock_tint")

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

local function assert_eq(a, b, msg)
  if a ~= b then error((msg or "values differ") .. " (" .. tostring(a) .. " ~= " .. tostring(b) .. ")", 2) end
end

-- The tint is the whole point of the feature: it must be a WARM / yellowish
-- multiply. Guard the shape so a future edit can't silently neutralise it (grey)
-- or invert it (cool/blue), which would undo the vanilla-stone look.
test("STONE_TINT is a warm yellowish multiply", function()
  local t = rock_tint.STONE_TINT
  assert_true(t.r > 0 and t.g > 0 and t.b > 0, "all channels present and positive")
  -- Yellow = red & green high, blue pulled down. red >= green > blue.
  assert_true(t.r >= t.g, "red not below green")
  assert_true(t.g > t.b, "green above blue (warm)")
  -- A meaningful shift, not a rounding-error tint: blue must be clearly cut.
  assert_true(t.b <= 0.75, "blue clearly reduced for a visible yellow shift")
  -- A multiply tint cannot brighten; keep every channel in the valid 0..1 range.
  assert_true(t.r <= 1.0 and t.g <= 1.0 and t.b <= 1.0, "channels within 0..1")
end)

-- The ice-rock tint (ci-18n) is the COLD mirror of STONE_TINT: it must be a cool
-- bluish multiply so the shared huge-rock art reads as an icy boulder, not a warm
-- sandstone one. Guard the shape so a future edit can't neutralise it (grey) or warm
-- it (yellow), which would make the ice-rocks indistinguishable from the sandy rocks.
test("ICE_TINT is a cool bluish multiply (the cold mirror of STONE_TINT)", function()
  local t = rock_tint.ICE_TINT
  assert_true(t.r > 0 and t.g > 0 and t.b > 0, "all channels present and positive")
  -- Cool = blue high, red pulled down. blue >= green > red.
  assert_true(t.b >= t.g, "blue not below green")
  assert_true(t.g > t.r, "green above red (cool)")
  -- A meaningful shift, not a rounding-error tint: red must be clearly cut.
  assert_true(t.r <= 0.75, "red clearly reduced for a visible blue shift")
  -- A multiply tint cannot brighten; keep every channel in the valid 0..1 range.
  assert_true(t.r <= 1.0 and t.g <= 1.0 and t.b <= 1.0, "channels within 0..1")
  -- It must genuinely differ from the warm stone tint (the two rocks must contrast).
  assert_true(t.b > rock_tint.STONE_TINT.b, "the ice tint is bluer than the stone tint")
  assert_true(t.r < rock_tint.STONE_TINT.r, "the ice tint is less red than the stone tint")
end)

test("apply tints every flat sprite variation", function()
  local pics = {
    { filename = "a.png", width = 10, height = 10 },
    { filename = "b.png", width = 10, height = 10 },
    { filename = "c.png", width = 10, height = 10 },
  }
  local out = rock_tint.apply(pics, rock_tint.STONE_TINT)
  assert_eq(out, pics, "returns the same table")
  for i, s in ipairs(pics) do
    assert_true(s.tint ~= nil, "variation " .. i .. " has a tint")
    assert_eq(s.tint.r, rock_tint.STONE_TINT.r, "variation " .. i .. " red")
    assert_eq(s.tint.g, rock_tint.STONE_TINT.g, "variation " .. i .. " green")
    assert_eq(s.tint.b, rock_tint.STONE_TINT.b, "variation " .. i .. " blue")
  end
end)

test("apply tints every layer of a layered sprite", function()
  local pics = {
    { layers = { { filename = "x.png" }, { filename = "x-mask.png" } } },
  }
  rock_tint.apply(pics, rock_tint.STONE_TINT)
  for _, layer in ipairs(pics[1].layers) do
    assert_true(layer.tint ~= nil, "layer has a tint")
    assert_eq(layer.tint.b, rock_tint.STONE_TINT.b, "layer blue")
  end
  assert_true(pics[1].tint == nil, "container sprite is not itself tinted when it has layers")
end)

test("each sprite gets its OWN tint table (no shared alias)", function()
  local pics = {
    { filename = "a.png" },
    { filename = "b.png" },
  }
  rock_tint.apply(pics, rock_tint.STONE_TINT)
  assert_true(pics[1].tint ~= pics[2].tint, "tints are distinct tables")
  -- Mutating one must not bleed into the other or into the source constant.
  pics[1].tint.r = 0.123
  assert_eq(pics[2].tint.r, rock_tint.STONE_TINT.r, "sibling unaffected")
  assert_true(rock_tint.STONE_TINT.r ~= 0.123, "source constant unaffected")
end)

test("apply errors loudly on a missing/empty pictures table", function()
  assert_true(not pcall(rock_tint.apply, nil, rock_tint.STONE_TINT), "nil pictures rejected")
  assert_true(not pcall(rock_tint.apply, {}, rock_tint.STONE_TINT), "empty pictures rejected")
  assert_true(not pcall(rock_tint.apply, { {} }, nil), "nil tint rejected")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
