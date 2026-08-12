#!/usr/bin/env python3
# Procedural equirectangular texture maps for the Cindra planet.
#
# Cindra is a TIDALLY LOCKED "ribbon planet" (DESIGN.md sections 1-4): a molten
# dayside hemisphere (magma ocean, radiant glow), a frozen nightside hemisphere
# (the DARKEST face, deep dark ice with icy-blue glints), and the survivable
# ribbon between them. The star sits perilously close, so the dayside is a hot,
# bright, self-glowing furnace and the nightside is a dark frozen vault. The
# signature visual tension is fire vs ice.
#
# THE GLOBE IS PAINTED WITH THE GROUND (ci-4qyj). The surface colour is not a
# free-hand gradient: scripts/terrain_ramp.py reads mods/cindra/scripts/terrain.lua
# and replays its own chain -- perpendicular position -> heat value H -> tile ->
# map colour -- so each point on the disc gets the colour that spot has on the map
# view. The ci-wly/ci-oe83 three-part heightmap therefore shows up from orbit at
# its REAL widths instead of an eyeballed ramp, and a future edit to the terrain
# ramp moves the space art with it (guarded by
# unit-tests/test_terrain_ramp_lockstep.py):
#   • HOT LAVA OCEAN (~26% of the axis, the left limb): the field is pinned in the
#     lava-hot band, so it is one broad molten orange-red sheet -- an OCEAN, not a
#     thin rim -- carrying the strong self-glow.
#   • HOT BELT: a narrow, fast ramp of molten crust and glowing cracks where the
#     field crosses the heat-death threshold. The glow DIES at that threshold, so
#     what lights up from orbit is exactly the lethal ground.
#   • HABITABLE MIDDLE (~33%, the centre of the disc): the dark warm basalt/ash
#     band we actually build on. It carries NO self-glow, so it falls into shadow
#     where the key light does not reach: the tidal-lock terminator comes from the
#     LIGHT, not a painted seam (ci-i9m).
#   • COLD BELT: dust and snow through the freeze threshold.
#   • COLD ICE OCEAN (~26%, the right limb): pale cyan-white smooth ice reading as
#     our frozen terrain, with a faint icy-blue shimmer. It goes dark via the light
#     falloff, not a black albedo, so it is ICE -- not a Fulgora-electric vault.
#
# TIDALLY LOCKED means the planet presents ONE face permanently: it must not spin
# in either the star-map sprite or the orbital backdrop. We bake that into the
# MAP itself by arranging the fire/ice gradient along LONGITUDE so the presented
# front hemisphere always shows the whole dramatic split:
#
#   insolation  sol = -cy   (cy = y component of the unit-sphere point)
#     sol = +1  -> sub-stellar point    (the hot lava ocean)      at lon = -90
#     sol =  0  -> terminator           (the habitable middle)    at lon =   0 / 180
#     sol = -1  -> anti-stellar point   (the cold ice ocean)      at lon = +90
#
# sol IS the ribbon's perpendicular axis in normalised form: sol * half_width is
# the tile coordinate terrain.lua's field is a function of, so feeding it straight
# into the terrain profile is what makes the globe show the real planet.
#
# On an orthographic disc a point at longitude near the presented centre projects
# to screen-x ~ sin(lon), and sol ~ -sin(lon), so sol maps almost linearly to the
# horizontal across the visible face: the habitable middle sits dead centre, the
# lava ocean on the left limb, the ice ocean on the right.
#
# Everything is derived from 3D fractal noise sampled on the UNIT SPHERE (not on
# the flat image plane), so the maps are seamless at the longitude wrap and free
# of pole pinching.
#
# Channel formats mirror vanilla (see the base game's graphics/space/*.png):
#   albedo (planet_surface), emission (planet_emission) -> RGBA
#   reflectivity, normal, cloud-normal, cloud-flow       -> RGB
#   cloud (global_cloud)                                 -> RGBA (coloured)
#   flare (hero_cloud spritesheet)                       -> RGBA
#
# Deterministic: same SEED -> same art every run.
# Run via: scripts/render-planet.sh  (wraps the nix python env)
#
# Importable: generate_maps(W, H, seed) returns the raw float layers so a pixel
# test can assert the lava-ocean / habitable / ice-ocean split (see
# unit-tests/test_planet_maps.py) without shelling out to the file writer.

import os
import sys
import numpy as np
# PIL is imported lazily in to_img() so generate_maps() stays importable in a
# numpy-only environment (the pixel test needs no image encoder).

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import terrain_ramp  # noqa: E402  -- sibling module, needs the path line above

