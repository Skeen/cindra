-- No paving over Cindra's ribbon (ci-cbn).
--
-- The ribbon's danger is load-bearing: you must NOT be able to landfill the
-- lava to make it safe, nor foundation across the void/ice to widen the buildable
-- band. Cindra keeps its hot/cold lethal zones and its finite width precisely
-- because you cannot pave the hazards away.
--
-- PRIMARY GUARANTEE (data-stage, already in place): every Cindra tile is a
-- `cindra-<vanilla>` clone (prototypes/tiles.lua), so its NAME is absent from the
-- vanilla landfill/foundation `place_as_tile.tile_condition` whitelists (which list
-- water / wetland / oil-ocean / `lava` / `lava-hot`). The engine therefore already
-- REFUSES to place landfill or foundation on any Cindra tile -- verified by
-- tests/test_paving.lua driving the real player build path. We can't strengthen
-- that at the prototype level without mutating the SHARED vanilla landfill/foundation
-- items, which would change every other planet (the never-mutate-other-planets
-- invariant), so the whitelist is the cleanest data-stage restriction available.
--
-- RUNTIME SAFETY NET (this module): make the guarantee EXPLICIT and per-surface,
-- and defend against anything the whitelist coincidence misses -- a future Cindra
-- tile that reuses a vanilla condition name, a blueprint edge, or another mod's
-- scripted placement. On a surface named "cindra", any tile flagged
-- `is_foundation` (landfill, foundation, and every variant -- ice-platform,
-- space-platform-foundation, the Gleba overgrowth soils) that gets built is
-- reverted to the tile it replaced and the consumed item refunded, with a message.
-- Cindra's OWN tiles are never `is_foundation`, and plain paving (concrete /
-- refined-concrete) is NOT `is_foundation`, so decorating walkable ground is
-- untouched.
--
-- 🚨 Gated on surface.name == "cindra": no other planet -- and no space platform
-- (its surface is never named "cindra") -- is ever touched.
--
-- HAZARD NO-PAVE (ci-wly): beyond foundation, you also cannot PAVE (concrete /
-- stone-path / any tile) ATOP the hottest / iciest HAZARD tiles (terrain.NO_PAVE:
-- hot-lava, lava, warm smooth-stone, cracks-hot, smooth-ice, rough-ice). Neutralising
-- the lethal ground by paving over it would defeat the ribbon's danger AND reopens the
-- ci-8vu lava-pump exploit (a concrete path onto the lava). So any tile built over a
-- no-pave tile on the cindra surface is reverted too, tile-by-tile (a concrete batch
-- that laps both hazard and safe ground keeps the safe part, reverts only the hazard).
--
-- on_player_built_tile / on_robot_built_tile cover hand, bots and blueprint
-- (blueprint tile ghosts are revived by bots, or instant-placed by the player).

local terrain = require("scripts.terrain")

local M = {}

local function is_cindra(surface)
  return surface and surface.valid and surface.name == "cindra"
end

-- Revert an is_foundation tile built on Cindra to the tile it replaced and refund
-- the item the placement consumed. A no-op on every non-Cindra surface and for any
-- non-foundation tile, so the common case costs a single name + boolean check.
local function undo_paving(event)
  local surface = game.surfaces[event.surface_index]
  if not is_cindra(surface) then return end

  local placed = event.tile
  if not placed then return end

  -- Two reasons to revert a built tile on cindra: (1) it is foundation (landfill /
  -- foundation / ice-platform / the Gleba soils) -- never allowed anywhere on cindra;
  -- (2) it was paved ATOP a NO-PAVE hazard tile (terrain.NO_PAVE) -- the lethal ground
  -- must stay lethal (ci-wly). Foundation reverts the whole batch; hazard no-pave
  -- reverts only the positions actually over a hazard tile, so a concrete slab that
  -- laps both hazard and safe ground keeps the safe part.
  local block_all = placed.is_foundation
  local revert = {}
  for _, t in pairs(event.tiles) do
    if block_all or terrain.is_no_pave(t.old_tile.name) then
      revert[#revert + 1] = { name = t.old_tile.name, position = t.position }
    end
  end
  if #revert == 0 then return end
  surface.set_tiles(revert)

  -- Refund the consumed item (one per reverted tile), preserving quality. The
  -- data-stage whitelist normally rejects the build before any item is spent, so
  -- this matters only for the edge cases the safety net exists to catch.
  local item = event.item
  local count = #revert
  if item then
    local quality = event.quality and event.quality.name or nil
    local stack = { name = item.name, count = count, quality = quality }
    local giver
    if event.player_index then
      giver = game.get_player(event.player_index)
    elseif event.robot and event.robot.valid then
      giver = event.robot
    end
    local inserted = giver and giver.insert(stack) or 0
    if inserted < count then
      stack.count = count - inserted
      surface.spill_item_stack({ position = revert[1].position, stack = stack })
    end
  end

  -- Clear feedback to the placing player.
  if event.player_index then
    local p = game.get_player(event.player_index)
    if p and p.valid then
      p.create_local_flying_text({ text = { "cindra-message.no-paving" }, position = revert[1].position })
    end
  end
end

function M.register()
  script.on_event(defines.events.on_player_built_tile, undo_paving)
  script.on_event(defines.events.on_robot_built_tile, undo_paving)
end

-- Exposed for the integration test (drive the handler directly).
M.undo_paving = undo_paving

return M
