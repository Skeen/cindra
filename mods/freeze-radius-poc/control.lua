-- Freeze-radius PoC control-stage entry point.
--
-- The PoC has no runtime gameplay of its own: the entire experiment lives in the
-- integration suite, which builds a scratch surface, associates it with the
-- freeze-carrier planet, places emitters + probes, ticks, and reads
-- LuaEntity.frozen. So control.lua only boots the test suite (and only when the
-- factorio-test framework is present, exactly like the other Cindra PoCs).

if script.active_mods["factorio-test"] then
  require("__factorio-test__/init")({
    "tests/test_headline",
    "tests/test_radius_sweep",
    "tests/test_source_kinds",
    "tests/test_shape",
    "tests/test_band_split",
    "tests/test_perf",
  }, {
    load_luassert = true,
  })
end
