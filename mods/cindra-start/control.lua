-- Runtime hook for the Cindra start. APS handles the surface swap; this file
-- makes the opening PLAYABLE from tick zero.
--
-- WHAT IT DOES NOW (ci-arw): pre-researches the technologies a start-on-Cindra
-- player must "arrive with". Cindra sits after Vulcanus in normal progression
-- (§6), so a normal player reaches the lava->metal spine already holding the
-- foundry / lava / ice-processing techs. A from-scratch start on Cindra has none
-- of that, and -- with no Vulcanus to import foundries from and no petrochemistry
-- for lubricant -- would soft-lock. Granting the tech chain (including ci-arw's
-- `cindra-improvised-metallurgy`, which unlocks the native lubricant + the
-- Cindra-buildable field foundry) lets the player crude-liquefy bootstrap coal
-- into lubricant, cast a first foundry, and reach the economy with no soft-lock.
--
-- WHAT IT ALSO DOES NOW (ci-8wu): hands out a MINIMAL physical starting KIT --
-- a landed supply chest ("capsule") pre-stocked with the two machines that are
-- painful to hand-bootstrap plus basic power, so a from-scratch Cindra start is
-- immediately playable instead of grinding the first foundry + power by hand.
-- The kit only EASES the opening; it is not a full economy (that traversal is
-- ci-uex). Placed once, near where the player lands, via on_player_created +
-- an on_nth_tick(30) poll (APS drops the player into a cargo-pod cutscene where
-- player.character is briefly nil, so we retry until the character exists and
-- the player is standing on the Cindra surface).
--
-- All of this is GATED on the Cindra start being the chosen one, so it never
-- touches a normal game: with APS absent the `aps-planet` setting does not exist,
-- and with any other planet chosen the guard is false. Nothing here mutates a
-- shared prototype; it only sets per-force runtime research state in a game that
-- is, by construction, a Cindra start.

-- The tech chain a start-on-Cindra player must arrive with to reach the
-- lava->metal economy without a soft-lock:
--   * cindra-improvised-metallurgy -- ci-arw: native lubricant (crude coal +
--     renewable silica oil) and the Cindra-buildable `cindra-field-foundry`.
--   * foundry                       -- the Vulcanus foundry tech; on Cindra its
--     own build recipe stays pressure-locked (we use the field recipe instead).
--     Since ci-669 the Cindra casting recipes ride on the cindra-lava tech, not
--     this one, but the foundry MACHINE (which runs them) still needs it.
--   * cindra-lava                   -- `1 stone + power -> 10 cindra-lava` (ci-669),
--                                      the spine; also unlocks the Cindra casting recipes.
--
-- The ice chain (mine the ice field for a fixed ice+calcite mix, ci-9l6; melt ice
-- -> water in the chemical plant) needs no entry here: mining needs no tech, and
-- the melt hangs off planet-discovery-cindra, which APS removes for a Cindra start
-- while ENABLING its unlocked recipes from tick zero
-- (vendor/any-planet-start/data-final-fixes.lua). So the vanilla ice-melting recipe
-- is already available on an APS start (ci-3mx).
local PRE_RESEARCHED = {
  "cindra-improvised-metallurgy",
  "foundry",
  "cindra-lava",
}

-- True only when Any Planet Start is installed AND Cindra is the chosen start.
-- The `aps-planet` startup setting is defined by APS itself, so its absence means
-- APS is not loaded (nothing to do).
local function is_cindra_start()
  local setting = settings.startup["aps-planet"]
  return setting ~= nil and setting.value == "cindra"
end

-- Grant the pre-researched chain to one force. Setting `researched = true`
-- fires each tech's unlock effects, enabling the recipes for that force.
local function pre_research(force)
  for _, name in ipairs(PRE_RESEARCHED) do
    local tech = force.technologies[name]
    if tech and not tech.researched then
      tech.researched = true
    end
  end
end

local function pre_research_all()
  if not is_cindra_start() then return end
  for _, force in pairs(game.forces) do
    pre_research(force)
  end
end

script.on_init(pre_research_all)
script.on_configuration_changed(pre_research_all)

-- Forces created after init (multiplayer teams, scripted forces) still get the
-- chain, so no player can end up on Cindra without the foundry path.
script.on_event(defines.events.on_force_created, function(event)
  if not is_cindra_start() then return end
  local force = event.force
  if force then pre_research(force) end
end)

