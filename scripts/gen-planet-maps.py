#!/usr/bin/env python3
# Procedural equirectangular texture maps for the Cindra planet.
#
# Cindra is a TIDALLY LOCKED "ribbon planet" (DESIGN.md sections 1-4): a molten
# dayside hemisphere (magma ocean, radiant glow), a frozen nightside hemisphere
# (the DARKEST face, deep dark ice with icy-blue glints), and a warm SANDY
# terminator band (the survivable ribbon) between them. The star sits perilously
# close, so the dayside is a hot, bright, self-glowing furnace and the nightside
# is a dark frozen vault. The signature visual tension is fire vs ice, seamed by
# a lit sandy ribbon.
#
# The presented face reads FIERY (left limb) -> SANDY (centre) -> ICY (right limb)
# via a SMOOTH albedo ramp that mirrors the in-game map-view terrain ramp (ci-i9m,
# terrain.lua COLOR_STOPS), so the from-space planet reads as the terrain we play:
#   • SUNWARD hemisphere  : lava, radiant molten orange/red, strong emission,
#                           bright veins as if the crust is being blasted apart.
#   • MIDDLE / terminator  : a smooth sandy-neutral crossover -- NOT a painted
#                           stripe. It carries no self-glow, so it falls into
#                           shadow naturally where the key light does not reach:
#                           the tidal-lock terminator comes from the LIGHT, not a
#                           seam (ci-i9m supersedes the ci-fg6 self-lit sandy band).
#   • NIGHTWARD hemisphere : PALE ICE (frost -> icy white-blue), reading as our
#                           frozen terrain, with a faint icy-blue frost shimmer.
#                           It goes dark via the light falloff, not a black albedo,
#                           so it is ICE -- not a Fulgora-electric near-black vault.
#
# TIDALLY LOCKED means the planet presents ONE face permanently: it must not spin
# in either the star-map sprite or the orbital backdrop. We bake that into the
# MAP itself by arranging the fire/ice gradient along LONGITUDE so the presented
# front hemisphere always shows the whole dramatic split:
#
#   insolation  sol = -cy   (cy = y component of the unit-sphere point)
#     sol = +1  -> sub-stellar point   (hottest molten dayside)  at lon = -90
#     sol =  0  -> terminator ribbon   (survivable sandy seam)   at lon =   0 / 180
#     sol = -1  -> anti-stellar point  (coldest frozen nightside) at lon = +90
#
# On an orthographic disc a point at longitude near the presented centre projects
# to screen-x ~ sin(lon), and sol ~ -sin(lon), so sol maps almost linearly to the
# horizontal across the visible face: sol=0 (sandy) sits dead centre, fire on the
# left limb, ice on the right. Widening the ribbon in sol-space therefore widens
# the sandy band on the presented disc into a clear fiery|sandy|icy thirds read.
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
# test can assert the fiery/sandy/icy split (see unit-tests/test_planet_maps.py)
# without shelling out to the file writer.

import os
import sys
import numpy as np
# PIL is imported lazily in to_img() so generate_maps() stays importable in a
# numpy-only environment (the pixel test needs no image encoder).

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


# Hot -> cold surface colour ramp, MIRRORING the in-game map-view ramp in
# scripts/terrain.lua (COLOR_STOPS, ci-4h7): reds sunward, a sandy neutral centre,
# pale cyan/frost nightward. Sampling the SAME ramp for the from-space art is what
# makes the orbital/star-map planet "read as our terrain" (ci-i9m): the fiery
# hemisphere is lava/volcanic, the frozen hemisphere is PALE ICE (not a near-black
# Fulgora-electric vault), and the terminator is a smooth sandy blend -- NOT a
# painted stripe. The day/night falloff is supplied by the parallel key light
# (bake) / light_direction (orbit), not by a self-lit seam.
TERRAIN_STOPS = [
    (0.00, (0.98, 0.42, 0.06)),   # lava, orange-red
    (0.18, (0.80, 0.30, 0.10)),   # molten crust
    (0.35, (0.55, 0.40, 0.28)),   # warm volcanic brown
    (0.50, (0.62, 0.56, 0.42)),   # sandy building neutral (terminator)
    (0.66, (0.60, 0.64, 0.64)),   # cool grey dust
    (0.82, (0.66, 0.82, 0.88)),   # pale frost
    (1.00, (0.82, 0.95, 1.00)),   # icy white-blue
]