W, H = 2048, 1024          # equirectangular, 2:1
SEED = 51001                # deterministic; change for a different world

# ---------------------------------------------------------------------------
# 3D value noise, fully vectorised over an (M,3) array of sample points.
# A periodic lattice of random values is trilinearly interpolated; wrapping the
# integer lattice coords modulo G keeps it tileable in 3D (invisible on a
# sphere) so we never see a seam.
# ---------------------------------------------------------------------------
G = 256  # lattice resolution


def value_noise3(coords, seed):
    grid = np.random.default_rng(seed).random((G, G, G)).astype(np.float32)
    x0 = np.floor(coords).astype(np.int64)
    f = coords - x0
    f = f * f * (3.0 - 2.0 * f)  # smoothstep fade
    ix, iy, iz = x0[:, 0] % G, x0[:, 1] % G, x0[:, 2] % G
    jx, jy, jz = (ix + 1) % G, (iy + 1) % G, (iz + 1) % G
    fx, fy, fz = f[:, 0], f[:, 1], f[:, 2]

    def corner(a, b, c):
        return grid[a, b, c]

    c00 = corner(ix, iy, iz) * (1 - fx) + corner(jx, iy, iz) * fx
    c10 = corner(ix, jy, iz) * (1 - fx) + corner(jx, jy, iz) * fx
    c01 = corner(ix, iy, jz) * (1 - fx) + corner(jx, iy, jz) * fx
    c11 = corner(ix, jy, jz) * (1 - fx) + corner(jx, jy, jz) * fx
    c0 = c00 * (1 - fy) + c10 * fy
    c1 = c01 * (1 - fy) + c11 * fy
    return c0 * (1 - fz) + c1 * fz


def fbm(unit, seed, base_freq=2.0, octaves=6, lac=2.0, gain=0.5):
    """Fractal Brownian motion in [0,1] over unit-sphere points (M,3)."""
    total = np.zeros(unit.shape[0], np.float32)
    amp, freq, norm = 1.0, base_freq, 0.0
    for o in range(octaves):
        total += amp * value_noise3(unit * freq, seed + o * 17)
        norm += amp
        amp *= gain
        freq *= lac
    return total / norm


def ridged(unit, seed, base_freq=2.0, octaves=6):
    """Ridged multifractal: sharp bright filaments (lava channels / ice cracks)."""
    n = fbm(unit, seed, base_freq, octaves)
    return 1.0 - np.abs(2.0 * n - 1.0)


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


# The hot -> cold surface profile, READ OUT OF THE GAME (ci-4qyj). There is no
# colour ramp, threshold or band width in this file: terrain_ramp.load() parses
# mods/cindra/scripts/terrain.lua and hands back its own
# position -> heat -> tile -> colour chain. The art can therefore never disagree
# with the ground (the drift this bead exists to fix), and re-tuning the terrain
# re-tunes the globe on the next render.
TERRAIN = terrain_ramp.load()


def normal_map(h, strength):
    """Tangent-space normal map from a scalar height field."""
    gy, gx = np.gradient(h.astype(np.float32))
    nx, ny, nz = -gx * strength, -gy * strength, np.ones_like(h)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    n = np.stack([nx / ln, ny / ln, nz / ln], -1)
    return (n * 0.5 + 0.5) * 255.0


