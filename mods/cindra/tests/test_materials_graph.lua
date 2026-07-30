-- PROOF (ci-6vj S6, DESIGN §8.4 / §8.6): the authoritative Cindra materials +
-- petrochemical recipe graph is CLOSED and HONEST. Where the earlier per-chain
-- tests (test_lava, test_aluminium, test_plastics, test_sulfur, test_mass_driver)
-- each prove one link, this test walks the WHOLE graph as one object and proves
-- the four load-bearing, cross-chain invariants the design turns on:
--
--   (a) NO HARD DEADLOCK. Every byproduct (O2, CO2, quicklime, sulfur,
--       sulfuric-acid, both spent catalysts, water) has at least one real
--       (non-vent) consumer, AND a drain path to a pure sink so a backed-up
--       pipe/box can never wedge the whole line. The three FORCE-EMITTED floods
--       (O2, CO2, quicklime -- a machine emits them whether you want them or not)
--       additionally get a dedicated emergency vent, exactly the three the
--       authoritative recipe table (§8.2 #17/#18/#19) specifies; the rest drain
--       TRANSITIVELY to one of those vents (proven by reachability), which is why
--       the design does not -- and this test does not require it to -- mint four
--       more vent recipes the §8.2 table never lists.
--   (b) THE O2 ECONOMY HAS REAL SINKS. O2's sources (water electrolysis + the
--       dominant alumina electrolysis) are matched by real, non-vent sinks
--       (zeolite regeneration + methanol rocket fuel + ALICE), so the vent is an
--       early-game relief valve, not the only drain.
--   (c) NET STONE IS NEGATIVE at 0% AND at the +300% productivity cap. Every
--       recipe in the graph that RETURNS stone, charged for its own stone (direct
--       stone + lava-as-stone) inputs, is individually net stone-NEGATIVE even at
--       the cap; and those are the ONLY stone sources in the graph, so no
--       combination can self-sustain. Mining is always a real top-up (ci-669).
--   (d) NO FREE-METAL / FREE-CARBON / FREE-PLASTIC LOOP. Every Cindra
--       matter-conversion recipe disables productivity (so a prod bonus can never
--       mint CO2, methanol, plastic, powder, or metal) -- the SOLE exception is
--       alumina electrolysis, whose prod reward lands only on the aluminium
--       intermediate (its O2 byproduct is pinned ignored_by_productivity), and
--       whose input alumina is itself net stone-negative to make. Metal/carbon
--       enter only through real, net-negative upstreams; the catalyst loops are
--       net input-consuming (a make-up feed), never a free source.
--
-- The graph is read LIVE from the shipped prototypes (never hardcoded amounts),
-- so any recipe rename, byproduct addition, or productivity flip that would open a
-- deadlock or an exploit fails here first. Interfaces fixed by DESIGN §8.

