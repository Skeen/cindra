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

-- === Items =================================================================
for _, spec in ipairs({
  { name = "cindra-red-mud", tinted = true },
  { name = "cindra-slag", tinted = true },
}) do
  test(spec.name .. " item is registered with a Cindra-stone placeholder icon", function()
    local p = proto("item", spec.name)
    assert_true(p ~= nil, spec.name .. " must be registered as an item")
    assert_eq(100, p.stack_size, spec.name .. " stack size")
    assert_true(p.icons and p.icons[1], spec.name .. " must set a layered icon")
    assert_eq("__cindra__/graphics/icons/cindra-stone.png", p.icons[1].icon,
      spec.name .. " must reuse the bespoke stone render (no vanilla placeholder)")
    assert_eq(64, p.icons[1].icon_size, spec.name .. " icon_size")
    assert_true(p.icons[1].tint ~= nil, spec.name .. " must set a distinguishing tint")
  end)
end

-- === Carbothermic furnace ===================================================
test("the carbothermic furnace is a private-category high-draw machine", function()
  local e = proto("assembling-machine", "cindra-carbothermic-furnace")
  assert_true(e ~= nil, "the furnace entity must be registered")
  assert_eq("45MW", e.energy_usage, "the furnace must draw 45 MW (a ruinous continuous draw)")
  assert_eq(1, #e.crafting_categories, "the furnace runs exactly one (private) category")
  assert_eq("cindra-carbothermic", e.crafting_categories[1], "the private category")
  assert_nil(e.next_upgrade, "the furnace must not upgrade to a vanilla assembler")
  assert_eq("cindra-carbothermic-furnace", e.minable.result, "the furnace mines back to itself")
  local item = proto("item", "cindra-carbothermic-furnace")
  assert_true(item ~= nil, "the furnace item must be registered")
  assert_eq("cindra-carbothermic-furnace", item.place_result, "the item places the furnace")
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
  assert_eq("cindra-carbothermic", r.categories[1], "the private carbothermic category")
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
  local c = proto("recipe-category", "cindra-carbothermic")
  assert_true(c ~= nil, "the cindra-carbothermic recipe-category must be registered")
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
    "cindra-carbothermic-furnace", "cindra-vent-slag",
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
