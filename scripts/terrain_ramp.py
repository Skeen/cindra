#!/usr/bin/env python3
# The Cindra hot->cold SURFACE PROFILE, read straight out of the in-game terrain.
#
# WHY THIS EXISTS (ci-4qyj). The from-space art (scripts/gen-planet-maps.py) and
# the ground you actually land on (mods/cindra/scripts/terrain.lua) must be the
# SAME planet. Until now the two carried hand-copied colour ramps that were
# "kept in lockstep" by hand -- and they drifted: the ci-oe83 heightmap rebuild
# moved terrain.lua's COLOR_STOPS while the art kept the older ci-6i1 stops, so
# the orbital globe no longer showed the terrain below it.
#
# So the art no longer OWNS a ramp. This module PARSES the Lua source and
# reproduces terrain.lua's own model:
#
#     perpendicular position p  --M.field-->  heat value H
#     H  --M.VALUE_RAMP-->  tile  --map_color-->  RGB
#
# which is exactly the chain the in-game map view uses. Feed it the sunward->
# nightward position of a point on the globe and you get the colour that spot has
# on the map. The oceans, the belts and the habitable middle therefore land at
# their REAL widths on the disc instead of being a free-hand gradient:
#
#     |<-- hot lava ocean -->|<- belt ->|<- habitable ->|<- belt ->|<-- ice ocean -->|
#      p = +half                          p = 0                      p = -half
#
# There is no colour, threshold or width constant in this file -- every number
# comes from terrain.lua. unit-tests/test_terrain_ramp_lockstep.py runs the real
# Lua module and asserts this Python model agrees with it tile-for-tile and
# colour-for-colour, so the two can never drift again.
#
# The ART uses the DEFAULT zone widths (a baked sprite cannot track a player's
# startup settings); terrain.lua's defaults are the same table settings.lua
# builds its per-zone width settings from, so "default" is the canonical planet.

import os
import re

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
TERRAIN_LUA = os.path.normpath(
    os.path.join(HERE, "..", "mods", "cindra", "scripts", "terrain.lua"))


# ---------------------------------------------------------------------------
# A very small reader for the Lua TABLE LITERALS terrain.lua declares its data
# in. It understands exactly what those tables contain: numbers, quoted strings,
# booleans, nested tables, `key = value` pairs and positional entries, plus
# references to already-known constants (`M.HOT_DMG`, `-RAMP_BIG`). Anything
# else raises, so a shape change in terrain.lua is a loud failure, never a
# silent wrong colour.
# ---------------------------------------------------------------------------

_COMMENT = re.compile(r"--(?!\[\[).*?$", re.M)
_NUMBER = re.compile(r"[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?")
_NAME = re.compile(r"-?[A-Za-z_][A-Za-z_0-9.]*")


class LuaTableReader:
    def __init__(self, text, consts):
        self.s = text
        self.i = 0
        self.consts = consts

    def _ws(self):
        while self.i < len(self.s) and self.s[self.i] in " \t\r\n":
            self.i += 1

    def _expect(self, ch):
        self._ws()
        if self.i >= len(self.s) or self.s[self.i] != ch:
            raise ValueError(f"expected {ch!r} at offset {self.i}: {self.s[self.i:self.i + 40]!r}")
        self.i += 1

    def table(self):
        """Read one `{...}` literal; returns a list (positional) or dict (keyed)."""
        self._expect("{")
        items, pairs = [], {}
        while True:
            self._ws()
            if self.i < len(self.s) and self.s[self.i] == "}":
                self.i += 1
                return pairs if pairs else items
            key = None
            m = re.compile(r"([A-Za-z_][A-Za-z_0-9]*)\s*=(?!=)").match(self.s, self.i)
            if m:
                key, self.i = m.group(1), m.end()
            value = self.value()
            if key is None:
                items.append(value)
            else:
                pairs[key] = value
            self._ws()
            if self.i < len(self.s) and self.s[self.i] in ",;":
                self.i += 1

    def value(self):
        self._ws()
        c = self.s[self.i]
        if c == "{":
            return self.table()
        if c in "\"'":
            self.i += 1
            start = self.i
            while self.s[self.i] != c:
                self.i += 1
            out = self.s[start:self.i]
            self.i += 1
            return out
        m = _NUMBER.match(self.s, self.i)
        if m and not _NAME.match(self.s, self.i):
            self.i = m.end()
            return float(m.group(0))
        m = _NAME.match(self.s, self.i)
        if m:
            self.i = m.end()
            word = m.group(0)
            if word == "true":
                return True
            if word == "false":
                return False
            if word == "nil":
                return None
            sign, bare = (-1.0, word[1:]) if word.startswith("-") else (1.0, word)
            bare = bare.split(".")[-1]          # M.HOT_DMG -> HOT_DMG
            if bare not in self.consts:
                raise ValueError(f"terrain.lua reference {word!r} is not a known constant")
            return sign * self.consts[bare]
        raise ValueError(f"unparsable Lua value at offset {self.i}: {self.s[self.i:self.i + 40]!r}")


