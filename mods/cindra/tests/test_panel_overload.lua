-- PROOF (ci-sz8q): the three PLAYER-OBSERVABLE facts a playtest reported broken
-- about solar-panel overload. Every assertion here is about what the player can
-- see happen in the world (panel health, a corpse on the ground), never about the
-- shape of the damage formula:
--
--   1. The grid draws everything the panels make  -> the panels take NO damage.
--      (The bug: overload fired on the array's NAMEPLATE output, so a factory
--      consuming 100% of its solar still burned its own panels down.)
--   2. Nothing draws                              -> the panels DO take damage.
--      (The control: the fix must not simply switch overload off.)
--   3. Overload kills a panel                     -> it leaves a REMNANT.
--      (The bug: a dying panel just vanished -- no wreck, no sound, no animation.)
--   4. Partial draw                               -> LESS damage than no draw.
--      (Damage tracks the surplus that was really left over, not the nameplate.)
--
-- The load is real machines (vanilla RADARS: always-on ~320 kW consumers each),
-- not a simulated consumption number, so "the grid draws it" means the engine
-- actually moved the power. No consumption override is set anywhere in this file:
-- these tests run the real-play path.
--
-- Daytime is pinned per test (freeze_daytime + flare.daytime_for), so the panels'
-- real output is a known constant and the test is not at the mercy of whatever
-- daytime a previous test left behind.

local H = require("tests.helpers")
local C = require("scripts.flare-config")
local flare = require("scripts.flare")
local panels = require("scripts.panels")
local panel_solar = require("scripts.panel-solar")

-- A Cindra surface whose panels really produce `intensity` (the engine's own
-- daylight curve, frozen), with the periodic driver off so each test drives the
-- sweeps itself. NO consumption override: the deficit is measured, not simulated.
local function solar_surface(intensity)
  local s = H.cindra_surface()
  H.power_reset()
  s.freeze_daytime = true
  s.daytime = flare.daytime_for(s, intensity)
  return s
end

-- Total HP missing across every panel on the surface (panels are re-queried, so
-- this survives morphs and deaths; a dead panel counts as fully damaged).
local function damage_on(surface, expected)
  local dmg, alive = 0, 0
  for _, p in pairs(surface.find_entities_filtered({ name = panel_solar.all_names() })) do
    dmg = dmg + (p.max_health - p.health)
    alive = alive + 1
  end
  return dmg + (expected - alive) * C.PANEL_MAX_HEALTH, alive
end

-- Vanilla radars: an always-scanning ~320 kW draw each, so N of them is a real,
-- steady factory load. Placed off the panel column but inside the substation
-- supply area, so they sit on the SAME electric network as the panels.
local function radars(surface, n, y0)
  local list = {}
  for i = 1, n do
    list[i] = surface.create_entity({
      name = "radar", position = { -8, (y0 or 6) + (i - 1) * 4 }, force = "player",
    })
  end
  return list
end

describe("solar overload - damage follows the REAL undisposed surplus (ci-sz8q)", function()
  it("grid draws 100% of the panels' output: the panels take NO damage", function()
    -- 4 full-band panels at the between-flare baseline = 4 x 330 kW = 1.32 MW.
    -- Six radars want ~1.9 MW, so every watt the panels make is consumed and
    -- there is no surplus at all -- the panels must be untouched.
    local s = solar_surface(C.BASELINE_INTENSITY)
    H.grid(s, 0, 30)
    H.panel_col(s, 4, 6)
    radars(s, 6)

    async(600)
    after_ticks(120, function()
      for _ = 1, 20 do panels.sweep(s) end
      local dmg, alive = damage_on(s, 4)
      assert.are.equal(4, alive, "no panel may die while the grid consumes all of their output")
      assert.are.equal(0, dmg,
        "a grid drawing 100% of the panels' output must do ZERO overload damage; dmg=" .. dmg)
      done()
    end)
  end)

  it("nothing draws: the same array DOES take damage (control)", function()
    -- Identical array, identical output, no consumers: now the whole 1.32 MW has
    -- nowhere to go, so overload must still fire. Without this the test above
    -- would also pass if overload were simply disabled.
    local s = solar_surface(C.BASELINE_INTENSITY)
    H.grid(s, 0, 30)
    H.panel_col(s, 4, 6)

    async(600)
    after_ticks(120, function()
      for _ = 1, 20 do panels.sweep(s) end
      local dmg = damage_on(s, 4)
      assert.is_true(dmg > 0,
        "an array with no disposal and no load must take overload damage; dmg=" .. dmg)
      done()
    end)
  end)

  it("partial draw: less surplus left over -> strictly less damage", function()
    -- Three radars (~1 MW) eat most of the 1.32 MW the array makes, so only the
    -- leftover ~0.3 MW can burn panels: real damage, but far less than the
    -- unloaded control above. This is the property the nameplate model got wrong.
    local s = solar_surface(C.BASELINE_INTENSITY)
    H.grid(s, 0, 30)
    H.panel_col(s, 4, 6)

    async(600)
    after_ticks(120, function()
      for _ = 1, 20 do panels.sweep(s) end
      local unloaded = damage_on(s, 4)

      local s2 = solar_surface(C.BASELINE_INTENSITY)
      H.grid(s2, 0, 30)
      H.panel_col(s2, 4, 6)
      radars(s2, 3)
      after_ticks(120, function()
        for _ = 1, 20 do panels.sweep(s2) end
        local loaded = damage_on(s2, 4)
        assert.is_true(loaded < unloaded,
          "a partly-consumed array must take LESS damage than an unconsumed one: loaded="
            .. loaded .. " unloaded=" .. unloaded)
        done()
      end)
    end)
  end)
end)

