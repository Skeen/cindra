-- Plain-Lua unit test for Cindra's mod branding (ci-06j).
-- Run: cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_branding.lua
--
-- Branding is pure text (info.json + the locale .cfg), so its invariants live
-- here rather than in a Factorio integration test. This guards the ci-06j /
-- ci-8ua requirements:
--
--   * the old two-word tagline appears NOWHERE in the whole repo -- not in
--     user-facing strings, not in docs, not in code comments. The mod is just
--     "Cindra". A repo-wide `git grep` guard (below) fails if it creeps back.
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

-- REGRESSION GUARD (ci-8ua): the old two-word tagline must appear in ZERO
-- tracked files across the WHOLE repo -- docs, code comments, locale, info.json,
-- everything. Earlier branding work only purged it from user-facing strings and
-- let it linger in docs; from here it is banned everywhere so it cannot creep
-- back in.
--
-- The forbidden needle is assembled from fragments so this guard file does not
-- itself contain the contiguous phrase it hunts for (otherwise it would report
-- itself). The search runs via `git grep`, which only sees tracked files, so a
-- fresh clone with the string scrubbed passes.
local FORBIDDEN = "ribbon" .. " " .. "world"

local function repo_root()
  local f = io.popen("git rev-parse --show-toplevel 2>/dev/null")
  if not f then return nil end
  local root = f:read("*l")
  f:close()
  if root == nil or root == "" then return nil end
  return root
end

test("the old tagline appears in NO tracked file anywhere in the repo", function()
  local root = repo_root()
  assert_true(root ~= nil,
    "regression guard needs git (a git working tree) to scan tracked files")
  -- -I skips binary files, -i is case-insensitive, -n prints line numbers.
  local cmd = "git -C '" .. root .. "' grep -I -i -n -e '" .. FORBIDDEN
    .. "' 2>/dev/null"
  local f = assert(io.popen(cmd), "could not run git grep")
  local hits = f:read("*a") or ""
  f:close()
  assert_true(hits == "",
    "the forbidden tagline reappeared in tracked files (the mod is just "
      .. "'Cindra'); offending lines:\n" .. hits)
end)

-- REGRESSION GUARD (ci-oe2): the mod's OLD internal name (the design's former
-- identifier, spelled below from fragments) must appear in ZERO tracked files
-- across the WHOLE repo -- info.json, prototype/graphic/locale namespaces,
-- require paths, scripts, docs, and code comments alike. The internal name is
-- now 'cindra' everywhere; this guard fails if the old name creeps back.
--
-- Like the tagline guard above, the needle is assembled from fragments so this
-- file does not itself contain the contiguous word it hunts for.
local FORBIDDEN_NAME = "coer" .. "cia"

test("the old internal name appears in NO tracked file anywhere", function()
  local root = repo_root()
  assert_true(root ~= nil,
    "regression guard needs git (a git working tree) to scan tracked files")
  -- -I skips binary files, -i is case-insensitive, -n prints line numbers.
  local cmd = "git -C '" .. root .. "' grep -I -i -n -e '" .. FORBIDDEN_NAME
    .. "' 2>/dev/null"
  local f = assert(io.popen(cmd), "could not run git grep")
  local hits = f:read("*a") or ""
  f:close()
  assert_true(hits == "",
    "the old internal name 'coer".."cia' reappeared in tracked files (the mod "
      .. "is now 'cindra' everywhere); offending lines:\n" .. hits)
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
