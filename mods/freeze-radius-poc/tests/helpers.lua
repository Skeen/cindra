-- Shared setup for the freeze-radius PoC integration tests (ci-b5i).
--
-- Everything runs on the freeze-carrier planet's OWN surface. The engine refuses
-- LuaPlanet::associate_surface when the planet has entities_require_heating=true
-- (a hard constraint), so the freeze flag only rides a planet's native surface;
-- we create it via LuaPlanet::create_surface. This still honours the never-touch-
-- other-planets rule: the mod only ever acts on its own freeze-radius-poc surface.
--
-- THE KEY RELIABILITY RULE (learned the hard way): a hot heat source warms the
-- ground TILES within its radius, and those tiles DO NOT COOL back down on any
-- test timescale. So two measurements that share ground contaminate each other
-- (an old emitter's warmth thaws a later probe). Every measurement must therefore
-- sit on FRESH, never-heated ground. H.fresh_region hands out disjoint x-bands
-- from a monotonic cursor that is never rewound for the whole test run, so no two
-- regions -- across all test files -- ever overlap. This is what makes the suite
-- deterministic; do NOT reuse a region.

local C = require("scripts.config")

local H = {}

-- Emitters reach at most ~101 tiles (the engine clamp, see test_radius_sweep), so
-- neighbouring regions must be separated by more than that plus slack. 400 tiles
-- of empty (frozen, never-heated) ground between region ends is comfortably safe.
H.GAP = 400

-- Monotonic region cursor (tiles along +x). Never rewound: guarantees every
-- region is fresh ground for the entire run.
local cursor = 0

-- The planet's freezing surface (created once). freeze_daytime is pinned so the
-- day/night cycle never perturbs a test that advances ticks.
function H.surface()
  local s = game.surfaces[C.SURFACE]
  if not s then s = game.planets[C.PLANET].create_surface() end
  s.freeze_daytime = true
  return s
end

-- Allocate a FRESH rectangular region on never-heated ground. Generates + flattens
-- [baseX-6 .. baseX+lenX+6] x [-halfY-2 .. halfY+2] to a solid buildable slab so
-- probes never collide with generated water/cliffs. Returns (baseX, surface).
function H.fresh_region(lenX, halfY)
  halfY = halfY or 6
  local s = H.surface()
  local baseX = cursor
  cursor = cursor + lenX + H.GAP

  local x0, x1 = baseX - 6, baseX + lenX + 6
  local half_extent = math.max((x1 - x0) / 2, halfY + 6)
  s.request_to_generate_chunks({ (x0 + x1) / 2, 0 }, math.ceil(half_extent / 32) + 1)
  s.force_generate_chunk_requests()

  local tiles = {}
  for x = x0, x1 do
    for y = -halfY - 2, halfY + 2 do
      tiles[#tiles + 1] = { name = "refined-concrete", position = { x, y } }
    end
  end
  s.set_tiles(tiles)
  return baseX, s
end

-- Place a heat-interface emitter of the given radius, held HOT (buffer >> freeze
-- point) so it emits every tick. Reach is a pure distance mechanic, independent of
-- how hot the buffer is (test_source_kinds), so any hot temperature works.
function H.emitter(s, radius, pos, temp)
  temp = temp or C.EMITTER_TEMPERATURE
  local e = s.create_entity({ name = C.emitter_name(radius), position = pos, force = "player" })
  assert(e, "failed to create emitter r" .. radius)
  e.temperature = temp
  e.set_heat_setting({ temperature = temp, mode = "at-least" })
  return e
end

-- Place a freezable probe entity (defaults to the 1x1 inserter, so position ==
-- exact tile and distance maths is unambiguous).
function H.probe(s, pos, name)
  local e = s.create_entity({ name = name or C.PROBE_INSERTER, position = pos, force = "player" })
  assert(e, "failed to create probe at " .. pos[1] .. "," .. pos[2])
  return e
end

-- Furthest contiguous THAWED distance in a { [dist] = entity } probe table over an
-- ordered distance ladder. Returns -1 if even the nearest probe is frozen.
function H.reach(probes, dists)
  local reach = -1
  for _, d in ipairs(dists) do
    local p = probes[d]
    if p and p.valid and not p.frozen then reach = d else break end
  end
  return reach
end

return H
