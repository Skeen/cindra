-- Manufactured lava, the central economy spine (§15-5; DESIGN.md §1, §2, §5, §7).
--
-- Cindra has no lava lakes to pump (that is Vulcanus). Here lava is MADE from
-- stone with ruinous electric power: `1 stone + [power] -> 5 lava`. That fluid
-- then feeds the Vulcanus foundry chain (molten iron / copper), so the whole
-- metal economy routes through a recipe whose real cost is the star's surplus.
--
-- THREE PARTS, matching the bead:
--
-- 1. THE LAVA RECIPE. `1 stone -> 5 lava` (ratio fixed by spec, §7). Category
--    "metallurgy", so the FOUNDRY crafts it -- no new building. "Power is the
--    lever": the stone/lava amounts are fixed, and the entire cost knob is
--    `energy_required` against the foundry's electric draw. Productivity is
--    DISABLED so power stays the honest cost (a productivity bonus would mint
--    free lava and defeat the "ruinous power" identity).
--
-- 2. FOUNDRY INTEGRATION -- BROUGHT, NOT RE-UNLOCKED. The foundry and its
--    `molten-iron-from-lava` / `molten-copper-from-lava` recipes are Vulcanus
--    content the player already owns by the time Cindra is reachable (§6 gates
--    Cindra after Vulcanus). We do NOT clone or re-unlock them; the manufactured
--    `lava` fluid simply IS the fluid they consume. That is the integration.
--
-- 3. STONE LOOP-BACK. The Vulcanus molten recipes return stone as a BYPRODUCT
--    (10 stone per 250 molten iron, 15 per 250 molten copper -- an OUTPUT, not
--    an input). That returned stone loops back into fresh lava, so mining is a
--    top-up, not the whole supply. We rely on the vanilla byproduct and MUST NOT
--    touch those shared recipes (mutating them would leak onto Vulcanus, the
--    never-mutate-other-planets invariant). See BALANCE NOTE below.
--
-- BALANCE NOTE (deferred to §15-14, ci-63d): the spec wants the loop "net
-- SLIGHTLY consuming" so fresh mining stays a slow activity. With the two values
-- both fixed here (1 stone -> 5 lava, and vanilla's ~10-15 stone back per 500
-- lava consumed) the loop is in fact net-heavily-consuming. Both sides are
-- locked -- the ratio is "fixed per spec" and the foundry byproduct is a shared
-- Vulcanus prototype we cannot edit -- so reconciling the aspiration is a
-- balance-pass decision (batch scaling, or a Cindra-exclusive casting tier),
-- flagged, not silently shipped.
--
-- v1 ART: reuse the vanilla lava fluid icon (a hot sunward world reads right).

-- The ratio is fixed by spec (§7): 1 stone in, 5 lava out. Batch scaling that
-- preserves this ratio is a balance-pass option (§15-14), not a spec change.
local STONE_IN = 1
local LAVA_OUT = 5

-- THE POWER LEVER (tune, §7). All of "ruinous power" lives here. The material
-- cost is fixed at a single stone and productivity is off, so the ONLY cost knob
-- is energy_required against the foundry's 2.5 MW draw. Because the batch is
-- small (5 lava) and one downstream melt swallows 500 lava, ~100 lava crafts
-- back every metal cycle: at this energy_required that aggregate energy dwarfs
-- the ~16 s melt step, so power -- not stone -- is what metal really costs.
-- Calibrated for real against the flare/solar numbers in §15-7 (ci-9k6) and the
-- balance pass (§15-14).
local ENERGY_REQUIRED = 15

local recipe = {
  type = "recipe",
  name = "cindra-lava",
  -- Metallurgy = the foundry's crafting category. The foundry is "brought" from
  -- Vulcanus, so no new building is needed to manufacture lava. (2.1 merged the
  -- old `category`/`additional_categories` fields into this `categories` table.)
  categories = { "metallurgy" },
  subgroup = "fluid-recipes",
  order = "z[cindra]-a[lava]",
  enabled = false, -- gated: unlocked by cindra-lava tech below, never free.
  energy_required = ENERGY_REQUIRED,
  ingredients = {
    { type = "item", name = "stone", amount = STONE_IN },
  },
  results = {
    { type = "fluid", name = "lava", amount = LAVA_OUT },
  },
  -- Power is the lever, not productivity: no free lava from a prod bonus.
  allow_productivity = false,
  -- Single fluid product: show the recipe as the lava it makes.
  icon = "__space-age__/graphics/icons/fluid/lava.png",
  icon_size = 64,
  main_product = "lava",
}

-- Its own tech, gated behind BOTH the foundry (you need the machine + the
-- Vulcanus metal path it unlocks) and Cindra discovery (so the recipe is
-- Cindra-progression content, never an option a Vulcanus-only player stumbles
-- into). Purely additive: it unlocks a NEW recipe and mutates nothing shared.
local technology = {
  type = "technology",
  name = "cindra-lava",
  icon = "__space-age__/graphics/icons/fluid/lava.png",
  icon_size = 64,
  icon_mipmaps = 4,
  effects = {
    { type = "unlock-recipe", recipe = "cindra-lava" },
  },
  prerequisites = { "foundry", "planet-discovery-cindra" },
  unit = {
    count = 200,
    ingredients = {
      { "automation-science-pack", 1 },
      { "logistic-science-pack", 1 },
      { "chemical-science-pack", 1 },
    },
    time = 30,
  },
}

data:extend({ recipe, technology })
