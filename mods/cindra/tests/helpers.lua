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

-- A clean, buildable surface that is NOT Cindra: the "somewhere else" a
-- planet-locked recipe (the science pack, ci-gk4u) must refuse to be crafted on.
--
-- It is a scratch surface, so it carries the engine's DEFAULT surface properties
-- -- which are exactly Nauvis's set (gravity 10, pressure 1000, magnetic-field 90,
-- solar-power 100; base/prototypes/planet/surface-property.lua), i.e. the home
-- base a player would ship Cindra intermediates back to. Surface-condition
-- checking is ON here exactly as it is on a real planet
-- (`ignore_surface_conditions` defaults to false), so a recipe the engine refuses
-- here is a recipe it refuses for the player.
--
-- Building our own instead of on the real nauvis keeps every test off the other
-- planets' maps entirely (the never-mutate-other-planets invariant).
function H.offworld_surface()
  local s = game.surfaces["cindra-offworld"]
  if not s then
    s = game.create_surface("cindra-offworld", { width = 256, height = 256 })
    s.request_to_generate_chunks({ 0, 0 }, 4)
    s.force_generate_chunk_requests()
  end

  for _, e in pairs(s.find_entities_filtered({ area = { { -60, -60 }, { 60, 60 } } })) do
    if e.type ~= "character" then e.destroy() end
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

-- ===========================================================================
-- The "you must reach Cindra first" gate (ci-r7w4).
--
-- In normal play Cindra is a DESTINATION: its technologies hang off
-- `planet-discovery-cindra`, so none of its content is researchable until the
-- player has actually reached the planet. The Any-Planet-Start CINDRA START is a
-- different world on purpose -- the player begins ON Cindra -- so APS's
-- data-final-fixes retires the discovery tech (hides it, strips it out of every
-- prerequisite list in the game, and enables the recipes it used to hand out).
--
-- Tests that asserted the prerequisite edge unconditionally were therefore red on
-- clean main under the documented with-APS mod set: the gating they described
-- does not exist there, and never should. That made a target-side failure
-- indistinguishable from an MR's own. So the gate is asserted through the helper
-- below, which states the invariant belonging to whichever world is loaded. The
-- default assertion is UNCHANGED and unweakened: the prerequisite must be there.
-- ===========================================================================

H.DISCOVERY_TECH = "planet-discovery-cindra"

-- Is any-planet-start loaded at all? (ci-e9sj) Loaded and CHOSEN are different
-- worlds, and only the second one changes the game -- with APS present but its
-- picker left on its own default ("none"), APS's data-final-fixes returns early,
-- so nothing is stripped and cindra-start's runtime grants never fire. There are
-- therefore THREE worlds, and control.lua registers one suite per world:
--
--   1. not aps_loaded()      -> APS absent            -> test_aps_absent
--   2. aps_cindra_start()    -> Cindra is the start   -> the four start suites
--   3. loaded, not chosen    -> Cindra merely offered -> test_aps_offered
--
-- Both predicates read startup settings / active mods only, so control.lua can
-- call them at registration time.
function H.aps_loaded()
  return script.active_mods["any-planet-start"] ~= nil
end

-- True only when Cindra is the CHOSEN Any-Planet-Start start planet. `aps-planet`
-- is APS's own startup setting, so its absence means APS is not loaded at all;
-- with any other planet chosen the discovery tech survives untouched and the
-- default gate still applies. Same predicate cindra-start's control.lua uses to
-- decide whether it is running a Cindra start.
function H.aps_cindra_start()
  local setting = settings.startup["aps-planet"]
  return setting ~= nil and setting.value == "cindra"
end

-- Every technology reachable from `name` by walking prerequisites (`name` itself
-- excluded), as a set. Reachability of the whole chain, not one edge.
function H.prereq_closure(name)
  local seen, queue = {}, { name }
  while #queue > 0 do
    local tech = prototypes.technology[table.remove(queue)]
    if tech then
      for prereq in pairs(tech.prerequisites) do
        if not seen[prereq] then
          seen[prereq] = true
          queue[#queue + 1] = prereq
        end
      end
    end
  end
  return seen
end

-- A retired tech is one no player can ever research: APS hides the start
-- planet's discovery tech instead of deleting it, so it lingers in
-- `prototypes.technology` but never appears in the tech tree.
function H.tech_is_retired(name)
  local tech = prototypes.technology[name]
  return tech == nil or tech.hidden
end

-- The APS-start half of the gate: the discovery gate is gone BY DESIGN, so what
-- must hold is that it went for that reason and stranded nothing. `tech_name`
-- must still be reachable -- a Cindra tech left sitting behind the retired
-- discovery tech (or any other unresearchable one) would soft-lock the start,
-- which is exactly what this catches.
function H.assert_reachable_on_aps_start(tech_name)
  assert.is_true(H.tech_is_retired(H.DISCOVERY_TECH),
    H.DISCOVERY_TECH .. " must be retired by the APS Cindra start -- the player is already there")
  for _, tech in pairs(prototypes.technology) do
    assert.is_nil(tech.prerequisites[H.DISCOVERY_TECH],
      tech.name .. " still requires the retired " .. H.DISCOVERY_TECH .. " -- unresearchable, so a soft-lock")
  end

  local tech = prototypes.technology[tech_name]
  assert.is_not_nil(tech, tech_name .. " must still exist on an APS Cindra start")
  assert.is_false(tech.hidden, tech_name .. " must stay researchable on an APS Cindra start")
  for prereq in pairs(H.prereq_closure(tech_name)) do
    assert.is_false(H.tech_is_retired(prereq),
      tech_name .. " is stranded behind the retired " .. prereq .. " -- the APS start would soft-lock")
  end
end

-- Assert that `tech_name` is Cindra-progression content -- in EITHER world.
--   * default        -> it lists `planet-discovery-cindra` as a DIRECT
--                       prerequisite, so it cannot be researched before the
--                       player reaches the planet. `message` describes that edge.
--   * APS Cindra start -> the gate is retired and nothing is stranded behind it
--                       (see assert_reachable_on_aps_start).
function H.assert_behind_cindra_discovery(tech_name, message)
  if H.aps_cindra_start() then
    H.assert_reachable_on_aps_start(tech_name)
    return
  end
  assert.is_not_nil(prototypes.technology[tech_name].prerequisites[H.DISCOVERY_TECH], message)
end

return H