describe("solar overload - a panel killed by overload breaks properly (ci-sz8q)", function()
  it("leaves a remnant at its position instead of vanishing", function()
    -- A flare-peak array with no disposal and no load: the sunmost panel burns
    -- through its 200 HP in a few sweeps. When it dies it must break like any
    -- other Factorio building -- a wreck stays on the ground where it stood.
    local s = solar_surface(C.PEAK_INTENSITY)
    H.grid(s, 0, 12)
    local p = H.panel(s, { 6, 6 })
    local pos = { x = p.position.x, y = p.position.y }

    async(600)
    after_ticks(120, function()
      for _ = 1, 60 do
        if not p.valid then break end
        panels.sweep(s, C.PEAK_INTENSITY)
      end
      assert.is_false(p.valid, "a sustained full-surplus flare must destroy the panel (control)")

      local corpses = s.find_entities_filtered({ type = "corpse", position = pos, radius = 3 })
      assert.is_true(#corpses > 0,
        "a panel killed by overload must leave a remnant at its position, not vanish")
      done()
    end)
  end)
end)

-- COVERAGE GUARD (ci-zpq2): "it breaks properly" must hold for EVERY panel the
-- player can actually have on the ground, not just the base one.
--
-- The ci-sz8q proof above kills a plain vanilla `solar-panel`. In real play that
-- is the MINORITY case: scripts/panels.lua morphs a placed panel to the reduced
-- output BAND matching its sunward position (§ ci-9ht), so the panel that burns
-- up under a flare is usually a `cindra-solar-band-bNN` variant. Nothing proved
-- those die properly, which is exactly how a "panels vanish" report survives a
-- fix. So the band list is enumerated LIVE from panel_solar.all_names(): a new
-- band cannot ship without its own death proof.
--
-- Observable death, as the player experiences it: the building is gone, a WRECK
-- stays on the ground where it stood, and a destruction EFFECT fires there (the
-- panel's own dying explosion -- sound + smoke -- as opposed to the overload
-- spark, which is the ongoing damage cue and is excluded by name).
local function kill_by_overload(s, p)
  local pos = { x = p.position.x, y = p.position.y }
  -- The nightmost band makes ~300 kW at the flare peak, so its HP budget is a
  -- little over 1 HP per sweep: give every band ample sweeps to burn through 200 HP.
  local swept = 0
  for _ = 1, 500 do
    if not p.valid then break end
    panels.sweep(s, C.PEAK_INTENSITY)
    swept = swept + 1
  end
  return pos, swept
end

-- Destruction effects at `pos` that are NOT the overload spark: the panel's own
-- death explosion (what makes the break audible/visible), never the damage cue.
local function death_effects(s, pos)
  local n = 0
  for _, e in pairs(s.find_entities_filtered({ type = "explosion", position = pos, radius = 2 })) do
    if e.name ~= C.PANEL_SPARK then n = n + 1 end
  end
  return n
end

describe("solar overload - EVERY panel band breaks properly, not just the base (ci-zpq2)", function()
  for _, band in ipairs(panel_solar.all_names()) do
    it("`" .. band .. "` killed by overload leaves a wreck and fires its death effect", function()
      assert.is_truthy(prototypes.entity[band],
        "band prototype " .. band .. " does not exist -- the enumeration is stale")

      local s = solar_surface(C.PEAK_INTENSITY)
      H.grid(s, 0, 12)
      local p = s.create_entity({ name = band, position = { 6, 6 }, force = "player" })
      assert.is_truthy(p, "could not place " .. band)

      async(600)
      after_ticks(120, function()
        local pos, swept = kill_by_overload(s, p)
        assert.is_false(p.valid,
          "control: a sustained full-surplus flare must destroy " .. band .. " (swept " .. swept .. ")")

        local corpses = s.find_entities_filtered({ type = "corpse", position = pos, radius = 3 })
        assert.is_true(#corpses > 0,
          band .. " must leave a wreck where it stood, not vanish")
        assert.is_true(death_effects(s, pos) > 0,
          band .. " must fire its destruction effect (sound/smoke) when it dies, not disappear silently")
        done()
      end)
    end)
  end
end)

describe("solar overload - the real-play path: a MORPHED panel breaks properly (ci-zpq2)", function()
  it("a panel that morphed to its sunward band still leaves a wreck when overload kills it", function()
    -- The full player sequence: place the vanilla panel the player crafts, let the
    -- sunward-band reconcile morph it (destroy+create, scripts/panels.lua), THEN
    -- burn it down. This is the entity the player actually watches die.
    local s = solar_surface(C.PEAK_INTENSITY)
    H.grid(s, 0, 12)
    H.panel(s, { 6, 6 })
    panels.reconcile_variants(s)

    local p = panels.panels(s)[1]
    assert.is_truthy(p, "the morphed panel is still on the surface")
    assert.are_not.equal(C.PANEL, p.name,
      "this position must morph to a reduced band, or the test is not on the variant path")

    async(600)
    after_ticks(120, function()
      local pos = kill_by_overload(s, p)
      assert.is_false(p.valid, "control: the morphed panel must die under a sustained deficit")

      local corpses = s.find_entities_filtered({ type = "corpse", position = pos, radius = 3 })
      assert.is_true(#corpses > 0,
        "a morphed panel killed by overload must leave a wreck at its position, not vanish")
      assert.is_true(death_effects(s, pos) > 0,
        "a morphed panel must fire its destruction effect when it dies")
      done()
    end)
  end)
end)