-- ===========================================================================
-- The authoritative graph (DESIGN §8.2): every Cindra materials/petrochemical
-- recipe, plus the three VANILLA recipes the chain reads (the acid recipe the
-- lava tech unlocks + the two lava casts). If a recipe is renamed or dropped, the
-- existence guard below fails -- the graph is a frozen contract.
-- ===========================================================================
local CINDRA_RECIPES = {
  "cindra-lava",                            -- 64 stone -> 320 lava + 8 sulfur(ignored)
  "cindra-electrolysis",                    -- 40 water -> 40 H2 + 20 O2
  "cindra-calcination",                     -- 2 calcite -> 2 quicklime + 40 CO2
  "cindra-alumina",                         -- leach: 20 stone + 30 acid + 20 water -> 10 alumina + 14 stone(ignored) + 2 sulfur(ignored)
  "cindra-aluminium",                       -- electrolyse: 4 alumina -> 2 aluminium + 30 O2(ignored)   [PROD ON]
  "cindra-aluminium-powder",                -- 1 aluminium -> 2 powder
  "cindra-solid-rocket-fuel",               -- ALICE: 2 powder + 2 ice + 10 O2 -> 1 rocket-fuel
  "cindra-methanol-rocket-fuel",            -- 50 methanol + 50 O2 -> 10 rocket-fuel
  "cindra-methanol-synthesis",              -- 20 CO2 + 60 H2 + mcat -> 20 methanol + 20 water (+catalyst rolls)
  "cindra-methanol-catalyst",               -- 10 copper + 2 alumina -> 1 mcat
  "cindra-methanol-catalyst-reprocessing",  -- 1 spent-mcat + 20 acid -> 6 copper + 1 alumina
  "cindra-mto-polymerisation",              -- 40 methanol + zcat -> 2 plastic + 40 water (+catalyst rolls)
  "cindra-zeolite-catalyst",                -- 8 stone + 3 alumina + 2 quicklime + 100 steam -> 1 zcat
  "cindra-zeolite-catalyst-regeneration",   -- 1 spent-zcat + 20 O2 -> 1 zcat
  "cindra-quicklime-disposal",              -- 10 quicklime + 50 lava -> 5 stone(ignored)
  "cindra-vent-oxygen",                     -- 100 O2 -> (pure sink)
  "cindra-vent-co2",                        -- 100 CO2 -> (pure sink)
  "cindra-vent-quicklime",                  -- 10 quicklime -> (pure sink)
}
local VANILLA_RECIPES = {
  "sulfuric-acid",            -- 5 sulfur + 1 iron-plate + 100 water -> 50 acid (unlocked, never mutated)
  "molten-iron-from-lava",    -- 500 lava -> 250 molten-iron + 10 stone
  "molten-copper-from-lava",  -- 500 lava -> 250 molten-copper + 15 stone
}
local GRAPH = {}
for _, n in ipairs(CINDRA_RECIPES) do GRAPH[#GRAPH + 1] = n end
for _, n in ipairs(VANILLA_RECIPES) do GRAPH[#GRAPH + 1] = n end

-- Materials.
local STONE, LAVA, SULFUR, ACID = "stone", "lava", "sulfur", "sulfuric-acid"
local WATER = "water"
local H2   = "cindra-hydrogen"
local O2   = "cindra-oxygen"
local CO2  = "cindra-carbon-dioxide"
local METHANOL  = "cindra-methanol"
local QUICKLIME = "cindra-quicklime"
local ALUMINA   = "cindra-alumina"
local ALUMINIUM = "cindra-aluminium"
local POWDER    = "cindra-aluminium-powder"
local MCAT       = "cindra-methanol-catalyst"
local MCAT_SPENT = "cindra-spent-methanol-catalyst"
local ZCAT       = "cindra-zeolite-catalyst"
local ZCAT_SPENT = "cindra-spent-zeolite-catalyst"
local PLASTIC = "plastic-bar"

local VENTS = {
  ["cindra-vent-oxygen"] = true,
  ["cindra-vent-co2"] = true,
  ["cindra-vent-quicklime"] = true,
}

-- The engine's hard productivity cap (+300%): the worst case any module config
-- can reach. Every "at the cap" assertion uses this.
local MAX_PROD = 3.0

-- ===========================================================================
-- Small graph-reading layer (all LIVE off prototypes.recipe).
-- ===========================================================================
local function ing_amount(r, name)
  for _, e in pairs(r.ingredients) do if e.name == name then return e.amount end end
  return 0
end

local function product_of(r, name)
  for _, e in pairs(r.products) do if e.name == name then return e end end
  return nil
end

local function consumes(r, name) return ing_amount(r, name) > 0 end
local function produces(r, name) return product_of(r, name) ~= nil end

-- Productivity ON for a recipe? (mirrors the check used across the chain tests.)
local function prod_on(r)
  return (r.allowed_effects and r.allowed_effects.productivity) or false
end

-- The stone a stone-emitting recipe hands back at a given productivity, honouring
-- ignored_by_productivity (the fixed floor) + whether prod is even allowed.
local function stone_out(r, p)
  local sp = product_of(r, STONE)
  if not sp then return 0 end
  local ignored = sp.ignored_by_productivity or 0
  local scalable = sp.amount - ignored
  local eff = prod_on(r) and p or 0 -- prod-off recipes never scale
  return ignored + scalable * (1 + eff)
end

-- Lava embodies stone at the LIVE cindra-lava ratio (prod off there, so fixed).
local function lava_per_stone()
  local lava = prototypes.recipe["cindra-lava"]
  return product_of(lava, LAVA).amount / ing_amount(lava, STONE)
end

-- Stone (equivalent) a recipe SPENDS directly: raw stone in + lava in as stone.
local function stone_equiv_in(r)
  return ing_amount(r, STONE) + ing_amount(r, LAVA) / lava_per_stone()
end

-- Recipes in the graph that consume / produce a material.
local function consumers(name, include_vents)
  local out = {}
  for _, rn in ipairs(GRAPH) do
    if include_vents or not VENTS[rn] then
      if consumes(prototypes.recipe[rn], name) then out[#out + 1] = rn end
    end
  end
  return out
end

local function producers(name)
  local out = {}
  for _, rn in ipairs(GRAPH) do
    if produces(prototypes.recipe[rn], name) then out[#out + 1] = rn end
  end
  return out
end

local function set_of(list)
  local s = {}
  for _, v in ipairs(list) do s[v] = true end
  return s
end

-- Can `start` reach a PURE SINK (a recipe that consumes a reachable material and
-- produces nothing -- i.e. a vent)? BFS over materials, expanding through any
-- graph recipe that consumes a reachable material. This is the rigorous "no hard
-- deadlock" test: a backed-up byproduct can always flow to a drain.
local function drains_to_pure_sink(start)
  local reachable = { [start] = true }
  local changed = true
  while changed do
    changed = false
    for _, rn in ipairs(GRAPH) do
      local r = prototypes.recipe[rn]
      local hits = false
      for _, ing in pairs(r.ingredients) do
        if reachable[ing.name] then hits = true break end
      end
      if hits then
        if #r.products == 0 then return true end -- a pure sink: drained
        for _, p in pairs(r.products) do
          if not reachable[p.name] then reachable[p.name] = true; changed = true end
        end
      end
    end
  end
  return false
end

-- ===========================================================================
describe("cindra materials graph: the authoritative graph is present", function()
  it("every recipe in the frozen §8.2 contract exists", function()
    for _, rn in ipairs(GRAPH) do
      assert.is_not_nil(prototypes.recipe[rn], "graph recipe must exist: " .. rn)
    end
  end)
end)

-- ===========================================================================
-- (a) No hard deadlock.
-- ===========================================================================
describe("cindra materials graph (a): no byproduct can hard-deadlock the line", function()
  -- The full byproduct set the brief enumerates.
  local BYPRODUCTS = { O2, CO2, QUICKLIME, SULFUR, ACID, MCAT_SPENT, ZCAT_SPENT, WATER }
  -- The three FORCE-EMITTED floods that get a dedicated emergency vent (§8.2).
  local FLOODS = {
    { mat = O2,        vent = "cindra-vent-oxygen" },
    { mat = CO2,       vent = "cindra-vent-co2" },
    { mat = QUICKLIME, vent = "cindra-vent-quicklime" },
  }

  it("every byproduct has at least one real (non-vent) consumer", function()
    for _, mat in ipairs(BYPRODUCTS) do
      local real = consumers(mat, false) -- exclude vents
      assert.is_true(#real >= 1,
        mat .. " must have a real, non-vent consumer (else it is a dead byproduct)")
    end
  end)

  it("each force-emitted flood (O2/CO2/quicklime) has a dedicated emergency vent (pure sink)", function()
    for _, f in ipairs(FLOODS) do
      local v = prototypes.recipe[f.vent]
      assert.is_not_nil(v, "the emergency vent must exist: " .. f.vent)
      assert.is_true(consumes(v, f.mat), f.vent .. " must consume " .. f.mat)
      assert.are.equal(0, #v.products, f.vent .. " must be a PURE sink (no products)")
      -- And the flood also has a genuine consumer besides its vent.
      assert.is_true(#consumers(f.mat, false) >= 1,
        f.mat .. " must also have a real consumer, not just the vent")
    end
  end)

  it("EVERY byproduct drains to a pure sink (transitively) -- no wedge is possible", function()
    -- The floods drain directly; sulfur/acid/water/spent-catalysts drain through
    -- their consumers to one of the three vents (e.g. water -> electrolysis -> O2
    -- -> vent; sulfur -> acid -> leach -> alumina -> electrolysis -> O2 -> vent).
    for _, mat in ipairs(BYPRODUCTS) do
      assert.is_true(drains_to_pure_sink(mat),
        mat .. " must have a drain path to a pure sink (no hard deadlock)")
    end
  end)
end)

-- ===========================================================================
-- (b) The O2 economy has real sinks against its sources.
-- ===========================================================================
describe("cindra materials graph (b): the O2 economy balances (real sinks, not just a vent)", function()
  it("O2 is produced only by water + alumina electrolysis (its two sources)", function()
    assert.are.same(
      set_of({ "cindra-electrolysis", "cindra-aluminium" }),
      set_of(producers(O2)),
      "O2's only sources are water electrolysis and alumina electrolysis")
  end)

  it("alumina electrolysis is the DOMINANT O2 source, and its O2 is prod-immune (§8.4)", function()
    local water = product_of(prototypes.recipe["cindra-electrolysis"], O2).amount
    local alum_p = product_of(prototypes.recipe["cindra-aluminium"], O2)
    assert.is_true(alum_p.amount > water,
      "alumina electrolysis must out-emit water electrolysis (the dominant O2 source): "
        .. alum_p.amount .. " vs " .. water)
    assert.are.equal(alum_p.amount, alum_p.ignored_by_productivity or 0,
      "the alumina-electrolysis O2 must be fully ignored_by_productivity (prod can't mint gas)")
  end)

  it("the three REAL O2 sinks exist (zeolite regen + methanol fuel + ALICE)", function()
    for _, rn in ipairs({
      "cindra-zeolite-catalyst-regeneration",
      "cindra-methanol-rocket-fuel",
      "cindra-solid-rocket-fuel",
    }) do
      local r = prototypes.recipe[rn]
      assert.is_true(consumes(r, O2), rn .. " must consume O2 (a real, non-vent sink)")
      assert.is_nil(product_of(r, O2), rn .. " is a sink, it must not re-emit O2")
    end
    -- Concretely: the non-vent O2 consumer set is exactly those three.
    assert.are.same(
      set_of({
        "cindra-zeolite-catalyst-regeneration",
        "cindra-methanol-rocket-fuel",
        "cindra-solid-rocket-fuel",
      }),
      set_of(consumers(O2, false)),
      "the real (non-vent) O2 sinks are exactly zeolite-regen + methanol-fuel + ALICE")
  end)

  it("the O2 vent is the emergency relief valve on top of the real sinks", function()
    local v = prototypes.recipe["cindra-vent-oxygen"]
    assert.is_true(consumes(v, O2) and #v.products == 0,
      "vent-oxygen must be a pure O2 sink (the early/mid-game relief valve)")
  end)
end)

-- ===========================================================================
-- (c) Net stone is negative at 0% and at the +300% cap.
-- ===========================================================================
describe("cindra materials graph (c): net stone is NEGATIVE at 0% and +300% (ci-669)", function()
  it("the ONLY stone sources in the graph are the leach, the disposal, and the two casts", function()
    -- If a future recipe starts returning stone, it must be accounted here or the
    -- whole-graph argument breaks -- so pin the source set.
    assert.are.same(
      set_of({
        "cindra-alumina",             -- leach return (ignored_by_prod)
        "cindra-quicklime-disposal",  -- disposal flux (ignored_by_prod)
        "molten-iron-from-lava",      -- vanilla cast byproduct
        "molten-copper-from-lava",    -- vanilla cast byproduct
      }),
      set_of(producers(STONE)),
      "exactly these four recipes may return stone")
  end)

  it("every stone source is individually net stone-NEGATIVE at 0% AND at the +300% cap", function()
    -- Charge each stone-emitting recipe for its own stone (direct stone + the
    -- stone embodied in any lava it eats). If out < in even at the +300% cap, no
    -- combination of these (the only sources) can ever self-sustain.
    for _, rn in ipairs(producers(STONE)) do
      local r = prototypes.recipe[rn]
      local sin = stone_equiv_in(r)
      assert.is_true(sin > 0, rn .. " must spend stone-equivalent to return stone")
      assert.is_true(stone_out(r, 0) < sin, string.format(
        "%s must net-consume stone at 0%% (out %.1f < in %.1f)", rn, stone_out(r, 0), sin))
      assert.is_true(stone_out(r, MAX_PROD) < sin, string.format(
        "%s must net-consume stone at +300%% (out %.1f < in %.1f)", rn, stone_out(r, MAX_PROD), sin))
    end
  end)

  it("the WHOLE-graph net stone is negative: sum of (out - in) over all sources < 0", function()
    -- The aggregate at the worst case (max prod on the scaling casts): the sum of
    -- every source's own (stone returned - stone spent) is still negative, so the
    -- graph as a whole net-consumes rock.
    local net0, netcap = 0, 0
    for _, rn in ipairs(producers(STONE)) do
      local r = prototypes.recipe[rn]
      net0 = net0 + (stone_out(r, 0) - stone_equiv_in(r))
      netcap = netcap + (stone_out(r, MAX_PROD) - stone_equiv_in(r))
    end
    assert.is_true(net0 < 0, "aggregate net stone must be < 0 at 0% (got " .. net0 .. ")")
    assert.is_true(netcap < 0, "aggregate net stone must be < 0 at +300% (got " .. netcap .. ")")
  end)
end)

-- ===========================================================================
-- (d) No free-metal / free-carbon / free-plastic loop.
-- ===========================================================================
describe("cindra materials graph (d): no free-metal/carbon/plastic loop (matter honesty)", function()
  it("every Cindra conversion recipe disables productivity -- except the aluminium intermediate", function()
    for _, rn in ipairs(CINDRA_RECIPES) do
      local r = prototypes.recipe[rn]
      if rn == "cindra-aluminium" then
        assert.is_true(prod_on(r),
          "alumina electrolysis is the one sanctioned prod target (aluminium is an intermediate)")
      else
        assert.is_false(prod_on(r),
          rn .. " must disable productivity (no minting free carbon/metal/plastic/powder)")
      end
    end
  end)

  it("the one prod-enabled recipe rewards ONLY the metal: its O2 byproduct is prod-immune", function()
    local r = prototypes.recipe["cindra-aluminium"]
    local o2 = product_of(r, O2)
    assert.are.equal(o2.amount, o2.ignored_by_productivity or 0,
      "aluminium electrolysis O2 must be fully ignored_by_productivity (prod mints metal only, never gas)")
    assert.is_true(consumes(r, ALUMINA),
      "aluminium is produced only by consuming real (net stone-negative) alumina")
  end)

  it("NO FREE METAL: aluminium + alumina come only from real, net-negative upstreams", function()
    -- Aluminium has exactly one source, and it eats alumina.
    assert.are.same(set_of({ "cindra-aluminium" }), set_of(producers(ALUMINIUM)),
      "aluminium is only ever produced by electrolysis")
    -- Alumina comes from the leach (net stone-negative) + catalyst reprocessing.
    assert.are.same(
      set_of({ "cindra-alumina", "cindra-methanol-catalyst-reprocessing" }),
      set_of(producers(ALUMINA)),
      "alumina comes only from the leach and catalyst reprocessing")
    assert.is_true(consumes(prototypes.recipe["cindra-alumina"], STONE),
      "the leach that makes alumina consumes real stone")
    -- The methanol-catalyst loop is net alumina-CONSUMING: the make eats 2 alumina,
    -- reprocessing hands back only 1 -- a make-up feed, never a free alumina source.
    local made = ing_amount(prototypes.recipe["cindra-methanol-catalyst"], ALUMINA)
    local recovered = product_of(prototypes.recipe["cindra-methanol-catalyst-reprocessing"], ALUMINA).amount
    assert.is_true(recovered < made, string.format(
      "the methanol-catalyst loop must net-consume alumina (make %d, recover %d)", made, recovered))
  end)

  it("NO FREE CARBON/PLASTIC: CO2/methanol/plastic each come from ONE prod-off conversion", function()
    -- Carbon enters only as calcite -> CO2 -> methanol -> plastic, and each step is
    -- a single prod-off conversion, so a prod bonus can never mint any of them.
    for _, spec in ipairs({
      { mat = CO2,      src = "cindra-calcination",        feed = "calcite" },
      { mat = METHANOL, src = "cindra-methanol-synthesis", feed = CO2 },
      { mat = PLASTIC,  src = "cindra-mto-polymerisation", feed = METHANOL },
    }) do
      assert.are.same(set_of({ spec.src }), set_of(producers(spec.mat)),
        spec.mat .. " must have exactly one source in the graph: " .. spec.src)
      local r = prototypes.recipe[spec.src]
      assert.is_true(consumes(r, spec.feed),
        spec.src .. " must consume its real carbon feed " .. spec.feed)
      assert.is_false(prod_on(r), spec.src .. " must disable productivity (no minting)")
    end
  end)

  it("NO FREE POWDER: grinding is prod-off, so rocket fuel can't be cheapened per aluminium", function()
    -- Powder (the ALICE fuel base) is the last metal-bearing conversion; if prod
    -- were allowed, 1 aluminium could grind to >2 powder and undercut the "fuel
    -- worth far more electricity than it holds" invariant (§8.6).
    local r = prototypes.recipe[POWDER]
    assert.is_false(prod_on(r), "aluminium-powder grinding must disable productivity")
    assert.is_true(consumes(r, ALUMINIUM), "powder is ground only from real aluminium")
  end)
end)
