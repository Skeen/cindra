-- Plain-Lua unit test for the scanner's ENTITY/ITEM art wiring
-- (prototypes/scanner.lua, ci-0e8: the user-supplied radio-station set).
-- Run: cd mods/env-scanner && nix shell nixpkgs#lua -c lua unit-tests/test_scanner_graphics.lua
--
-- The Factorio runtime API does not expose an entity/item prototype's sprite or
-- icon FILE paths, so the in-engine test (tests/test_scanner.lua) cannot assert
-- the art is wired -- only that the mod LOADS and that the animated overlay
-- renders. This test closes the prototype-shape gap: it stubs the data stage,
-- requires the real prototype module, and asserts the body/shadow/glow static
-- layers, the two animated AnimationPrototypes (body + emissive glow), the icon,
-- and that every referenced PNG actually ships. A renamed/removed asset, an
-- un-wired layer, or a dropped animation fails here.

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

-- === Static preview sprite: body / shadow / glow layers =====================
test("scanner entity wires a 3-layer static sprite (body + shadow + glow)", function()
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

-- === ci-ijk: the emission layers MUST blend additive (the black-box cause) ===
test("static emission layer blends additive so it never paints a black box", function()
  -- SAME root cause as the ci-036 lava-manufacturer bug (verified in-engine for
  -- the scanner too): the emission strip is FULLY OPAQUE (alpha 1 everywhere)
  -- with a black background and only bright openings. draw_as_glow does NOT
  -- change the blend op, so without blend_mode = "additive" the opaque black is
  -- drawn straight over the body -> a solid black box (the user's symptom).
  -- Fails on the pre-fix spec (blend_mode == nil), passes on the fix.
  local layers = proto("constant-combinator", C.SCANNER).sprites.layers
  local glow
  for _, l in ipairs(layers) do if l.draw_as_glow then glow = l end end
  assert_true(glow ~= nil, "a draw_as_glow (emission) layer must exist")
  assert_eq("additive", glow.blend_mode,
    "static emission layer must set blend_mode = 'additive' (opaque black bg else boxes the body)")
end)

-- === Animated overlay prototypes (drawn on placed scanners) ==================
-- These are what make the building actually animate in-world. Both must be full
-- 20-frame / 8-wide strips at the same geometry as the static body so they land
-- exactly on top of it; the glow strip must be drawn as a glow.
local function check_anim(name, strip_hint)
  local a = proto("animation", name)
  assert_true(a ~= nil, "animation prototype must be registered: " .. name)
  assert_eq("animation", a.type, "must be an AnimationPrototype")
  assert_true(a.filename:find(strip_hint) ~= nil,
    "animation must use the " .. strip_hint .. " strip, got: " .. tostring(a.filename))
  assert_eq(160, a.width, "frame width matches the static body")
  assert_eq(290, a.height, "frame height matches the static body")
  assert_eq(20, a.frame_count, "strip is a 20-frame animation")
  assert_eq(8, a.line_length, "strip is laid out 8 frames per row")
  assert_true(a.scale ~= nil and a.shift ~= nil, "must set scale + shift (aligns with the body)")
  assert_true(ships(a.filename), "animation PNG must ship: " .. a.filename)
  return a
end

test("body overlay is a non-empty 20-frame animation of the body strip", function()
  local a = check_anim(C.BODY_ANIM, "radio%-station%-hr%-animation")
  assert_true(not a.draw_as_glow, "the body overlay is the opaque, lit layer")
end)

test("glow overlay is a non-empty 20-frame draw_as_glow animation of the emission strip", function()
  local a = check_anim(C.GLOW_ANIM, "emission")
  assert_true(a.draw_as_glow == true, "the emission overlay must draw as a glow")
  -- ci-ijk: the in-world glow overlay carries the same opaque emission strip, so
  -- it needs additive blending too or it boxes the animated body at runtime.
  assert_eq("additive", a.blend_mode,
    "glow overlay must set blend_mode = 'additive' (opaque black bg else boxes the body)")
end)

-- === ci-ijk: the scanner is a 2x2 building (Overseer) =======================
test("scanner entity has a 2x2 footprint", function()
  local e = proto("constant-combinator", C.SCANNER)
  assert_eq(2, e.tile_width, "scanner must be 2 tiles wide")
  assert_eq(2, e.tile_height, "scanner must be 2 tiles tall")
  local sb = e.selection_box
  assert_true(sb ~= nil, "selection_box must be set")
  local w = sb[2][1] - sb[1][1]
  local h = sb[2][2] - sb[1][2]
  assert_true(math.abs(w - 2) < 0.01 and math.abs(h - 2) < 0.01,
    "selection box must be 2x2, got " .. w .. "x" .. h)
  local cb = e.collision_box
  assert_true(cb ~= nil, "collision_box must be set")
  local cw = cb[2][1] - cb[1][1]
  assert_true(cw > 1.0 and cw <= 2.0, "collision box must span most of the 2x2 (width " .. cw .. ")")
end)

-- === ci-6jz: the model must not float (shadow re-seated under the body) ======
-- The ground shadow was stranded at the OLD (30, 6) tuning when ci-ijk moved the
-- body down and grew it, so the building read as floating with a detached shadow.
-- It is now re-seated under the legs at (2, -18) px. Guards the regression: the
-- stale value had a large +x (0.94 tiles) and a positive y (below tile centre),
-- while a grounded shadow that tracks the raised body sits roughly centred and
-- ABOVE tile centre (negative y). Fails on the pre-fix (30, 6), passes on the fix.
test("ground shadow is re-seated under the raised body (not the stale 1x1 offset)", function()
  local layers = proto("constant-combinator", C.SCANNER).sprites.layers
  local shadow
  for _, l in ipairs(layers) do if l.draw_as_shadow then shadow = l end end
  assert_true(shadow ~= nil, "a draw_as_shadow layer must exist")
  local sx, sy = shadow.shift[1], shadow.shift[2]
  assert_true(math.abs(sx) < 0.3,
    "shadow must sit roughly under the body centre, not far to the side (x=" .. sx .. ")")
  assert_true(sy < 0,
    "shadow must track the up-shifted body (negative y), not the stale +y (y=" .. sy .. ")")
end)

-- === ci-6jz: rotation is disabled ===========================================
-- The body is one Sprite4Way that reads the same from every side, so rotation is
-- pointless; the not-rotatable flag removes it (supports_direction is asserted
-- false in the in-engine test). Fails on main (no such flag).
test("scanner entity carries the not-rotatable flag", function()
  local e = proto("constant-combinator", C.SCANNER)
  assert_true(e.flags ~= nil, "flags must be set")
  local has = false
  for _, f in ipairs(e.flags) do if f == "not-rotatable" then has = true end end
  assert_true(has, "scanner must carry the 'not-rotatable' flag (rotation disabled)")
end)

-- === ci-6jz: circuit-wire attach points redesigned for the 2x2 body =========
-- The clone inherited the 1x1 constant-combinator connection points, which
-- floated mid-structure on the 2x2 building. They are re-seated at the front
-- base. Guards: the field is overridden (4 direction entries), each carries a
-- red/green wire + shadow point INSIDE the 2x2 selection box, and red != green.
test("circuit-wire connection points are re-seated inside the 2x2 footprint", function()
  local e = proto("constant-combinator", C.SCANNER)
  local pts = e.circuit_wire_connection_points
  assert_true(pts ~= nil, "circuit_wire_connection_points must be set")
  assert_eq(4, #pts, "one entry per direction (identical; body is a Sprite4Way)")
  local function in_box(p)
    -- selection box is 2x2 -> [-1, 1] on each axis; a real attach point is well inside.
    return math.abs(p[1]) < 1.0 and math.abs(p[2]) < 1.0
  end
  for i, entry in ipairs(pts) do
    assert_true(entry.wire ~= nil and entry.wire.red ~= nil and entry.wire.green ~= nil,
      "entry " .. i .. " must define red + green wire points")
    assert_true(entry.shadow ~= nil and entry.shadow.red ~= nil and entry.shadow.green ~= nil,
      "entry " .. i .. " must define red + green wire-shadow points")
    assert_true(in_box(entry.wire.red) and in_box(entry.wire.green),
      "entry " .. i .. " wire points must sit inside the 2x2 footprint")
    -- red and green must be distinct so the two wires do not overlap.
    assert_true(entry.wire.red[1] ~= entry.wire.green[1] or entry.wire.red[2] ~= entry.wire.green[2],
      "entry " .. i .. " red and green wire points must differ")
  end
end)

-- ci-ijk (Overseer): the item sorts right after the programmable-speaker, in the
-- circuit-network subgroup. The real cross-prototype ordering (against vanilla
-- speaker/display-panel) is asserted in the integration test
-- (mods/cindra/tests/test_env_scanner.lua); here we guard the wiring locally.
test("scanner item sits in the circuit-network subgroup, ordered after the speaker", function()
  local item = proto("item", C.SCANNER)
  assert_eq("circuit-network", item.subgroup, "item must be in the circuit-network subgroup")
  -- programmable-speaker is order "d[other]-b[programmable-speaker]"; the scanner
  -- must sort after it (and the display panel's "s[..]" sorts after the scanner).
  assert_true(item.order > "d[other]-b[programmable-speaker]",
    "scanner order (" .. tostring(item.order) .. ") must sort after the programmable-speaker")
  assert_true(item.order < "s[display-panel]",
    "scanner order (" .. tostring(item.order) .. ") must sort before the display panel")
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

-- === ci-kuu: bespoke virtual-signal icons ===================================
-- Every scanner signal must draw its OWN bespoke icon that ships in this mod,
-- not a base-game placeholder. Fails on main (icons were __base__/graphics/...
-- accumulator/solar-panel/etc.), passes on the fix.
local readings = require("scripts.readings")

test("all seven signals are registered as virtual-signal prototypes", function()
  local n = 0
  for _, name in pairs(readings.SIGNALS) do
    n = n + 1
    assert_true(proto("virtual-signal", name) ~= nil,
      "virtual-signal must be registered: " .. name)
  end
  assert_eq(7, n, "readings.SIGNALS must define exactly seven signals")
end)

test("every signal icon is a bespoke env-scanner asset, never a base placeholder", function()
  for _, name in pairs(readings.SIGNALS) do
    local sig = proto("virtual-signal", name)
    assert_true(sig.icon ~= nil, "signal must set an icon: " .. name)
    assert_true(sig.icon:find("__base__") == nil,
      "signal " .. name .. " must NOT use a base-game placeholder, got: " .. sig.icon)
    assert_true(sig.icon:find("__env%-scanner__/graphics/icons/signals/") ~= nil,
      "signal " .. name .. " must use a bespoke signals/ icon, got: " .. sig.icon)
    assert_eq(64, sig.icon_size, "signal icon_size must be 64: " .. name)
    assert_true(ships(sig.icon), "signal icon PNG must ship: " .. sig.icon)
  end
end)

test("each signal's icon file is named for its signal (path derives from name)", function()
  -- Guards the "derive path from name" wiring: a mismatch between the signal
  -- name and its shipped PNG stem (e.g. a rename on one side only) fails here.
  for _, name in pairs(readings.SIGNALS) do
    local sig = proto("virtual-signal", name)
    assert_true(sig.icon:find("/" .. name:gsub("%-", "%%-") .. "%.png$") ~= nil,
      "signal " .. name .. " icon must be <name>.png, got: " .. sig.icon)
  end
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
