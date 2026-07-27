-- Mass-driver runtime: the charge -> fire -> deliver loop.
--
-- A `mass-driver` (visible container) is paired at build time with a hidden
-- `mass-driver-charger` (accumulator) on its own tile. The charger fills from
-- the electric grid. Once it is full AND the driver holds a projectile shell
-- AND some cargo AND a same-force space platform (in orbit) exists to receive it,
-- the driver FIRES: it spends the whole buffer, consumes one shell, and delivers
-- a shot of cargo across surfaces into the platform's hub -- the same place normal
-- rocket cargo lands (defines.inventory.hub_main). Then it must recharge before
-- firing again (naturally bursty: charge up, fire, charge up again).
--
-- There is NO platform-side structure: a launch behaves like a vanilla rocket
-- delivering to a platform, reusing the vanilla launch-to-platform destination.
--
-- The only launch costs are electricity (the buffer) and one native-metal
-- shell. No rocket fuel, no chemistry.

local M = {}

M.DRIVER = "mass-driver"
M.CHARGER = "mass-driver-charger"
M.SHELL = "mass-driver-shell"

M.SHOT_CAPACITY = 100        -- max cargo items moved per shot
M.SHELL_PER_SHOT = 1         -- native shells consumed per shot
M.FULL_FRACTION = 0.99       -- "charged" means buffer >= this fraction of full
M.FIRE_INTERVAL = 20         -- ticks between fire checks

local function ensure_storage()
  storage.md_drivers = storage.md_drivers or {}   -- [unit_number] = {driver=, charger=}
end

-- Spawn the hidden charger that overlaps a freshly built driver.
local function attach_charger(driver)
  local charger = driver.surface.create_entity({
    name = M.CHARGER,
    position = driver.position,
    force = driver.force,
    create_build_effect_smoke = false,
  })
  if charger then
    charger.destructible = false
    charger.operable = false
  end
  storage.md_drivers[driver.unit_number] = { driver = driver, charger = charger }
  return charger
end

local function on_build_event(event)
  local e = event.entity
  if not (e and e.valid) then return end
  ensure_storage()
  if e.name == M.DRIVER then
    attach_charger(e)
  end
end

local function on_remove_event(event)
  local e = event.entity
  if not (e and e.valid) then return end
  ensure_storage()
  if e.name == M.DRIVER then
    local rec = storage.md_drivers[e.unit_number]
    if rec and rec.charger and rec.charger.valid then rec.charger.destroy() end
    storage.md_drivers[e.unit_number] = nil
  end
end

-- The shot's destination: a same-force space platform hub, the vanilla place
-- rocket cargo lands (defines.inventory.hub_main). Prefer a platform orbiting the
-- driver's own planet; fall back to any same-force platform with a live hub. Nil
-- when the force owns no platform with a hub yet -- then nothing launches and the
-- payload is preserved.
local function find_platform_hub(driver)
  local platforms = driver.force.platforms
  if not platforms then return nil end
  local planet_name = driver.surface.name
  local fallback = nil
  for _, platform in pairs(platforms) do
    local hub = platform.hub
    if hub and hub.valid then
      local loc = platform.space_location
      if loc and loc.name == planet_name then return hub end
      fallback = fallback or hub
    end
  end
  return fallback
end

-- Attempt to fire one driver. Returns true if a shot was launched.
local function try_fire(rec)
  local driver, charger = rec.driver, rec.charger
  if not (driver and driver.valid and charger and charger.valid) then return false end

  -- Must be fully charged (bursty: spend the whole buffer per shot).
  if charger.energy < charger.electric_buffer_size * M.FULL_FRACTION then return false end

  local inv = driver.get_inventory(defines.inventory.chest)
  if not inv then return false end
  if inv.get_item_count(M.SHELL) < M.SHELL_PER_SHOT then return false end

  -- Need a destination before consuming anything (no platform hub => no launch,
  -- payload preserved).
  local hub = find_platform_hub(driver)
  if not hub then return false end
  local hub_inv = hub.get_inventory(defines.inventory.hub_main)
  if not hub_inv then return false end

  -- Gather up to SHOT_CAPACITY of cargo (everything that is not a shell) and
  -- deliver it across surfaces into the platform hub -- like normal rocket cargo.
  local remaining = M.SHOT_CAPACITY
  local moved = 0
  for _, stack in pairs(inv.get_contents()) do
    if remaining <= 0 then break end
    if stack.name ~= M.SHELL and stack.count > 0 then
      local take = math.min(stack.count, remaining)
      local id = { name = stack.name, count = take, quality = stack.quality }
      local removed = inv.remove(id)
      if removed > 0 then
        local put = { name = stack.name, count = removed, quality = stack.quality }
        local inserted = hub_inv.insert(put)
        if inserted < removed then
          -- Hub full: return the overflow to the driver, keep it for later.
          inv.insert({ name = stack.name, count = removed - inserted, quality = stack.quality })
        end
        moved = moved + inserted
        remaining = remaining - inserted
      end
    end
  end

  -- Only spend the shell + energy if we actually launched cargo (no payload =>
  -- no launch).
  if moved > 0 then
    inv.remove({ name = M.SHELL, count = M.SHELL_PER_SHOT })
    charger.energy = 0
    return true
  end
  return false
end

local function on_fire_tick()
  ensure_storage()
  for un, rec in pairs(storage.md_drivers) do
    if rec.driver and rec.driver.valid then
      try_fire(rec)
    else
      if rec.charger and rec.charger.valid then rec.charger.destroy() end
      storage.md_drivers[un] = nil
    end
  end
end

-- Exposed for tests: fire a single driver on demand.
function M.try_fire_driver(driver)
  ensure_storage()
  local rec = storage.md_drivers[driver.unit_number]
  if not rec then return false end
  return try_fire(rec)
end

function M.init()
  ensure_storage()
end

function M.register()
  local build_events = {
    defines.events.on_built_entity,
    defines.events.on_robot_built_entity,
    defines.events.script_raised_built,
    defines.events.script_raised_revive,
  }
  if defines.events.on_space_platform_built_entity then
    build_events[#build_events + 1] = defines.events.on_space_platform_built_entity
  end
  for _, ev in pairs(build_events) do
    script.on_event(ev, on_build_event)
  end

  local remove_events = {
    defines.events.on_player_mined_entity,
    defines.events.on_robot_mined_entity,
    defines.events.on_entity_died,
    defines.events.script_raised_destroy,
  }
  if defines.events.on_space_platform_mined_entity then
    remove_events[#remove_events + 1] = defines.events.on_space_platform_mined_entity
  end
  for _, ev in pairs(remove_events) do
    script.on_event(ev, on_remove_event)
  end

  script.on_nth_tick(M.FIRE_INTERVAL, on_fire_tick)
end

return M
