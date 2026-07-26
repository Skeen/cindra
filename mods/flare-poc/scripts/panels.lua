-- Panel damage: the disposal-deficit rule (planet_design.md sec.10 "Panel damage
-- mechanic (self-correcting, NOT cascading)").
--
-- Rule: "undisposed surplus damages the panels producing it." A panel degrades
-- only if its own output had nowhere to go (a disposal deficit on its grid).
-- Properties this module guarantees, each locked by a test:
--   * Damage budget scales with the DEFICIT (W with nowhere to go), never with
--     panel count.
--   * Degrade before death: capped per-sweep loss, so panels run "hot" (reduced
--     efficiency) and only die under a SUSTAINED deficit. Recoverable when
--     disposal is added.
--   * Self-correcting negative feedback: a degraded/dead panel produces less, so
--     potential falls toward capture. Fewer/weaker panels -> smaller surge. It
--     converges to "panels <= disposal", it does NOT death-spiral.
--   * Edge-biased: the most-sunward panels degrade first, so regrowth has a
--     front and placement matters (spec option).
--   * Dissipator is the fuse: its capacity is counted in `capture` before any
--     panel is touched (see scripts/sinks.lua), so disposal-first scaling means
--     zero panel loss.
--
-- Per-grid, scoped by electric_network_id, and per-surface: a saturated grid
-- only damages its own panels; other grids and other planets are untouched.

local C = require("scripts.config")
local flare = require("scripts.flare")
local sinks = require("scripts.sinks")

local M = {}

-- Efficiency of a panel = its current health fraction. A degraded panel runs
-- "hot" and produces proportionally less, which is what makes the feedback
-- self-correcting.
local function efficiency(panel)
  return panel.health / panel.max_health
end

-- Every flare panel on the surface (optionally one network), sunward-first
-- (descending x) so damage is edge-biased and deterministic.
function M.panels(surface, network_id)
  local list = {}
  for _, p in pairs(surface.find_entities_filtered({ name = C.PANEL })) do
    if network_id == nil or p.electric_network_id == network_id then
      list[#list + 1] = p
    end
  end
  table.sort(list, function(a, b)
    if a.position.x ~= b.position.x then return a.position.x > b.position.x end
    return a.position.y > b.position.y
  end)
  return list
end

-- Potential solar power (W) the panels WOULD deliver at `intensity`, discounted
-- by each panel's efficiency. This is the "output looking for somewhere to go".
function M.potential(panels, intensity)
  local total = 0
  for _, p in ipairs(panels) do
    total = total + C.PANEL_NOMINAL_W * intensity * efficiency(p)
  end
  return total
end

-- Full disposal-deficit calculation for one network. Returns potential, the
-- capture breakdown (scripts/sinks.capture), and deficit = potential - capture.
-- deficit > 0 means surplus with nowhere to go.
function M.deficit(surface, network_id, intensity)
  intensity = intensity or flare.current_intensity()
  local panels = M.panels(surface, network_id)
  local potential = M.potential(panels, intensity)
  local capture = sinks.capture(surface, network_id)
  return {
    panels = panels,
    intensity = intensity,
    potential = potential,
    capture = capture,
    deficit = potential - capture.total,
  }
end

-- Apply damage for a single network's deficit, edge-biased and capped per sweep.
-- Returns hp dealt and panels destroyed. Only panels whose output overflowed
-- (the sunward end) are touched, proportional to the deficit.
local function damage_network(info)
  local budget = (info.deficit / 1e6) * C.HP_PER_MW_DEFICIT
  local dealt, destroyed = 0, 0
  for _, p in ipairs(info.panels) do
    if budget <= 0 then break end
    if p.valid then
      local hit = math.min(budget, C.MAX_HP_LOSS_PER_SWEEP, p.health)
      local new_health = p.health - hit
      dealt = dealt + hit
      budget = budget - hit
      if new_health <= 0 then
        p.destroy()
        destroyed = destroyed + 1
      else
        p.health = new_health
      end
    end
  end
  return dealt, destroyed
end

-- Recovery when disposal is sufficient: degraded panels heal back toward full,
-- so a deficit's efficiency drop is reversible once you add disposal.
local function recover(panels)
  for _, p in ipairs(panels) do
    if p.valid and p.health < p.max_health then
      p.health = math.min(p.max_health, p.health + C.RECOVERY_HP_PER_SWEEP)
    end
  end
end

-- One damage/recovery sweep across a surface, per electric network. Groups flare
-- panels by network, then for each network either damages (deficit > 0) or
-- recovers (deficit <= 0). Returns a per-network summary for tests/telemetry.
function M.sweep(surface, intensity)
  if surface.name ~= C.SURFACE then return {} end
  intensity = intensity or flare.current_intensity()

  -- Group panels by network id.
  local by_net = {}
  for _, p in pairs(M.panels(surface)) do
    local id = p.electric_network_id
    if id then
      by_net[id] = by_net[id] or {}
      by_net[id][#by_net[id] + 1] = p
    end
  end

  local summary = {}
  for id in pairs(by_net) do
    local info = M.deficit(surface, id, intensity)
    local dealt, destroyed = 0, 0
    if info.deficit > 0 then
      dealt, destroyed = damage_network(info)
    else
      recover(info.panels)
    end
    summary[id] = {
      intensity = intensity,
      potential = info.potential,
      capture = info.capture,
      deficit = info.deficit,
      hp_dealt = dealt,
      destroyed = destroyed,
    }
  end
  return summary
end

return M
