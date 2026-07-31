-- Plain-Lua unit test for the red-mud subsystem prototypes (ci-c7j): the Bayer
-- alumina route + iron recovery. Pure data-stage shape + invariant checks that
-- need no Factorio runtime -- it stubs the data stage, requires the REAL
-- prototypes/red-mud.lua module, and asserts the recipe/item/tech shapes and the
-- load-bearing matter-honesty invariants (prod OFF, NO stone return, iron traces
-- to real red mud). The runtime behaviour + whole-graph invariants are proven in
-- the integration tests (tests/test_red_mud.lua, tests/test_materials_graph.lua).
--
-- Run: cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_red_mud.lua

package.path = package.path .. ";./?.lua;./?/init.lua"

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
  if x ~= nil then error(msg or "expected nil", 2) end
end

-- === Stub the Factorio data stage =========================================
local function deepcopy(t)
  if type(t) ~= "table" then return t end
  local out = {}
  for k, v in pairs(t) do out[k] = deepcopy(v) end
  return out
end

package.loaded["util"] = {
  table = { deepcopy = deepcopy },
  by_pixel = function(x, y) return { x / 32, y / 32 } end,
}

-- Minimal vanilla prototypes red-mud.lua clones. Each is only cloned and then has
-- fields SET on it, so a bare table with the touched fields suffices.
local registry = {}
local data = {
  raw = {
    ["item"] = {
      ["calcite"] = { type = "item", name = "calcite" },
      ["assembling-machine-3"] = { type = "item", name = "assembling-machine-3" },
    },
    ["assembling-machine"] = {
      ["assembling-machine-3"] = {
        type = "assembling-machine", name = "assembling-machine-3",
        energy_usage = "375kW", crafting_categories = { "crafting" },
      },
    },
  },
}
function data:extend(list)
  for _, proto in ipairs(list) do
    registry[proto.type] = registry[proto.type] or {}
    registry[proto.type][proto.name] = proto
  end
end
_G.data = data

require("prototypes.red-mud")

local function proto(kind, name) return (registry[kind] or {})[name] end

-- Icon/sprite file checks (the runtime API does not expose icon paths, so we
-- assert the shipped PNGs the same way test_materials_graphics does). Unit tests
-- run from mods/cindra, so __cindra__/ maps to ./.
local function to_rel(modpath) return (modpath:gsub("^__cindra__/", "./")) end

local function ships(modpath)
  local f = io.open(to_rel(modpath), "rb")
  if f then f:close() return true end
  return false
end

-- PNG colour-type byte (26th, 1-indexed): 6 = truecolour+alpha (RGBA). Factorio
-- draws indexed/palette PNGs black, so shipped art must be RGBA.
local function png_color_type(modpath)
  local f = io.open(to_rel(modpath), "rb")
  if not f then return nil end
  local head = f:read(26)
  f:close()
  if not head or #head < 26 then return nil end
  return head:byte(26)
end

local function amount_of(list, name)
  for _, e in ipairs(list) do
    if e.name == name then return e.amount end
  end
  return nil
end

local function product(list, name)
  for _, e in ipairs(list) do
    if e.name == name then return e end
  end
  return nil
end

-- === Items: bespoke icons (ci-zdp) =========================================
-- Each item draws its OWN dedicated 64x64 render (Malcolm Riley unused-renders),
-- not the shared cindra-stone placeholder. red mud additionally leans rust-red
-- in-engine; slag ships already-grey so it needs no tint.
for _, spec in ipairs({
  { name = "cindra-red-mud", tinted = true },
  { name = "cindra-slag", tinted = false },
}) do
  test(spec.name .. " draws its bespoke icon (no cindra-stone placeholder)", function()
    local p = proto("item", spec.name)
    assert_true(p ~= nil, spec.name .. " must be registered as an item")
    assert_eq(100, p.stack_size, spec.name .. " stack size")
    assert_true(p.icons and p.icons[1], spec.name .. " must set a layered icon")
    local path = p.icons[1].icon
    local expected = "__cindra__/graphics/icons/" .. spec.name .. ".png"
    assert_eq(expected, path, spec.name .. " must draw its own bespoke render")
    assert_true(path:find("cindra-stone", 1, true) == nil,
      spec.name .. " must NOT fall back to the cindra-stone placeholder")
    assert_true(path:find("__base__", 1, true) == nil and path:find("__space%-age__") == nil,
      spec.name .. " must not use a vanilla placeholder icon")
    assert_eq(64, p.icons[1].icon_size, spec.name .. " icon_size")
    assert_true(ships(path), "icon PNG must ship: " .. path)
    assert_eq(6, png_color_type(path), "icon PNG must be truecolour RGBA: " .. path)
    if spec.tinted then
      assert_true(p.icons[1].tint ~= nil, spec.name .. " must keep its rust-red lean tint")
    end
  end)
