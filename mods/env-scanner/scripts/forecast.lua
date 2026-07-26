-- Optional flare-forecast source for the scanner.
--
-- The scanner does NOT own or duplicate any flare-timing logic (that lives in
-- Cindra's flare system, ci-9k6). It only ASKS for a forecast, via the
-- documented cross-mod remote interface (C.FLARE_INTERFACE / C.FLARE_METHOD).
-- If no mod registers that interface, `get` returns nil and the flare signals
-- stay inactive -- so this mod runs standalone on any planet with no cindra.
--
-- `set_provider` is a test seam: it lets the integration tests inject a
-- deterministic forecast without needing the cindra mod loaded. It is
-- module-level (not `storage`) state, only ever set by tests; the real runtime
-- path is the remote interface, which is deterministic on load.

local C = require("scripts.config")

local M = {}

M._provider = nil

-- Inject a forecast provider: fn(surface) -> forecast-table|nil. Test-only.
function M.set_provider(fn)
  M._provider = fn
end

-- Remove any injected provider, restoring the default remote-interface path.
function M.clear_provider()
  M._provider = nil
end

-- Fetch the flare forecast for a surface, or nil when none applies / no source.
-- Shape (when non-nil): { countdown = int, phase = string, intensity = number }.
function M.get(surface)
  if M._provider then
    return M._provider(surface)
  end
  local iface = remote.interfaces[C.FLARE_INTERFACE]
  if iface and iface[C.FLARE_METHOD] then
    -- pcall so a misbehaving provider mod can never break the scanner.
    local ok, res = pcall(remote.call, C.FLARE_INTERFACE, C.FLARE_METHOD, surface.index)
    if ok then return res end
  end
  return nil
end

return M
