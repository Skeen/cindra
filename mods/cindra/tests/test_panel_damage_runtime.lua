-- PROOF (ci-snq): the panel OVERLOAD damage actually FIRES through the LIVE
-- driver path, not just when a test calls panels.sweep(s, PEAK) with an injected
-- peak. The reported gap was "the code exists but it's not visibly working in
-- playtest": every prior panel-damage test disabled the driver and injected PEAK,
-- so nothing exercised the real chain
--
--   on_flare_tick (N=23)  -> flare.apply    -> storage.cindra_flare = {intensity}
--   on_panel_damage (N=29)-> panels.sweep() -> reads flare.current_intensity()
--
-- These tests leave the DRIVER ENABLED and let the registered on_nth_tick handlers
-- advance a real (pinned) sporadic flare, so the damage is driven end-to-end.
--
-- They also lock in the two properties the bead calls out:
--   * grid saturation is read from REAL storage fill (Coercia's "full battery is
--     the alarm"): a pegged buffer no longer masks the surplus.
--   * the damage is SCHEDULE-driven, not daylight-driven: it fires even when the
--     surface daytime is frozen (robust to the tidal-lock / no-day-cycle change,
--     ci-2ba / ci-2sr).

local H = require("tests.helpers")
local C = require("scripts.flare-config")
local flare = require("scripts.flare")
local panels = require("scripts.panels")
local panel_solar = require("scripts.panel-solar")

-- Live panels on the surface, re-queried each time (reconcile morphs entities, so
-- held handles go stale): count alive plus total accumulated damage.
local function survey(surface)
  local alive, damage = 0, 0
  for _, p in pairs(surface.find_entities_filtered({ name = panel_solar.all_names() })) do
    alive = alive + 1
    damage = damage + (p.max_health - p.health)
  end
  return alive, damage
end

-- Put the runtime in real-play state: driver ENABLED, no test consumption
-- override, clean flare schedule. Then pin a flare whose plateau the async window
-- lands on (advance_schedule will not skip it while game.tick stays inside the
-- event window).
local function arm_live_flare()
  storage.cindra_driver_enabled = true
  storage.cindra_consumption_w = nil
  storage.cindra_flare = nil
  storage.cindra_flare_sched = nil
  flare.set_schedule(game.tick + 30, 1)
end

describe("panel damage - live driver path (ci-snq)", function()
  it("insufficient disposal: panels degrade during a real flare (no injected peak)", function()
    local s = H.cindra_surface()
    arm_live_flare()
    -- Wired sunward panels in the survivable ribbon, NO disposal built.
    H.grid(s, 0, 48)
    H.panel_col(s, 6, 8) -- y = 8..28

    async(400)
    after_ticks(360, function()
      local alive, dmg = survey(s)
      assert.is_true(dmg > 0,
        "panels MUST take damage during a live flare with no disposal; alive="
          .. alive .. " dmg=" .. dmg .. " intensity=" .. flare.current_intensity())
      done()
    end)
  end)

  it("sufficient disposal: dissipators cover the surplus -> zero loss over a live flare", function()
    local s = H.cindra_surface()
    arm_live_flare()
    H.grid(s, 0, 48)
    H.panel_col(s, 6, 8)
    -- Ample dissipation (3 x 20 MW = 60 MW) dwarfs the array's peak surplus, so the
    -- fuse absorbs it all and no panel is ever damaged.
    H.dissipator(s, { -6, 8 })
    H.dissipator(s, { -6, 12 })
    H.dissipator(s, { -6, 16 })

    async(400)
    after_ticks(360, function()
      local alive, dmg = survey(s)
      assert.are.equal(6, alive, "no panel may be destroyed with sufficient disposal")
      assert.are.equal(0, dmg, "sufficient disposal -> zero panel damage; dmg=" .. dmg)
      done()
    end)
  end)

  -- NOTE: death UNDER A SUSTAINED DEFICIT is proven DETERMINISTICALLY in
  -- test_panel_damage.lua ("dies under a SUSTAINED deficit"). A live-path death
  -- test would be tick-phase dependent (the on_nth_tick sweep count within a
  -- plateau, and thus the damage-vs-recovery balance, varies with game.tick at
  -- test start), so it is intentionally NOT reproduced here -- this suite proves
  -- the live path DEALS DAMAGE (above) and leaves the death threshold to the
  -- deterministic test.

  it("grid saturation reads REAL storage fill: a pegged buffer stops masking the surplus", function()
    -- Coercia's "a full battery is the alarm". A capacitor with headroom counts as
    -- disposal (spares panels); the SAME capacitor pegged near cap no longer counts,
    -- so the surplus becomes a deficit and panels take damage. Driver disabled here
    -- so we can pin the buffer fill deterministically and read the model directly.
    local s = H.cindra_surface()
    H.power_reset()
    H.grid(s, 0, 24)
    H.panel(s, { 6, 6 })
    panels.reconcile_variants(s) -- morph invalidates the placed handle; re-query below
    local cap = H.capacitor(s, { -6, 6 })
    H.set_consumption(0)
    local id
    for _, panel in pairs(s.find_entities_filtered({ name = panel_solar.all_names() })) do
      id = panel.electric_network_id
      break
    end

    async(120)
    after_ticks(6, function()
      -- Empty buffer: it has headroom, so it is credited as capture.
      cap.energy = 0
      local empty = panels.deficit(s, id, C.PEAK_INTENSITY)
      assert.is_true(empty.capture.storage > 0, "an empty buffer must count as disposal")

      -- Same buffer pegged NEAR cap (95% -- above the saturation threshold but not
      -- bit-exact full): the realistic plateau case. It can no longer meaningfully
      -- absorb, so Coercia's alarm drops it out of capture and the deficit grows.
      -- (On the old bit-exact check `energy < buffer_size` this still counted as
      -- full disposal and masked the surplus -- the reported "not firing" gap.)
      cap.energy = 0.95 * cap.electric_buffer_size
      local full = panels.deficit(s, id, C.PEAK_INTENSITY)
      assert.are.equal(0, full.capture.storage, "a near-full buffer must NOT count as disposal")
      assert.is_true(full.deficit > empty.deficit,
        "a near-full buffer raises the alarm: deficit grows when storage saturates ("
          .. empty.deficit .. " -> " .. full.deficit .. ")")
      done()
    end)
  end)

  it("only Cindra-surface panels are touched (nauvis untouched) on the live path", function()
    local s = H.cindra_surface()
    arm_live_flare()
    H.grid(s, 0, 24)
    H.panel_col(s, 4, 8)

    -- A vanilla solar panel on nauvis, on its own grid: the Cindra flare must never
    -- reach it (the surface gate).
    local nauvis = game.surfaces["nauvis"]
    local off_world = nauvis.create_entity({ name = C.PANEL, position = { 0, 0 }, force = "player" })

    async(400)
    after_ticks(360, function()
      local _, dmg = survey(s)
      assert.is_true(dmg > 0, "the Cindra array must take damage (control)")
      assert.is_true(off_world.valid and off_world.health == off_world.max_health,
        "a solar panel on nauvis must be completely untouched by Cindra's flare")
      off_world.destroy()
      done()
    end)
  end)

  it("is schedule-driven, not daylight-driven: fires from the intensity model alone (tidal-lock safe, ci-2ba/ci-2sr)", function()
    -- The mail (ci-2ba/ci-2sr) warns Cindra's day/night cycle is being removed
    -- (tidally locked), so the damage must NOT assume a daylight curve. It does not:
    -- panels.sweep() reads flare.current_intensity() == storage.cindra_flare.intensity,
    -- which the scheduler sets from the pure flare.state() model. Prove the sweep
    -- damages panels from a stored peak intensity ALONE -- no flare.apply, no
    -- freeze_daytime, no surface.daytime touched at all.
    local s = H.cindra_surface()
    H.power_reset() -- driver disabled: no daytime manipulation happens anywhere
    H.grid(s, 0, 48)
    H.panel_col(s, 6, 8)
    panels.reconcile_variants(s)

    -- Stand in for the scheduler: a peak flare intensity, set WITHOUT any daylight
    -- machinery. (Real runtime sets this same field from the schedule in flare.apply.)
    storage.cindra_flare = { intensity = C.PEAK_INTENSITY }

    async(120)
    after_ticks(6, function()
      assert.are.equal(C.PEAK_INTENSITY, flare.current_intensity(),
        "current_intensity reads the schedule model, not the daylight curve")
      panels.sweep(s) -- no intensity arg: pulls it from the stored model
      local _, dmg = survey(s)
      assert.is_true(dmg > 0,
        "overload damage must fire from the intensity model with no day/night cycle; dmg=" .. dmg)
      done()
    end)
  end)
end)
