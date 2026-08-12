-- Plain-Lua unit test for the pure graphics auditor (scripts/graphics-audit.lua).
-- Run:
--   cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_graphics_audit.lua
--
-- Proves the auditor distinguishes a VISIBLE entity (sprite in the engine's
-- render field) from an INVISIBLE one (sprite absent, or in the WRONG field --
-- the ci-sop capacitor bug: an accumulator whose art was on a top-level
-- `picture` instead of `chargable_graphics`). The data-stage guard
-- (prototypes/graphics-audit.lua) runs this same logic against real prototypes.

package.path = package.path .. ";./?.lua;./?/init.lua"
local audit = require("scripts.graphics-audit")

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

-- A minimal valid layered Sprite (the shape entity_art produces).
local function sprite(path)
  return { layers = { { filename = path, width = 256, height = 256 } } }
end

test("a top-level picture on an accumulator is NOT visible (the ci-sop bug)", function()
  -- Exactly the pre-fix capacitor: chargable_graphics dropped, art on `picture`.
  local proto = { picture = sprite("__cindra__/graphics/entity/capacitor/capacitor.png") }
  assert_false(audit.is_visible(proto, "accumulator"),
    "accumulator art in the wrong field must read as invisible")
end)

test("an accumulator with chargable_graphics.picture IS visible (the fix)", function()
  local proto = { chargable_graphics = { picture = sprite("__cindra__/graphics/entity/capacitor/capacitor.png") } }
  assert_true(audit.is_visible(proto, "accumulator"),
    "accumulator art in chargable_graphics must render")
end)

test("an accumulator with no graphics at all is invisible", function()
  assert_false(audit.is_visible({}, "accumulator"))
  assert_false(audit.is_visible({ chargable_graphics = {} }, "accumulator"),
    "empty chargable_graphics has no sprite")
end)

test("assembling-machine / furnace visibility keys off graphics_set", function()
  local q = { graphics_set = { animation = sprite("q.png") } }
  assert_true(audit.is_visible(q, "assembling-machine"))
  assert_true(audit.is_visible(q, "furnace"))
  assert_false(audit.is_visible({ graphics_set = {} }, "assembling-machine"))
end)

test("reactor / e-e-interface / simple-entity / container visibility", function()
  assert_true(audit.is_visible({ picture = sprite("r.png") }, "reactor"))
  assert_true(audit.is_visible({ picture = sprite("d.png") }, "electric-energy-interface"))
  assert_true(audit.is_visible({ pictures = sprite("rock.png") }, "simple-entity"))
  assert_true(audit.is_visible({ picture = sprite("chest.png") }, "container"))
  assert_false(audit.is_visible({}, "reactor"))
end)

