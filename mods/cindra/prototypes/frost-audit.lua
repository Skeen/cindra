-- Data-stage freeze/frost guard: fail the load if ANY Cindra-added entity is
-- IMMUNE to the nightside freeze (ci-qha1), or freezes with no frost sheen
-- (ci-u92y). Two invariants, one guard, in that order of importance -- an entity
-- that cannot freeze at all is a bigger hole than one that freezes unpainted.
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

-- === FREEZE IMMUNITY (ci-qha1) ==============================================
-- One layer deeper than the frost art, and the more load-bearing of the two:
-- whether a Cindra entity freezes AT ALL. Freezing on the nightside is the
-- planet's core mechanic, and until ci-qha1 every Cindra entity's freeze
-- behaviour was inherited by accident from whatever vanilla prototype it was
-- deep-copied from -- which is how the glass furnace ran forever in the dark for
-- two releases (ci-6qyk) while an arc furnace beside it froze solid.
--
-- HUMAN RULING: "It should not be immune, I don't think anything should be." So
-- every Cindra-added entity of a type the engine can freeze must carry
-- heating_energy > 0 (the engine's freeze switch) or be named in
-- scripts/frost-audit.lua's FREEZE_EXEMPT with a written reason. The class is
-- discovered LIVE from data.raw, so a new entity cannot ship immune by accident:
-- someone has to make the omission explicit.
--
-- The runtime API cannot replace this guard even though it exposes is_freezable:
-- a test only sees the entities it thinks to place, and is_freezable reports TRUE
-- for an entity whose heating_energy is 0 -- it never actually freezes. The
-- behavioural half is measured in tests/test_frost.lua; this half is what makes
-- an omission impossible rather than merely detectable.
local immune = audit.freeze_immune(data.raw)
if #immune > 0 then
  error("cindra: entity/entities IMMUNE to the planet's freeze mechanic: "
    .. table.concat(immune, ", ")
    .. " -- give each a heating_energy > 0 (that field IS the engine's freeze"
    .. " switch, not merely a power cost; match the vanilla sibling it was cloned"
    .. " from, e.g. 100kW for a machine, 300kW for a rocket-silo, 20kW for a"
    .. " power-switch). If it must NOT freeze, add it to FREEZE_EXEMPT in"
    .. " scripts/frost-audit.lua WITH A WRITTEN REASON, and extend"
    .. " tests/test_frost.lua. If the engine ignores heating_energy on its"
    .. " prototype type, MEASURE that and add the type to UNFREEZABLE_TYPES."
    .. " If this is not an entity prototype at all, add its type to"
    .. " NON_ENTITY_TYPES. See ci-qha1.")
end

-- The inverse, and the subtler bug: a heat draw on a type the engine IGNORES
-- freezes nothing while reading as protection to the next person who greps.
local dead = audit.dead_heating(data.raw)
if #dead > 0 then
  error("cindra: heating_energy declared on prototype type(s) the ENGINE IGNORES,"
    .. " so it freezes nothing and only LOOKS like protection: "
    .. table.concat(dead, ", ")
    .. " -- either drop the dead field (the type's exemption in UNFREEZABLE_TYPES"
    .. " already covers it) or re-type the entity to something the engine freezes."
    .. " See ci-qha1 / ci-de55.")
end
