-- Data-stage freeze/frost guard: fail the load if ANY Cindra-added entity is
-- IMMUNE to the nightside freeze (ci-qha1), or freezes with no frost sheen
-- (ci-u92y) -- and, before either, if a Cindra prototype's TYPE cannot be
-- classified as entity-or-not (ci-3ed3), because a verdict on an unclassified
-- prototype is a guess. Ordered by size of hole: an entity that cannot freeze at
-- all is a bigger one than an entity that freezes unpainted.
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

-- SIX audits, one report, in scripts/frost-audit.lua's M.problems:
--
--  1. CLASSIFICATION (ci-3ed3) -- a Cindra prototype of a type the audit cannot
--     classify as entity-or-not stops the load asking to be CLASSIFIED. First,
--     because it decides whether the other three apply at all: before ci-3ed3 an
--     unclassified type defaulted to "entity" and a `mod-data` prototype was
--     reported as an entity immune to the freeze, which sent the reader looking
--     for a heating_energy to add to a data-only prototype.
--  2. FREEZE IMMUNITY (ci-qha1) -- the load-bearing one: whether a Cindra entity
--     freezes AT ALL. Freezing on the nightside is the planet's core mechanic, and
--     until ci-qha1 every Cindra entity's freeze behaviour was inherited by
--     accident from whatever vanilla prototype it was deep-copied from -- which is
--     how the glass furnace ran forever in the dark for two releases (ci-6qyk)
--     while an arc furnace beside it froze solid. HUMAN RULING: "It should not be
--     immune, I don't think anything should be." So every Cindra-added entity of a
--     type the engine can freeze carries heating_energy > 0 (the engine's freeze
--     switch) or is named in FREEZE_EXEMPT with a written reason.
--  3. SCRIPT-FREEZE COVERAGE (ci-de55) -- the engine REFUSES to freeze some
--     prototype types at any price (measured), which for a while read as an
--     exemption: the capacitor, the molten-salt battery, the solar bands and the
--     dissipator all kept working in the deep dark. They are now frozen by script
--     instead (scripts/script-freeze.lua), and this audit is what stops a NEW
--     building of such a type from falling between the two -- refused by the
--     engine and unclaimed by us, i.e. immune from both directions at once.
--  4. FROZEN TWINS (ci-de55) -- and a script-frozen building must wear its ice.
--     These types have no frozen_patch field for the engine to draw, so a scripted
--     freeze is INVISIBLE unless the twin's own art carries it; a building that
--     silently stops working is worse than the immunity being fixed.
--  5. DEAD HEAT DRAW -- the inverse and subtler bug: heating_energy on a type the
--     engine IGNORES freezes nothing while reading as protection to the next
--     person who greps for it.
--  6. FROST ART (ci-u92y) -- a machine that DOES freeze must wear the sheen.
--
-- The class each audit covers is discovered LIVE from data.raw, so a new entity
-- cannot ship immune or bare by accident: someone has to make the omission
-- explicit. The runtime API cannot replace this even though it exposes
-- is_freezable -- a test only sees the entities it thinks to place, and
-- is_freezable reports TRUE for an entity whose heating_energy is 0, which never
-- actually freezes. The behavioural half is measured in tests/test_frost.lua;
-- this half is what makes an omission impossible rather than merely detectable.
--
-- Erroring on the FIRST problem (rather than all of them) keeps the message short
-- enough to read; fix it and the next load reports the next one.
local problems = audit.problems(data.raw, SKIP_PREFIXES)
if #problems > 0 then
  error(problems[1].message)
end
