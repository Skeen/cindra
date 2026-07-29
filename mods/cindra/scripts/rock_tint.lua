-- The bootstrap-rock stone tint (ci-jvc) -- a pure, data-stage colour helper.
--
-- Cindra's finite bootstrap rocks (prototypes/resources.lua) are a deep-copy of
-- the vanilla `huge-rock`, whose stock art is a fairly dark, cool brown-grey. On
-- the dark volcanic-soil terminator they read as generic rubble rather than the
-- warm STONE rocks a Factorio player expects to hand-mine for stone. This module
-- carries the single warm multiply-tint we lay over the rock's sprite variations
-- to pull them toward that vanilla-stone / sandstone look, and the pure function
-- that applies it.
--
-- WHY A MULTIPLY TINT (not new art). The engine multiplies a Sprite's `tint` into
-- the source texture at render, so a warm tint (blue pulled well below red/green)
-- shifts the existing brown-grey toward a golden stone without redrawing a single
-- pixel. Calibrated against the vanilla sand-rock art in a headless PIL preview:
-- {1.0, 0.93, 0.62} reads clearly yellower than the stock rock yet keeps the
-- crevice depth (stronger blue cuts tip over into a muddy olive). See the before/
-- after attached to ci-jvc.
--
-- DELIBERATELY PURE: no `game.*` / `prototypes.*`. It only rewrites a `pictures`
-- table it is handed, so its whole surface is reachable from a plain-Lua unit
-- test (unit-tests/test_rock_tint.lua) with no Factorio.

local M = {}

-- Warm "vanilla stone" multiply-tint. Red stays full; green is trimmed a little
-- and blue a lot, which is what turns the cool brown-grey rock golden. 0..1 RGB
-- (matching prototypes/resources.lua's colour style); alpha left at 1 (opaque).
M.STONE_TINT = { r = 1.0, g = 0.93, b = 0.62, a = 1.0 }

-- Apply `tint` to every sprite variation in a `pictures` table, in place, and
-- return it. Handles the two shapes a SpriteVariations can take: a flat array of
-- Sprites (huge-rock's form) and Sprites that carry `layers`; each leaf Sprite
-- gets the tint. A shallow copy of the tint is stored per sprite so callers can
-- never alias (and later mutate) a single shared colour table.
--
-- `pictures` must be an array-style table (the common `pictures = { {...}, ... }`
-- form). Errors loudly on nil so a refactor that moves the art can't silently
-- ship un-tinted rocks.
function M.apply(pictures, tint)
  assert(type(pictures) == "table", "rock_tint.apply: pictures must be a table")
  assert(type(tint) == "table", "rock_tint.apply: tint must be a table")
  assert(#pictures > 0, "rock_tint.apply: pictures has no variations to tint")

  local function copy_tint()
    return { r = tint.r, g = tint.g, b = tint.b, a = tint.a }
  end

  for _, sprite in ipairs(pictures) do
    if type(sprite.layers) == "table" then
      for _, layer in ipairs(sprite.layers) do
        layer.tint = copy_tint()
      end
    else
      sprite.tint = copy_tint()
    end
  end
  return pictures
end

return M
