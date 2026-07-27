-- Plain-Lua unit test for Cindra's mod branding (ci-06j).
-- Run: cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_branding.lua
--
-- Branding is pure text (info.json + the locale .cfg), so its invariants live
-- here rather than in a Factorio integration test. This guards the ci-06j
-- requirements:
--
--   * the "The Ribbon World" tagline appears NOWHERE user-facing (info.json
--     title/description, or any value in the locale .cfg). It may live in
--     internal docs only, never in a string the player sees.
--   * info.json title is exactly "Cindra" (no tagline);
--   * info.json author is "Vuza" (not the "you" placeholder);
--   * a mod thumbnail.png ships at the mod root (Factorio thumbnail spec:
--     a thumbnail.png in the mod's root directory);
--   * the description talks about "the sun", not "orbiting ... its star".

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

-- info.json is small and stable; pull field values by pattern rather than
-- pulling in a JSON parser.
local info = read_file("info.json")

local function json_string(field)
  return info:match('"' .. field .. '"%s*:%s*"([^"]*)"')
end

test("info.json title is exactly 'Cindra' (no tagline)", function()
  local title = json_string("title")
  assert_true(title == "Cindra",
    "info.json title must read exactly 'Cindra'; got " .. tostring(title))
end)

test("info.json author is 'Vuza' (not the placeholder)", function()
  local author = json_string("author")
  assert_true(author == "Vuza",
    "info.json author must be 'Vuza'; got " .. tostring(author))
end)

test("info.json description says 'the sun', not 'orbiting ... its star'", function()
  local desc = json_string("description")
  assert_true(desc ~= nil, "info.json must carry a description")
  assert_true(desc:find("the sun", 1, true) ~= nil,
    "description must mention 'the sun'; got: " .. tostring(desc))
  assert_true(desc:lower():find("orbiting perilously close to its star", 1, true) == nil,
    "description must drop the old 'orbiting perilously close to its star' phrasing")
end)

test("the mod ships a thumbnail.png at its root", function()
  local f = io.open("thumbnail.png", "rb")
  assert_true(f ~= nil, "thumbnail.png must exist at the cindra mod root")
  if f then
    local head = f:read(8)
    f:close()
    -- PNG magic: 89 50 4E 47 0D 0A 1A 0A
    assert_true(head ~= nil and head:sub(1, 4) == "\137PNG",
      "thumbnail.png must be a real PNG")
  end
end)

-- The tagline must appear in NO user-facing string. Scan info.json and every
-- value in the locale .cfg (both the main mod and the cindra-start sibling).
local function assert_no_tagline(label, text)
  assert_true(text:lower():find("ribbon world", 1, true) == nil,
    "the 'Ribbon World' tagline must not appear in " .. label
      .. " (docs-only, never user-facing)")
end

test("no 'Ribbon World' tagline in info.json", function()
  assert_no_tagline("info.json", info)
end)

test("no 'Ribbon World' tagline anywhere in the locale .cfg", function()
  assert_no_tagline("locale/en/cindra.cfg", read_file("locale/en/cindra.cfg"))
end)

test("no 'Ribbon World' tagline in the cindra-start sibling locale", function()
  local path = "../cindra-start/locale/en/cindra-start.cfg"
  local f = io.open(path, "r")
  if not f then return end -- sibling not present in this checkout; nothing to guard
  local body = f:read("*a")
  f:close()
  assert_no_tagline(path, body)
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
