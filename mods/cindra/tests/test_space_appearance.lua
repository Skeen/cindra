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

  -- Route icon for the Vulcanus -> Cindra connection (ci-bu4). The runtime API
  -- does NOT expose a space-connection's icons (data-stage-only, like planet.icon
  -- above), so we assert the composite at its real source: the pure builder that
  -- planet.lua wires into the connection's `icons` field.
  describe("route icon (ci-bu4)", function()
    it("bases the composite on the vanilla transfer-arrow sprite (arrows, like every route)", function()
      local i = space.route_icons()
      assert.are.equal("__space-age__/graphics/icons/planet-route.png", i[1].icon,
        "the base layer is the planet-route transfer-arrow sprite")
      assert.is_nil(i[1].scale, "the arrow base fills the icon (no shrink/shift)")
    end)

    it("draws Cindra (destination) in FRONT and Vulcanus (origin) behind", function()
      local i = space.route_icons()
      -- Icon layers draw bottom-to-top: layer 2 is behind, the LAST layer is frontmost.
      local origin, dest = i[2], i[#i]
      assert.is_not_nil(string.find(origin.icon, "vulcanus", 1, true),
        "the origin badge (behind) is Vulcanus")
      assert.are.equal("__cindra__/graphics/icons/cindra.png", dest.icon,
        "the destination badge drawn LAST (frontmost) is the baked Cindra globe")
    end)

    it("sizes both badges the same, so Cindra is not oversized vs Vulcanus (ci-bu4)", function()
      local i = space.route_icons()
      local origin, dest = i[2], i[#i]
      assert.are.equal(origin.scale, dest.scale, "origin and destination badges share one scale")
      assert.are.equal(0.333, dest.scale, "both badges use the vanilla route-badge scale (0.333)")
      -- Shift convention: origin top-left, destination bottom-right.
      assert.are.equal(-6, origin.shift[1], "origin sits top-left (x)")
      assert.are.equal(-6, origin.shift[2], "origin sits top-left (y)")
      assert.are.equal(6, dest.shift[1], "destination sits bottom-right (x)")
      assert.are.equal(6, dest.shift[2], "destination sits bottom-right (y)")
    end)

    it("uses the baked Cindra icon as the destination, never the Vulcanus placeholder", function()
      local i = space.route_icons()
      assert.is_nil(string.find(i[#i].icon, "vulcanus", 1, true),
        "destination must be the baked Cindra icon (guards the two-Vulcanus-globes bug)")
    end)
  end)

  it("freezes the globe (tidal lock): backdrop rotation_seconds is the huge NO_ROTATION", function()
    local params = space.build_render_parameters(fake_nauvis_params())
    assert.is_not_nil(params.platform_backdrop, "backdrop must be built")
    assert.are.equal(NO_ROTATION, params.platform_backdrop.rotation_seconds,
      "tidal lock is expressed as an enormous rotation_seconds so the globe never visibly turns")
    assert.is_true(params.platform_backdrop.rotation_seconds >= 1.0e9,
      "rotation must be effectively infinite (globe static)")
  end)

  -- ci-ane: tidal lock also means NO axis WOBBLE. Vanilla planets nod their
  -- globes with a non-zero planet_axis_deviation_amplitude ({10,10}); Cindra had
  -- inherited {6,6}, so the rotation-frozen globe still wobbled in the space view.
  -- Freezing rotation_seconds is not sufficient -- the axis deviation is a
  -- separate periodic nod. Guard that BOTH deviation components are zero so a
  -- later tweak cannot quietly reintroduce the wobble.
  it("does not wobble: axis deviation amplitude is zeroed (tidal lock, ci-ane)", function()
    local b = space.build_render_parameters(fake_nauvis_params()).platform_backdrop
    local amp = b.planet_axis_deviation_amplitude
    assert.is_not_nil(amp, "axis deviation amplitude must be set (to zero), not left to a default")
    assert.are.equal(0, amp[1], "no wobble on the first axis component")
    assert.are.equal(0, amp[2], "no wobble on the second axis component")
  end)

  it("points the backdrop maps at the baked Cindra fire/ice art", function()
    local b = space.build_render_parameters(fake_nauvis_params()).platform_backdrop
    assert.are.equal("__cindra__/graphics/space/cindra.png", b.planet_surface.filename)
    assert.are.equal("__cindra__/graphics/space/cindra-emission.png", b.planet_emission.filename)
    assert.are.equal("__cindra__/graphics/space/cindra-cloud.png", b.global_cloud.filename)
  end)

  -- ci-i9m: the hero solar-flare overlay is REMOVED. It rendered as garish white/
  -- yellow vertical PLUMES near the bottom of the globe (the "rocket-engine plume"
  -- junk artifact the mayor flagged). Guard its absence so a later tweak cannot
  -- quietly reintroduce the plume.
  it("has no hero-flare overlay -> no bottom-of-globe plume artifact (ci-i9m)", function()
    local b = space.build_render_parameters(fake_nauvis_params()).platform_backdrop
    assert.is_nil(b.hero_cloud_texture_1, "no hero-flare spritesheet on the backdrop")
    assert.is_nil(b.hero_clouds, "no hero-flare instances on the backdrop")
  end)

  -- The dayside/ice emission still self-lights across the disc so the fiery limb
  -- glows even where the key light grazes (ci-i9m: the terminator falls dark from
  -- the LIGHT, not because emission is missing). Guard that wiring: the self-glow
  -- must NOT be gated on shadow and the scalar is positive.
  it("shows emission self-glow across the disc so lava glows even where grazed", function()
    local b = space.build_render_parameters(fake_nauvis_params()).platform_backdrop
    assert.is_false(b.emission_scales_with_shadow,
      "dayside self-glow must show across the disc, not only where lit")
    assert.is_true(b.emission_scalar ~= nil and b.emission_scalar > 0,
      "positive emission scalar so the molten glow reads")
  end)

  -- ci-6y9: ORBITAL parity with the baked star-map icon. The live backdrop is
  -- engine-lit from these knobs, tuned against a REAL in-engine orbital screenshot
  -- (scripts/render-orbit.sh + scenarios/orbit-shot) so the live view reads like
  -- the icon: single sun from the LEFT, blown-out molten limb, soft ~half-lit
  -- terminator, deep-blue ICE nightside. Supersedes the old ci-fg6 vividness guard
  -- (it demanded specular >= 0.85, which at the grazing terminator lit the sandy
  -- transition into a bright CREAM wall, unlike the icon's darker rocky terminator).
  -- Mirrors the unit test; keep the two in sync.
  it("orbital parity: blown-out lava limb, near-horizontal left sun, cool ice (ci-6y9)", function()
    local b = space.build_render_parameters(fake_nauvis_params()).platform_backdrop
    -- Dayside blown out past the old 2.4; the emission map's blue ice-side self-glow
    -- also stands in for the Blender bake's cool ambient (the engine has no ambient
    -- field), lifting the shadowed ICE off black so it reads deep blue.
    assert.is_true(b.emission_scalar >= 3.0, "dayside blown out (emission >= 3.0)")
    -- Single sun near-HORIZONTAL from the LEFT (the bake's perpendicular sun).
    local L = b.light_direction
    assert.is_true(L[1] < -0.7, "sun comes from the LEFT (x strongly negative)")
    assert.is_true(math.abs(L[1]) > math.abs(L[3]),
      "near-horizontal: |x| dominates the viewer-tilt |z|")
    -- Soft, wide terminator (icon's soft ~55% seam), not a crisp hard half.
    assert.is_true(b.light_radius >= 8.0, "soft wide terminator (light_radius >= 8)")
    -- COOL atmosphere rim: blue-dominant, not the old warm twilight that tinted
    -- the night side olive.
    local a = b.atmosphere_color
    assert.is_true(a[3] > a[1], "cool blue atmosphere rim (blue > red)")
    -- Icy sheen present but SUBTLE, dropped well below the old cream-wall 0.95.
    assert.is_true(b.specular_intensity ~= nil and b.specular_intensity > 0, "icy sheen present")
    assert.is_true(b.specular_intensity < 0.85, "sheen subtle (dropped from the old cream-wall 0.95)")
    -- Cool-tinted specular so the frost glints blue, not warm/white.
    assert.is_true(b.specular_color ~= nil and b.specular_color[3] > b.specular_color[1],
      "cool blue frost sheen (specular blue > red)")
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
