-- Shared constants for the freeze-radius PoC (ci-b5i).
--
-- One module so the data stage (prototypes) and the tests agree on the same
-- names + the same radius ladder, and so a test can iterate the ladder instead
-- of hard-coding entity names.

local C = {}

-- The scratch surface the whole PoC lives on, and the freeze-carrier planet the
-- surface is associated with. The planet's only job is to carry
-- `entities_require_heating = true` (a whole-planet PlanetPrototype bool); the
-- surface inherits that once associated, so freezing runs on our own controlled
-- flat surface and never touches nauvis / any real planet.
C.SURFACE = "freeze-radius-poc"
C.PLANET = "freeze-radius-poc"

-- The heating temperature we hold every emitter at. A heat-interface only emits
-- while its buffer is hot; we pin it at the buffer max (1000C, well above any
-- freeze point) so heat output is never the variable under test. Verified: the
-- thaw reach is a pure DISTANCE mechanic, identical from 100C to 1000C
-- (test_source_kinds), so only the RADIUS matters.
C.EMITTER_TEMPERATURE = 1000

-- The heat-interface radius ladder. `heating_radius` is a PROTOTYPE float (>= 0,
-- default 1, no documented max), so it cannot be swept at runtime; we register
-- one clone per value and the tests pick the clone they need. Values span the
-- vanilla regime (~1, dense heat pipes) up through the tens-of-tiles regime this
-- spike exists to characterise (100 is the headline; 300 probes for a clamp).
C.RADII = { 1, 2, 3, 4, 5, 6, 7, 8, 10, 25, 50, 75, 100, 128, 150, 200, 300 }

-- Prototype name for the emitter clone at a given radius. Kept in one place so
-- data.lua and the tests can never drift.
function C.emitter_name(radius)
  return "freeze-poc-emitter-r" .. tostring(radius)
end

-- Freezable probe entities. A small, deliberately varied set: an assembling
-- machine + inserter (stop-when-frozen producers) and a pipe (the spec calls out
-- native PIPE/FLUID freezing, which the scripted-damage model could never do).
-- Each is a base-game entity present without space-age.
C.PROBE_ASSEMBLER = "assembling-machine-1"
C.PROBE_INSERTER = "inserter"
C.PROBE_PIPE = "pipe"

return C
