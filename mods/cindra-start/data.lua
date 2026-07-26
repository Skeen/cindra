-- Register Cindra as a startable planet with Any Planet Start. The `filename` is
-- the data-updates file APS `require`s ONLY when the player has chosen Cindra as
-- their start; that file tunes prototypes for the Cindra-start scenario.
-- `technology` is the discovery tech APS removes when you start on the planet
-- (you are already there).
APS.add_planet{
  name = "cindra",
  filename = "__cindra-start__/cindra-start",
  technology = "planet-discovery-cindra",
}
