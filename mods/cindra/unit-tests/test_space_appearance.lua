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

test("freezes the globe (tidal lock): rotation_seconds is the huge NO_ROTATION", function()
  local params = space.build_render_parameters(fake_nauvis_params())
  assert_true(params.platform_backdrop ~= nil, "backdrop built")
  assert_eq(NO_ROTATION, params.platform_backdrop.rotation_seconds, "tidal lock rotation")
  assert_true(params.platform_backdrop.rotation_seconds >= 1.0e9, "effectively infinite")
end)

test("points the backdrop maps at the baked Cindra fire/ice art", function()
  local b = space.build_render_parameters(fake_nauvis_params()).platform_backdrop
  assert_eq("__cindra__/graphics/space/cindra.png", b.planet_surface.filename)
  assert_eq("__cindra__/graphics/space/cindra-emission.png", b.planet_emission.filename)
  assert_eq("__cindra__/graphics/space/cindra-cloud.png", b.global_cloud.filename)
  assert_eq("__cindra__/graphics/space/cindra-flare.png", b.hero_cloud_texture_1.filename)
  assert_eq(24, b.hero_cloud_texture_1.frame_count, "24-frame flare sheet")
end)

test("flares/clouds animate in place while the globe stays frozen", function()
  local b = space.build_render_parameters(fake_nauvis_params()).platform_backdrop
  assert_eq(2, #b.hero_clouds, "two staggered flares")
  for i, h in ipairs(b.hero_clouds) do
    assert_eq(false, h.rotate_with_planet, "flare #" .. i .. " arcs in place, not with the frozen globe")
  end
  assert_eq(true, b.hero_clouds_are_emissive, "flares glow")
end)

-- The redesign (ci-hmc) fixes a BLACK presented middle. The sandy ribbon carries
-- its own emission in the map, but that only reaches the orbital view if the
-- backdrop shows emission regardless of the shadow side. Guard that wiring: the
-- self-glow must NOT be gated on shadow, and the emission scalar must be positive.
test("emission self-glow always shows -> the sandy middle is never black in orbit", function()
  local b = space.build_render_parameters(fake_nauvis_params()).platform_backdrop
  assert_eq(false, b.emission_scales_with_shadow, "dayside+sandy-seam glow must show across the disc, not only in light")
  assert_true(b.emission_scalar and b.emission_scalar > 0, "positive emission scalar so the glow reads")
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
