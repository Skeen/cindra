-- Plain-Lua unit test for the scanner's ENTITY/ITEM art wiring
-- (prototypes/scanner.lua, ci-0e8: the user-supplied radio-station set).
-- Run: cd mods/env-scanner && nix shell nixpkgs#lua -c lua unit-tests/test_scanner_graphics.lua
--
-- The Factorio runtime API does not expose an entity/item prototype's sprite or
-- icon FILE paths, so the in-engine test (tests/test_scanner.lua) cannot assert
-- the art is wired -- only that the mod LOADS (which validates frame geometry
-- against the real images). This test closes that gap: it stubs the data stage,
-- requires the real prototype module, and asserts the body/shadow/glow layers,
-- the icon, and that every referenced PNG actually ships. A renamed/removed
-- asset or an un-wired layer fails here.

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

-- === Stub the Factorio data stage ==========================================
-- prototypes/scanner.lua needs `util` (deepcopy + by_pixel), the global `data`
-- (a `constant-combinator` entity + item to clone, and an :extend sink), and
-- the pure scripts.config / scripts.readings modules (loaded for real).

local function deepcopy(t)
  if type(t) ~= "table" then return t end
  local out = {}
  for k, v in pairs(t) do out[k] = deepcopy(v) end
  return out
end

package.loaded["util"] = {
  table = { deepcopy = deepcopy },
  by_pixel = function(x, y) return { x / 32, y / 32 } end,
}

-- Registry is keyed by type then name: the entity, item, and recipe all share
-- the "environmental-scanner" name, so a name-only key would collide.
local registry = {}
local data = {
  raw = {
    ["constant-combinator"] = {
      ["constant-combinator"] = { type = "constant-combinator", name = "constant-combinator", sprites = {} },
    },
    ["item"] = {
      ["constant-combinator"] = { type = "item", name = "constant-combinator" },
    },
  },
}
function data:extend(list)
  for _, proto in ipairs(list) do
    registry[proto.type] = registry[proto.type] or {}
    registry[proto.type][proto.name] = proto
  end
end
_G.data = data

require("prototypes.scanner")

local C = require("scripts.config")
local function proto(kind, name) return (registry[kind] or {})[name] end

-- Translate a Factorio mod path ("__env-scanner__/graphics/...") to a path
-- relative to the mod root (the cwd this test runs from) and check it exists.
local function ships(modpath)
  local rel = modpath:gsub("^__env%-scanner__/", "./")
  local f = io.open(rel, "rb")
  if f then f:close() return true end
  return false
end

-- === Entity body / shadow / glow layers ====================================
test("scanner entity wires a 3-layer sprite (body + shadow + glow)", function()
  local e = proto("constant-combinator", C.SCANNER)
  assert_true(e ~= nil, "scanner entity must be registered")
  assert_eq("constant-combinator", e.type, "still a constant-combinator")
  assert_true(e.sprites ~= nil and e.sprites.layers ~= nil, "sprites.layers must exist")
  assert_eq(3, #e.sprites.layers, "expected body + shadow + glow layers")
end)

test("body layer renders one 160x290 frame of the radio-station strip", function()
  local body = proto("constant-combinator", C.SCANNER).sprites.layers[1]
  assert_true(body.filename:find("radio%-station%-hr%-animation") ~= nil,
    "body must use the animation strip, got: " .. tostring(body.filename))
  -- The strip is 1280x870 = an 8-wide grid of 160x290 frames; we draw frame 0.
  assert_eq(160, body.width, "frame width")
  assert_eq(290, body.height, "frame height")
  assert_true(body.scale ~= nil, "body must set a scale")
  assert_true(body.shift ~= nil, "body must set a shift")
  assert_true(not body.draw_as_shadow and not body.draw_as_glow, "body is the lit, opaque layer")
  assert_true(ships(body.filename), "body PNG must ship: " .. body.filename)
end)

test("shadow layer is a draw_as_shadow layer from the shadow image", function()
  local layers = proto("constant-combinator", C.SCANNER).sprites.layers
  local shadow
  for _, l in ipairs(layers) do if l.draw_as_shadow then shadow = l end end
  assert_true(shadow ~= nil, "a draw_as_shadow layer must exist")
  assert_true(shadow.filename:find("shadow") ~= nil, "shadow must use the shadow image")
  assert_true(ships(shadow.filename), "shadow PNG must ship: " .. shadow.filename)
end)

test("emission layer is a draw_as_glow layer from the emission strip", function()
  local layers = proto("constant-combinator", C.SCANNER).sprites.layers
  local glow
  for _, l in ipairs(layers) do if l.draw_as_glow then glow = l end end
  assert_true(glow ~= nil, "a draw_as_glow (emission) layer must exist")
  assert_true(glow.filename:find("emission") ~= nil, "glow must use the emission strip")
  -- Emission is drawn on the SAME frame geometry as the body so it registers.
  assert_eq(160, glow.width, "glow frame width matches body")
  assert_eq(290, glow.height, "glow frame height matches body")
  assert_true(ships(glow.filename), "emission PNG must ship: " .. glow.filename)
end)

-- === Item + entity icon =====================================================
test("entity and item share the radio-station icon at icon_size 64", function()
  local e = proto("constant-combinator", C.SCANNER)
  local item = proto("item", C.SCANNER)
  assert_true(item ~= nil, "scanner item must be registered")
  for _, p in ipairs({ e, item }) do
    assert_true(p.icon and p.icon:find("radio%-station%-icon") ~= nil,
      "icon must be the radio-station icon, got: " .. tostring(p.icon))
    assert_eq(64, p.icon_size, "icon_size must match the 64px icon")
    assert_true(ships(p.icon), "icon PNG must ship: " .. p.icon)
  end
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