def generate_maps(W=W, H=H, seed=SEED):
    """Compute every equirectangular layer as float arrays.

    Returns a dict of named layers. Colour layers (albedo/emission/cloud) are
    RGBA float arrays in [0,255]; scalar-derived layers (reflectivity/normal/
    cloud-normal/cloud-flow) are RGB float arrays in [0,255]. The flare
    spritesheet is built separately (build_flare_sheet). Also returned are the
    zone masks so a test can address each region without re-deriving the
    geometry: the terrain-derived heat field and its lava_ocean / hot_belt /
    habitable / cold_belt / ice_ocean regions, plus the lighting-side
    sol/day/night/ribbon gates.
    """
    # -- Sphere sample points for every equirectangular texel ----------------
    xs = (np.arange(W) + 0.5) / W
    ys = (np.arange(H) + 0.5) / H
    lon = xs * 2.0 * np.pi - np.pi           # (W,)
    lat = np.pi / 2.0 - ys * np.pi           # (H,)
    LON, LAT = np.meshgrid(lon, lat)         # (H,W)
    cx = np.cos(LAT) * np.cos(LON)
    cy = np.cos(LAT) * np.sin(LON)
    cz = np.sin(LAT)
    unit = np.stack([cx, cy, cz], axis=-1).reshape(-1, 3).astype(np.float32)

    def field(s, **kw):
        return fbm(unit, s, **kw).reshape(H, W)

    # -- The tidally-locked axis --------------------------------------------
    # sol in [-1, 1]: +1 sub-stellar (fire), 0 terminator, -1 anti-stellar (ice).
    # A little noise warps the boundary so the fire/ice coastline is ragged.
    sol = (-cy).reshape(H, W)
    warp = (field(seed + 400, base_freq=3.0, octaves=4) - 0.5)
    sol = np.clip(sol + 0.06 * warp, -1.0, 1.0)

    # -- THE TERRAIN, sampled from orbit (ci-4qyj) ---------------------------
    # sol is the ribbon's perpendicular axis in normalised form, so sol * half is
    # the tile coordinate terrain.lua's heightmap is a function of. Sample the real
    # field there and the disc inherits the planet's actual geometry: the two
    # OCEANS are the pinned plateaus at the ends of the axis (each ~26% of it), the
    # damage belts are the fast crossings on either side, and the habitable middle
    # is the broad clamped stretch between them.
    perp = sol * TERRAIN.half
    # The map-gen dithers its band boundaries with a per-tile speckle in H
    # (terrain.SPECKLE_H) so co-present tiles interpenetrate instead of drawing a
    # clean line. Reuse the SAME amplitude here, so a contour seen from orbit
    # breaks up exactly as far as the ground does.
    speckle = field(seed + 700, base_freq=26.0, octaves=4) - 0.5
    heat_field = np.clip(TERRAIN.field(perp) + 2.0 * TERRAIN.speckle_h * speckle, 0.0, 1.0)

    # The five regions, straight off the field -- the same partition the game uses
    # for lethal ground, so what glows from orbit is what burns on foot.
    lava_ocean = TERRAIN.tile_index(heat_field) == 0
    ice_ocean = TERRAIN.tile_index(heat_field) == len(TERRAIN.tile_names) - 1
    hot_belt = heat_field >= TERRAIN.hot_dmg
    cold_belt = heat_field <= TERRAIN.cold_dmg
    habitable = ~hot_belt & ~cold_belt

    # Smooth versions for shading: `molten` rises from 0 at the heat-death
    # threshold to 1 across the lava ocean, `frozen` mirrors it on the ice side.
    # Both are ZERO through the habitable middle, so the middle self-lights nothing
    # and the terminator stays a LIGHT effect, never a painted seam (ci-i9m).
    lava_lo = float(TERRAIN.value_ramp[0]["lo"])            # the lava-hot band floor
    ice_hi = float(TERRAIN.value_ramp[-2]["lo"])            # the smooth-ice band roof
    molten = smoothstep(TERRAIN.hot_dmg, lava_lo, heat_field)
    frozen = smoothstep(-TERRAIN.cold_dmg, -ice_hi, -heat_field)
    # How far past each pinned extreme: drives the white-hot core / deepest frost.
    heat = np.clip((heat_field - TERRAIN.hot_dmg) / (1.0 - TERRAIN.hot_dmg), 0, 1)
    cold = np.clip((TERRAIN.cold_dmg - heat_field) / TERRAIN.cold_dmg, 0, 1)

    # Lighting-side gates (unchanged): which hemisphere the star actually lights.
    # These are the LIGHT, not the surface -- the day/night falloff is supplied by
    # the parallel key (bake) and light_direction (orbit). This is ART only; it
    # does NOT touch the in-game mapgen zone widths (planet.lua / ribbon.lua).
    day = smoothstep(0.05, 0.30, sol)                      # star-lit hemisphere
    night = smoothstep(0.05, 0.30, -sol)                   # shadowed hemisphere
    ribbon = np.clip(1.0 - day - night, 0.0, 1.0)          # terminator transition

    # -- Height / relief field ----------------------------------------------
    height = field(seed, base_freq=2.2, octaves=7)
    height = np.clip(height + 0.10 * (field(seed + 500, base_freq=4.0, octaves=4) - 0.5), 0, 1)
    detail = field(seed + 900, base_freq=18.0, octaves=5)

    # Lava channels (ridged filaments) trace the hottest cracks on the dayside.
    lava = ridged(unit, seed + 111, base_freq=3.0, octaves=6).reshape(H, W)
    lava = np.power(lava, 2.4)                              # thin bright veins
    # Ice fractures: a second ridged network for the nightside frost cracks.
    frost = ridged(unit, seed + 222, base_freq=4.0, octaves=5).reshape(H, W)
    frost = np.power(frost, 2.6)

    # -- Albedo (RGBA): the in-game surface, seen from orbit (ci-4qyj) -------
    # Every pixel takes the map colour terrain.lua gives the tile at that point of
    # the ribbon axis, so the disc IS the terrain: a broad molten orange-red lava
    # ocean, a fast crust ramp, the dark warm basalt/ash habitable middle, dust and
    # snow, then the pale cyan-white ice ocean. No hand-painted stripe anywhere --
    # the bands are the planet's own, at the planet's own widths. Height gives
    # gentle relief shading on top.
    base = TERRAIN.color_at_heat(heat_field).astype(np.float32)   # (H,W,3)
    shade = np.clip(0.80 + 0.34 * (height - 0.5) + 0.10 * (detail - 0.5), 0.55, 1.15)
    alb = base * shade[..., None]

    # Lava veins burn brighter INSIDE the molten region, so the ocean reads as
    # churning liquid rock rather than flat orange paint (the emission map carries
    # the actual glow on top). Gated on `molten`, so no vein ever strays into the
    # habitable middle where there is no lava to see.
    vein = np.clip(lava * molten, 0.0, 1.0)
    lava_col = np.array([1.00, 0.55, 0.14])
    alb = alb * (1.0 - 0.55 * vein[..., None]) + lava_col[None, None, :] * (0.55 * vein)[..., None]

    # A SOFT, WHITE-cyan frost sheen on the ice ocean's fracture ridges -- a frosted
    # ICE surface, deliberately NOT the near-black base + saturated electric-blue
    # cracks that read as Fulgora lightning (ci-i9m). The pale ramp base already
    # reads as ice; the sheen just adds sparkle. Darkness on the ice limb comes from
    # the light falloff, not from a black albedo.
    fr = np.clip(frost * frozen, 0.0, 1.0)
    frost_col = np.array([0.86, 0.93, 1.00])
    alb = alb * (1.0 - 0.35 * fr[..., None]) + frost_col[None, None, :] * (0.35 * fr)[..., None]

    alpha = np.full((H, W), 255.0)
    albedo = np.concatenate([np.clip(alb, 0, 1) * 255.0, alpha[..., None]], -1)

    # -- Emission (RGBA): the identity --------------------------------------
    # The LAVA OCEAN is what glows (ci-4qyj). The glow is gated on `molten`, which
    # is zero below the heat-death threshold and saturates across the ocean, so the
    # radiant part of the disc is exactly the lethal molten ground -- the player can
    # read the danger from orbit. It is hottest (white/yellow) at the pinned
    # sub-stellar extreme, cooling to orange and deep red toward the belt. Kept
    # STRONGLY glowing (ci-fg6) so the ocean saturates toward white-hot, which the
    # bake's Glare node then blooms.
    #
    # The base sheet is deliberately held BELOW saturation so the vein and pool
    # structure still reads inside it. The field is PINNED flat across the ocean
    # (that is what makes it an ocean), so a base bright enough to clip would make
    # the whole sheet one dead flat white slab with no convection to look at --
    # which is what a uniform ocean glow looked like before this was tuned down.
    ocean = np.clip(molten * (0.30 + 0.42 * heat), 0, 1)
    veins = np.clip(lava * molten * (0.55 + 1.05 * heat), 0, 1)
    pools = np.clip((0.55 - height) / 0.55, 0, 1) * molten
    glow = np.clip(0.90 * ocean + 0.30 * veins + 0.55 * pools * heat, 0, 1)

    hot_white = np.array([1.00, 0.93, 0.72])       # sub-stellar white-hot (only the peak)
    orange = np.array([1.00, 0.42, 0.06])          # magma orange (the dayside body)
    deep_red = np.array([0.72, 0.09, 0.02])        # cooling terminator lava
    t_hot = heat[..., None]
    mid = deep_red[None, None, :] * (1 - np.clip(t_hot * 1.5, 0, 1)) + orange[None, None, :] * np.clip(t_hot * 1.5, 0, 1)
    white_t = np.clip((t_hot - 0.80) / 0.20, 0, 1)
    warm = mid * (1 - white_t) + hot_white[None, None, :] * white_t
    em = glow[..., None] * warm

    # NO habitable-middle self-glow (ci-i9m): the terminator is a NATURAL dark
    # falloff supplied by the parallel key light, not a self-lit painted stripe. The
    # old rib_glow injected a bright band down the centre -- exactly the "hard seam"
    # the mayor flagged -- so it is removed. Because `molten` and `frozen` are both
    # zero across the safe middle, the band we build on emits NOTHING and simply
    # goes dark where the light does not reach it: the tidal-lock terminator, free.

    # The ICE OCEAN gets a faint SHIMMERING ICY-BLUE self-glow on its fracture
    # ridges, kept DIM so the frozen side stays dark overall (the light falloff, not
    # the albedo, makes it dark) yet still shimmers blue rather than reading pitch
    # black. Whiter/cooler than a saturated electric blue so it reads as ICE
    # sparkle, not Fulgora lightning.
    shimmer = np.clip(frost * frozen, 0, 1) * 0.22
    shimmer_col = np.array([0.55, 0.76, 1.00])
    em += shimmer[..., None] * shimmer_col[None, None, :]

    em = np.clip(em, 0, 1)
    em_mask = np.clip(em.max(-1), 0, 1)
    emission = np.concatenate([em * 255.0, (em_mask * 255.0)[..., None]], -1)

    # -- Reflectivity (RGB) --------------------------------------------------
    # The ICE OCEAN's frozen sheet is the only glossy ground; the habitable rock is
    # matte-ish and the molten ocean is matte. Keyed to the terrain regions, so the
    # glints land on ice rather than on "whatever the star is not lighting".
    refl = (0.75 * frozen * (0.3 + 0.7 * frost)
            + 0.10 * molten
            + 0.25 * habitable)
    refl = np.clip(refl, 0, 1) * 255.0
    reflectivity = np.stack([refl, refl, refl], -1)

    # -- Normal map ----------------------------------------------------------
    # Relief follows the ground: broken crust in the belts, the flattest surfaces on
    # the two liquid/frozen OCEANS, moderate relief across the habitable rock. Kept
    # modest through the middle (ci-i9m) so the grazing key light does not catch a
    # rocky RIDGE down the centre and re-introduce a seam-like band.
    relief = height * (0.35 * molten + 0.45 * habitable + 0.30 * frozen)
    relief += 0.15 * lava * molten + 0.10 * frost * frozen
    normal = normal_map(relief, 55.0)

    # -- Clouds (global_cloud, RGBA coloured): weather over the HABITABLE band --
    # The only place with an atmosphere worth seeing is the temperate middle, where
    # the lava ocean's steam meets the ice ocean's haze. Centre the band on the
    # middle of the heat field and let it fade out over the two damage belts, so the
    # weather sits over the ground you can stand on.
    cloudfield = field(seed + 6200, base_freq=3.2, octaves=5)
    mid_h = 0.5 * (TERRAIN.hot_dmg + TERRAIN.cold_dmg)
    band = np.exp(-((heat_field - mid_h) / (0.5 * (TERRAIN.hot_dmg - TERRAIN.cold_dmg))) ** 2)
    cloud_cov = np.clip(band * smoothstep(0.35, 0.75, cloudfield), 0, 1) * 0.85
    steam = np.array([0.95, 0.80, 0.62])           # warm steam on the hot edge
    haze = np.array([0.70, 0.82, 1.00])            # cold haze on the cold edge
    edge = np.clip((heat_field - mid_h) / (TERRAIN.hot_dmg - TERRAIN.cold_dmg) + 0.5,
                   0, 1)[..., None]
    cloud_rgb = np.clip(haze[None, None, :] * (1 - edge) + steam[None, None, :] * edge, 0, 1)
    cloud_rgb = cloud_rgb * (0.5 + 0.5 * cloud_cov[..., None])
    cloud = np.concatenate([cloud_rgb * 255.0, (cloud_cov * 255.0)[..., None]], -1)
    cloud_normal = normal_map(cloud_cov, 40.0)

    fa = field(seed + 3000, base_freq=2.0, octaves=3)
    fb = field(seed + 4000, base_freq=2.0, octaves=3)
    cloud_flow = np.stack([((fa - 0.5) * 2.0 * 0.5 + 0.5) * 255.0,
                           ((fb - 0.5) * 2.0 * 0.5 + 0.5) * 255.0,
                           np.full((H, W), 128.0)], -1)

    return {
        "cindra.png": (albedo, "RGBA"),
        "cindra-emission.png": (emission, "RGBA"),
        "cindra-reflectivity.png": (reflectivity, "RGB"),
        "cindra-normal.png": (normal, "RGB"),
        "cindra-cloud.png": (cloud, "RGBA"),
        "cindra-cloud-normal.png": (cloud_normal, "RGB"),
        "cindra-cloud-flow.png": (cloud_flow, "RGB"),
        # Zone masks (H,W) for tests -- not written to disk. `heat` is the terrain
        # field the surface is painted from; the five region masks partition it
        # exactly as terrain.lua does; sol/day/night/ribbon are the LIGHT geometry.
        "_masks": {
            "sol": sol, "day": day, "night": night, "ribbon": ribbon,
            "heat": heat_field,
            "lava_ocean": lava_ocean, "hot_belt": hot_belt & ~lava_ocean,
            "habitable": habitable,
            "cold_belt": cold_belt & ~ice_ocean, "ice_ocean": ice_ocean,
        },
    }


