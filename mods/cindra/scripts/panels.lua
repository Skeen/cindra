-- Panel damage: the disposal-deficit rule (§15-8; DESIGN.md §5 "undisposed
-- surplus damages the panels producing it"). Integrated from the proven
-- flare-poc (ci-zg3).
--
-- Rule: a panel degrades only if its own output had nowhere to go (a disposal
-- deficit on its grid). Properties this module guarantees, each locked by a test:
--   * The deficit is the REAL undisposed surplus, measured from the engine's own
--     per-network solar accounting (ci-sz8q), not the array's nameplate output:
--     a grid consuming 100% of what its panels make takes ZERO damage.
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
--     a front and placement matters. "Sunward" is the ribbon temperature at the
--     panel's PERPENDICULAR coordinate (scripts/ribbon.lua via scripts/axis.lua,
--     the single source of truth; hotter = more sunward), so the die-off front
--     follows the planet's real temperature gradient in either orientation.
--   * Dissipator is the fuse: it draws the surplus before any panel is touched
--     (really, on the measured path; as rated `capture` on the modelled one,
--     scripts/sinks.lua), so disposal-first scaling = zero loss.
--
-- Per-grid (scoped by electric_network_id) and per-surface: a saturated grid
-- only damages its own panels; other grids and other planets are untouched.

local C = require("scripts.flare-config")
local ribbon = require("scripts.ribbon")
local axis = require("scripts.axis")
local flare = require("scripts.flare")
local sinks = require("scripts.sinks")
local panel_solar = require("scripts.panel-solar")

local M = {}

