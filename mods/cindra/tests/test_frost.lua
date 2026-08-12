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
-- is measured here without anyone remembering to list it.
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

-- Every Cindra crafting machine, discovered live -- the same class
-- prototypes/frost-audit.lua demands a frozen_patch from.
local function cindra_crafting_machines()
  local names = {}
  for name, proto in pairs(prototypes.entity) do
    if (proto.type == "assembling-machine" or proto.type == "furnace")
      and name:sub(1, 7) == "cindra-" then
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
      local froze = 0
      for _, name in ipairs(machines) do
        -- The audit's predicate, measured against the world: a machine freezes
        -- exactly when it carries a heating draw. This is what lets the data-stage
        -- guard demand a frost layer from precisely the machines a player will
        -- ever see frosted -- and it fails loudly if a heating tweak ever silently
        -- moves a machine from one side of that line to the other.
        local heats = prototypes.entity[name].heating_energy > 0
        if heats then
          froze = froze + 1
          assert.is_true(cold[name].frozen,
            name .. " carries a heating draw, so it must FREEZE in the cold"
            .. " -- the state its frost layer shows")
          assert.are.equal(defines.entity_status.frozen, cold[name].status,
            name .. " must report the frozen status (reads as stopped, not working)")
          assert.is_false(warm[name].frozen,
            name .. " must stay THAWED beside a hot heat source (frost is not always-on)")
          assert.are_not.equal(defines.entity_status.frozen, warm[name].status,
            name .. " beside heat must not report frozen")
        else
          -- Currently only the glass furnace, which drops the foundry's heating
          -- draw (prototypes/lava.lua; whether that exemption is intended is the
          -- open design question ci-6qyk). It stays bare and working in the deep
          -- cold, so the audit rightly demands no frost layer from it.
          assert.is_false(cold[name].frozen,
            name .. " carries NO heating draw, so it must never freeze"
            .. " -- if it does, it needs a frost layer and the audit must cover it")
        end
      end
      assert.is_true(froze >= 2,
        "at least the arc furnace and the oxidizer must actually freeze, got " .. froze)
      done()
    end)
  end)
end)
