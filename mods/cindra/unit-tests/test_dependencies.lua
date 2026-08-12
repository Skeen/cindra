-- Plain-Lua unit test for the SHIPPED dependency lists (ci-dza6).
-- Run: cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_dependencies.lua
--
-- A mod's `info.json` dependencies decide what the PLAYER is forced to install,
-- so they are a player-facing contract even though they are pure text. Stage 3
-- of the ci-810e PlanetsLib plan (docs/planetslib-evaluation.md §6) adds
-- `"? PlanetsLib"` to mods/cindra: an OPTIONAL dependency, load-order only.
--
-- The distinction is load-bearing, not stylistic. PlanetsLib's data stage
-- rewrites the vanilla centrifuge, sets `weight` on ~100 vanilla items, walks
-- the whole technology tree stripping hidden-tech prerequisites, mirrors lab
-- science onto the Biolab and adds tooltip machinery to every recipe. Declared
-- OPTIONAL, none of that happens unless the player already chose to install the
-- library. Declared HARD (a bare name, or `~`), installing Cindra would
-- conscript every player into all of it -- Cindra silently changing
-- Nauvis/Vulcanus gameplay, which is exactly what the AGENTS.md load-bearing
-- invariant forbids ("NEVER MUTATE GLOBAL STATE THAT AFFECTS OTHER PLANETS").
--
-- Dropping the `?` is a one-character edit, and in-engine it fails as a total
-- load failure rather than as a finding: Factorio refuses to enable a mod whose
-- required dependency is missing, so the whole suite goes dark at once with
-- nothing pointing at info.json. Naming the rule here turns that into one legible
-- failure, and pins the mandatory set as a whole so no other third-party mod can
-- arrive as a forced install either.
--
-- Sibling coverage:
--   * tests/test_planetslib_absent.lua -- the in-engine consequence: with
--     PlanetsLib NOT installed, Cindra still loads, is still reachable, and the
--     library's global mutations are nowhere in the game.
--   * tests/test_planetslib_compat.lua -- the preconditions PlanetsLib imposes
--     on us, asserted from our own side in every run.
--   * tests/test_planetslib_coload.lua -- both mods loaded, nothing moved.

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

local function repo_root()
  local f = io.popen("git rev-parse --show-toplevel 2>/dev/null")
  if not f then return nil end
  local root = f:read("*l")
  f:close()
  if root == nil or root == "" then return nil end
  return root
end

-- The dependency array is a flat list of strings; pull it out by pattern rather
-- than pulling in a JSON parser (same approach as unit-tests/test_branding.lua).
local function dependencies(info)
  local block = info:match('"dependencies"%s*:%s*%[(.-)%]')
  assert_true(block ~= nil, "info.json must declare a dependencies array")
  local deps = {}
  for entry in block:gmatch('"([^"]*)"') do
    deps[#deps + 1] = entry
  end
  return deps
end

-- Split a dependency entry into its prefix and the mod name it names.
-- Factorio prefixes: `!` incompatible, `?` optional, `(?)` hidden optional,
-- `~` required-but-no-load-order, and no prefix at all = required.
local function parse(entry)
  local rest = entry:gsub("^%s+", "")
  local prefix = ""
  local p = rest:match("^%(%?%)") or rest:match("^[!?~]")
  if p then
    prefix = p
    rest = rest:sub(#p + 1):gsub("^%s+", "")
  end
  local name = rest:match("^([%w%-_ ]-)%s*[<>=]") or rest
  name = name:gsub("%s+$", "")
  return prefix, name
end

local function is_optional(prefix)
  return prefix == "?" or prefix == "(?)"
end

local cindra_deps = dependencies(read_file("info.json"))

test("mods/cindra declares PlanetsLib as an OPTIONAL dependency", function()
  local found
  for _, entry in ipairs(cindra_deps) do
    local prefix, name = parse(entry)
    if name == "PlanetsLib" then found = { entry = entry, prefix = prefix } end
  end
  assert_true(found ~= nil,
    "mods/cindra/info.json must declare PlanetsLib (ci-dza6, stage 3 of the "
      .. "ci-810e plan); got: " .. table.concat(cindra_deps, ", "))
  assert_true(is_optional(found.prefix),
    "the PlanetsLib dependency must stay OPTIONAL ('? PlanetsLib'). A hard "
      .. "dependency would force PlanetsLib's vanilla mutations (centrifuge, "
      .. "~100 item weights, tech-tree prereq stripping) onto every Cindra "
      .. "player, changing Nauvis/Vulcanus gameplay. Got: " .. found.entry)
end)

test("mods/cindra forces the player to install nothing new", function()
  -- The mandatory set, stated independently of the file so an addition has to
  -- be a deliberate edit here as well. `base`/`space-age` are the engine and
  -- its DLC; `env-scanner` is our own sibling mod, shipped alongside (ci-xor).
  local ALLOWED_REQUIRED = { base = true, ["space-age"] = true, ["env-scanner"] = true }
  for _, entry in ipairs(cindra_deps) do
    local prefix, name = parse(entry)
    if not is_optional(prefix) and prefix ~= "!" then
      assert_true(ALLOWED_REQUIRED[name],
        "'" .. entry .. "' is a REQUIRED dependency, so installing Cindra "
          .. "forces the player to install " .. name .. " too. Third-party "
          .. "libraries must be optional ('? " .. name .. "').")
    end
  end
end)

test("NO shipped mod takes a hard PlanetsLib dependency", function()
  -- The rule is mod-set-wide, not just about mods/cindra: the companion mods
  -- load in the same game, so a hard dep in any of them drags the library in
  -- just the same.
  local root = repo_root()
  assert_true(root ~= nil, "this guard needs a git working tree to enumerate mods")
  local f = assert(io.popen("ls -1 '" .. root .. "/mods' 2>/dev/null"), "could not list mods/")
  local mods = {}
  for line in f:lines() do mods[#mods + 1] = line end
  f:close()
  assert_true(#mods > 0, "expected at least one mod under mods/")

  local checked = 0
  for _, mod in ipairs(mods) do
    local path = root .. "/mods/" .. mod .. "/info.json"
    local handle = io.open(path, "r")
    if handle then
      handle:close()
      checked = checked + 1
      for _, entry in ipairs(dependencies(read_file(path))) do
        local prefix, name = parse(entry)
        if name == "PlanetsLib" then
          assert_true(is_optional(prefix),
            "mods/" .. mod .. " declares a non-optional PlanetsLib dependency ("
              .. entry .. "); it must be '? PlanetsLib' or absent")
        end
      end
    end
  end
  assert_true(checked > 0, "no mods/*/info.json was read; the guard scanned nothing")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
