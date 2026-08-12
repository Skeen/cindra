-- Diode-shot scenario (ci-ntgh): capture in-engine screenshots of the placed
-- power diode so its RENDER can be verified for real. NOT shipped gameplay --
-- this is a render harness in the same vein as scenarios/orbit-shot (loaded only
-- via `--load-scenario cindra/diode-shot` under the headless EGL renderer, see
-- scripts/render-diode.sh).
--
-- The factorio-test harness runs the game HEADLESS, where game.take_screenshot is
-- a silent no-op, and LuaEntityPrototype exposes no graphics accessors -- so
-- neither the integration suite nor the plain-Lua unit tests can prove "nothing
-- stray is drawn on screen". This scenario closes that gap.
--
-- Four rows, each its own shot:
--   idle     -- a bare unwired diode, a vanilla power-switch as the MODEL
--               reference (the diode must read as exactly that silhouette), and
--               an unpowered assembling machine as the ALERT-ICON control (it
--               proves the shutter does capture status icons at all).
--   powered  -- source network (an infinite EEI + pole) wired to the left
--               connector, sink network (pole + a lamp load) to the right.
--   starved  -- the left connector wired to a real but DEAD network. This is the
--               ci-ntgh reproduction: the hidden input buffer sits TAP_DX tiles
--               off the device, so its unmet demand drew a no-power icon way
--               outside the device model.
--   overview -- all of it, wide, so stray geometry anywhere around the models
--               shows up.

-- The scenario runs as `__level__`, so the mod's own modules need the explicit
-- `__cindra__.` prefix (a bare "scripts.diode-config" resolves against the level).
local C = require("__cindra__.scripts.diode-config")

local IDLE_Y, POWERED_Y, STARVED_Y, WATER_Y = 0, 16, 32, 46
local AREA = { { -40, -16 }, { 40, 60 } }

local built_tick = nil

-- Lay clean, uniform ground and strip the decoratives, so anything drawn on top
-- reads unambiguously as entity graphics.
local function prepare_ground(surface)
  for _, e in pairs(surface.find_entities_filtered({ area = AREA })) do
    if e.valid and e.type ~= "character" then e.destroy() end
  end
  surface.destroy_decoratives({ area = AREA })
  local tiles = {}
  for x = AREA[1][1], AREA[2][1] do
    for y = AREA[1][2], AREA[2][2] do
      tiles[#tiles + 1] = { name = "refined-concrete", position = { x, y } }
    end
  end
  surface.set_tiles(tiles)
end

local function shoot(surface)
  local shots = {
    { tag = "idle", pos = { 4, IDLE_Y }, zoom = 2.0, res = { 900, 700 } },
    { tag = "powered", pos = { 0, POWERED_Y }, zoom = 2.0, res = { 900, 700 } },
    { tag = "starved", pos = { 0, STARVED_Y }, zoom = 2.0, res = { 900, 700 } },
    { tag = "water", pos = { 0, WATER_Y }, zoom = 2.0, res = { 900, 700 } },
    { tag = "overview", pos = { 0, 20 }, zoom = 0.55, res = { 1300, 1600 } },
  }
  for _, s in ipairs(shots) do
    game.take_screenshot({
      surface = surface,
      position = s.pos,
      zoom = s.zoom,
      resolution = s.res,
      path = "diode-" .. s.tag .. ".png",
      daytime = 0.0,
      force_render = true,
      anti_alias = true,
      show_entity_info = false,
    })
  end
end

local function build_scene()
  local surface = game.surfaces[1]
  local force = game.forces["player"]

  -- Get the character out of frame: it would otherwise stand on the diode.
  for _, p in pairs(game.players) do
    if p.character then p.character.destroy() end
  end
  prepare_ground(surface)

  local function build(name, pos)
    return surface.create_entity({ name = name, position = pos, force = force, raise_built = true })
  end
  local function copper(a, a_id, b, b_id)
    a.get_wire_connector(a_id, true).connect_to(b.get_wire_connector(b_id, true), false, defines.wire_origin.player)
  end
  local LEFT = defines.wire_connector_id.power_switch_left_copper
  local RIGHT = defines.wire_connector_id.power_switch_right_copper
  local POLE = defines.wire_connector_id.pole_copper

  -- (1) IDLE row: bare diode + model reference + alert-icon control.
  build(C.DEVICE, { 0, IDLE_Y })
  build("power-switch", { 5, IDLE_Y })
  -- Alert-icon control: an inserter on NO network at all. In game this wears the
  -- red "not connected to an electric network" plug. If it is bare in the shot,
  -- the shutter does not capture status icons and the diode shots cannot be read
  -- as evidence either way.
  build("inserter", { 9, IDLE_Y })

  -- (2) POWERED row: infinite source on the left, a real load on the right.
  do
    local dev = build(C.DEVICE, { 0, POWERED_Y })
    local src_pole = build("medium-electric-pole", { -8, POWERED_Y })
    local sink_pole = build("medium-electric-pole", { 8, POWERED_Y })
    local gen = build("electric-energy-interface", { -11, POWERED_Y })
    gen.power_production = 1e6
    build("small-lamp", { 11, POWERED_Y })
    copper(dev, LEFT, src_pole, POLE)
    copper(dev, RIGHT, sink_pole, POLE)
  end

  -- (3) STARVED row: both sides wired to real but DEAD networks (poles only, no
  -- generation). The input buffer's unmet demand is what drew the floating icon.
  do
    local dev = build(C.DEVICE, { 0, STARVED_Y })
    local src_pole = build("medium-electric-pole", { -8, STARVED_Y })
    local sink_pole = build("medium-electric-pole", { 8, STARVED_Y })
    -- Second control: an inserter on the DEAD source network, in frame. In game
    -- it wears the yellow "no power" bolt -- the same icon the hidden input
    -- buffer draws, so it calibrates what the diode row should look like.
    build("inserter", { -5, STARVED_Y })
    build("small-lamp", { 11, STARVED_Y })
    copper(dev, LEFT, src_pole, POLE)
    copper(dev, RIGHT, sink_pole, POLE)
  end

  -- (4) WATER row: the tap poles are cloned from the small-electric-pole, which
  -- ships a water_reflection, so a blanked-but-uncleared tap still casts a POLE
  -- reflection on water TAP_DX tiles either side of the device -- the leaked
  -- model, back on screen. Flood exactly the tap columns to expose it. NOTE: the
  -- headless llvmpipe renderer used by scripts/render-diode.sh draws no water
  -- reflections at all, so this row reads clean either way there; it is worth
  -- looking at when running the scenario on a real GPU. The removal itself is
  -- asserted at the data stage in unit-tests/test_power_diode_graphics.lua.
  do
    local tiles = {}
    for _, side in ipairs({ -1, 1 }) do
      for x = C.TAP_DX - 2, C.TAP_DX + 2 do
        for y = WATER_Y - 3, WATER_Y + 3 do
          tiles[#tiles + 1] = { name = "water", position = { side * x, y } }
        end
      end
    end
    surface.set_tiles(tiles)
    build(C.DEVICE, { 0, WATER_Y })
  end

  return surface
end

script.on_event(defines.events.on_tick, function(ev)
  -- Let world init settle before building, then give the diode sweep a few
  -- seconds to reach its steady state before the shutter.
  if ev.tick < 60 then return end
  if not built_tick then
    built_tick = ev.tick
    storage.surface = build_scene()
    return
  end
  if ev.tick < built_tick + 300 then return end
  script.on_event(defines.events.on_tick, nil)
  shoot(storage.surface)
end)
