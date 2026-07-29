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
# The presented face reads FIERY (left limb) -> SANDY (centre) -> ICY (right limb):
#   • SUNWARD hemisphere  : lava, radiant molten orange/red, strong emission,
#                           bright veins as if the crust is being blasted apart.
#   • MIDDLE / terminator  : SANDY YELLOW, warm and clearly LIT (a modest sandy
#                           self-emission guarantees the seam never reads black).
#   • NIGHTWARD hemisphere : the DARKEST part, deep dark, with SHIMMERING ICY-BLUE
#                           glinting through the darkness (sparse frost-ridge glow).
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
    # sol in [-1, 1]: +1 sub-stellar (fire), 0 terminator ribbon, -1 anti-stellar
    # (ice). A little noise warps the boundary so the seam is a ragged coastline.
    sol = (-cy).reshape(H, W)
    warp = (field(seed + 400, base_freq=3.0, octaves=4) - 0.5)
    # Warp amplitude scaled down with the slimmed band (ci-fg6): the seam is now a
    # THIN terminator, so a large warp would scatter sand blobs deep into the
    # hemispheres. Keep it comparable to the band half-width for a ragged-but-thin
    # coastline.
    sol = np.clip(sol + 0.035 * warp, -1.0, 1.0)

    # THIN sandy terminator (ci-fg6): the mayor's space-view refinement slims the
    # sandy middle band ~10x, so the planet reads as mostly FIERY hemisphere + ICY
    # hemisphere with only a thin sand seam between them (consistent with tidal
    # lock: fire limb -> thin sand terminator -> ice limb). The old band was the
    # middle THIRD of the disc (smoothstep 0.12..0.48, half-width ~0.30 in sol,
    # which maps ~linearly to screen-x; see the header). Here the smoothstep
    # midpoint drops to ~0.033 (half-width ~10x smaller), so the hemispheres reach
    # full fire/ice strength almost to the centre with only a sliver of sand. This
    # is ART only (equirect maps -> baked sprite + orbital backdrop); it does NOT
    # touch the in-game mapgen zone widths (planet.lua / ribbon.lua, ci-da2).
    day = smoothstep(0.013, 0.053, sol)                    # molten hemisphere
    night = smoothstep(0.013, 0.053, -sol)                 # frozen hemisphere
    ribbon = np.clip(1.0 - day - night, 0.0, 1.0)          # thin sandy seam
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

    # -- Albedo (RGBA) -------------------------------------------------------
    # Dayside: a hot ember crust so the lava reads as radiant molten rock even
    # where the emission is masked; bright lava veins push it toward a glowing
    # orange. Brighter + more saturated than the old dull-peach crust (ci-fg6) so
    # the fire limb reads as GLOWING lava, not matte rock.
    day_v = 0.30 + 0.30 * height + 0.55 * lava
    day_rgb = np.stack([day_v * 1.35, day_v * 0.52, day_v * 0.14], -1)     # molten orange-red
    # Ribbon: SANDY YELLOW, the survivable seam. Bright, warm, gently duned by
    # the height field so it is not a flat wash.
    sand = np.array([0.84, 0.68, 0.40])
    rib_v = 0.82 + 0.22 * (height - 0.5) + 0.10 * (detail - 0.5)
    rib_rgb = sand[None, None, :] * np.clip(rib_v, 0.4, 1.15)[..., None]
    # Nightside: the DARKEST zone, but no longer flat navy (ci-fg6). A near-black
    # deep-blue base with SHIMMERING icy-blue glints where frost ridges catch the
    # last starlight -- brighter, cooler and more plentiful glints so the ice limb
    # reads as a shimmery blue frozen vault, while the base stays the darkest zone.
    night_base = np.array([0.015, 0.030, 0.075])
    glint = frost * (0.35 + 0.65 * height)
    glint_col = np.array([0.46, 0.74, 1.00])
    ice_rgb = night_base[None, None, :] + 0.95 * glint[..., None] * glint_col[None, None, :]

    albedo = day_rgb * D + ice_rgb * N + rib_rgb * R
    alpha = np.full((H, W), 255.0)
    albedo = np.concatenate([np.clip(albedo, 0, 1) * 255.0, alpha[..., None]], -1)

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

    # Ribbon: a modest WARM SANDY self-glow. This is the fix for the black
    # centre -- the seam carries its own light, so it reads sandy-lit in both the
    # baked star-map sprite and the orbital backdrop regardless of key-light angle.
    rib_glow = ribbon * (0.20 + 0.12 * height + 0.06 * (detail - 0.5))
    sand_em = np.array([1.00, 0.80, 0.46])
    em += np.clip(rib_glow, 0, 1)[..., None] * sand_em[None, None, :]

    # Nightside: SHIMMERING ICY-BLUE glinting through the dark -- a self-glow on
    # the frost ridges, lifted (ci-fg6) so the ice limb visibly shimmers blue,
    # yet still kept below the sandy seam's glow so the vault stays the darkest,
    # dimmest-lit zone (the test guards ice_emax < seam_emax).
    shimmer = np.clip(frost * night, 0, 1) * 0.24
    shimmer_col = np.array([0.30, 0.64, 1.00])
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
    relief = height * (0.6 * day + 1.0 * ribbon + 0.35 * night)
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