-- Every flare panel on the surface (optionally one network), SUNWARD-first so
-- damage is edge-biased and deterministic. Sunward-ness is the ribbon axis
-- temperature at the panel's Y (hotter = more sunward = damaged first); ties
-- (same Y) break on X so the order is fully deterministic. Matches EVERY output
-- band (base + variants, § ci-9ht), not just the base name, so position-scaled
-- panels are all counted.
function M.panels(surface, network_id)
  local list = {}
  for _, p in pairs(surface.find_entities_filtered({ name = panel_solar.all_names() })) do
    if network_id == nil or p.electric_network_id == network_id then
      list[#list + 1] = p
    end
  end
  local orient = axis.orientation()
  table.sort(list, function(a, b)
    local ta = ribbon.temperature(axis.perp(a.position.x, a.position.y, orient))
    local tb = ribbon.temperature(axis.perp(b.position.x, b.position.y, orient))
    if ta ~= tb then return ta > tb end
    -- Tie (same perpendicular coordinate): break on the LONG (along-ribbon) axis
    -- so the order is fully deterministic in either orientation.
    if orient == axis.HORIZONTAL then return a.position.x > b.position.x end
    return a.position.y > b.position.y
  end)
  return list
end

-- Potential solar power (W) the alive panels deliver at `intensity`. An alive
-- panel produces its full BAND output regardless of condition; the feedback that
-- shrinks potential is panels DYING (array size), not efficiency, which keeps
-- the loop stable and terminating (see module note). Each panel contributes its
-- own position-scaled nominal (§ ci-9ht: a nightward panel produces ~nothing, so
-- it adds ~no surplus and takes ~no disposal-deficit damage), read from its
-- prototype name -- so the damage model tracks the real per-panel output.
function M.potential(panels, intensity)
  local total = 0
  for _, p in ipairs(panels) do
    if p.valid then total = total + panel_solar.nominal_w(p.name) * intensity end
  end
  return total
end

-- Morph freshly placed panels to the output variant matching their sunward Y
-- (§ ci-9ht). Runs lazily on the panel track (scripts/driver.lua) instead of
-- hooking build events: that keeps ALL build-event registration in the mass
-- driver's single handler (on_event is REPLACE-not-add) and keeps this system
-- entirely per-Cindra-surface (zero off-planet footprint). A placed panel morphs
-- once, within a sweep of being built, then name == target forever (a placed
-- panel never moves), so it never re-morphs and never resets a degraded panel's
-- health. Destroy+create is the only way to change a panel's fixed `production`;
-- it happens exactly once, at full health, right after placement.
function M.reconcile_variants(surface)
  if surface.name ~= C.SURFACE then return 0 end
  local todo = {}
  local orient = axis.orientation()
  for _, p in pairs(surface.find_entities_filtered({ name = panel_solar.all_names() })) do
    local target = panel_solar.variant_for_y(axis.perp(p.position.x, p.position.y, orient))
    if p.name ~= target then todo[#todo + 1] = { entity = p, target = target } end
  end
  local morphed = 0
  for _, job in ipairs(todo) do
    local p = job.entity
    if p.valid then
      local surf, pos, force, dir, last_user =
        p.surface, p.position, p.force, p.direction, p.last_user
      p.destroy()
      local v = surf.create_entity({
        name = job.target, position = pos, force = force, direction = dir,
        create_build_effect_smoke = false,
      })
      if v then
        if last_user then v.last_user = last_user end
        morphed = morphed + 1
      end
    end
  end
  return morphed
end

-- Full disposal-deficit calculation for one network. deficit > 0 means surplus
-- with nowhere to go; it is what the damage budget is spent from.
--
-- TWO SOURCES, one meaning (ci-sz8q):
--   * MEASURED (real play): the engine's own per-network accounting of solar
--     power that was offered and NOT taken away (sinks.unconsumed_solar_w). This
--     is the ACTUAL undisposed surplus, so a grid drawing 100% of what its panels
--     make has a deficit of ZERO and takes no damage -- however large the array's
--     nameplate output is. It also counts every real sink for free: factory
--     consumers, dissipators actually drawing, accumulators still charging.
--   * MODELLED (fallback): potential - capture, the nameplate estimate. Used when
--     a consumption override is set (a test/dev simulating a load, where there is
--     no real load to measure) or when the network cannot be read yet.
--
-- `potential` and `capture` stay in the result either way: they are the model's
-- telemetry (and what the sink/catchability tests read).
function M.deficit(surface, network_id, intensity)
  intensity = intensity or flare.current_intensity()
  local panels = M.panels(surface, network_id)
  local potential = M.potential(panels, intensity)
  local capture = sinks.capture(surface, network_id)
  local modelled = potential - capture.total

  local measured = nil
  if sinks.consumption_override() == nil then
    measured = sinks.unconsumed_solar_w(panels[1])
  end

  return {
    panels = panels,
    intensity = intensity,
    potential = potential,
    capture = capture,
    measured = measured,
    modelled = modelled,
    deficit = measured or modelled,
  }
end

-- Pop the overload effect on a panel that just took a hit (ci-clf; ci-sz8q art).
-- A self-reaping accumulator-DISCHARGE glow (prototypes/panel-spark.lua) at the
-- panel's position, so the otherwise-silent disposal-deficit degradation has a
-- visible cue -- the player can SEE which panels are burning up from an unabsorbed
-- flare.
-- Created on the panel's OWN surface, which the sweep has already gated to
-- "cindra", so no other planet ever sees a spark. Fired BEFORE a lethal hit so a
-- panel about to be destroyed still arcs at its last position.
local function spark(panel)
  panel.surface.create_entity({ name = C.PANEL_SPARK, position = panel.position })
end

-- Apply damage for one network's deficit, edge-biased. The HP budget scales with
-- the deficit and is spent sunward-first: a small budget only dents the sunmost
-- panels (degrade), a large sustained budget consumes their health and kills
-- them (death), then spills to the next panel inward. Every panel that takes a
-- hit pops an overload spark (ci-clf). Returns hp dealt, deaths, and spark count.
--
-- DEATH IS A REAL DEATH (ci-sz8q): a lethal hit calls entity.die(), not
-- entity.destroy(). destroy() removes the entity silently -- the panel simply
-- VANISHED, with no death animation, no remnant and no destruction sound, which
-- read as a bug rather than as burning out. die() runs the engine's own death
-- path, so the panel breaks like anything else in Factorio: it plays its
-- `dying_explosion`, leaves its `solar-panel-remnants` corpse on the ground, and
-- raises on_entity_died for anything listening. Non-lethal hits still set health
-- directly, which keeps the damage budget EXACT (the balance tests measure HP to
-- within 1) and independent of any damage-type resistance.
local function damage_network(info)
  local budget = (info.deficit / 1e6) * C.HP_PER_MW_DEFICIT
  local dealt, destroyed, sparked = 0, 0, 0
  for _, p in ipairs(info.panels) do
    if budget <= 0 then break end
    if p.valid then
      local hit = math.min(budget, p.health)
      dealt = dealt + hit
      budget = budget - hit
      if hit > 0 then
        spark(p)
        sparked = sparked + 1
      end
      if hit >= p.health then
        p.die()
        destroyed = destroyed + 1
      else
        p.health = p.health - hit
      end
    end
  end
  return dealt, destroyed, sparked
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
    local dealt, destroyed, sparked = 0, 0, 0
    if info.deficit > 0 then
      dealt, destroyed, sparked = damage_network(info)
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
      sparked = sparked,
    }
  end
  return summary
end

return M
