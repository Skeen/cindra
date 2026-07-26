-- Register Cindra as an option in the Any Planet Start dropdown.
-- APS exposes a global table from its own settings.lua; since
-- `any-planet-start` is a required dependency, it has already loaded by the time
-- this runs, so APS is in scope.
--
-- The Cindra planet prototype exists (cindra/prototypes/planet.lua), so this is
-- a real, backed choice.
APS.add_choice("cindra")
