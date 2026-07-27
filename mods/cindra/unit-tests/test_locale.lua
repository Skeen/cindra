-- Plain-Lua unit test for the Cindra locale (locale/en/cindra.cfg).
-- Run: cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_locale.lua
--
-- The .cfg is pure text (no Factorio runtime needed to read it), so its
-- invariants are checked here rather than in an integration test: the game
-- resolves locale client-side, so `prototypes.*` cannot tell us whether a key
-- actually exists in the file. This test is the guard that keeps the ci-11b
-- lore/description text well-formed and complete:
--
--   * the file parses (well-formed sections, no duplicate keys, no empty values);
--   * the §3 codex/lore section is present and substantial;
--   * every locale key a prototype explicitly references (localised_name /
--     localised_description = { "cat.key" }) has a matching entry, so no building
--     or item ships showing an "Unknown key" placeholder;
--   * every *-description has a sibling *-name (no orphan descriptions).

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

local function assert_true(x, msg)
  if not x then error(msg or "expected true", 2) end
end

local function read_file(path)
  local f = assert(io.open(path, "r"), "could not open " .. path)
  local body = f:read("*a")
  f:close()
  return body
end

-- Parse an .ini/.cfg into { section = { key = value, ... }, ... }.
-- Also records, per section, the raw key order so we can catch duplicates.
local function parse_cfg(body)
  local sections, dup = {}, {}
  local current
  local line_no = 0
  for line in (body .. "\n"):gmatch("(.-)\n") do
    line_no = line_no + 1
    local trimmed = line:gsub("^%s+", ""):gsub("%s+$", "")
    if trimmed == "" or trimmed:sub(1, 1) == "#" then
      -- blank or comment; skip
    else
      local sec = trimmed:match("^%[([^%]]+)%]$")
      if sec then
        current = sec
        sections[sec] = sections[sec] or {}
      else
        local key, value = trimmed:match("^([^=]+)=(.*)$")
        assert_true(key ~= nil, "line " .. line_no .. " is neither section, comment nor key=value: " .. line)
        assert_true(current ~= nil, "key before any section on line " .. line_no)
        if sections[current][key] ~= nil then
          dup[#dup + 1] = current .. "." .. key
        end
        sections[current][key] = value
      end
    end
  end
  return sections, dup
end

local CFG_PATH = "locale/en/cindra.cfg"
local body = read_file(CFG_PATH)
local cfg, dups = parse_cfg(body)

test("cfg parses with no duplicate keys inside a section", function()
  assert_true(#dups == 0, "duplicate locale keys: " .. table.concat(dups, ", "))
end)

test("no locale value is empty or blank", function()
  for section, entries in pairs(cfg) do
    for key, value in pairs(entries) do
      assert_true(value:gsub("%s", "") ~= "",
        "empty locale value for " .. section .. "." .. key)
    end
  end
end)

test("mod identity strings are present", function()
  assert_true(cfg["mod-name"] and cfg["mod-name"].cindra, "[mod-name] cindra")
  assert_true(cfg["mod-description"] and cfg["mod-description"].cindra, "[mod-description] cindra")
  assert_true(cfg["space-location-name"] and cfg["space-location-name"].cindra,
    "[space-location-name] cindra")
end)

test("map name is just 'Cindra' with no tagline (ci-2sr)", function()
  local name = cfg["space-location-name"] and cfg["space-location-name"].cindra
  assert_true(name == "Cindra",
    "[space-location-name] cindra must read exactly 'Cindra'; got " .. tostring(name))
  assert_true(not name:lower():find("ribbon"),
    "the 'Ribbon World' tagline must not leak into the map name (docs only)")
end)

test("planet carries a map description (ci-2sr)", function()
  local desc = cfg["space-location-description"] and cfg["space-location-description"].cindra
  assert_true(desc ~= nil, "[space-location-description] cindra must exist for the map panel")
  assert_true(#desc > 60, "the planet description must be real prose, like the vanilla planets")
end)

test("§3 codex/lore section carries all five entries, each substantial", function()
  local lore = cfg["cindra-lore"]
  assert_true(lore ~= nil, "[cindra-lore] section must exist")
  for _, key in ipairs({ "discovery", "ribbon", "flare", "nightside", "alloy" }) do
    assert_true(lore[key] ~= nil, "missing lore entry: cindra-lore." .. key)
    assert_true(#lore[key] > 40, "lore entry too short to be real prose: " .. key)
  end
end)

test("planet discovery technology has both a name and a lore description", function()
  assert_true(cfg["technology-name"] and cfg["technology-name"]["planet-discovery-cindra"],
    "technology-name.planet-discovery-cindra")
  local desc = cfg["technology-description"] and cfg["technology-description"]["planet-discovery-cindra"]
  assert_true(desc ~= nil and #desc > 100, "planet discovery description must be full lore text")
end)

-- Gather every locale key a prototype file explicitly references as a
-- LocalisedString literal: { "category.key" }. These MUST resolve or the game
-- renders an "Unknown key" placeholder in the building/item tooltip.
local function collect_referenced_keys()
  local refs = {}
  local dir = "prototypes"
  -- lua has no portable directory listing; enumerate the known prototype files.
  local p = io.popen and io.popen("ls " .. dir .. "/*.lua 2>/dev/null")
  local files = {}
  if p then
    for line in p:lines() do files[#files + 1] = line end
    p:close()
  end
  assert_true(#files > 0, "expected to find prototype .lua files to scan")
  for _, path in ipairs(files) do
    local src = read_file(path)
    for cat, key in src:gmatch('{%s*"([%w%-]+)%.([%w%-]+)"%s*}') do
      refs[cat .. "|" .. key] = path
    end
  end
  return refs
end

test("every locale key referenced by a prototype exists in the cfg", function()
  local refs = collect_referenced_keys()
  local missing = {}
  for combo, path in pairs(refs) do
    local cat, key = combo:match("^(.-)|(.+)$")
    if not (cfg[cat] and cfg[cat][key] ~= nil) then
      missing[#missing + 1] = cat .. "." .. key .. " (referenced in " .. path .. ")"
    end
  end
  assert_true(#missing == 0, "prototype references with no locale entry: " .. table.concat(missing, ", "))
end)

test("every *-description has a sibling *-name (no orphan descriptions)", function()
  local orphans = {}
  for section, entries in pairs(cfg) do
    local base = section:match("^(.+)%-description$")
    if base then
      local name_section = cfg[base .. "-name"] or {}
      for key in pairs(entries) do
        if name_section[key] == nil then
          orphans[#orphans + 1] = section .. "." .. key
        end
      end
    end
  end
  assert_true(#orphans == 0, "descriptions with no matching name: " .. table.concat(orphans, ", "))
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
