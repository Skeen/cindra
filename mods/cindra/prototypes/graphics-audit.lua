-- Data-stage graphics guard (ci-sop): fail the load if ANY custom Cindra entity
-- would render invisible (its engine graphics field holds no sprite). A sprite
-- in the wrong field is silently ignored by the engine, so this is the ONLY way
-- to catch an invisible entity in an automated test: the runtime prototype API
-- exposes no graphics accessor. Runs LAST in data.lua, after every Cindra
-- entity is registered, so the whole factorio-test suite fails to boot if a
-- regression re-introduces an invisible building. Audit logic is the pure,
-- unit-tested scripts/graphics-audit.lua.

local audit = require("scripts.graphics-audit")

-- Skip the entities being reworked concurrently (ci-98r owns its graphics
-- audit): the mass driver (driver + charger + orbital catcher). Everything else
-- prefixed "cindra-" is audited here -- including the sunward solar-band variants
-- (cindra-solar-band-*, ci-8al), which are clones of the vanilla solar panel and
-- so carry its sprite (they pass this audit rather than needing a skip).
local SKIP_PREFIXES = {
  "cindra-mass-driver",
}

local specs = audit.discover(data.raw, SKIP_PREFIXES)
local bad = audit.offenders(data.raw, specs)
if #bad > 0 then
  error("cindra: invisible entity prototype(s) with no render graphics wired: "
    .. table.concat(bad, ", ") .. " (see prototypes/graphics-audit.lua)")
end

-- Second guard (ci-z94): a player-placed power building of an animated class
-- must SHOW ITS STATE. The class is enumerated live from data.raw, so a new
-- Cindra accumulator or electric-energy-interface cannot ship as a still image
-- the way the ci-pru placeholders did -- the flare loop is played by reading
-- which units are working, and a static building tells the player nothing.
local static = audit.static_offenders(data.raw, specs)
if #static > 0 then
  error("cindra: player-placed power entity/entities with no working animation: "
    .. table.concat(static, ", ")
    .. " (generate one with ./scripts/render-entity-anim.sh; see prototypes/graphics-audit.lua)")
end
