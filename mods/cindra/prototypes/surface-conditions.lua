-- Records WHICH surface-condition backend this game was built with (ci-ndm9).
--
-- scripts/surface-conditions.lua has two paths -- delegate to PlanetsLib, or run
-- our own implementation -- and a data-stage choice leaves no trace a test or a
-- bug report can read: by the time anything is running, the prototypes look the
-- same either way (which is the whole contract). So the choice is written down
-- here, as a `mod-data` prototype, readable at runtime via
-- `prototypes.mod_data["cindra-surface-conditions"].data.backend`.
--
-- Without it the guarded branch would be code nothing can prove ever ran.
-- tests/test_surface_conditions.lua asserts the default run never reaches for a
-- library the player does not have, and tests/test_planetslib_coload.lua reads the
-- same record with PlanetsLib installed.
--
-- WHAT IT READS: "PlanetsLib" when the player has the library (the `? PlanetsLib`
-- dependency, ci-dza6, orders it ahead of us so its API is up before we edit
-- anything), "cindra" otherwise -- which is almost every game, since the
-- dependency is optional and the library is not vendored. Both are correct; what
-- would be a bug is the two producing different prototypes, which is what the
-- suites check.
--
-- Requires nothing and is required by nothing: it only observes. Load it LAST so
-- it reports the state every earlier prototype file actually saw.

local SC = require("scripts.surface-conditions")

data:extend({
  {
    type = "mod-data",
    name = "cindra-surface-conditions",
    data = {
      -- "PlanetsLib" if the library's helpers did the work, "cindra" if ours did.
      backend = SC.backend(),
    },
  },
})
