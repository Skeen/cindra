-- Sprite metadata for the solar-flare hero spritesheet (cindra-flare.png), read
-- by util.sprite_load in prototypes/space-appearance.lua. The sheet is 24 frames
-- on a 6-wide grid of 256px cells (built by scripts/gen-planet-maps.py
-- build_flare_sheet). Kept beside the PNG so the loader can auto-resolve size/grid
-- the same way vanilla space-age sprites do (e.g. planet-lightning.lua).
return {
  width = 256,
  height = 256,
  shift = { 0, 0 },
  line_length = 6,
}
