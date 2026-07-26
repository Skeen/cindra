-- Panel damage: the disposal-deficit rule (§15-8; DESIGN.md §5 "undisposed
-- surplus damages the panels producing it"). Integrated from the proven
-- flare-poc (ci-zg3).
--
-- Rule: a panel degrades only if its own output had nowhere to go (a disposal
-- deficit on its grid). Properties this module guarantees, each locked by a test:
--   * Damage budget scales with the DEFICIT (W with nowhere to go), never with
--     panel count.
--   * Degrade before death: a mild deficit spends less than a panel's health, so
--     panels run "hot" (a recoverable condition drop) and only DIE under a
--     sustained/severe deficit. Health regenerates when disposal is added.
--   * Self-correcting negative feedback: damage kills panels sunward-first, which
--     shrinks the array, which lowers both the potential and the flare peak. It
--     converges to "alive panels <= disposal capacity" and then stops - it does
--     NOT death-spiral to zero (a dead panel removes the cause of the overload).
--   * Edge-biased: the most-SUNWARD panels take the deficit first, so die-off has
--     a front and placement matters. "Sunward" is read from the ribbon axis
--     (scripts/ribbon.lua, the single source of truth: +Y is sunward/hot), so the
--     die-off front follows the planet's real temperature gradient, not an
--     arbitrary axis.
--   * Dissipator is the fuse: its capacity is counted in `capture` before any
--     panel is touched (scripts/sinks.lua), so disposal-first scaling = zero loss.
--
-- Per-grid (scoped by electric_network_id) and per-surface: a saturated grid
-- only damages its own panels; other grids and other planets are untouched.

local C = require("scripts.flare-config")
local ribbon = require("scripts.ribbon")
local flare = require("scripts.flare")
local sinks = require("scripts.sinks")

local M = {}

-- Every flare panel on the surface (optionally one network), SUNWARD-first so
-- damage is edge-biased and deterministic. Sunward-ness is the ribbon axis
-- temperature at the panel's Y (hotter = more sunward = damaged first); ties
-- (same Y) break on X so the order is fully deterministic.
function M.panels(surface, network_id)
  local list = {}
  for _, p in pairs(surface.find_entities_filtered({ name = C.PANEL })) do
    if network_id == nil or p.electric_network_id == network_id then
      list[#list + 1] = p
    end
  end
  table.sort(list, function(a, b)
    local ta = ribbon.temperature(a.position.y)
    local tb = ribbon.temperature(b.position.y)
    if ta ~= tb then return ta > tb end
    return a.position.x > b.position.x
  end)
  return list
end

-- Potential solar power (W) the alive panels deliver at `intensity`. An alive
-- panel produces its full output regardless of condition; the feedback that
-- shrinks potential is panels DYING (array size), not efficiency, which keeps
-- the loop stable and terminating (see module note).
function M.potential(panels, intensity)
  local total = 0
  for _, p in ipairs(panels) do
    if p.valid then total = total + C.PANEL_NOMINAL_W * intensity end
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

-- Apply damage for one network's deficit, edge-biased. The HP budget scales with
-- the deficit and is spent sunward-first: a small budget only dents the sunmost
-- panels (degrade), a large sustained budget consumes their health and kills
-- them (death), then spills to the next panel inward. Returns hp dealt + deaths.
local function damage_network(info)
  local budget = (info.deficit / 1e6) * C.HP_PER_MW_DEFICIT
  local dealt, destroyed = 0, 0
  for _, p in ipairs(info.panels) do
    if budget <= 0 then break end
    if p.valid then
      local hit = math.min(budget, p.health)
      dealt = dealt + hit
      budget = budget - hit
      if hit >= p.health then
        p.destroy()
        destroyed = destroyed + 1
      else
        p.health = p.health - hit
      end
    end
  end
  return dealt, destroyed
end

-- Recovery when disposal is sufficient: degraded panels heal back toward full, so
-- a deficit's condition drop is reversible once you add disposal.
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

  local by_net = {}
  for _, p in pairs(M.panels(surface)) do
    local id = p.electric_network_id
    if id then by_net[id] = true end
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
