-- Proof: the Cindra ART wiring (ci-94v) is correct AND cross-planet-safe.
--
-- The art side of the planet prototype (icon / star-map sprite fields and the
-- non-rotating orbital backdrop) is owned by the PURE module
-- prototypes/space-appearance.lua; data-updates.lua only applies it. The runtime
-- prototype API does NOT expose planet.icon / .platform_surface_render_parameters
-- (they are data-stage-only fields), so those VALUES are unreachable from
-- prototypes.*. We therefore assert them at their real source: the module is
-- required at file scope (control.lua parse time) and its pure builders are
-- exercised under the actual Factorio Lua runtime + real util.table.deepcopy.
--
-- This mirrors the ribbon / resource-field dual-test convention: the same shape
-- is asserted off-game in unit-tests/test_space_appearance.lua (which also drives
-- data-updates.lua itself). Keep the two in sync.
--
-- What test_planet.lua already covers (kept there, not duplicated): the wired
-- space_location + discovery tech LOAD valid, i.e. every referenced sprite path
-- resolves. This file covers the assertable field VALUES + the deep-copy
-- invariant that guards Nauvis.

local space = require("prototypes.space-appearance")

-- One full rotation takes ~31 years of game time: the globe never visibly turns.
-- Mirror of the module-private NO_ROTATION so the test states the contract.
local NO_ROTATION = 1.0e9

-- Deterministic deep snapshot for byte-for-byte "unchanged" assertions.
-- serpent is a Factorio built-in; sortkeys makes the string order-stable.
local function serpent_snapshot(t)
  return serpent.line(t, { sortkeys = true, comment = false })
end

-- A synthetic stand-in for nauvis.platform_surface_render_parameters: the generic,
-- planet-agnostic space-dust fields the module deep-copies. Nested table included
-- so the deep-copy regression is a real deep test, not a shallow one.
local function fake_nauvis_params()
  return {
    draw_orbit = true,
    stars = { intensity = 0.5, brightness = { 0.1, 0.2, 0.3 } },
    platform_backdrop = { radius = 1, rotation_seconds = 100, planet_surface = { filename = "__base__/x.png" } },
  }
end

describe("cindra space appearance (art wiring, ci-94v)", function()
  it("uses the baked Cindra icon + star-map sprite, not the Vulcanus placeholder", function()
    local f = space.icon_fields
    assert.are.equal("__cindra__/graphics/icons/cindra.png", f.icon)
    assert.are.equal("__cindra__/graphics/icons/starmap-planet-cindra.png", f.starmap_icon)
    assert.are.equal(64, f.icon_size)
    assert.are.equal(512, f.starmap_icon_size)
    -- Guard against a regression back to a vanilla placeholder.
    assert.is_nil(string.find(f.icon, "vulcanus", 1, true), "icon must not be a vulcanus placeholder")
    assert.is_nil(string.find(f.starmap_icon, "vulcanus", 1, true), "star-map must not be a vulcanus placeholder")
  end)

  it("apply_icons merges every icon field onto a planet table", function()
    local planet = {}
    local ret = space.apply_icons(planet)
    assert.are.equal(planet, ret, "apply_icons returns the same table it mutated")
    for k, v in pairs(space.icon_fields) do
      assert.are.equal(v, planet[k], "planet." .. k .. " must be set")
    end
  end)

  it("freezes the globe (tidal lock): backdrop rotation_seconds is the huge NO_ROTATION", function()
    local params = space.build_render_parameters(fake_nauvis_params())
    assert.is_not_nil(params.platform_backdrop, "backdrop must be built")
    assert.are.equal(NO_ROTATION, params.platform_backdrop.rotation_seconds,
      "tidal lock is expressed as an enormous rotation_seconds so the globe never visibly turns")
    assert.is_true(params.platform_backdrop.rotation_seconds >= 1.0e9,
      "rotation must be effectively infinite (globe static)")
  end)

  it("points the backdrop maps at the baked Cindra fire/ice art", function()
    local b = space.build_render_parameters(fake_nauvis_params()).platform_backdrop
    assert.are.equal("__cindra__/graphics/space/cindra.png", b.planet_surface.filename)
    assert.are.equal("__cindra__/graphics/space/cindra-emission.png", b.planet_emission.filename)
    assert.are.equal("__cindra__/graphics/space/cindra-cloud.png", b.global_cloud.filename)
    assert.are.equal("__cindra__/graphics/space/cindra-flare.png", b.hero_cloud_texture_1.filename)
  end)

  it("animates flares/clouds in place while the globe stays frozen (rotate_with_planet=false)", function()
    local b = space.build_render_parameters(fake_nauvis_params()).platform_backdrop
    assert.are.equal(2, #b.hero_clouds, "two staggered solar-flare instances")
    for i, h in ipairs(b.hero_clouds) do
      assert.is_false(h.rotate_with_planet,
        "hero flare #" .. i .. " must arc in place (not rigidly spin with the frozen globe)")
    end
    assert.is_true(b.hero_clouds_are_emissive, "flares glow")
    assert.are.equal(24, space.build_render_parameters(fake_nauvis_params()).platform_backdrop
      .hero_cloud_texture_1.frame_count, "24-frame flare spritesheet")
  end)

  -- THE cross-planet invariant: build_render_parameters must deep-copy the passed
  -- nauvis params and override only Cindra's backdrop, never mutating the shared
  -- nauvis table. This runs under Factorio's REAL util.table.deepcopy.
  it("REGRESSION: never mutates the passed (nauvis) params -- guards other planets", function()
    local input = fake_nauvis_params()
    local before = serpent_snapshot(input)

    local params = space.build_render_parameters(input)

    assert.are_not.equal(input, params, "must return a fresh table, not the nauvis one")
    assert.are.equal(before, serpent_snapshot(input),
      "the nauvis params must be byte-for-byte unchanged (deep-copy, not in-place override)")

    -- And the generic (planet-agnostic) fields must survive the copy into Cindra's params.
    assert.is_true(params.draw_orbit, "generic space-dust fields are carried over")
    assert.are.equal(0.5, params.stars.intensity, "nested generic fields deep-copied through")

    -- Mutating the output must not reach back into the input (independent tables).
    params.platform_backdrop.radius = 99999
    assert.are.equal(1, input.platform_backdrop.radius, "output and input share no nested state")
  end)

  it("apply_backdrop sets Cindra's params from nauvis without touching nauvis", function()
    local planet = {}
    local nauvis = { platform_surface_render_parameters = fake_nauvis_params() }
    local nauvis_before = serpent_snapshot(nauvis.platform_surface_render_parameters)

    local ret = space.apply_backdrop(planet, nauvis)

    assert.are.equal(planet, ret)
    assert.is_not_nil(planet.platform_surface_render_parameters, "cindra gets its backdrop")
    assert.are.equal(NO_ROTATION, planet.platform_surface_render_parameters.platform_backdrop.rotation_seconds)
    assert.are.equal(nauvis_before, serpent_snapshot(nauvis.platform_surface_render_parameters),
      "nauvis params untouched by apply_backdrop")
  end)

  it("apply_backdrop is a no-op when nauvis has no render params (nothing to copy)", function()
    local planet = {}
    space.apply_backdrop(planet, {})
    assert.is_nil(planet.platform_surface_render_parameters, "no source params -> nothing wired")
  end)
end)