test("offenders() flags only the entities that render nothing", function()
  local raw = {
    ["accumulator"] = {
      ["cindra-capacitor"]  = { picture = sprite("wrong-field.png") },          -- invisible
      ["cindra-battery"]    = { chargable_graphics = { picture = sprite("ok.png") } }, -- visible
    },
    ["reactor"] = {
      ["cindra-heater"] = { picture = sprite("heater.png") },                   -- visible
    },
  }
  local specs = {
    { type = "accumulator", name = "cindra-capacitor" },
    { type = "accumulator", name = "cindra-battery" },
    { type = "reactor",     name = "cindra-heater" },
    { type = "accumulator", name = "cindra-missing" },                          -- absent -> invisible
  }
  local bad = audit.offenders(raw, specs)
  table.sort(bad)
  assert_eq(2, #bad, "exactly two offenders")
  assert_eq("cindra-capacitor", bad[1])
  assert_eq("cindra-missing", bad[2])
end)

test("discover() finds cindra-* entities across types and honours skip prefixes", function()
  local raw = {
    ["accumulator"] = {
      ["cindra-capacitor"] = { chargable_graphics = { picture = sprite("c.png") } },
      ["accumulator"]      = { chargable_graphics = { picture = sprite("v.png") } }, -- vanilla, ignored
    },
    ["container"] = {
      ["cindra-mass-driver"] = { picture = sprite("md.png") },  -- skipped (reworked elsewhere)
    },
    ["reactor"] = {
      ["cindra-electric-heater"] = { picture = sprite("h.png") },
    },
  }
  local specs = audit.discover(raw, { "cindra-mass-driver" })
  local names = {}
  for _, s in ipairs(specs) do names[s.name] = true end
  assert_true(names["cindra-capacitor"], "discovers the capacitor")
  assert_true(names["cindra-electric-heater"], "discovers the heater")
  assert_false(names["cindra-mass-driver"], "skips the reworked mass driver")
  assert_false(names["accumulator"], "ignores vanilla (non-cindra) entities")
end)

-- === Animated-state audit (ci-z94) =========================================
-- The ci-pru placeholders rendered fine and never moved. On a planet whose power
-- game is read by looking at which storage units are working, a still building
-- is its own bug -- so the auditor has to tell "wired an animation" apart from
-- "parked a still image in the animation field".

-- A minimal multi-frame Animation (the shape working_art produces).
local function anim(path, frames)
  return { layers = {
    { filename = path, width = 256, height = 256, repeat_count = frames or 16 },
    { filename = path, width = 256, height = 256, frame_count = frames or 16, line_length = 4 },
  } }
end

-- A player-placed building: not hidden, and the player can mine it back.
local function placed(fields)
  fields.minable = { mining_time = 0.3, result = "x" }
  return fields
end

test("has_animation() rejects a still image parked in an animation field", function()
  assert_false(audit.has_animation(sprite("still.png")),
    "a one-frame sprite is not an animation, whatever field it sits in")
  assert_false(audit.has_animation({ layers = { { filename = "s.png", frame_count = 1 } } }),
    "frame_count = 1 is a still image")
  assert_true(audit.has_animation(anim("glow.png")), "a multi-frame strip is an animation")
  assert_true(audit.has_animation({ filenames = { "a.png", "b.png" }, frame_count = 2 }),
    "a multi-file sheet is an animation")
end)

test("static_offenders() flags an accumulator that only has an idle picture", function()
  local raw = { ["accumulator"] = {
    ["cindra-capacitor"] = placed({ chargable_graphics = { picture = sprite("idle.png") } }),
  } }
  local bad = audit.static_offenders(raw, { { type = "accumulator", name = "cindra-capacitor" } })
  assert_eq(2, #bad, "both the charge and the discharge state are missing")
end)

test("static_offenders() passes an accumulator with both working animations", function()
  local raw = { ["accumulator"] = {
    ["cindra-capacitor"] = placed({ chargable_graphics = {
      picture = sprite("idle.png"),
      charge_animation = anim("charge.png"),
      discharge_animation = anim("discharge.png"),
    } }),
  } }
  assert_eq(0, #audit.static_offenders(raw, { { type = "accumulator", name = "cindra-capacitor" } }))
end)

test("static_offenders() flags a half-animated accumulator (charge only)", function()
  local raw = { ["accumulator"] = {
    ["cindra-battery"] = placed({ chargable_graphics = {
      picture = sprite("idle.png"),
      charge_animation = anim("charge.png"),
      discharge_animation = sprite("still.png"),   -- a still image, not an animation
    } }),
  } }
  local bad = audit.static_offenders(raw, { { type = "accumulator", name = "cindra-battery" } })
  assert_eq(1, #bad)
  assert_true(bad[1]:find("discharge_animation", 1, true) ~= nil,
    "names the missing state, got: " .. bad[1])
end)

test("an electric-energy-interface must animate its load, not just draw a picture", function()
  local raw = { ["electric-energy-interface"] = {
    ["cindra-dissipator"] = placed({ picture = sprite("idle.png") }),
  } }
  local specs = { { type = "electric-energy-interface", name = "cindra-dissipator" } }
  assert_eq(1, #audit.static_offenders(raw, specs), "a bare picture cannot show load")
  raw["electric-energy-interface"]["cindra-dissipator"].animation = anim("heat.png")
  assert_eq(0, #audit.static_offenders(raw, specs))
end)

test("hidden phantoms and unminable test rigs owe no animation", function()
  -- The power diode's buffer/tap helpers (hidden, deliberately draw nothing) and
  -- the flare measurement sink (unminable, factorio-test only) are not buildings
  -- the player looks at, so requiring a working light of them would be noise.
  local raw = {
    ["electric-energy-interface"] = {
      ["cindra-diode-input"] = { hidden = true, picture = sprite("empty.png") },
    },
    ["accumulator"] = {
      ["cindra-measurement-sink"] = { chargable_graphics = { picture = sprite("v.png") } },
    },
  }
  local specs = {
    { type = "electric-energy-interface", name = "cindra-diode-input" },
    { type = "accumulator", name = "cindra-measurement-sink" },
  }
  assert_eq(0, #audit.static_offenders(raw, specs))
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
