-- Manufactured lava, the central economy spine (§15-5; DESIGN.md §1, §2, §5, §7).
--
-- Cindra has no lava lakes to pump (that is Vulcanus). Here lava is MADE from
-- stone with ruinous electric power at the fixed spec ratio `1 stone -> 5 lava`.
-- That fluid then feeds the Vulcanus foundry chain (molten iron / copper), so
-- the whole metal economy routes through a recipe whose real cost is the star's
-- surplus.
--
-- THROUGHPUT RESCALE (ci-e8a, follow-up to ci-095). The recipe ships BATCHED:
-- `100 stone -> 500 lava` -- the SAME 1:5 ratio, but one craft now yields
-- exactly one downstream melt's worth of lava (a foundry-relevant amount). The
-- pre-rescale `1 stone -> 5 lava` needed ~100 lava foundries to sustain a single
-- melting foundry (unusable); after the rescale a SINGLE-DIGIT count does (~8),
-- with far fewer fluid transactions (better UPS + pipes) than a hundred tiny
-- machines. See the MACHINE-COUNT / POWER note below.
--
-- THREE PARTS, matching the bead:
--
-- 1. THE LAVA RECIPE. `100 stone -> 500 lava` (ratio fixed by spec at 1:5, §7).
--    Category "metallurgy", so the FOUNDRY crafts it -- no new building. "Power
--    is the lever": the stone/lava amounts are fixed by the ratio, and the cost
--    knob is `energy_required` against the foundry's electric draw. Productivity
--    is ALLOWED: lava is the central intermediate and its cost is ruinous power,
--    so a productivity bonus is a fair reward and matches vanilla intermediate
--    conventions (the downstream molten recipes allow it too). Power stays the
--    dominant cost via `energy_required`; productivity only softens it.
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
-- both fixed here (1:5 stone:lava, and vanilla's ~10-15 stone back per 500 lava
-- consumed) the loop is in fact net-heavily-consuming. Both sides are locked --
-- the ratio is "fixed per spec" and the foundry byproduct is a shared Vulcanus
-- prototype we cannot edit -- so reconciling the aspiration is a balance-pass
-- decision (a Cindra-exclusive casting tier), flagged, not silently shipped.
--
-- MACHINE-COUNT vs POWER (the ci-e8a tension, made explicit). The count of lava
-- foundries needed to sustain ONE melting foundry is
--     N = (500 lava/melt * energy_required) / (16 s melt * LAVA_OUT)
-- and the energy spent PER LAVA is the foundry's fixed draw * energy_required /
-- LAVA_OUT. Both are proportional to `energy_required / LAVA_OUT`, so on the
-- SHARED foundry (whose 2.5 MW draw + speed we cannot mutate -- other-planets
-- invariant) they are the SAME knob: you cannot cut the machine count without
-- cutting energy-per-lava by the same factor. The two are mathematically
-- exclusive here. The user's anger is the ~100-machine unusability, so
-- USABILITY wins: energy_required is tuned to the near-maximum that still lands
-- a single-digit N (=8), keeping power as ruinous as a usable count allows. At
-- scale that is still a serious sink (8 foundries * 2.5 MW = 20 MW to feed one
-- melt, and a real base runs many). Getting BOTH a single-digit count AND the
-- old per-lava energy needs a dedicated high-draw Cindra caster (decouple via a
-- bigger per-machine draw) -- the §15-14 / ci-63d casting-tier decision, out of
-- scope for this P1 fix.
--
-- v1 ART: the vanilla lava fluid icon, color-layered warmer so the manufactured
-- pour reads distinct from natural Vulcanus lava (prototypes/lava-icon.lua).
local lava_icon = require("prototypes.lava-icon")

-- The ratio is fixed by spec (§7): 1 stone in, 5 lava out. We ship it BATCHED
-- 100:500 (same ratio) so one craft is one melt's feed -- see rescale note above.
local STONE_IN = 100
local LAVA_OUT = 500

-- THE POWER LEVER (tune, §7). All of "ruinous power" lives here. The material
-- cost is fixed by the ratio, so the dominant cost knob is energy_required
-- against the foundry's 2.5 MW draw (productivity only trims it). At 128 the
-- 500-lava batch takes ~32 s on the foundry (speed 4), so ~8 lava foundries feed
-- one melting foundry: single-digit, usable, and still power-dominated (the
-- aggregate foundry energy over those 8 dwarfs the ~16 s melt step). This is the
-- near-max energy_required that keeps N single-digit -- see the MACHINE-COUNT vs
-- POWER note above. Calibrated against the flare/solar numbers in §15-7 (ci-9k6)
-- and the balance pass (§15-14).
local ENERGY_REQUIRED = 128

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
  -- Central intermediate + ruinous power cost: productivity is a fair reward and
  -- matches vanilla intermediate conventions. Power stays the dominant cost.
  allow_productivity = true,
  -- Single fluid product: show the recipe as the lava it makes, color-layered
  -- warmer so manufactured lava reads distinct from the natural Vulcanus pour.
  -- (Tint lives on the RECIPE icon only -- never on the shared `lava` fluid,
  -- which the Vulcanus chain consumes: retinting it would leak onto Vulcanus.)
  icons = lava_icon.build(),
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
