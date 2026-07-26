-- Register Cindra as a startable planet with Any Planet Start. The `filename` is
-- the data-updates file APS `require`s ONLY when the player has chosen Cindra as
-- their start; that file tunes prototypes for the Cindra-start scenario.
-- `technology` is the discovery tech APS removes when you start on the planet
-- (you are already there).
--
-- APS is optional: `APS` is nil when it is not installed, so guard on the `mods`
-- table (available in the data stage). Without APS this registration is skipped
-- and the mod loads clean.
if mods["any-planet-start"] then
  APS.add_planet{
    name = "cindra",
    filename = "__cindra-start__/cindra-start",
    technology = "planet-discovery-cindra",
  }
end
