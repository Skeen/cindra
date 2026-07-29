-- Plain-Lua unit test for the pure power-diode transfer maths (scripts/diode.lua).
-- Run: cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_diode.lua
--
-- The no-Factorio path. M.transfer_amount is deliberately pure (no game.* /
-- prototypes.*), so its whole surface -- the three-way min and the never-negative
-- clamp that make reverse flow impossible -- is reachable here. The factorio-test
-- in tests/test_power_diode.lua asserts the SAME behaviour under the real runtime.

package.path = package.path .. ";./?.lua;./?/init.lua"
local diode = require("scripts.diode")
local C = require("scripts.diode-config")

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

-- rate/60 joules per tick: the configurable max transfer rate, per tick.
local function cap(rate_w, dt) return rate_w / 60 * dt end

test("rate cap binds when supply and headroom are plentiful", function()
  -- Lots available, lots of headroom -> the move is exactly the rate cap.
  local rate, dt = 6e6, 10
  local move = diode.transfer_amount(1e12, 1e12, rate, dt)
  assert_eq(cap(rate, dt), move, "move must equal the rate cap")
end)

test("available supply binds below the cap", function()
  -- Only 5 J in the input buffer, cap is far larger -> move is limited to supply.
  local move = diode.transfer_amount(5, 1e12, 6e6, 10)
  assert_eq(5, move, "move cannot exceed what the input buffer holds")
end)

test("output headroom binds below the cap", function()
  -- Output nearly full: only 3 J of room -> move is limited to headroom.
  local move = diode.transfer_amount(1e12, 3, 6e6, 10)
  assert_eq(3, move, "move cannot exceed the output buffer's free space")
end)

test("no supply, no move (one-way: nothing flows back)", function()
  local move = diode.transfer_amount(0, 1e12, 6e6, 10)
  assert_eq(0, move, "an empty input buffer transfers nothing")
end)

test("negative headroom clamps to zero, never reverses", function()
  -- A saturated / over-full output must never produce a negative (reverse) move.
  local move = diode.transfer_amount(1e12, -100, 6e6, 10)
  assert_eq(0, move, "a full output must clamp to zero, not run backwards")
end)

test("move scales linearly with dt while rate-bound", function()
  local rate = 6e6
  local m1 = diode.transfer_amount(1e12, 1e12, rate, 1)
  local m10 = diode.transfer_amount(1e12, 1e12, rate, 10)
  assert_eq(m1 * 10, m10, "10 ticks moves 10x one tick at the same rate")
end)

test("config exposes a positive, finite transfer rate", function()
  assert_true(C.RATE_W > 0, "the PoC must ship a positive default rate")
  assert_true(C.INPUT_FLOW_W >= C.RATE_W and C.OUTPUT_FLOW_W >= C.RATE_W,
    "pole flow limits must not throttle below the script rate")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
