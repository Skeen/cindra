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
-- WHAT IT ALSO DOES NOW (ci-8wu, relocated by ci-q6nh): hands out a MINIMAL
-- physical starting KIT -- the two machines that are painful to hand-bootstrap
-- plus basic power, so a from-scratch Cindra start is immediately playable
-- instead of grinding the first foundry + power by hand. The kit only EASES the
-- opening; it is not a full economy (that traversal is ci-uex).
--
-- The kit is loaded INTO THE CRASH-SITE SPACESHIP APS already drops on the
-- surface (ci-q6nh), not into a separate chest beside it: the wreck is where a
-- player instinctively looks for their salvage, and one landmark reads better
-- than two. The ship only has five inventory slots, so its default cargo -- 8
-- firearm magazines -- is stripped to make room; Cindra has no biters at start,
-- so the ammo was dead weight anyway. Stocked once, via on_player_created + an
-- on_nth_tick(30) poll (APS creates the crash site inside its own
-- on_player_created handler, so the ship may not exist yet when ours runs).
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
-- Bootstrap starting KIT (ci-8wu; moved into the crashed ship by ci-q6nh).
-- MINIMAL by design: the two machines that are genuinely painful to
-- hand-bootstrap on a from-scratch Cindra start (a foundry -- a Vulcanus-only
-- machine you would otherwise import -- and the lava caster that feeds it), plus
-- enough basic power to run them. The pre-research above unlocks the RECIPES;
-- this hands over the first physical MACHINES so the opening is playable from
-- tick zero instead of a hand-craft grind. Everything here is a vanilla or
-- Cindra item obtained through the normal runtime API -- no prototype is
-- mutated, so no other planet is touched.
-- ===========================================================================

-- The wreck APS lands on the start surface. Its container inventory is where the
-- kit goes, so the player finds their salvage where they look for it.
local KIT_SHIP = "crash-site-spaceship"

