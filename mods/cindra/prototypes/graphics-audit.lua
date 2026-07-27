-- Data-stage graphics guard (ci-sop): fail the load if ANY custom Cindra entity
-- would render invisible (its engine graphics field holds no sprite). A sprite
-- in the wrong field is silently ignored by the engine, so this is the ONLY way
-- to catch an invisible entity in an automated test: the runtime prototype API
-- exposes no graphics accessor. Runs LAST in data.lua, after every Cindra
-- entity is registered, so the whole factorio-test suite fails to boot if a
-- regression re-introduces an invisible building. Audit logic is the pure,
-- unit-tested scripts/graphics-audit.lua.

local audit = require("scripts.graphics-audit")

-- Skip the entities being reworked concurrently (ci-98r / ci-8al own their
-- graphics audit): the mass driver (driver + charger + orbital catcher) and the
-- solar-panel band variants. Everything else prefixed "cindra-" is audited here.
local SKIP_PREFIXES = {
  "cindra-mass-driver",
  "cindra-solar-panel",
}

local specs = audit.discover(data.raw, SKIP_PREFIXES)
local bad = audit.offenders(data.raw, specs)
if #bad > 0 then
  error("cindra: invisible entity prototype(s) with no render graphics wired: "
    .. table.concat(bad, ", ") .. " (see prototypes/graphics-audit.lua)")
end
