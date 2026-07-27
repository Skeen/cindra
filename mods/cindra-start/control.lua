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
-- WHAT IT DOES NOT DO YET: hand out a physical starting KIT (machines, power,
-- initial items). That is the bootstrap-traversal work (ci-uex); it layers a
-- give_starting_kit / seed_ship_items pass ON TOP of this pre-research, following
-- the reference sketch below. Kept separate so the two concerns do not collide:
--
--   * give_starting_kit(player) on on_player_created, polling on on_nth_tick(30)
--     until player.character exists (APS drops the player into a cargo-pod
--     cutscene where character is briefly nil).
--   * seed_ship_items() on on_init via the "freeplay" remote to stock the wreck.
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
--     own build recipe stays pressure-locked (we use the field recipe instead),
--     but it unlocks the molten-iron/copper-from-lava recipes the economy needs.
--   * cindra-lava                   -- `1 stone + power -> 5 lava`, the spine.
--
-- The ice chain (crush oxide-asteroid-chunk -> ice + calcite; melt ice -> water in
-- the chemical plant) needs no entry here: it hangs off planet-discovery-cindra,
-- which APS removes for a Cindra start while ENABLING its unlocked recipes from
-- tick zero (vendor/any-planet-start/data-final-fixes.lua). So the crusher build +
-- vanilla crush/melt recipes are already available on an APS start (ci-3mx).
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
