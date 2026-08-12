-- Dev/test shortcut: make "horizontal" the DEFAULT value of Cindra's ribbon
-- orientation setting, so a run generates the E-W ribbon (fire at the TOP, ice at
-- the bottom) with no mod-settings clicking and no binary mod-settings.dat surgery.
--
-- WHY A MOD AND NOT A SETTING WRITE (ci-vjc). The orientation is a STARTUP setting,
-- so one Factorio run = one orientation: the tile probability expressions and the
-- resource band masks are built from the axis at the DATA stage, and no runtime
-- override can rotate a world that was already generated vertical. Proving the
-- horizontal ribbon end-to-end therefore needs a SECOND engine run configured
-- horizontal, which is what scripts/cindra-test.sh does with this mod
-- (`npm run test:integration:horizontal`).
--
-- The runner deletes mod-settings.dat before every run (so every run reads the
-- CURRENT code defaults, see scripts/cindra-test.sh), and Factorio only falls back
-- to a setting's default_value when the name is absent from that file -- which it
-- always is. Changing the DEFAULT in the settings stage is therefore all it takes,
-- and it needs no privileged access to the file format.
--
-- Same shape as the sibling cindra-dev-default (a stand-alone dev mod that only
-- moves a default): shipping the mod set means dropping this one without touching
-- any real Cindra code, and the player can still override the value in the
-- mod-settings UI.
--
-- settings-updates.lua (not settings.lua): the setting PROTOTYPE belongs to cindra
-- and is created in its settings stage; this file runs afterwards, when it exists.
local setting = data.raw["string-setting"]["cindra-ribbon-orientation"]
if not setting then
  error("cindra-dev-horizontal: cindra-ribbon-orientation setting is missing -- " ..
    "is the cindra mod enabled?")
end
setting.default_value = "horizontal"
