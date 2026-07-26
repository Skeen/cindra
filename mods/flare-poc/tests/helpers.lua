-- Shared setup for the flare PoC integration tests.
--
-- Everything runs on a surface literally named C.SURFACE ("flare-poc"), created
-- on demand. This satisfies the `surface.name == C.SURFACE` gate the runtime
-- handlers use and guarantees the tests never touch nauvis or any other planet.

local C = require("scripts.config")

local H = {}

-- A clean, buildable flare-poc surface, wiped to a solid concrete slab each call.
-- The driver is left DISABLED (storage.fp.driver_enabled = false) so the
-- periodic handlers never perturb a test that advances ticks; tests drive the
-- flare and the sweep explicitly.
function H.surface()
  local s = game.surfaces[C.SURFACE]
  if not s then
    s = game.create_surface(C.SURFACE, { width = 512, height = 128 })
    s.request_to_generate_chunks({ 0, 0 }, 6)
    s.force_generate_chunk_requests()
  end
  for _, e in pairs(s.find_entities_filtered({ area = { { -120, -40 }, { 120, 40 } } })) do
    if e.type ~= "character" then e.destroy() end
  end
  local tiles = {}
  for x = -110, 110 do
    for y = -30, 30 do
      tiles[#tiles + 1] = { name = "refined-concrete", position = { x, y } }
    end
  end
  s.set_tiles(tiles)
  -- The flare's fixed multiplier; the daytime is set per-phase by flare.apply.
  s.solar_power_multiplier = C.SOLAR_MULT
  s.freeze_daytime = true
  return s
end

function H.reset()
  storage.fp = { driver_enabled = false }
end

function H.set_consumption(w)
  storage.fp = storage.fp or {}
  storage.fp.consumption_w = w
end

-- Substations wired into ONE network across the work band. Solar panels are 3x3
-- and need a real pole to get an electric_network_id at all; substations (supply
-- radius 9, wire reach 18) blanket the area so every panel/sink placed in the
-- band lands on the same grid. Spacing 16 < wire reach so they auto-connect.
function H.grid(surface, x_from, x_to, y)
  y = y or 0
  local subs = {}
  local x = x_from
  while x <= x_to do
    subs[#subs + 1] = surface.create_entity({
      name = "substation", position = { x, y }, force = "player",
    })
    x = x + 16
  end
  return subs
end

function H.panel(surface, pos)
  return surface.create_entity({ name = C.PANEL, position = pos, force = "player" })
end

function H.capacitor(surface, pos)
  return surface.create_entity({ name = C.CAPACITOR, position = pos, force = "player" })
end

function H.battery(surface, pos)
  return surface.create_entity({ name = C.BATTERY, position = pos, force = "player" })
end

function H.dissipator(surface, pos)
  return surface.create_entity({ name = C.DISSIPATOR, position = pos, force = "player" })
end

function H.measure_sink(surface, pos)
  return surface.create_entity({ name = C.MEASURE_SINK, position = pos, force = "player" })
end

-- A row of panels along the sunward axis (increasing x = more sunward) at a
-- fixed y. Panels are 3x3, so step defaults to 4 to leave a tile gap.
function H.panel_row(surface, count, x0, y, step)
  step = step or 4
  local list = {}
  for i = 1, count do
    list[i] = H.panel(surface, { x0 + (i - 1) * step, y })
  end
  return list
end

return H
