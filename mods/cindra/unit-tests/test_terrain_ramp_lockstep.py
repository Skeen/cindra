#!/usr/bin/env python3
# LOCKSTEP guard (ci-4qyj): the from-space art is painted with the GROUND.
#
# The player sees Cindra twice -- as a globe in the star map / orbital backdrop,
# and as tiles under their feet. Those two views used to be two hand-copied
# colour ramps, and they DRIFTED: the ci-oe83 heightmap rebuild moved
# terrain.lua's ramp while gen-planet-maps.py kept the older ci-6i1 one, so the
# planet you orbited was not the planet you landed on.
#
# scripts/terrain_ramp.py fixes that by READING terrain.lua and replaying its
# position -> heat -> tile -> colour chain. That is only worth anything if the
# replay is FAITHFUL, so this test runs BOTH implementations -- the real Lua
# module under `lua`, and the Python port -- across the whole perpendicular axis
# and asserts they name the same tile and mix the same colour at every sample.
#
# Any edit to terrain.lua's zone widths, field anchors, value ramp or colour
# stops that the Python reader cannot follow fails HERE, before it can ship a
# globe that lies about the surface.
#
# Run (numpy + lua):
#   python3 mods/cindra/unit-tests/test_terrain_ramp_lockstep.py

import importlib.util
import os
import shutil
import subprocess
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
MODROOT = os.path.normpath(os.path.join(HERE, ".."))
REPO = os.path.normpath(os.path.join(MODROOT, "..", ".."))
RAMP_PY = os.path.join(REPO, "scripts", "terrain_ramp.py")

spec = importlib.util.spec_from_file_location("terrain_ramp", RAMP_PY)
tr = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tr)

passed = failed = 0


def check(name, cond, detail=""):
    global passed, failed
    if cond:
        passed += 1
        print("ok - " + name)
    else:
        failed += 1
        print("not ok - " + name + ("  [" + detail + "]" if detail else ""))


# --- Run the REAL Lua terrain module ----------------------------------------
# One line per sample: p H tile r g b, straight out of terrain.lua's own public
# API (M.field -> M.value_tile -> M.map_color), i.e. exactly what paints the
# in-game map view.
SAMPLES = 401
LUA_DUMP = f"""
package.path = package.path .. ";./?.lua;./?/init.lua"
local terrain = require("scripts.terrain")
local _, total = terrain.bands()
local half = total / 2
print("TOTAL", total)
for i = 0, {SAMPLES - 1} do
  local p = -half + total * i / {SAMPLES - 1}
  local H = terrain.field(p)
  local tile = terrain.value_tile(H)
  local c = terrain.map_color(tile)
  print(string.format("S %.10f %.10f %s %.10f %.10f %.10f", p, H, tile, c[1], c[2], c[3]))
end
"""

lua_bin = shutil.which("lua") or shutil.which("lua5.4") or shutil.which("lua5.2")
if lua_bin is None:
    # Never SKIP: a silent skip is how a lockstep guard rots. The dev shell
    # (flake.nix devTools) ships lua for exactly this reason.
    print("not ok - lua interpreter available (needed to run terrain.lua)")
    print("\n0 passed, 1 failed")
    sys.exit(1)

proc = subprocess.run([lua_bin, "-"], input=LUA_DUMP, cwd=MODROOT,
                      capture_output=True, text=True)
if proc.returncode != 0:
    print("not ok - terrain.lua loads under plain lua")
    print(proc.stderr)
    print("\n0 passed, 1 failed")
    sys.exit(1)

lua_total = None
lua_p, lua_h, lua_tile, lua_rgb = [], [], [], []
for line in proc.stdout.splitlines():
    parts = line.split()
    if parts[:1] == ["TOTAL"]:
        lua_total = float(parts[1])
    elif parts[:1] == ["S"]:
        lua_p.append(float(parts[1]))
        lua_h.append(float(parts[2]))
        lua_tile.append(parts[3])
        lua_rgb.append([float(x) for x in parts[4:7]])

lua_p = np.array(lua_p)
lua_h = np.array(lua_h)
lua_rgb = np.array(lua_rgb)

# --- The Python port --------------------------------------------------------
prof = tr.load()
py_h = prof.field(lua_p)
py_idx = prof.tile_index(py_h)
py_tile = ["cindra-" + prof.tile_names[int(i)] for i in py_idx]
py_rgb = prof.color_at(lua_p)

check("terrain.lua ran and produced samples",
      lua_total is not None and len(lua_p) == SAMPLES,
      f"total={lua_total} samples={len(lua_p)}")
check("axis width agrees (python reads the same zone widths)",
      abs(prof.total - lua_total) < 1e-9,
      f"py={prof.total} lua={lua_total}")

dh = float(np.abs(py_h - lua_h).max())
check("heat field H agrees everywhere (max |dH| < 1e-9)", dh < 1e-9, f"max|dH|={dh:.3e}")

mismatched = [(float(p), a, b) for p, a, b in zip(lua_p, py_tile, lua_tile) if a != b]
check("every sample names the SAME tile as terrain.lua",
      not mismatched,
      f"{len(mismatched)} mismatches, first={mismatched[0] if mismatched else None}")

drgb = float(np.abs(py_rgb - lua_rgb).max())
check("every sample mixes the SAME map colour (max |dRGB| < 1e-9)",
      drgb < 1e-9, f"max|dRGB|={drgb:.3e}")

# --- The parsed palette is the Lua palette, entry for entry -----------------
LUA_STOPS = """
package.path = package.path .. ";./?.lua;./?/init.lua"
local terrain = require("scripts.terrain")
for _, s in ipairs(terrain.COLOR_STOPS) do
  print(string.format("%.10f %.10f %.10f %.10f", s[1], s[2][1], s[2][2], s[2][3]))
end
"""
sp = subprocess.run([lua_bin, "-"], input=LUA_STOPS, cwd=MODROOT,
                    capture_output=True, text=True)
lua_stops = [[float(x) for x in ln.split()] for ln in sp.stdout.splitlines() if ln.strip()]
py_stops = [[t] + list(rgb) for t, rgb in
            [(float(s[0]), [float(c) for c in s[1]]) for s in prof.color_stops]]
check("the parsed COLOR_STOPS palette IS terrain.lua's palette",
      len(lua_stops) == len(py_stops)
      and np.allclose(np.array(lua_stops), np.array(py_stops), atol=1e-12),
      f"lua={len(lua_stops)} stops, py={len(py_stops)} stops")

# --- The regions the orbital view has to show actually exist ----------------
# (Read off the field, so this also proves the parsed geometry is sane: a planet
# with no lava ocean or no habitable middle would be the wrong planet.)
frac = prof.region_fractions()
check("the axis is exactly the five regions (fractions sum to 1)",
      abs(sum(frac.values()) - 1.0) < 1e-3,
      f"sum={sum(frac.values()):.4f} {frac}")
check("both oceans are broad and equal (each > 20% of the axis)",
      frac["lava_ocean"] > 0.20 and frac["ice_ocean"] > 0.20
      and abs(frac["lava_ocean"] - frac["ice_ocean"]) < 1e-3,
      f"lava={frac['lava_ocean']:.3f} ice={frac['ice_ocean']:.3f}")
check("a real habitable middle survives between them (> 15% of the axis)",
      frac["habitable"] > 0.15,
      f"habitable={frac['habitable']:.3f}")

print(f"\n{passed} passed, {failed} failed")
sys.exit(0 if failed == 0 else 1)
