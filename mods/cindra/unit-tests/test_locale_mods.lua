-- Cross-mod locale regression guard (ci-dvr).
-- Run: cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_locale_mods.lua
--
-- The reported bug (ci-dvr) was mod settings showing their raw key (e.g.
-- "cindra-zone-width-hot-lava") in Settings > Mod settings because the locale
-- entry was missing. cindra/unit-tests/test_locale.lua already guards the cindra
-- mod's OWN settings; this test extends the SAME guard to EVERY mod in the mod
-- set so the bug can never regress silently in ANY mod -- the "across ALL Cindra
-- mods" half of the bead.
--
-- npm's test:unit only runs THIS directory (`cd mods/cindra && lua
-- unit-tests/test_*.lua`), so the sibling mods have no CI-run unit tests of their
-- own. This guard reaches them from here (cwd = mods/cindra) via "../<mod>/...".
--
-- What it checks, per mod:
--   * every mod setting registered by settings.lua has a [mod-setting-name] and
--     [mod-setting-description] entry, and every string-setting value has a
--     [string-mod-setting-<name>] dropdown label, in that mod's locale;
--   * every sibling locale .cfg is well-formed (parses, no empty values).
--
-- Mods deliberately NOT swept and why:
--   * cindra-dev-default: settings.lua only sets an APS default; registers no
--     setting prototype and ships no prototypes, so it has nothing to translate.
-- The old two-word tagline is banned repo-wide by test_branding.lua's git-grep
-- guard, so it is not re-checked here.
--
-- (The flare-poc / mass-driver / freeze-radius-poc spikes were removed with
-- ci-eao once their behavior shipped in mods/cindra or the spike concluded, so
-- their locale sweeps went with them.)

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

-- Minimal .cfg parser: { section = { key = value } }, plus a duplicate list.
local function parse_cfg(body, label)
  local sections, dup, current, line_no = {}, {}, nil, 0
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
        assert_true(key ~= nil,
          (label or "cfg") .. " line " .. line_no .. " is not section/comment/key=value: " .. line)
        assert_true(current ~= nil, (label or "cfg") .. " key before any section on line " .. line_no)
        if sections[current][key] ~= nil then dup[#dup + 1] = current .. "." .. key end
        sections[current][key] = value
      end
    end
  end
  return sections, dup
end

-- Load a mod's settings.lua under a stubbed data:extend, collecting every
-- setting prototype it registers (including loop-generated ones). `mods` is
-- stubbed empty so APS-guarded siblings (cindra-start / cindra-dev-default) take
-- their "APS absent" branch and register nothing, exactly as they would with APS
-- uninstalled. Returns the collected settings (possibly empty).
local function load_settings(path)
  local collected = {}
  local prev_data, prev_mods = _G.data, _G.mods
  _G.data = { raw = {}, extend = function(_, list)
    for _, s in ipairs(list) do collected[#collected + 1] = s end
  end }
  _G.mods = {}
  local ok, err = pcall(dofile, path)
  _G.data, _G.mods = prev_data, prev_mods
  assert_true(ok, path .. " failed to load under the test stub: " .. tostring(err))
  return collected
end

-- ---------------------------------------------------------------------------
-- Per-mod mod-setting locale coverage. cwd is mods/cindra, so siblings are
-- reached via "../<mod>/...". Every mod that ships a settings.lua is swept.
-- ---------------------------------------------------------------------------
local SETTING_MODS = {
  { mod = "cindra",            settings = "settings.lua",
    locale = "locale/en/cindra.cfg" },
  { mod = "cindra-start",      settings = "../cindra-start/settings.lua",
    locale = "../cindra-start/locale/en/cindra-start.cfg" },
  { mod = "cindra-dev-default", settings = "../cindra-dev-default/settings.lua",
    locale = nil },
}

for _, m in ipairs(SETTING_MODS) do
  local settings = load_settings(m.settings)
  local cfg = m.locale and parse_cfg(read_file(m.locale), m.mod) or {}

  test(m.mod .. ": every mod setting has a [mod-setting-name] entry", function()
    local names = cfg["mod-setting-name"] or {}
    local missing = {}
    for _, s in ipairs(settings) do
      if names[s.name] == nil then missing[#missing + 1] = s.name end
    end
    assert_true(#missing == 0,
      m.mod .. " settings with no [mod-setting-name] (they show the raw key in-game):\n  "
        .. table.concat(missing, "\n  "))
  end)

  test(m.mod .. ": every mod setting has a [mod-setting-description] entry", function()
    local descs = cfg["mod-setting-description"] or {}
    local missing = {}
    for _, s in ipairs(settings) do
      if descs[s.name] == nil then missing[#missing + 1] = s.name end
    end
    assert_true(#missing == 0,
      m.mod .. " settings with no [mod-setting-description]:\n  " .. table.concat(missing, "\n  "))
  end)

  test(m.mod .. ": every string-setting value has a [string-mod-setting-*] label", function()
    local missing = {}
    for _, s in ipairs(settings) do
      if s.type == "string-setting" and s.allowed_values then
        local section = cfg["string-mod-setting-" .. s.name] or {}
        for _, value in ipairs(s.allowed_values) do
          if section[value] == nil then missing[#missing + 1] = s.name .. " -> " .. value end
        end
      end
    end
    assert_true(#missing == 0,
      m.mod .. " string-setting values with no dropdown label:\n  " .. table.concat(missing, "\n  "))
  end)
end

-- ---------------------------------------------------------------------------
-- Every sibling locale .cfg must be well-formed: it parses, has no duplicate
-- keys inside a section, and no empty values (a blank value renders as an empty
-- label, as bad as a missing one).
-- ---------------------------------------------------------------------------
local SIBLING_LOCALES = {
  { mod = "cindra-start",    path = "../cindra-start/locale/en/cindra-start.cfg" },
  { mod = "env-scanner",     path = "../env-scanner/locale/en/env-scanner.cfg" },
}

for _, m in ipairs(SIBLING_LOCALES) do
  test(m.mod .. ": locale cfg is well-formed (parses, no dup keys, no empty values)", function()
    local cfg, dup = parse_cfg(read_file(m.path), m.mod)
    assert_true(#dup == 0, m.mod .. " duplicate locale keys: " .. table.concat(dup, ", "))
    for section, entries in pairs(cfg) do
      for key, value in pairs(entries) do
        assert_true(value:gsub("%s", "") ~= "",
          m.mod .. " empty locale value for " .. section .. "." .. key)
      end
    end
  end)
end

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
