-- Plain-Lua unit test for the rock-model audit (scripts/rock-models.lua), the guard
-- behind the data-stage check in prototypes/rock-models.lua.
-- Run: cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_rock_models.lua
--
-- WHAT THE PLAYER SEES, AND WHY IT IS CHECKED HERE. A rock announces itself by its
-- silhouette long before it is clicked: the cold side is supposed to read as ICE, and a
-- volcanic rock standing on burning ground is supposed to GLOW. Cindra shipped neither
-- -- the cold rocks were the brown huge-rock model under a blue multiply-tint, which
-- the playtest called out as "blue-tinted normal rocks" -- so the observable failure is
-- "the wrong boulder is on screen".
--
-- That is checkable only at the data stage: the engine draws a simple-entity from its
-- `pictures`, and the runtime prototype API exposes NO graphics accessor, so a
-- factorio-test literally cannot see which model is being drawn. scripts/rock-models.lua
-- is pure so the check is reachable from here with no Factorio at all, and these tests
-- drive it with hand-built data.raw fixtures that reproduce the real regression.

package.path = package.path .. ";./?.lua;./?/init.lua"
local rock_models = require("scripts.rock-models")
local field = require("scripts.resource-field")

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

local function assert_true(x, msg)
  if not x then error(msg or "expected true", 2) end
end

local function joined(list) return table.concat(list, " | ") end

local function has(list, needle)
  for _, v in ipairs(list) do
    if v:find(needle, 1, true) then return true end
  end
  return false
end

-- Sprites for a fake vanilla model: `n` variations under that model's own art path.
local function pictures_for(model, n)
  local pics = {}
  for i = 1, n do
    pics[i] = { filename = "__fake__/graphics/" .. model .. "/" .. model .. "-" .. i .. ".png" }
  end
  return pics
end

-- A data.raw-like table where every catalogue rock correctly wears its declared model
-- (and carries its declared tint, if any). `mutate` gets the table before it is returned
-- so a test can break exactly one thing.
local function fixture(mutate)
  local entities = {}
  for _, spec in ipairs(rock_models.ROCKS) do
    entities[spec.clone_from] = entities[spec.clone_from]
      or { name = spec.clone_from, pictures = pictures_for(spec.clone_from, 3) }
    local pics = pictures_for(spec.clone_from, 3)
    if spec.tint then
      for _, p in ipairs(pics) do p.tint = { r = 1, g = 0.9, b = 0.6, a = 1 } end
    end
    entities[spec.name] = {
      name = spec.name, pictures = pics,
      autoplace = { order = spec.place_order },
    }
  end
  local raw = { ["simple-entity"] = entities }
  if mutate then mutate(raw) end
  return raw
end

-- ---------------------------------------------------------------------------
-- The catalogue itself: the models the bead asks for.
-- ---------------------------------------------------------------------------

test("the cold-side rocks wear ICE FORMATION models, not a recoloured rock (ci-w87)", function()
  for _, name in ipairs(field.ice_rock_names()) do
    local spec = rock_models.spec(name)
    assert_true(spec ~= nil, name .. " must declare a model")
    assert_true(spec.clone_from:find("lithium%-iceberg"),
      name .. " must wear an ice-formation model; got " .. spec.clone_from)
    assert_true(spec.tint == nil,
      name .. " must draw the ice art as authored -- a tint over other art is the ci-w87 bug")
  end
  -- Both ends of the size family are present, so the cold ground has a big rock and an
  -- occasional landmark rather than one repeated boulder.
  local sources = {}
  for _, name in ipairs(field.ice_rock_names()) do sources[rock_models.clone_from(name)] = true end
  assert_true(sources["lithium-iceberg-big"], "the big ice formation is used")
  assert_true(sources["lithium-iceberg-huge"], "the huge ice formation is used")
end)

test("no Cindra rock wears the plain huge-rock model on the COLD side (ci-w87)", function()
  for _, name in ipairs(field.ice_rock_names()) do
    assert_true(rock_models.clone_from(name) ~= "huge-rock",
      name .. " is still the brown rubble model -- exactly what the playtest rejected")
  end
end)

