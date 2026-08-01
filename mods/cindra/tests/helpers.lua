-- Shared setup for the Cindra integration tests.
--
-- All Cindra tests run on a surface literally named "cindra" (created on
-- demand). This satisfies the `surface.name == "cindra"` gate the runtime
-- handlers use, and guarantees the tests never touch nauvis or any other planet
-- (the never-mutate-other-planets invariant).

local C = require("scripts.flare-config")

local H = {}

-- A clean, buildable Cindra surface. Generated once, then wiped and paved with a
-- solid slab of land in the work area on each call.
function H.cindra_surface()
  local s = game.surfaces["cindra"]
  if not s then
    if game.planets and game.planets["cindra"] then
      s = game.planets["cindra"].create_surface()
    else
      s = game.create_surface("cindra", { width = 256, height = 256 })
    end
    s.request_to_generate_chunks({ 0, 0 }, 4)
    s.force_generate_chunk_requests()
  end

  for _, e in pairs(s.find_entities_filtered({ area = { { -60, -60 }, { 60, 60 } } })) do
    -- Keep the character AND the worldgen lava-heat emitters (§ freeze, ci-bvk): the
    -- latter are ambient infrastructure the map-gen placed to keep this work area
    -- thawed on the entities_require_heating surface, NOT test clutter. Wiping them
    -- would refreeze every machine a test then builds here.
    if e.type ~= "character" and e.name ~= "cindra-lava-heat" then e.destroy() end
  end

  local tiles = {}
  for x = -45, 45 do
    for y = -45, 45 do
      tiles[#tiles + 1] = { name = "refined-concrete", position = { x, y } }
    end
  end
  s.set_tiles(tiles)
  return s
end

-- ===========================================================================
-- Power-system helpers (§15 items 7-9). The flare tests build panels + sinks on
-- the Cindra surface and drive the flare / damage sweeps EXPLICITLY, so the
-- periodic driver must stay disabled (storage.cindra_driver_enabled = false)
-- during ticks. reset() does that and clears the flare/consumption state.
-- ===========================================================================

function H.power_reset()
  storage.cindra_driver_enabled = false
  storage.cindra_consumption_w = nil
  storage.cindra_flare = nil
  -- Clear the sporadic-flare schedule so each test starts clean and can pin its
  -- own deterministic anchor via flare.set_schedule.
  storage.cindra_flare_sched = nil
end

function H.set_consumption(w)
  storage.cindra_consumption_w = w
end

-- A substation column along the SUNWARD (Y) axis at `x` (default 0), spanning
-- [y0, y1]. Substations (supply radius 9, wire reach 18) at spacing 12 all
-- auto-connect into ONE network and blanket the column, so every panel/sink
-- placed within radius 9 in x lands on the same grid. A final substation at y1
-- tops up the far end when the last step falls short.
function H.grid(surface, y0, y1, x)
  x = x or 0
  local subs = {}
  local last = nil
  local y = y0
  while y <= y1 do
    subs[#subs + 1] = surface.create_entity({ name = "substation", position = { x, y }, force = "player" })
    last = y
    y = y + 12
  end
  if last ~= nil and (y1 - last) >= 3 then
    subs[#subs + 1] = surface.create_entity({ name = "substation", position = { x, y1 }, force = "player" })
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

-- A column of panels along the SUNWARD axis (increasing Y = more sunward) at a
-- fixed x. Panels are 3x3, so step defaults to 4 to leave a tile gap. row[count]
-- is the sunmost panel (highest Y), which the disposal-deficit rule damages first.
function H.panel_col(surface, count, y0, x, step)
  x = x or 6
  step = step or 4
  local list = {}
  for i = 1, count do
    list[i] = H.panel(surface, { x, y0 + (i - 1) * step })
  end
  return list
end

return H
