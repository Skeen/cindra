-- Plain-Lua unit test for the pure Cindra ART wiring (ci-94v). Run:
--   cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_space_appearance.lua
--
-- prototypes/space-appearance.lua is pure (its only dependency is util.table.
-- deepcopy), so its whole surface is reachable off-game. This is the fast path;
-- tests/test_space_appearance.lua asserts the SAME module shape under the real
-- Factorio runtime + real util. Keep the two in sync.
--
-- This file ALSO drives data-updates.lua itself (via dofile with a stubbed data
-- stage), which the runtime test cannot do: it proves the wiring APPLIES the art
-- to Cindra, updates the discovery tech icon, and leaves nauvis byte-for-byte
-- unchanged (the never-mutate-other-planets invariant).

package.path = package.path .. ";./?.lua;./?/init.lua"

-- Stub `util` (a Factorio core lib) with a real recursive deep copy, so the
-- module's deep-copy path behaves like it does in-game.
local function deepcopy(t)
  if type(t) ~= "table" then return t end
  local r = {}
  for k, v in pairs(t) do r[deepcopy(k)] = deepcopy(v) end
  return r
end
package.loaded["util"] = { table = { deepcopy = deepcopy } }

local space = require("prototypes.space-appearance")

local NO_ROTATION = 1.0e9

local passed, failed = 0, 0

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
    print("ok - " .. name)
  else
    failed = failed + 1
    print("not ok - " .. name .. ": " .. tostring(err))
  end
end

local function assert_eq(a, b, msg)
  if a ~= b then error((msg or "values differ") .. " (" .. tostring(a) .. " ~= " .. tostring(b) .. ")", 2) end
end

local function assert_true(x, msg)
  if not x then error(msg or "expected true", 2) end
end

local function assert_nil(x, msg)
  if x ~= nil then error((msg or "expected nil") .. " (got " .. tostring(x) .. ")", 2) end
end