end

-- === Arc furnace ============================================================
test("the arc furnace is a private-category high-draw machine", function()
  local e = proto("assembling-machine", "cindra-arc-furnace")
  assert_true(e ~= nil, "the furnace entity must be registered")
  assert_eq("45MW", e.energy_usage, "the furnace must draw 45 MW (a ruinous continuous draw)")
  assert_eq(1, #e.crafting_categories, "the furnace runs exactly one (private) category")
  assert_eq("cindra-arc-furnace", e.crafting_categories[1], "the private category")
  assert_nil(e.next_upgrade, "the furnace must not upgrade to a vanilla assembler")
  assert_eq("cindra-arc-furnace", e.minable.result, "the furnace mines back to itself")
  local item = proto("item", "cindra-arc-furnace")
  assert_true(item ~= nil, "the furnace item must be registered")
  assert_eq("cindra-arc-furnace", item.place_result, "the item places the furnace")
end)

-- === Arc furnace: bespoke art (ci-hs1j) =====================================
-- Hurricane046's animated "arc furnace" set (CC-BY), freed by ci-a6z. The body +
-- emission are 320x320-frame sheets; the shadow is a static image. No AM3 leak.
test("the furnace draws the arc-furnace set (no assembling-machine-3 art)", function()
  local e = proto("assembling-machine", "cindra-arc-furnace")
  assert_true(e.graphics_set and e.graphics_set.animation and e.graphics_set.animation.layers,
    "the furnace must render via a layered graphics_set.animation")
  local body = e.graphics_set.animation.layers[1].filename
  local expected = "__cindra__/graphics/entity/arc-furnace/arc-furnace-hr-animation-1.png"
  assert_eq(expected, body, "the furnace body sprite must be the arc-furnace render")
  assert_true(body:find("assembling%-machine") == nil and body:find("__base__", 1, true) == nil,
    "no assembling-machine-3 / vanilla sprite may leak through")
  assert_true(body:find("carbothermic", 1, true) == nil,
    "no carbothermic-furnace art may leak through")
  assert_true(ships(body), "the furnace body sprite must ship: " .. body)
  assert_eq(6, png_color_type(body), "the furnace body sprite must be truecolour RGBA")
  local shadow = e.graphics_set.animation.layers[2]
  assert_true(shadow and shadow.draw_as_shadow, "the furnace must ship a shadow layer")
  assert_true(ships(shadow.filename), "the furnace shadow sprite must ship: " .. shadow.filename)
  assert_eq(6, png_color_type(shadow.filename), "the furnace shadow sprite must be truecolour RGBA")
  local glow = e.graphics_set.animation.layers[3]
  assert_true(glow and glow.draw_as_glow, "the furnace must ship an emissive glow layer")
  assert_eq("additive", glow.blend_mode, "the opaque-black emission sheet must blend additive")
  assert_true(ships(glow.filename), "the furnace emission sprite must ship: " .. glow.filename)
end)

test("the furnace item + entity carry the arc-furnace icon", function()
  local icon = "__cindra__/graphics/icons/arc-furnace-icon.png"
  for _, kind in ipairs({ "assembling-machine", "item" }) do
    local p = proto(kind, "cindra-arc-furnace")
    assert_eq(icon, p.icon, kind .. " must draw the arc-furnace icon")
    assert_true(p.icon and p.icon:find("assembling%-machine") == nil,
      kind .. " must not keep the assembling-machine-3 icon")
    assert_true(p.icon:find("carbothermic", 1, true) == nil,
      kind .. " must not keep the carbothermic-furnace icon")
    assert_eq(64, p.icon_size, kind .. " furnace icon_size")
  end
  assert_true(ships(icon), "the furnace icon PNG must ship: " .. icon)
  assert_eq(6, png_color_type(icon), "the furnace icon PNG must be truecolour RGBA")
end)

-- === Bayer recipe ===========================================================
test("Bayer: stone + quicklime -> alumina + red mud, no stone return, prod off", function()
  local r = proto("recipe", "cindra-bayer-alumina")
  assert_true(r ~= nil, "the Bayer recipe must be registered")
  assert_true((amount_of(r.ingredients, "stone") or 0) > 0, "Bayer consumes real stone")
  assert_true((amount_of(r.ingredients, "cindra-quicklime") or 0) > 0, "Bayer consumes quicklime")
  assert_nil(amount_of(r.ingredients, "sulfuric-acid"), "Bayer needs no sulfuric acid")
  assert_true(product(r.results, "cindra-alumina") ~= nil, "Bayer yields alumina")
  assert_true(product(r.results, "cindra-red-mud") ~= nil, "Bayer yields red mud")
  assert_nil(product(r.results, "stone"), "Bayer must return NO stone (opens no stone vector)")
  assert_eq(false, r.allow_productivity, "Bayer must disable productivity")
  assert_eq(false, r.enabled, "Bayer must be gated off until its tech")
  assert_eq("cindra-alumina", r.main_product, "alumina is the main product")
end)

-- === Iron recovery ==========================================================
test("iron recovery: red mud + CO2 -> iron-plate + slag, private category, prod off", function()
  local r = proto("recipe", "cindra-iron-recovery")
  assert_true(r ~= nil, "the iron-recovery recipe must be registered")
  assert_true((amount_of(r.ingredients, "cindra-red-mud") or 0) > 0, "iron recovery consumes red mud")
  assert_true((amount_of(r.ingredients, "cindra-carbon-dioxide") or 0) > 0,
    "iron recovery consumes CO2 (its carbon reductant, closing the calcination loop)")
  assert_true(product(r.results, "iron-plate") ~= nil, "iron recovery yields the vanilla iron-plate")
  assert_true(product(r.results, "cindra-slag") ~= nil, "iron recovery yields slag")
  assert_nil(amount_of(r.ingredients, "stone"), "iron recovery touches no stone")
  assert_nil(product(r.results, "stone"), "iron recovery returns no stone")
  assert_eq(1, #r.categories, "iron recovery runs exactly one (private) category")
  assert_eq("cindra-arc-furnace", r.categories[1], "the private arc-furnace category")
  assert_eq(false, r.allow_productivity, "iron recovery must disable productivity (no free metal)")
  assert_eq(false, r.enabled, "iron recovery must be gated off until its tech")
end)

-- === Slag vent ==============================================================
test("vent-slag is a prod-off pure sink for the inert tailings", function()
  local r = proto("recipe", "cindra-vent-slag")
  assert_true(r ~= nil, "the slag vent must be registered")
  assert_true((amount_of(r.ingredients, "cindra-slag") or 0) > 0, "vent-slag consumes slag")
  assert_eq(0, #r.results, "vent-slag must be a pure sink (no products)")
  assert_eq(false, r.allow_productivity, "vent-slag must disable productivity")
end)

-- === Category + tech ========================================================
test("the private recipe category is registered", function()
  local c = proto("recipe-category", "cindra-arc-furnace")
  assert_true(c ~= nil, "the cindra-arc-furnace recipe-category must be registered")
end)

test("the tech clusters the subsystem behind the materials-chemistry tech", function()
  local t = proto("technology", "cindra-red-mud")
  assert_true(t ~= nil, "the cindra-red-mud tech must be registered")
  assert_eq("cindra-calcite-olefins", t.prerequisites[1],
    "the tech must require the materials-chemistry tech (needs its quicklime + CO2)")
  local unlocked = {}
  for _, eff in ipairs(t.effects) do
    if eff.type == "unlock-recipe" then unlocked[eff.recipe] = true end
  end
  for _, rn in ipairs({
    "cindra-bayer-alumina", "cindra-iron-recovery",
    "cindra-arc-furnace", "cindra-vent-slag",
  }) do
    assert_true(unlocked[rn], "the tech must unlock " .. rn)
  end
  -- Researched with brought vanilla packs (no soft-lock behind the Cindra pack).
  for _, ing in ipairs(t.unit.ingredients) do
    assert_true(ing[1] ~= "cindra-science-pack", "the tech must not cost the Cindra pack")
  end
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
