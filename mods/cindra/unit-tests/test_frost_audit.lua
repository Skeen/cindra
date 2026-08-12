-- Plain-Lua unit test for the pure frost auditor (scripts/frost-audit.lua).
-- Run:
--   cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_frost_audit.lua
--
-- Proves the auditor catches a Cindra crafting machine that would FREEZE BARE --
-- bespoke art assigned over the clone's graphics_set, taking the inherited
-- frozen_patch with it, so the machine freezes on the nightside showing no frost
-- while every building beside it wears one. That exact bug shipped twice
-- (ci-z7nu: oxidizer + glass furnace; ci-u92y: arc furnace), caught only by a
-- human playtest. The data-stage guard (prototypes/frost-audit.lua) runs this
-- same logic against the real prototypes and errors the load.

package.path = package.path .. ";./?.lua;./?/init.lua"
local audit = require("scripts.frost-audit")

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

local function assert_eq(a, b, msg)
  if a ~= b then error((msg or "values differ") .. " (" .. tostring(a) .. " ~= " .. tostring(b) .. ")", 2) end
end

-- A machine wearing bespoke art, with and without the frost layer. Machines
-- carry a heating draw (so they freeze) unless a test says otherwise.
local function bespoke(frozen_patch, reset, heating_energy)
  return {
    heating_energy = heating_energy == nil and "100kW" or heating_energy,
    graphics_set = {
      animation = { layers = { { filename = "__cindra__/graphics/entity/x/x.png" } } },
      frozen_patch = frozen_patch,
      reset_animation_when_frozen = reset,
    },
  }
end

local FROST = { filename = "__cindra__/graphics/entity/x/x-hr-frozen.png", width = 320, height = 320 }

test("a machine whose bespoke graphics_set dropped the frost patch is an offender", function()
  assert_false(audit.has_frost(bespoke(nil, true), "assembling-machine"),
    "a graphics_set with no frozen_patch must read as freezing bare")
end)

test("a machine with a created frost patch passes", function()
  assert_true(audit.has_frost(bespoke(FROST, true), "assembling-machine"))
  assert_true(audit.has_frost(bespoke(FROST, true), "furnace"), "furnaces use the same field")
end)

test("a Sprite4Way frost patch spelled per-direction also passes", function()
  local four_way = { north = FROST, east = FROST, south = FROST, west = FROST }
  assert_true(audit.has_frost(bespoke(four_way, true), "assembling-machine"),
    "a per-direction Sprite4Way patch is still a wired frost sheen")
end)

test("an EMPTY frozen_patch table does not count as frost", function()
  assert_false(audit.has_frost(bespoke({}, true), "assembling-machine"),
    "a patch with no sprite reference draws nothing")
end)

test("a machine with no graphics_set at all is an offender", function()
  assert_false(audit.has_frost({}, "assembling-machine"))
end)

test("types with no frozen-patch field are never required to have one", function()
  -- Accumulators / containers / heat pipes have no such engine field, so the
  -- audit must not demand art that could never render.
  assert_true(audit.has_frost({}, "accumulator"), "accumulator has no frozen-patch field")
  assert_true(audit.has_frost({}, "container"), "container has no frozen-patch field")
end)

test("a frozen machine must also halt its animation (reset_animation_when_frozen)", function()
  assert_false(audit.resets_animation(bespoke(FROST, nil), "assembling-machine"),
    "a frozen machine still running its work cycle under the ice reads as alive")
  assert_true(audit.resets_animation(bespoke(FROST, true), "assembling-machine"))
end)

-- === Only machines that ACTUALLY freeze need art ============================
-- Freezing needs heating_energy > 0 (the prototype API rule, measured in-engine
-- in tests/test_frost.lua: the arc furnace and oxidizer inherit 100kW and freeze;
-- the glass furnace clears it and never does). Demanding a frost layer from a
-- machine that cannot freeze would be art no player can ever see.
test("heating_energy decides whether a machine can freeze at all", function()
  assert_true(audit.freezes({ heating_energy = "100kW" }))
  assert_true(audit.freezes({ heating_energy = "1MW" }))
  assert_true(audit.freezes({ heating_energy = 100000 }), "a numeric draw counts too")
  assert_false(audit.freezes({ heating_energy = "0kW" }), "a zero draw never freezes")
  assert_false(audit.freezes({ heating_energy = 0 }))
  assert_false(audit.freezes({}), "no heating draw at all: the machine never freezes")
end)

test("a machine that never freezes is NOT required to carry frost art", function()
  -- The glass-furnace case: bespoke art, no frost patch, heating draw cleared.
  local unheated = bespoke(nil, nil)
  unheated.heating_energy = nil
  local raw = { ["assembling-machine"] = { ["cindra-unheated-machine"] = unheated } }
  local bad = audit.offenders(raw, audit.discover(raw, {}))
  assert_eq(0, #bad, "a machine that cannot freeze needs no frost layer")
end)

-- === The standing audit: discover + offenders ===============================
test("discover enumerates EVERY cindra- crafting machine, not a hand-kept list", function()
  local raw = {
    ["assembling-machine"] = {
      ["cindra-arc-furnace"] = bespoke(FROST, true),
      ["cindra-lava-manufacturer"] = bespoke(FROST, true),
      ["assembling-machine-3"] = bespoke(nil, nil), -- vanilla: not ours to audit
    },
    ["furnace"] = { ["cindra-electrolysis-cell"] = bespoke(FROST, true) },
    ["accumulator"] = { ["cindra-capacitor"] = {} }, -- no frozen-patch field
  }
  local specs = audit.discover(raw, {})
  local names = {}
  for _, s in ipairs(specs) do names[s.name] = true end
  assert_true(names["cindra-arc-furnace"], "the arc furnace must be audited")
  assert_true(names["cindra-lava-manufacturer"], "the glass furnace must be audited")
  assert_true(names["cindra-electrolysis-cell"], "the oxidizer (a furnace) must be audited")
  assert_false(names["assembling-machine-3"], "vanilla prototypes are not ours to audit")
  assert_false(names["cindra-capacitor"], "an accumulator has no frozen-patch field to require")
  assert_eq(0, #audit.offenders(raw, specs), "a fully frosted set has no offenders")
end)

test("a NEW machine that ships without frost is caught by the standing audit", function()
  -- The whole point of discovering the class live: nobody has to remember to add
  -- the new machine to a list for the guard to fail.
  local raw = {
    ["assembling-machine"] = {
      ["cindra-arc-furnace"] = bespoke(FROST, true),
      ["cindra-brand-new-machine"] = bespoke(nil, true), -- bespoke art, frost dropped
    },
  }
  local bad = audit.offenders(raw, audit.discover(raw, {}))
  assert_eq(1, #bad, "exactly the bare machine is reported")
  assert_true(bad[1]:find("cindra-brand-new-machine", 1, true) ~= nil,
    "the offender must be named so the error says what to fix, got: " .. tostring(bad[1]))
end)

test("skip prefixes exclude a machine whose art is mid-rework", function()
  local raw = { ["assembling-machine"] = { ["cindra-mass-driver-x"] = bespoke(nil, nil) } }
  assert_eq(0, #audit.discover(raw, { "cindra-mass-driver" }), "the skipped prefix is not audited")
  assert_eq(1, #audit.discover(raw, {}), "without the skip it would be audited")
end)

print(("\n%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