-- Deterministic deep serialization for byte-for-byte "unchanged" assertions.
local function snapshot(t)
  if type(t) ~= "table" then return tostring(t) end
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local parts = {}
  for _, k in ipairs(keys) do
    parts[#parts + 1] = tostring(k) .. "=" .. snapshot(t[k])
  end
  return "{" .. table.concat(parts, ",") .. "}"
end

local function fake_nauvis_params()
  return {
    draw_orbit = true,
    stars = { intensity = 0.5, brightness = { 0.1, 0.2, 0.3 } },
    platform_backdrop = { radius = 1, rotation_seconds = 100, planet_surface = { filename = "__base__/x.png" } },
  }
end

-- ---- Pure module (mirrors tests/test_space_appearance.lua) ----

test("uses the baked Cindra icon + star-map, not the Vulcanus placeholder", function()
  local f = space.icon_fields
  assert_eq("__cindra__/graphics/icons/cindra.png", f.icon)
  assert_eq("__cindra__/graphics/icons/starmap-planet-cindra.png", f.starmap_icon)
  assert_eq(64, f.icon_size)
  assert_eq(512, f.starmap_icon_size)
  assert_nil(string.find(f.icon, "vulcanus", 1, true), "icon must not be a vulcanus placeholder")
end)

test("apply_icons merges every icon field onto a planet table", function()
  local planet = {}
  local ret = space.apply_icons(planet)
  assert_eq(planet, ret, "apply_icons returns the mutated table")
  for k, v in pairs(space.icon_fields) do
    assert_eq(v, planet[k], "planet." .. k .. " set")
  end
end)

-- Route icon for the Vulcanus -> Cindra connection (ci-bu4). Pure builder, so it
-- is fully reachable off-game; tests/test_space_appearance.lua asserts the same
-- shape under the real Factorio runtime. Keep the two in sync.
test("route_icons: transfer-arrow base + Cindra destination frontmost, same-size badges", function()
  local i = space.route_icons()
  -- Base layer = the vanilla transfer-arrow sprite (arrows like every other route).
  assert_eq("__space-age__/graphics/icons/planet-route.png", i[1].icon, "arrow base layer")
  assert_nil(i[1].scale, "arrow base fills the icon (no shrink/shift)")

  -- Layers draw bottom-to-top: layer 2 behind (origin), last layer frontmost (destination).
  local origin, dest = i[2], i[#i]
  assert_true(string.find(origin.icon, "vulcanus", 1, true) ~= nil, "origin (behind) is Vulcanus")
  assert_eq("__cindra__/graphics/icons/cindra.png", dest.icon, "destination (frontmost) is the baked Cindra icon")
  assert_nil(string.find(dest.icon, "vulcanus", 1, true), "destination is NOT a Vulcanus placeholder (two-Vulcanus guard)")

  -- Same scale => Cindra is not oversized; vanilla route-badge scale + shifts.
  assert_eq(origin.scale, dest.scale, "origin and destination share one scale")
  assert_eq(0.333, dest.scale, "vanilla route-badge scale")
  assert_eq(-6, origin.shift[1], "origin top-left x")
  assert_eq(-6, origin.shift[2], "origin top-left y")
  assert_eq(6, dest.shift[1], "destination bottom-right x")
  assert_eq(6, dest.shift[2], "destination bottom-right y")
end)

test("freezes the globe (tidal lock): rotation_seconds is the huge NO_ROTATION", function()
  local params = space.build_render_parameters(fake_nauvis_params())
  assert_true(params.platform_backdrop ~= nil, "backdrop built")
  assert_eq(NO_ROTATION, params.platform_backdrop.rotation_seconds, "tidal lock rotation")
  assert_true(params.platform_backdrop.rotation_seconds >= 1.0e9, "effectively infinite")
end)

-- ci-ane: tidal lock also means NO axis WOBBLE. Vanilla planets nod their globes
-- with a non-zero planet_axis_deviation_amplitude ({10,10}); Cindra had inherited
-- {6,6}, so the rotation-frozen globe still wobbled in the space view. Freezing
-- rotation_seconds is not sufficient -- the axis deviation is a separate periodic
-- nod. Guard that BOTH deviation components are zero so a later tweak cannot
-- quietly reintroduce the wobble (mirrors tests/test_space_appearance.lua).
test("does not wobble: axis deviation amplitude is zeroed (tidal lock, ci-ane)", function()
  local b = space.build_render_parameters(fake_nauvis_params()).platform_backdrop
  local amp = b.planet_axis_deviation_amplitude
  assert_true(amp ~= nil, "axis deviation amplitude must be set (to zero), not left to a default")
  assert_eq(0, amp[1], "no wobble on the first axis component")
  assert_eq(0, amp[2], "no wobble on the second axis component")
end)

test("points the backdrop maps at the baked Cindra fire/ice art", function()
  local b = space.build_render_parameters(fake_nauvis_params()).platform_backdrop
  assert_eq("__cindra__/graphics/space/cindra.png", b.planet_surface.filename)
  assert_eq("__cindra__/graphics/space/cindra-emission.png", b.planet_emission.filename)
  assert_eq("__cindra__/graphics/space/cindra-cloud.png", b.global_cloud.filename)
end)

-- ci-i9m: the hero solar-flare overlay is REMOVED. It rendered as garish white/
-- yellow vertical PLUMES near the bottom of the globe (the "rocket-engine plume"
-- junk artifact the mayor flagged). Guard its absence so a later tweak cannot
-- quietly reintroduce the plume: no hero-cloud texture, no hero-cloud instances.
test("no hero-flare overlay -> no bottom-of-globe plume artifact (ci-i9m)", function()
  local b = space.build_render_parameters(fake_nauvis_params()).platform_backdrop
  assert_nil(b.hero_cloud_texture_1, "no hero-flare spritesheet on the backdrop")
  assert_nil(b.hero_clouds, "no hero-flare instances on the backdrop")
end)

-- The dayside/ice emission still self-lights across the disc so the fiery limb
-- glows even where the key light grazes (ci-i9m: the terminator falls dark from
-- the LIGHT, not because emission is missing). Guard that wiring: the self-glow
-- must NOT be gated on shadow, and the emission scalar must be positive.
test("emission self-glow always shows -> lava glows across the disc, not only in light", function()
  local b = space.build_render_parameters(fake_nauvis_params()).platform_backdrop
  assert_eq(false, b.emission_scales_with_shadow, "dayside glow must show across the disc, not only in light")
  assert_true(b.emission_scalar and b.emission_scalar > 0, "positive emission scalar so the glow reads")
end)

-- ci-6y9: ORBITAL parity with the baked star-map icon. The live backdrop is
-- engine-lit from these knobs; they were tuned against a REAL in-engine orbital
-- screenshot (scripts/render-orbit.sh + scenarios/orbit-shot) so the live view
-- reads like the icon: a single sun from the LEFT, a blown-out molten limb, a
-- soft ~half-lit terminator, and a deep-blue ICE nightside. This supersedes the
-- old ci-fg6 vividness guard (it demanded specular >= 0.85, which at the grazing
-- terminator lit the sandy transition into a bright CREAM wall, nothing like the
-- icon's darker rocky terminator). Guard the tuned values so a later tweak cannot
-- quietly drift the live view back off the icon.
test("orbital parity: blown-out lava limb, near-horizontal left sun, cool ice (ci-6y9)", function()
  local b = space.build_render_parameters(fake_nauvis_params()).platform_backdrop
  -- Dayside blown out past the old 2.4: the emission map's white-hot core clips to
  -- near-white like the icon's hot highlight, and its blue ice-side self-glow lifts
  -- the shadowed hemisphere off black -- the engine's stand-in for the Blender
  -- bake's cool world-ambient, since the engine exposes no ambient-colour field.
  assert_true(b.emission_scalar >= 3.0, "dayside blown out (emission >= 3.0)")
  -- Single sun near-HORIZONTAL from the LEFT (the bake's perpendicular sun): x
  -- strongly negative and dominant over the small viewer-tilt z, so the terminator
  -- runs vertical down the disc, not the old three-quarter angle.
  local L = b.light_direction
  assert_true(L[1] < -0.7, "sun comes from the LEFT (x strongly negative)")
  assert_true(math.abs(L[1]) > math.abs(L[3]), "near-horizontal: |x| dominates the viewer-tilt |z|")
  -- Soft, wide terminator so ~half the disc reads lit behind a gentle seam (the
  -- icon's soft ~55% boundary), not a crisp hard half.
  assert_true(b.light_radius >= 8.0, "soft wide terminator (light_radius >= 8)")
  -- COOL atmosphere rim: the icon's dark hemisphere is deep-blue ICE, so the rim
  -- is blue-dominant (blue over red), not the old warm twilight that tinted the
  -- night side olive.
  local a = b.atmosphere_color
  assert_true(a[3] > a[1], "cool blue atmosphere rim (blue > red)")
  -- Icy sheen still present but SUBTLE: dropped well below the old cream-wall 0.95.
  assert_true(b.specular_intensity and b.specular_intensity > 0, "icy sheen present")
  assert_true(b.specular_intensity < 0.85, "sheen subtle (dropped from the old cream-wall 0.95)")
  -- Cool-tinted specular so the frost glints blue, not warm/white.
  assert_true(b.specular_color and b.specular_color[3] > b.specular_color[1],
    "cool blue frost sheen (specular blue > red)")
end)

test("REGRESSION: build_render_parameters never mutates the passed nauvis params", function()
  local input = fake_nauvis_params()
  local before = snapshot(input)
  local params = space.build_render_parameters(input)
  assert_true(params ~= input, "returns a fresh table")
  assert_eq(before, snapshot(input), "nauvis params byte-for-byte unchanged (deep-copy)")
  assert_eq(true, params.draw_orbit, "generic fields carried over")
  assert_eq(0.5, params.stars.intensity, "nested generic fields deep-copied")
  params.platform_backdrop.radius = 99999
  assert_eq(1, input.platform_backdrop.radius, "output shares no nested state with input")
end)

test("apply_backdrop wires Cindra from nauvis without touching nauvis", function()
  local planet = {}
  local nauvis = { platform_surface_render_parameters = fake_nauvis_params() }
  local before = snapshot(nauvis.platform_surface_render_parameters)
  local ret = space.apply_backdrop(planet, nauvis)
  assert_eq(planet, ret)
  assert_true(planet.platform_surface_render_parameters ~= nil, "cindra gets its backdrop")
  assert_eq(NO_ROTATION, planet.platform_surface_render_parameters.platform_backdrop.rotation_seconds)
  assert_eq(before, snapshot(nauvis.platform_surface_render_parameters), "nauvis untouched")
end)

test("apply_backdrop is a no-op when nauvis has no render params", function()
  local planet = {}
  space.apply_backdrop(planet, {})
  assert_nil(planet.platform_surface_render_parameters, "no source -> nothing wired")
end)

-- ---- End-to-end: drive data-updates.lua with a stubbed data stage ----
-- Proves the wiring script itself applies the art and respects the invariant.

test("data-updates.lua wires Cindra + tech icon and leaves nauvis unchanged", function()
  local nauvis = {
    name = "nauvis",
    platform_surface_render_parameters = fake_nauvis_params(),
  }
  local nauvis_before = snapshot(nauvis)

  _G.data = {
    raw = {
      planet = {
        cindra = { name = "cindra", icon = "__base__/graphics/icons/vulcanus.png" },
        nauvis = nauvis,
      },
      technology = {
        ["planet-discovery-cindra"] = {
          name = "planet-discovery-cindra",
          icon = "__base__/graphics/technology/vulcanus.png",
          icon_size = 256,
        },
      },
    },
  }

  dofile("data-updates.lua")

  local cindra = _G.data.raw.planet.cindra
  local tech = _G.data.raw.technology["planet-discovery-cindra"]

  -- Cindra got the baked icon + star-map (placeholder replaced).
  assert_eq("__cindra__/graphics/icons/cindra.png", cindra.icon, "cindra icon swapped in")
  assert_eq("__cindra__/graphics/icons/starmap-planet-cindra.png", cindra.starmap_icon, "star-map swapped in")

  -- Cindra got the non-rotating orbital backdrop.
  assert_true(cindra.platform_surface_render_parameters ~= nil, "cindra backdrop applied")
  assert_eq(NO_ROTATION, cindra.platform_surface_render_parameters.platform_backdrop.rotation_seconds,
    "cindra backdrop is tidally locked")

  -- Discovery tech icon matched to the real planet.
  assert_eq("__cindra__/graphics/icons/cindra.png", tech.icon, "tech icon swapped in")
  assert_eq(64, tech.icon_size, "tech icon_size updated to match the new icon")

  -- THE invariant: nauvis is byte-for-byte unchanged by the whole wiring pass.
  assert_eq(nauvis_before, snapshot(nauvis), "nauvis prototype untouched by Cindra's art wiring")
end)

_G.data = nil

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
