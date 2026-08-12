-- Data-stage frost guard (ci-u92y): fail the load if ANY Cindra crafting machine
-- would freeze on the nightside with no frost sheen.
--
-- Cindra's machines freeze for real (`entities_require_heating`), and the engine
-- draws the frost ONLY from graphics_set.frozen_patch. Every signature machine
-- wears bespoke art that REPLACED its clone's graphics_set, silently dropping the
-- inherited patch -- the bug that shipped twice (ci-z7nu: oxidizer + glass
-- furnace; ci-u92y: arc furnace) and that only a human playtest caught. The
-- runtime prototype API exposes no graphics accessor, so a factorio-test cannot
-- see this; the guard has to run here.
--
-- Runs LAST in data.lua, after every Cindra entity is registered, so a new
-- machine that ships without a frost layer fails the whole suite to boot rather
-- than quietly freezing bare. Audit logic is the pure, unit-tested
-- scripts/frost-audit.lua; the class it covers (and what it deliberately does
-- not) is documented there.

local audit = require("scripts.frost-audit")

-- The mass driver's art is owned by a concurrent rework (ci-98r), the same skip
-- the sibling graphics audit takes. It is a rocket-silo, so it is outside
-- FROST_FIELDS anyway; the prefix is listed so the intent survives if the type
-- set ever grows.
local SKIP_PREFIXES = {
  "cindra-mass-driver",
}

local specs = audit.discover(data.raw, SKIP_PREFIXES)
local bad = audit.offenders(data.raw, specs)
if #bad > 0 then
  error("cindra: crafting machine(s) that FREEZE with no frost sheen: "
    .. table.concat(bad, ", ")
    .. " -- wire graphics_set.frozen_patch + reset_animation_when_frozen"
    .. " (create the layer with scripts/gen-frost-layer.py if the clone source"
    .. " has no fitting vanilla frost sprite). See prototypes/frost-audit.lua")
end