def build_flare_sheet():
    """Solar-flare hero spritesheet (cindra-flare.png).

    The star is perilously close, so it periodically throws flare arcs off the
    dayside limb. Placed with rotate_with_planet = false, it loops in place while
    the GLOBE stays static (tidally locked). White-hot core -> orange -> red,
    arcing loops that rise and fall on a seamless loop (phase advances 2*pi across
    the sheet, frame N == frame 0). Returns (float RGBA array in [0,255], "RGBA").
    """
    AN_N, AN_FS, AN_COLS = 24, 256, 6
    AN_ROWS = -(-AN_N // AN_COLS)  # ceil
    sheet = np.zeros((AN_ROWS * AN_FS, AN_COLS * AN_FS, 4), np.float32)
    ax = (np.arange(AN_FS) + 0.5) / AN_FS
    AX, AY = np.meshgrid(ax, ax)
    col_white = np.array([1.00, 0.97, 0.85])   # white-hot flare core
    col_orange = np.array([1.00, 0.50, 0.10])  # mid flare
    col_red = np.array([0.85, 0.12, 0.04])     # cooling outer arc
    loops = [
        (0.28, 0.78, 1.6, 0.0, 0.070),
        (0.50, 0.92, 1.2, 2.3, 0.080),
        (0.72, 0.68, 2.0, 4.1, 0.060),
    ]
    for fr in range(AN_N):
        p = 2.0 * np.pi * fr / AN_N
        rgb = np.zeros((AN_FS, AN_FS, 3), np.float32)
        a = np.zeros((AN_FS, AN_FS), np.float32)
        surge = 0.55 + 0.45 * np.sin(p)
        for (bx, ph_h, k, ph, sig) in loops:
            arc_h = ph_h * (0.6 + 0.4 * np.sin(p + ph)) * surge
            xc = bx + 0.10 * np.sin(2 * np.pi * k * AY + p + ph)
            yc_top = 1.0 - arc_h
            d = AX - xc
            core = np.exp(-(d / sig) ** 2)
            vfade = np.clip((AY - yc_top) / (1.0 - yc_top + 1e-3), 0, 1)
            core = core * vfade
            band = np.clip((AY - yc_top) / (1.0 - yc_top + 1e-3), 0, 1)[..., None]
            col = (col_red[None, None, :] * (1 - band)
                   + col_orange[None, None, :] * np.clip(band * 2, 0, 1))
            col = col * (1 - np.clip((band - 0.5) * 2, 0, 1)) + col_white[None, None, :] * np.clip((band - 0.5) * 2, 0, 1)
            rgb += core[..., None] * col
            a += core
        a = np.clip(a, 0.0, 1.0)
        rgb = np.clip(rgb, 0.0, 1.0)
        tile = np.concatenate([rgb * 255.0, (a * 255.0)[..., None]], -1)
        r, c = fr // AN_COLS, fr % AN_COLS
        sheet[r * AN_FS:(r + 1) * AN_FS, c * AN_FS:(c + 1) * AN_FS] = tile
    return sheet, "RGBA"


def to_img(arr, mode):
    from PIL import Image
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), mode)


def main(out):
    os.makedirs(out, exist_ok=True)
    layers = generate_maps()
    for name, val in layers.items():
        if name.startswith("_"):
            continue
        arr, mode = val
        to_img(arr, mode).save(f"{out}/{name}")
    sheet, mode = build_flare_sheet()
    to_img(sheet, mode).save(f"{out}/cindra-flare.png")
    print("wrote equirectangular maps to", out)
    for f in sorted(os.listdir(out)):
        print("  ", f)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "mods/cindra/graphics/space")
