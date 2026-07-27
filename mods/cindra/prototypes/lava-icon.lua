-- Pure icon spec for the manufactured-lava recipe (§15-5, ci-e8a).
--
-- The recipe OUTPUTS the shared vanilla `lava` fluid -- the Vulcanus foundry
-- chain eats it ("brought, not re-unlocked"), so we MUST NOT retint the fluid
-- itself: that would leak onto Vulcanus (never-mutate-other-planets). The only
-- surface we own is the RECIPE's own icon, so we color-layer THAT. Manufactured
-- lava reads a touch hotter/brighter than the natural Vulcanus pour: distinct
-- at a glance, still obviously lava.
--
-- The runtime prototype API does NOT expose recipe icons, so -- exactly like
-- prototypes/space-appearance.lua -- the icon lives in a PURE module the data
-- stage APPLIES and the test ASSERTS directly (the dual-test convention). This
-- module touches no `data` global, so it is require-able from both stages.

local M = {}

M.BASE_ICON = "__space-age__/graphics/icons/fluid/lava.png"
M.ICON_SIZE = 64

-- Distinct manufactured-lava tint (placeholder, §7): a hotter, brighter cast so
-- it separates from the vanilla Vulcanus lava icon at icon size. A real color
-- shift, NOT neutral white -- that separation is the whole point. Alpha < 1 so
-- the untinted base below still shows: the shift stays subtle and readable.
M.TINT = { r = 1.0, g = 0.85, b = 0.45, a = 0.5 }

-- Build the recipe `icons` array: the vanilla lava sprite carried UNDER a tinted
-- copy of itself. Two layers so the silhouette/detail stay readable while the
-- color visibly shifts warmer -- the "color-layer" the bead asks for.
function M.build()
  return {
    { icon = M.BASE_ICON, icon_size = M.ICON_SIZE },
    { icon = M.BASE_ICON, icon_size = M.ICON_SIZE, tint = M.TINT },
  }
end

return M
