-- Lethal-edge ticking damage (§4 Implementation A, §15 item 2).
--
-- This is where the ribbon axis becomes FELT. scripts/ribbon.lua is the pure
-- single source of truth for "where am I on the hot-cold axis"; this consumer
-- reads ribbon.damage_per_second(y) for every character on a Cindra surface and
-- applies that many HP/second as heat (sunward) or cold (nightward) damage. The
-- ramp (0 at the safe band edge -> max at the lethal edge) turns edge-pushing
-- into a graded risk: the best resources sit just inside the lethal band,
-- reachable briefly with mitigation gear (which cuts the damage via the
-- character's resistances), not behind a cliff.
--
-- 🚨 Scoped to `surface.name == "cindra"`: never touches a character standing on
-- any other planet. Buildings are handled separately: the nightside freeze lives
-- in scripts/building-heat.lua, and heat-side building damage is deferred (the
-- player is the teacher here).

local ribbon = require("scripts.ribbon")
local config = require("scripts.config")

local M = {}

-- Sweep cadence (ticks). on_nth_tick(N) is REPLACE-not-add, so this N must stay
-- distinct from every other periodic system's N (see scripts/driver.lua).
M.DAMAGE_INTERVAL = 20

-- ribbon.lua speaks in SEMANTIC damage kinds ("heat"/"cold") so it can stay pure
-- and game-agnostic; map them here to the concrete damage-type prototypes from
-- prototypes/damage-types.lua.
M.DAMAGE_TYPE = {
  heat = "cindra-heat",
  cold = "cindra-cold",
}

-- HP to inflict on a character at ribbon coordinate `y` over `interval_ticks`
-- ticks, plus the concrete damage-type prototype name. Pure helper (no game.*):
-- the maths is `dps * seconds`, so it is unit-testable and matches the axis
-- exactly. Returns 0, nil inside the safe band.
function M.damage_for(y, interval_ticks, cfg)
  local dps, kind = ribbon.damage_per_second(y, cfg)
  if dps <= 0 then return 0, nil end
  return dps * (interval_ticks / 60), M.DAMAGE_TYPE[kind]
end

-- One edge-damage sweep across a Cindra surface: damage every character by the
-- axis value at its own Y. `interval_ticks` defaults to M.DAMAGE_INTERVAL;
-- `cfg` (partial ribbon config) defaults to the mod settings.
function M.sweep(surface, interval_ticks, cfg)
  if not (surface and surface.valid) or surface.name ~= "cindra" then return end
  interval_ticks = interval_ticks or M.DAMAGE_INTERVAL
  cfg = cfg or config.ribbon_cfg()

  for _, char in pairs(surface.find_entities_filtered({ type = "character" })) do
    if char.valid then
      -- Read the perpendicular (hot-cold) coordinate off the axis so damage is
      -- correct in BOTH ribbon orientations (v2).
      local amount, dtype = M.damage_for(ribbon.perp(char.position, cfg), interval_ticks, cfg)
      if amount > 0 and dtype then
        -- The character's own force + resistances apply, so heat/cold-shielded
        -- gear mitigates the damage (edge-pushing), never zeroing the geography.
        char.damage(amount, char.force, dtype)
      end
    end
  end
end

return M
