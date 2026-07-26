-- Dev shortcut: make Cindra the default value in APS's planet-picker dropdown so
-- `./play.sh` + New Game lands on Cindra without manual clicks. The player can
-- still override via the mod-settings UI — this only changes the *default*, not
-- the available options.
--
-- Implemented as a stand-alone mod (rather than baked into cindra-start) so
-- shipping the mod set means dropping this one without touching real Cindra
-- code. Strictly opt-in: disabling this mod restores APS's "none" default.
--
-- APS.set_default_choice() respects APS.fixed_choice — if another mod has called
-- APS.set_fixed_choice() (locking the planet), our default is silently ignored.
-- That's the intended behaviour.
--
-- APS is an OPTIONAL dependency (`? any-planet-start`): the `APS` global is nil
-- when it is not installed. Guard on the `mods` table (present in the settings
-- stage) so this dev mod loads clean even without APS.
if mods["any-planet-start"] then
  APS.set_default_choice("cindra")
end