def terrain_ramp(t):
    """Vectorised piecewise-linear lookup into TERRAIN_STOPS.

    t is the normalised hot->cold position in [0,1] (0 = hottest lava,
    1 = coldest ice). Returns an RGB array shaped t.shape + (3,).
    """
    xs = np.array([s[0] for s in TERRAIN_STOPS], np.float32)
    cols = np.array([s[1] for s in TERRAIN_STOPS], np.float32)   # (K,3)
    out = np.empty(t.shape + (3,), np.float32)
    for ch in range(3):
        out[..., ch] = np.interp(t, xs, cols[:, ch])
    return out


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
    analytic zone masks (sol/day/night/ribbon) so a test can address the fire /
    sandy / ice regions without re-deriving the geometry.
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

    # NATURAL terminator, NOT a painted stripe (ci-i9m). The albedo below is a
    # SMOOTH hot->cold ramp along `t` (terrain_ramp), so the fiery hemisphere melts
    # into the frozen one through a sandy-neutral midpoint with no hard seam. The
    # day/night light falloff is supplied by the LEFT parallel key (bake) and
    # light_direction (orbit) -- the map no longer self-lights a sandy band.
    #
    # t = normalised hot->cold position in [0,1]: 0 = hottest lava, 1 = coldest ice.
    t = np.clip(0.5 * (1.0 - sol), 0.0, 1.0)
    # Soft masks still tag the hemispheres + the transition band so EMISSION can be
    # gated day-side (lava self-glow) / night-side (dim ice shimmer) and tests can
    # address the fire / terminator / ice regions. These are analytic gates, not a
    # painted colour band. This is ART only; it does NOT touch the in-game mapgen
    # zone widths (planet.lua / ribbon.lua, ci-da2).
    day = smoothstep(0.05, 0.30, sol)                      # molten hemisphere
    night = smoothstep(0.05, 0.30, -sol)                   # frozen hemisphere
    ribbon = np.clip(1.0 - day - night, 0.0, 1.0)          # terminator transition
    heat = np.clip(sol, 0.0, 1.0)                           # 0..1 toward substellar
    cold = np.clip(-sol, 0.0, 1.0)                          # 0..1 toward antistellar

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

    D, N, R = day[..., None], night[..., None], ribbon[..., None]

    # -- Albedo (RGBA): the SMOOTH hot->cold terrain ramp (ci-i9m) -----------
    # Base colour is the in-game terrain ramp sampled along `t`, so the surface
    # reads as OUR terrain: molten orange-red -> volcanic brown -> sandy neutral ->
    # pale frost -> icy white-blue, with NO hard painted seam (the old bright sandy
    # stripe is gone; the terminator is now just where the ramp -- and the light --
    # cross over). Height gives gentle relief shading.
    base = terrain_ramp(t)                                  # (H,W,3), the terrain look
    shade = np.clip(0.80 + 0.34 * (height - 0.5) + 0.10 * (detail - 0.5), 0.55, 1.15)
    alb = base * shade[..., None]

    # Hot side: brighten the lava veins toward glowing orange so the fiery limb
    # reads as radiant molten rock even under the raw albedo (the emission map
    # carries the actual glow on top).
    vein = np.clip(lava * heat, 0.0, 1.0)
    lava_col = np.array([1.00, 0.55, 0.14])
    alb = alb * (1.0 - 0.55 * vein[..., None]) + lava_col[None, None, :] * (0.55 * vein)[..., None]

    # Cold side: a SOFT, WHITE-cyan frost sheen on the frost ridges -- a frosted ICE
    # surface, deliberately NOT the near-black base + saturated electric-blue cracks
    # that read as Fulgora lightning (ci-i9m). The pale ramp base already reads as
    # ice; the sheen just adds a little sparkle. Darkness on the ice limb comes from
    # the light falloff, not from a black albedo.
    fr = np.clip(frost * cold, 0.0, 1.0)
    frost_col = np.array([0.86, 0.93, 1.00])
    alb = alb * (1.0 - 0.35 * fr[..., None]) + frost_col[None, None, :] * (0.35 * fr)[..., None]

    alpha = np.full((H, W), 255.0)
    albedo = np.concatenate([np.clip(alb, 0, 1) * 255.0, alpha[..., None]], -1)

    # -- Emission (RGBA): the identity --------------------------------------
    # Molten dayside glow, hottest (white/yellow) at the sub-stellar point,
    # cooling to orange and deep red toward the terminator. Pushed hotter across
    # the whole hemisphere (ci-fg6) so the fire limb reads as a STRONGLY GLOWING
    # magma ocean, not a dull ember: the base ocean glow is lifted and the veins
    # burn brighter, so far more of the dayside saturates toward white-hot (which
    # the bake's Glare node then blooms).
    ocean = np.clip(day * (0.48 + 0.62 * heat), 0, 1)
    veins = np.clip(lava * day * (0.55 + 1.05 * heat), 0, 1)
    pools = np.clip((0.55 - height) / 0.55, 0, 1) * day
    glow = np.clip(0.90 * ocean + 1.30 * veins + 0.45 * pools * heat, 0, 1)

    hot_white = np.array([1.00, 0.93, 0.72])       # sub-stellar white-hot (only the peak)
    orange = np.array([1.00, 0.42, 0.06])          # magma orange (the dayside body)
    deep_red = np.array([0.72, 0.09, 0.02])        # cooling terminator lava
    t_hot = heat[..., None]
    mid = deep_red[None, None, :] * (1 - np.clip(t_hot * 1.5, 0, 1)) + orange[None, None, :] * np.clip(t_hot * 1.5, 0, 1)
    white_t = np.clip((t_hot - 0.80) / 0.20, 0, 1)
    warm = mid * (1 - white_t) + hot_white[None, None, :] * white_t
    em = glow[..., None] * warm

    # NO sandy-seam self-glow (ci-i9m): the terminator is a NATURAL dark falloff
    # supplied by the parallel key light, not a self-lit painted stripe. The old
    # rib_glow injected a bright band down the centre -- exactly the "hard seam" the
    # mayor flagged -- so it is removed. The sandy midpoint now simply goes dark
    # where the light does not reach it, giving the tidal-lock terminator for free.

    # Nightside: a faint SHIMMERING ICY-BLUE self-glow on the frost ridges, kept
    # DIM so the frozen hemisphere stays dark overall (the light falloff, not the
    # albedo, makes it dark) yet still shimmers blue rather than reading pitch black.
    # Whiter/cooler than the old saturated electric blue so it reads as ICE sparkle,
    # not Fulgora lightning.
    shimmer = np.clip(frost * night, 0, 1) * 0.22
    shimmer_col = np.array([0.55, 0.76, 1.00])
    em += shimmer[..., None] * shimmer_col[None, None, :]

    em = np.clip(em, 0, 1)
    em_mask = np.clip(em.max(-1), 0, 1)
    emission = np.concatenate([em * 255.0, (em_mask * 255.0)[..., None]], -1)

    # -- Reflectivity (RGB) --------------------------------------------------
    # Icy nightside glints are the only glossy patches; sandy ribbon is matte-ish;
    # molten basalt dayside is matte.
    refl = (0.75 * night * (0.3 + 0.7 * frost)
            + 0.10 * day
            + 0.25 * ribbon)
    refl = np.clip(refl, 0, 1) * 255.0
    reflectivity = np.stack([refl, refl, refl], -1)

    # -- Normal map ----------------------------------------------------------
    # Keep the TERMINATOR relief modest (ci-i9m): the old strong ribbon relief
    # (weight 1.0) caught the grazing key light as a rocky RIDGE down the centre,
    # re-introducing a seam-like band. A gentler terminator relief lets the
    # fire->ice light gradient stay smooth.
    relief = height * (0.6 * day + 0.45 * ribbon + 0.35 * night)
    relief += 0.15 * lava * day + 0.10 * frost * night
    normal = normal_map(relief, 55.0)

    # -- Clouds (global_cloud, RGBA coloured): the TERMINATOR band -----------
    cloudfield = field(seed + 6200, base_freq=3.2, octaves=5)
    band = np.exp(-((sol) / 0.30) ** 2)
    cloud_cov = np.clip(band * smoothstep(0.35, 0.75, cloudfield), 0, 1) * 0.85
    steam = np.array([0.95, 0.80, 0.62])           # warm steam on the day edge
    haze = np.array([0.70, 0.82, 1.00])            # cold haze on the night edge
    edge = np.clip(sol / 0.3 * 0.5 + 0.5, 0, 1)[..., None]
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
        # Zone masks (H,W) for tests -- not written to disk.
        "_masks": {"sol": sol, "day": day, "night": night, "ribbon": ribbon},
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
