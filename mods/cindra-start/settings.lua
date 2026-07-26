-- Register Cindra as an option in the Any Planet Start dropdown.
-- APS is an OPTIONAL dependency (`? any-planet-start` in info.json): install it
-- and it exposes the global `APS` table from its own settings.lua, which loads
-- before this file. When APS is absent the global is nil, so we must guard: the
-- `mods` table (present in the settings stage) tells us whether APS is installed.
-- Without APS this mod loads clean and registers nothing.
--
-- The Cindra planet prototype exists (cindra/prototypes/planet.lua), so this is
-- a real, backed choice.
if mods["any-planet-start"] then
  APS.add_choice("cindra")
end