-- The kit itself. Keep this SHORT -- it eases the opening, it is not an economy.
-- One foundry + one lava caster is the whole point (the metal spine you cannot
-- easily hand-build); the rest is just enough solar to power them past nightfall.
--
-- HARD CONSTRAINT: `crash-site-spaceship` has FIVE inventory slots, so the kit is
-- at most five stacks (and the ship's default ammo has to go, see strip_ammo).
-- Anything past that is silently dropped on insert, hence the test that every
-- entry below actually arrives.
local KIT = {
  { name = "foundry",                  count = 1 },
  { name = "cindra-lava-manufacturer", count = 1 },
  { name = "solar-panel",              count = 3 },
  { name = "accumulator",              count = 2 },
  { name = "small-electric-pole",      count = 8 },
}

-- The crashed ship arrives holding 8 firearm magazines (base freeplay's ship
-- cargo, which APS forwards). Cindra's opening has nothing to shoot, and those
-- magazines occupy a slot the kit needs -- so every ammo stack comes out. Written
-- against the item TYPE rather than the magazine's name so a mod that swaps the
-- ship's ammo cannot quietly eat a kit slot.
local function strip_ammo(inv)
  for _, item in pairs(inv.get_contents()) do
    local proto = prototypes.item[item.name]
    if proto and proto.type == "ammo" then
      inv.remove({ name = item.name, count = item.count, quality = item.quality })
    end
  end
end

-- Load the kit into `ship`. Returns true when the ship was stocked. This is the
-- single source of truth for the kit -- both the runtime path below and the test
-- seam call it, so the tested code path IS the shipped one.
local function stock_ship(ship)
  if not (ship and ship.valid) then return false end
  local inv = ship.get_inventory(defines.inventory.chest)
  if not inv then return false end
  strip_ammo(inv)
  for _, stack in ipairs(KIT) do
    inv.insert({ name = stack.name, count = stack.count })
  end
  return true
end

local function find_kit_ship(surface)
  return surface.find_entities_filtered({ name = KIT_SHIP, limit = 1 })[1]
end

-- Fallback for a start with the crash site turned OFF (freeplay's
-- `disable_crashsite`, which APS honours): there is no ship to stock, so hand the
-- kit straight to the player rather than strand a from-scratch start with nothing.
-- Still no chest entity -- the kit is never a separate landmark.
local function give_kit_to_player(player)
  local inv = player.get_main_inventory()
  if not inv then return false end
  for _, stack in ipairs(KIT) do
    inv.insert({ name = stack.name, count = stack.count })
  end
  return true
end

-- How long to wait for APS to create the crash site before falling back to the
-- player's inventory. APS builds it inside its own on_player_created handler, so
-- in practice the ship is there on the first or second poll; this is only the
-- "there will never be a ship" escape hatch.
local KIT_SHIP_GRACE_TICKS = 300

-- Hand the kit to a freshly-landed player. Idempotent (storage.cindra_kit_given
-- guards against a second helping) and defensive: the Cindra surface and the
-- wreck on it are both created during APS's own on_player_created handler, so we
-- bail out (returning false = "retry later") until the ship actually exists.
-- Returns true when there is nothing more to do (stocked, or not applicable).
local function try_give_kit(player)
  if storage.cindra_kit_given then return true end
  if not (player and player.valid) then return true end

  local surface = game.get_surface("cindra")
  if surface then
    local ship = find_kit_ship(surface)
    if ship then
      stock_ship(ship)
      storage.cindra_kit_given = true
      return true
    end
  end

  -- Only bank the fallback once it actually landed: mid-cutscene the player has no
  -- character, so there is no main inventory to insert into yet. Keep retrying
  -- rather than marking the kit "given" into thin air.
  if game.tick >= (storage.cindra_kit_deadline or 0) and give_kit_to_player(player) then
    storage.cindra_kit_given = true
    return true
  end
  return false
end

-- A player landing: on a Cindra start, stock the wreck as soon as the player is
-- created; if the ship is not there yet, remember the player and let the poll
-- below finish. On ANY OTHER start this is where the whole kit is refused -- the
-- `is_cindra_start()` line below is the ONLY thing standing between a normal
-- Nauvis game and a free foundry.
--
-- Factored out of the event handler so the gate is reachable from the test seam
-- (ci-e9sj): the suite can drive a landing on both sides of the gate and watch
-- what the world does, instead of taking the guard's word for it. The runtime
-- path calls this exact function, so the tested path is the shipped one.
local function on_player_landed(player_index)
  if not is_cindra_start() then return false end
  local player = game.get_player(player_index)
  storage.cindra_kit_deadline = storage.cindra_kit_deadline or (game.tick + KIT_SHIP_GRACE_TICKS)
  if try_give_kit(player) == false then
    storage.cindra_kit_pending = player_index
  end
  return storage.cindra_kit_given == true
end

script.on_event(defines.events.on_player_created, function(event)
  on_player_landed(event.player_index)
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

-- Test seams. They drive the SAME stock_ship / give_kit_to_player / KIT as the
-- runtime path, so the APS suite can prove the kit contents on a headless Cindra
-- surface without faking the cargo-pod cutscene (the in-game feel of opening the
-- wreck stays a PLAYTEST item).
remote.add_interface("cindra-start", {
  -- Load the kit into the crash-site spaceship on `surface_index` (stripping its
  -- ammo first). Returns true when a ship was found and stocked.
  stock_bootstrap_ship = function(surface_index)
    local surface = game.get_surface(surface_index)
    if not surface then return false end
    return stock_ship(find_kit_ship(surface))
  end,
  -- The no-crash-site fallback: the kit goes straight into the player's inventory.
  give_bootstrap_kit_to_player = function(player_index)
    local player = game.get_player(player_index)
    if not (player and player.valid) then return false end
    return give_kit_to_player(player)
  end,
  -- The kit manifest, so the suite can assert the whole thing survives the ship's
  -- five slots instead of hard-coding a second copy of the list.
  get_bootstrap_kit = function()
    return KIT
  end,
  -- Replay a player LANDING through the gated runtime path (ci-e9sj), from a
  -- clean slate so the result never depends on whether the real
  -- on_player_created already ran in this save. Unlike the two seams above --
  -- which deliberately bypass the gate to pin the kit's CONTENTS -- this one
  -- goes through `is_cindra_start()`, so the suite can watch the world on both
  -- sides of it: a Cindra start ends up with the kit, any other start ends up
  -- with nothing. Returns true when the kit was actually delivered.
  simulate_player_landing = function(player_index)
    storage.cindra_kit_given = nil
    storage.cindra_kit_pending = nil
    storage.cindra_kit_deadline = nil
    return on_player_landed(player_index)
  end,
})