-- ===========================================================================
-- Bootstrap starting KIT (ci-8wu). MINIMAL by design: the two machines that are
-- genuinely painful to hand-bootstrap on a from-scratch Cindra start (a foundry
-- -- a Vulcanus-only machine you would otherwise import -- and the lava caster
-- that feeds it), plus enough basic power to run them. The pre-research above
-- unlocks the RECIPES; this hands over the first physical MACHINES so the opening
-- is playable from tick zero instead of a hand-craft grind. Everything here is a
-- vanilla or Cindra item obtained through the normal runtime API -- no prototype
-- is mutated, so no other planet is touched.
-- ===========================================================================

-- The container the kit lands in (a plain steel chest is our "supply capsule").
local KIT_CHEST = "steel-chest"

-- The kit itself. Keep this SHORT -- it eases the opening, it is not an economy.
-- One foundry + one lava caster is the whole point (the metal spine you cannot
-- easily hand-build); the rest is just enough solar to power them past nightfall.
local KIT = {
  { name = "foundry",                  count = 1 },
  { name = "cindra-lava-manufacturer", count = 1 },
  { name = "solar-panel",              count = 3 },
  { name = "accumulator",              count = 2 },
  { name = "small-electric-pole",      count = 8 },
}

-- Place the kit chest near `position` on `surface` and stock it. Returns the
-- chest (or nil if it could not be placed). This is the single source of truth
-- for the kit -- both the runtime drop below and the test seam call it, so the
-- tested code path IS the shipped one.
local function place_kit_chest(surface, position, force)
  local pos = surface.find_non_colliding_position(KIT_CHEST, position, 30, 1) or position
  local chest = surface.create_entity({ name = KIT_CHEST, position = pos, force = force })
  if not chest then return nil end
  local inv = chest.get_inventory(defines.inventory.chest)
  for _, stack in ipairs(KIT) do
    inv.insert({ name = stack.name, count = stack.count })
  end
  return chest
end

-- Drop the kit for a freshly-landed player. Idempotent (storage.cindra_kit_given
-- guards against a second capsule) and defensive: APS drops the player through a
-- cargo-pod cutscene where `character` is briefly nil and the surface is not yet
-- Cindra, so we bail out (returning false = "retry later") until both are ready.
-- Returns true when there is nothing more to do (dropped, or not applicable).
local function try_give_kit(player)
  if storage.cindra_kit_given then return true end
  if not (player and player.valid) then return true end
  local character = player.character
  if not character then return false end            -- still in the cutscene
  local surface = player.surface
  if surface.name ~= "cindra" then return false end -- not landed on Cindra yet
  place_kit_chest(surface, character.position, player.force)
  storage.cindra_kit_given = true
  return true
end

-- On a Cindra start, try to drop the kit as soon as the player is created; if the
-- character is not ready yet, remember the player and let the poll below finish.
script.on_event(defines.events.on_player_created, function(event)
  if not is_cindra_start() then return end
  local player = game.get_player(event.player_index)
  if try_give_kit(player) == false then
    storage.cindra_kit_pending = event.player_index
  end
end)

-- The retry poll: cheap no-op once the kit is given (or on any non-Cindra game).
-- A distinct N in cindra-start's OWN script registry, so it cannot collide with
-- the main cindra mod's periodic handlers.
script.on_nth_tick(30, function()
  if storage.cindra_kit_given then return end
  local idx = storage.cindra_kit_pending
  if not idx or not is_cindra_start() then return end
  if try_give_kit(game.get_player(idx)) then
    storage.cindra_kit_pending = nil
  end
end)

-- Test seam: stock a kit chest on a chosen surface/position and return where it
-- landed. Drives the SAME place_kit_chest as the runtime drop, so the APS suite
-- can prove the kit contents on a headless Cindra surface without faking the
-- cargo-pod cutscene (the in-game drop/feel stays a PLAYTEST item). Returns the
-- chest position (LuaEntity cannot cross the remote boundary).
remote.add_interface("cindra-start", {
  spawn_bootstrap_kit = function(surface_index, position, force_name)
    local surface = game.get_surface(surface_index)
    if not surface then return nil end
    local chest = place_kit_chest(surface, position, force_name or "player")
    return chest and chest.position or nil
  end,
})
