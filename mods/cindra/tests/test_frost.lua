-- FROST COVERAGE proof (ci-u92y): every Cindra crafting machine really does
-- freeze on the nightside, so every one of them needs a frost layer.
--
-- WHY THIS SUITE EXISTS. The frost sheen itself is drawn by the engine from
-- graphics_set.frozen_patch and cannot be read back at runtime (LuaEntityPrototype
-- exposes no graphics accessor), so the ART is guarded where it can be: a
-- data-stage audit that errors the load if any Cindra crafting machine lacks a
-- patch (prototypes/frost-audit.lua) and a pixel test on the created layer
-- (unit-tests/test_frost_layer.py). Both of those rest on ONE claim about the
-- world: that these machines freeze at all. That claim is what this suite proves,
-- against the real prototypes on the real Cindra surface -- and it is the half
-- that can rot silently, because a machine that stopped freezing (a heating tweak,
-- a different clone source) would make the audit demand art nobody sees, while a
-- NEW machine that freezes is exactly what the audit exists to catch.
--
-- The class is enumerated LIVE from prototypes.entity, so a machine added later
-- is measured here without anyone remembering to list it. Since ci-6qyk the
-- expectation is UNCONDITIONAL -- every machine in the class must freeze, and an
-- exemption must be named in FREEZE_EXEMPT with a reason (see the note there).
--
-- RELIABILITY (the ci-b5i lesson, same as tests/test_freeze.lua): a hot heat
-- source warms the ground TILES in reach and they DO NOT COOL on any test
-- timescale, so measurements that share ground contaminate each other. This suite
-- works on its own FRESH, never-heated ground, far from every other suite's.

local H = require("tests.helpers")
local freeze = require("scripts.freeze")

-- Fresh-ground base, parked far from tests/test_freeze.lua's cursor (100000+)
-- and from the origin work area.
local BASE = 300000
local SPACING = 14 -- tiles between probes: clears the widest machine (4x4) with room

-- Deliberate freeze exemptions, each with its reason stated here in code. EMPTY ON
-- PURPOSE (ci-6qyk): nothing Cindra ships is exempt from the planet's core mechanic.
-- The glass furnace used to be, by ACCIDENT -- prototypes/lava.lua cleared its
-- heating_energy to shed the foundry's Aquilo-sized power cost, not knowing the engine
-- also uses that field as the freeze switch -- so it ran forever in the dark while an
-- arc furnace beside it froze solid, wearing frost art it could never show. The one
-- design that could earn an entry here is "lava-chain machines are self-heating, being
-- full of molten rock"; that would have to be applied to the WHOLE chain, said out
-- loud, and have its now-unreachable frost art dropped. An accident is not an
-- exemption, and that is precisely what this suite exists to catch.
local FREEZE_EXEMPT = {}

-- Every Cindra crafting machine, discovered live -- the same class
-- prototypes/frost-audit.lua demands a frozen_patch from.
local function cindra_crafting_machines()
  local names = {}
  for name, proto in pairs(prototypes.entity) do
    if (proto.type == "assembling-machine" or proto.type == "furnace")
      and name:sub(1, 7) == "cindra-" and not FREEZE_EXEMPT[name] then
      names[#names + 1] = name
    end
  end
  table.sort(names) -- deterministic placement order
  return names
end

-- Generate + pave a flat, never-heated slab so probes never land on generated
-- lava/ice/void.
local function slab(s, x0, x1, y0, y1)
  local cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
  local rad = math.ceil(math.max(x1 - x0, y1 - y0) / 2 / 32) + 2
  s.request_to_generate_chunks({ cx, cy }, rad)
  s.force_generate_chunk_requests()
  local tiles = {}
  for x = math.floor(x0), math.ceil(x1) do
    for y = math.floor(y0), math.ceil(y1) do
      tiles[#tiles + 1] = { name = "refined-concrete", position = { x, y } }
    end
  end
  s.set_tiles(tiles)
end

describe("frost coverage (ci-u92y)", function()
  it("EVERY Cindra crafting machine freezes in the cold and thaws by a heat source", function()
    local s = H.cindra_surface()
    storage.cindra_freeze_autoplace = false -- hand-placed heat only on this ground

    local machines = cindra_crafting_machines()
    assert.is_true(#machines >= 3,
      "the audited class must not be empty (arc furnace, glass furnace, oxidizer at least), got " .. #machines)

    -- COLD ROW: no heat source anywhere near -- these must all freeze.
    local cold_y = BASE
    slab(s, -8, SPACING * (#machines + 1), cold_y - 8, cold_y + 8)
    -- WARM ROW: one hot emitter per machine, right beside it -- these must NOT
    -- freeze, so a frost sheen is never simply always-on.
    local warm_y = BASE + 1000
    slab(s, -8, SPACING * (#machines + 1), warm_y - 8, warm_y + 8)

    local cold, warm = {}, {}
    for i, name in ipairs(machines) do
      local x = SPACING * i
      cold[name] = s.create_entity({ name = name, position = { x, cold_y }, force = "player" })
      assert.is_not_nil(cold[name], "failed to place " .. name .. " on the cold row")

      local e = s.create_entity({ name = freeze.EMITTER_NAME, position = { x - 4, warm_y }, force = "player" })
      assert(e, "failed to create lava-heat emitter for " .. name)
      e.temperature = freeze.EMITTER_TEMPERATURE
      warm[name] = s.create_entity({ name = name, position = { x, warm_y }, force = "player" })
      assert.is_not_nil(warm[name], "failed to place " .. name .. " on the warm row")
    end

    async(6000)
    after_ticks(5000, function()
      -- UNCONDITIONAL, for every machine in the class (ci-6qyk). This loop used to
      -- branch on `heating_energy > 0` and merely assert that a machine WITHOUT a
      -- heating draw never freezes -- which is a restatement of the engine rule, not
      -- an invariant: any machine could opt itself out of the planet's core mechanic
      -- by clearing one field, and the suite would go green agreeing with it. The
      -- glass furnace did exactly that for two releases. The expectation is now the
      -- design rule instead: on Cindra, EVERYTHING freezes in the dark. A machine that
      -- should not must be named in FREEZE_EXEMPT above, with its reason.
      for _, name in ipairs(machines) do
        assert.is_true(cold[name].frozen,
          name .. " must FREEZE on never-heated ground with no heat source -- a Cindra"
          .. " machine that keeps working in the dark is exempt from the planet's core"
          .. " mechanic (usually because its prototype cleared heating_energy, which is"
          .. " also the engine's freeze switch: see ci-6qyk)")
        assert.are.equal(defines.entity_status.frozen, cold[name].status,
          name .. " must report the frozen status (reads as stopped, not working)")
        -- The other half, and it is load-bearing: a machine that is simply ALWAYS
        -- frozen would satisfy the assertions above and be just as broken.
        assert.is_false(warm[name].frozen,
          name .. " must stay THAWED beside a hot heat source (frost is not always-on)")
        assert.are_not.equal(defines.entity_status.frozen, warm[name].status,
          name .. " beside heat must not report frozen")
      end
      done()
    end)
  end)
end)