test("the lava-area volcanic rocks wear the HOT (glowing) models (ci-w87)", function()
  local hot, cool = {}, {}
  for _, name in ipairs(field.burned_rock_names()) do
    local src = rock_models.clone_from(name)
    assert_true(src ~= nil, name .. " must declare a model")
    if field.is_hot_burned_rock(name) then hot[#hot + 1] = src else cool[#cool + 1] = src end
  end
  assert_true(#hot == 2, "both sizes have a hot model; got " .. joined(hot))
  assert_true(#cool == 2, "both sizes have a cool model; got " .. joined(cool))
  for _, src in ipairs(hot) do
    assert_true(src:find("%-hot$"), "a lava-area rock must wear a hot model; got " .. src)
  end
  for _, src in ipairs(cool) do
    assert_true(not src:find("%-hot$"), "a safe-slope rock must NOT glow; got " .. src)
  end
  -- The hot twin must be the SAME boulder, just glowing: the sizes have to pair up, or
  -- crossing the lava edge would look like the rocks changed species.
  table.sort(hot)
  table.sort(cool)
  for i = 1, #hot do
    assert_true(hot[i] == cool[i] .. "-hot",
      "hot model " .. hot[i] .. " is not the glowing twin of " .. cool[i])
  end
end)

-- ---------------------------------------------------------------------------
-- The audit: it must actually catch the regression it exists to catch.
-- ---------------------------------------------------------------------------

test("a correctly modelled rock set audits clean", function()
  local bad = rock_models.offenders(fixture())
  assert_true(#bad == 0, "expected no offenders, got:\n  " .. table.concat(bad, "\n  "))
end)

test("CATCHES the real regression: an ice rock rebuilt from huge-rock art (ci-w87)", function()
  local raw = fixture(function(r)
    local e = r["simple-entity"]
    e["huge-rock"] = { name = "huge-rock", pictures = pictures_for("huge-rock", 3) }
    -- Exactly the shipped bug: the cold rock is the brown boulder, repainted blue.
    e[field.ICE_ROCK].pictures = pictures_for("huge-rock", 3)
    for _, p in ipairs(e[field.ICE_ROCK].pictures) do
      p.tint = { r = 0.62, g = 0.82, b = 1.0, a = 1.0 }
    end
  end)
  local bad = rock_models.offenders(raw)
  assert_true(has(bad, field.ICE_ROCK), "the mis-modelled ice rock must be reported: " .. joined(bad))
end)

test("CATCHES a rock that is merely recoloured instead of re-modelled", function()
  local raw = fixture(function(r)
    -- Right model, but painted over: still not what the player is meant to see.
    for _, p in ipairs(r["simple-entity"][field.ICE_ROCK].pictures) do
      p.tint = { r = 0.5, g = 0.8, b = 1.0, a = 1 }
    end
  end)
  assert_true(has(rock_models.offenders(raw), "recoloured"),
    "a tint on an untinted-by-design model must be reported")
end)

test("CATCHES a declared recolour that goes missing", function()
  local raw = fixture(function(r)
    for _, p in ipairs(r["simple-entity"][field.ROCK].pictures) do p.tint = nil end
  end)
  assert_true(has(rock_models.offenders(raw), "recolour"),
    "the sandy rock losing its stone tint must be reported")
end)

test("CATCHES a rock that draws nothing at all", function()
  local raw = fixture(function(r)
    r["simple-entity"][field.BURNED_ROCK_HOT].pictures = {}
  end)
  assert_true(has(rock_models.offenders(raw), "draws no sprite"),
    "an invisible rock must be reported")
end)

-- The COVERAGE guard: the class is enumerated from the live prototype table, so a new
-- rock cannot ship without a declared model just because nobody edited a list.
test("COVERAGE: a new autoplacing Cindra rock with no declared model fails the audit", function()
  local raw = fixture(function(r)
    r["simple-entity"]["cindra-obsidian-rock"] = {
      name = "cindra-obsidian-rock",
      pictures = pictures_for("some-vanilla-rock", 2),
      autoplace = {},
    }
  end)
  assert_true(has(rock_models.offenders(raw), "cindra-obsidian-rock"),
    "an undeclared worldgen rock must be reported")
end)

test("COVERAGE ignores Cindra entities that never generate in the world", function()
  local raw = fixture(function(r)
    -- No autoplace: the player never meets it as scenery, so it is not a worldgen rock.
    r["simple-entity"]["cindra-scripted-prop"] = {
      name = "cindra-scripted-prop", pictures = pictures_for("prop", 1),
    }
  end)
  local bad = rock_models.offenders(raw)
  assert_true(not has(bad, "cindra-scripted-prop"),
    "a non-autoplacing entity must not be flagged: " .. joined(bad))
end)

-- ---------------------------------------------------------------------------
-- Placement order. Two rocks sharing an autoplace order share the engine's per-tile
-- random roll, so the loser of every tie is dropped for colliding with the winner and
-- generates ZERO times -- silently, since the prototype is still perfectly valid. That
-- is what `cindra-volcanic-rock-huge` did before ci-w87: it never once appeared on a
-- live surface, and the family-summing tests never noticed.
-- ---------------------------------------------------------------------------

test("every rock has its OWN autoplace order (a shared one never generates, ci-w87)", function()
  local seen = {}
  for _, spec in ipairs(rock_models.ROCKS) do
    assert_true(spec.place_order ~= nil, spec.name .. " must declare a placement order")
    assert_true(seen[spec.place_order] == nil,
      spec.name .. " shares its order with " .. tostring(seen[spec.place_order])
        .. " -- one of them would generate nowhere")
    seen[spec.place_order] = spec.name
  end
end)

test("the HUGE model is placed before its big sibling, so landmarks survive (ci-w87)", function()
  -- Both sizes want the same ground; whichever is placed first claims the tile. The
  -- rare huge boulder has to go first or the common one crowds it out of existence.
  for _, pair in ipairs({ { field.ICE_ROCK_HUGE, field.ICE_ROCK },
                          { field.BURNED_ROCK_HUGE, field.BURNED_ROCK },
                          { field.BURNED_ROCK_HUGE_HOT, field.BURNED_ROCK_HOT } }) do
    assert_true(rock_models.place_order(pair[1]) < rock_models.place_order(pair[2]),
      pair[1] .. " must sort before " .. pair[2])
  end
end)

test("CATCHES two rocks registered on the same autoplace order", function()
  local raw = fixture(function(r)
    r["simple-entity"][field.ICE_ROCK].autoplace.order =
      rock_models.place_order(field.ICE_ROCK_HUGE)
  end)
  assert_true(has(rock_models.offenders(raw), field.ICE_ROCK),
    "a rock whose registered order is not its declared one must be reported")
end)

test("CATCHES a rock registered with no autoplace order at all", function()
  local raw = fixture(function(r)
    r["simple-entity"][field.BURNED_ROCK_HUGE].autoplace.order = nil
  end)
  assert_true(has(rock_models.offenders(raw), field.BURNED_ROCK_HUGE),
    "an order-less rock (the silent never-generates bug) must be reported")
end)

-- ---------------------------------------------------------------------------
-- The sprite helpers the audit is built on.
-- ---------------------------------------------------------------------------

test("sprite_filenames walks flat variations, layered sprites and filenames lists", function()
  local pics = {
    { filename = "a.png" },
    { layers = { { filename = "b.png" }, { filename = "c.png" } } },
    { filenames = { "d.png", "e.png" }, lines_per_file = 1 },
  }
  local found = rock_models.sprite_filenames(pics)
  assert_true(#found == 5, "found " .. #found .. ": " .. joined(found))
  assert_true(found[1] == "a.png" and found[5] == "e.png", "sorted: " .. joined(found))
end)

test("is_tinted sees a tint on a layer, not just on a top-level sprite", function()
  assert_true(not rock_models.is_tinted({ { filename = "a.png" } }), "untinted art is untinted")
  assert_true(rock_models.is_tinted({ { filename = "a.png", tint = { r = 1 } } }), "flat tint seen")
  assert_true(rock_models.is_tinted({ { layers = { { filename = "a.png", tint = { r = 1 } } } } }),
    "layer tint seen")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
