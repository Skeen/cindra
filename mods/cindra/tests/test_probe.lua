-- TEMPORARY probe (ci-a35): find a cliff_settings config that yields a DENSE,
-- continuous cliff wall along a constant-x contour. KEY: cliff_settings.control
-- must link to an enabled cliff autoplace-control.

describe("PROBE ci-a35 cliff configs", function()
  local function try(label, pen, cliff)
    local mgs = {
      width = 0, height = 0, seed = 4321,
      property_expression_names = pen,
      autoplace_settings = {
        tile = { treat_missing_as_default = false, settings = { ["sand-1"] = {} } },
        decorative = { treat_missing_as_default = false, settings = {} },
        entity = { treat_missing_as_default = false, settings = {} },
      },
      autoplace_controls = { ["nauvis_cliff"] = {} },
      default_enable_all_autoplace_controls = false,
      cliff_settings = cliff,
    }
    local sn = "probe-" .. label
    local s = game.surfaces[sn] or game.create_surface(sn, mgs)
    s.request_to_generate_chunks({ 0, 0 }, 5)
    s.force_generate_chunk_requests()
    local buckets = {}
    for _, e in pairs(s.find_entities_filtered({ type = "cliff", area = { { -160, -160 }, { 160, 160 } } })) do
      local bx = math.floor(e.position.x / 10) * 10
      buckets[bx] = (buckets[bx] or 0) + 1
    end
    local parts = {}
    for bx, n in pairs(buckets) do parts[#parts + 1] = bx .. ":" .. n end
    table.sort(parts)
    local total = s.count_entities_filtered({ type = "cliff", area = { { -160, -160 }, { 160, 160 } } })
    log("PROBE cliff [" .. label .. "] total=" .. total .. " buckets{" .. table.concat(parts, ",") .. "}")
  end

  it("PROBE: sweep cliff configs (with control)", function()
    -- ramp cliff_elevation = x, single contour near x=0, vanilla cliffiness.
    try("A", { elevation = "50", cliff_elevation = "x", cliffiness = "cliffiness_basic" },
      { name = "cliff", control = "nauvis_cliff", cliff_elevation_0 = 0, cliff_elevation_interval = 100000, cliff_smoothing = 0 })
    -- constant-high cliffiness for a continuous (gapless) wall.
    try("B", { elevation = "50", cliff_elevation = "x", cliffiness = "10" },
      { name = "cliff", control = "nauvis_cliff", cliff_elevation_0 = 0, cliff_elevation_interval = 100000, cliff_smoothing = 0 })
    -- smaller interval (repeating walls) to confirm the mechanism fires at all.
    try("C", { elevation = "50", cliff_elevation = "x", cliffiness = "cliffiness_basic" },
      { name = "cliff", control = "nauvis_cliff", cliff_elevation_0 = 0, cliff_elevation_interval = 40, cliff_smoothing = 0 })
    -- V-shaped: cliff at |x|=40, wall on both sides of a valley.
    try("D", { elevation = "50", cliff_elevation = "abs(x)", cliffiness = "10" },
      { name = "cliff", control = "nauvis_cliff", cliff_elevation_0 = 40, cliff_elevation_interval = 100000, cliff_smoothing = 0 })
    assert.is_true(true, "sweep ran")
  end)
end)