def _strip_comments(src):
    return _COMMENT.sub("", src)


def _read_scalar(src, name):
    m = re.search(rf"\b(?:M\.)?{name}\s*=\s*({_NUMBER.pattern})", src)
    if not m:
        raise ValueError(f"terrain.lua: constant {name} not found")
    return float(m.group(1))


def _read_table(src, name, consts):
    m = re.search(rf"\b(?:M\.)?{name}\s*=\s*\{{", src)
    if not m:
        raise ValueError(f"terrain.lua: table {name} not found")
    r = LuaTableReader(src, consts)
    r.i = m.end() - 1                     # sit on the opening brace
    return r.table()


# ---------------------------------------------------------------------------
# The terrain model (a faithful port of terrain.lua's own pure functions).
# ---------------------------------------------------------------------------

class TerrainProfile:
    """terrain.lua's position -> heat -> tile -> colour chain, vectorised."""

    def __init__(self, lua_source):
        src = _strip_comments(lua_source)
        consts = {
            "RAMP_BIG": _read_scalar(src, "RAMP_BIG"),
            "HOT_DMG": _read_scalar(src, "HOT_DMG"),
            "COLD_DMG": _read_scalar(src, "COLD_DMG"),
        }
        self.hot_dmg = consts["HOT_DMG"]
        self.cold_dmg = consts["COLD_DMG"]
        # The per-tile value speckle the map-gen dithers band boundaries with, so
        # the art can break its contours exactly as far as the ground does.
        self.speckle_h = _read_scalar(src, "SPECKLE_H")
        self.zones = _read_table(src, "ZONES", consts)
        self.field_h = _read_table(src, "FIELD_H", consts)
        self.value_ramp = _read_table(src, "VALUE_RAMP", consts)
        self.color_stops = _read_table(src, "COLOR_STOPS", consts)

        self.widths = np.array([float(z["width"]) for z in self.zones])
        self.total = float(self.widths.sum())
        self.half = self.total / 2.0
        # Zone bands [lo, hi] on the perpendicular axis, hot (+p) -> cold (-p).
        edges = self.half - np.concatenate([[0.0], np.cumsum(self.widths)])
        self.band_hi = edges[:-1]
        self.band_lo = edges[1:]

        self._anchor_p, self._anchor_h = self._field_anchors()
        self._ramp_lo = np.array([float(r["lo"]) for r in self.value_ramp])
        self.tile_names = [str(r["vanilla"]) for r in self.value_ramp]
        self._stop_t = np.array([float(s[0]) for s in self.color_stops])
        self._stop_rgb = np.array([[float(c) for c in s[1]] for s in self.color_stops])

    # -- geometry ----------------------------------------------------------
    def _role_index(self, role):
        for i, z in enumerate(self.zones):
            if z["role"] == role:
                return i
        raise ValueError(f"terrain.lua: no zone with role {role!r}")

    def band(self, role):
        i = self._role_index(role)
        return float(self.band_lo[i]), float(self.band_hi[i])

    def _damage_bounds(self):
        hot_from = min(self.band_lo[i] for i, z in enumerate(self.zones)
                       if z.get("damage") == "heat")
        cold_from = max(self.band_hi[i] for i, z in enumerate(self.zones)
                        if z.get("damage") == "cold")
        return float(hot_from), float(cold_from)

    def _field_anchors(self):
        """(p, H) anchors, cold -> hot; the piecewise-linear field runs through them."""
        h = self.field_h
        hot_from, cold_from = self._damage_bounds()
        mid_lo, mid_hi = self.band("middle")
        anchors = [
            (-self.half, 1.0 - h["edge"]),
            (float(self.band_hi[-1]), 1.0 - h["ocean"]),
            (cold_from, 1.0 - h["dmg"]),
            (mid_lo, 1.0 - h["middle"]),
            (mid_hi, h["middle"]),
            (hot_from, h["dmg"]),
            (float(self.band_lo[0]), h["ocean"]),
            (self.half, h["edge"]),
        ]
        return (np.array([a[0] for a in anchors]), np.array([a[1] for a in anchors]))

    # -- the chain ---------------------------------------------------------
    def field(self, p):
        """Heat value H in [0,1] at perpendicular position p (+half hot .. -half cold).

        Arithmetic deliberately mirrors terrain.lua's `pwl` operation for
        operation (not np.interp, which sums the terms differently): the tile
        lookup below is a STEP function, so a last-bit difference in H flips the
        tile at a threshold and the two views disagree along a contour.
        """
        p = np.asarray(p, dtype=np.float64)
        ap, ah = self._anchor_p, self._anchor_h
        i = np.clip(np.searchsorted(ap, p, side="left"), 1, len(ap) - 1)
        lo_p, hi_p = ap[i - 1], ap[i]
        lo_h, hi_h = ah[i - 1], ah[i]
        f = (p - lo_p) / (hi_p - lo_p)
        h = lo_h + (hi_h - lo_h) * f
        h = np.clip(h, 0.0, 1.0)
        h = np.where(p <= ap[0], ah[0], h)         # flat beyond the pinned ends
        return np.where(p >= ap[-1], ah[-1], h)

    def tile_index(self, H):
        """Index into VALUE_RAMP: the first tile whose `lo` the value clears."""
        idx = (np.asarray(H)[..., None] < self._ramp_lo).sum(axis=-1)
        return np.clip(idx, 0, len(self._ramp_lo) - 1)

    def gradient_pos(self, idx):
        """A tile's normalised hot->cold ordinal (0 = lava-hot core, 1 = ice core)."""
        return np.asarray(idx, dtype=np.float64) / (len(self._ramp_lo) - 1)

    def ramp_color(self, t):
        """terrain.lua's map-view colour ramp at gradient position t, as RGB in [0,1].

        Same operation order as terrain.lua's `ramp_color` (see field() for why
        bit-exactness matters).
        """
        t = np.asarray(t, dtype=np.float64)
        xs, cols = self._stop_t, self._stop_rgb
        i = np.clip(np.searchsorted(xs, t, side="left"), 1, len(xs) - 1)
        lo_t, hi_t = xs[i - 1], xs[i]
        f = ((t - lo_t) / (hi_t - lo_t))[..., None]
        ca, cb = cols[i - 1], cols[i]
        out = ca + (cb - ca) * f
        out = np.where((t <= xs[0])[..., None], cols[0], out)
        return np.where((t >= xs[-1])[..., None], cols[-1], out)

    def tile_at(self, p):
        """The vanilla tile name(s) painted at perpendicular position p."""
        idx = self.tile_index(self.field(p))
        if np.isscalar(p) or np.ndim(p) == 0:
            return self.tile_names[int(idx)]
        return [self.tile_names[int(i)] for i in np.ravel(idx)]

    def color_at(self, p):
        """The in-game map colour at perpendicular position p, as RGB in [0,1]."""
        return self.ramp_color(self.gradient_pos(self.tile_index(self.field(p))))

    def color_at_heat(self, H):
        """The in-game map colour for a heat value H (position already folded in)."""
        return self.ramp_color(self.gradient_pos(self.tile_index(H)))

    # -- the three regions the orbital view must read -----------------------
    def heat_at_fraction(self, f):
        """H at f in [0,1] measured COLD edge (0) -> HOT edge (1)."""
        return self.field(-self.half + np.asarray(f) * self.total)

    def region_fractions(self):
        """Axis fraction occupied by each named region, cold -> hot.

        Measured off the FIELD (not the nominal zone widths) so it reports what the
        art actually paints: the oceans are wherever the field sits in an ocean
        tile's band, which is what a player sees from orbit.
        """
        f = np.linspace(0.0, 1.0, 20001)
        idx = self.tile_index(self.heat_at_fraction(f))
        H = self.heat_at_fraction(f)
        n = len(self._ramp_lo)
        return {
            "ice_ocean": float((idx == n - 1).mean()),
            "cold_belt": float(((idx < n - 1) & (H <= self.cold_dmg)).mean()),
            "habitable": float(((H > self.cold_dmg) & (H < self.hot_dmg)).mean()),
            "hot_belt": float(((idx > 0) & (H >= self.hot_dmg)).mean()),
            "lava_ocean": float((idx == 0).mean()),
        }


_CACHE = {}


def load(path=TERRAIN_LUA):
    """Parse terrain.lua (cached) and return its TerrainProfile."""
    path = os.path.abspath(path)
    if path not in _CACHE:
        with open(path, "r", encoding="utf-8") as fh:
            _CACHE[path] = TerrainProfile(fh.read())
    return _CACHE[path]


if __name__ == "__main__":
    t = load()
    print(f"total width {t.total:g}  half {t.half:g}  "
          f"HOT_DMG {t.hot_dmg}  COLD_DMG {t.cold_dmg}")
    for name, frac in t.region_fractions().items():
        print(f"  {name:<10} {frac * 100:5.1f}% of the axis")
    print("\n  fraction  H      tile                          map colour")
    for f in np.linspace(0.0, 1.0, 21):
        H = float(t.heat_at_fraction(f))
        rgb = t.color_at_heat(H)
        print(f"  {f:8.2f}  {H:5.3f}  {t.tile_names[int(t.tile_index(H))]:<28}  "
              f"({rgb[0]:.3f}, {rgb[1]:.3f}, {rgb[2]:.3f})")
