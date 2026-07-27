-- Plain-Lua unit test for the cindra-start APS picker label
-- (locale/en/cindra-start.cfg). Run:
--   cd mods/cindra-start && nix shell nixpkgs#lua -c lua unit-tests/test_aps_locale.lua
--
-- Any Planet Start's planet picker is a `string-setting` (`aps-planet`) whose
-- allowed values are raw prototype names ("vulcanus", "cindra", ...). Factorio
-- renders each option's label from the locale key
--   [string-mod-setting] aps-planet-<value>
-- resolved CLIENT-SIDE, so `prototypes.*` cannot see it and an integration test
-- cannot assert it. Without this entry the dropdown falls back to the raw
-- lowercase "cindra" with no image (the ci-ohl bug). This test pins the fix:
-- the label exists, is the capitalized display name "Cindra", and carries the
-- [planet=cindra] rich-text tag that renders the planet icon in the picker
-- (mirroring APS's own aps-planet-vulcanus=[planet=vulcanus] Vulcanus).
--
-- The icon the [planet=cindra] tag resolves to (the real graphics/icons/
-- cindra.png at size 64) is proved separately, at its data-stage source, by
-- cindra/tests/test_space_appearance.lua + cindra/unit-tests/test_space_appearance.lua.

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

-- Minimal .cfg parser: { section = { key = value, ... }, ... }.
local function parse_cfg(body)
  local sections, current = {}, nil
  for line in (body .. "\n"):gmatch("(.-)\n") do
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
        assert_true(key ~= nil, "not a section/comment/key=value: " .. line)
        assert_true(current ~= nil, "key before any section: " .. line)
        sections[current][key] = value
      end
    end
  end
  return sections
end

local cfg = parse_cfg(read_file("locale/en/cindra-start.cfg"))

test("APS picker label for cindra exists", function()
  assert_true(cfg["string-mod-setting"] ~= nil, "[string-mod-setting] section must exist")
  assert_true(cfg["string-mod-setting"]["aps-planet-cindra"] ~= nil,
    "[string-mod-setting] aps-planet-cindra must be defined")
end)

test("label uses the capitalized display name 'Cindra', not the raw 'cindra'", function()
  local label = cfg["string-mod-setting"]["aps-planet-cindra"]
  assert_true(label:find("Cindra", 1, true) ~= nil,
    "label must contain the capitalized name 'Cindra', got: " .. tostring(label))
  -- Guard against a regression to a bare lowercase value with no capitalization.
  local text = label:gsub("%[[^%]]*%]", ""):gsub("%s", "")
  assert_true(text == "Cindra",
    "display text (rich-text tags stripped) must be exactly 'Cindra', got: " .. tostring(text))
end)

test("label carries the [planet=cindra] icon tag so the picker shows the planet image", function()
  local label = cfg["string-mod-setting"]["aps-planet-cindra"]
  assert_true(label:find("[planet=cindra]", 1, true) ~= nil,
    "label must include the [planet=cindra] rich-text tag, got: " .. tostring(label))
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
