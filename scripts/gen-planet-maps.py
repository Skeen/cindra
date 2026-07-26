#!/usr/bin/env python3
# Procedural equirectangular texture maps for the Cindra planet.
#
# Cindra is a TIDALLY LOCKED "ribbon world" (planet_design.md sections 1-4, 10):
# a molten dayside hemisphere (magma ocean, glowing emission), a frozen nightside
# hemisphere (dark ice, blue/white), and a thin temperate TERMINATOR band (the
# survivable ribbon) between them. The star sits perilously close, so the dayside
# is a hot, bright, self-glowing furnace and the nightside is a dark frozen vault.
# The signature visual tension is fire vs ice.
#
# TIDALLY LOCKED means the planet presents ONE face permanently: it must not spin
# in either the star-map sprite or the orbital backdrop. We bake that into the
# MAP itself by arranging the fire/ice gradient along LONGITUDE so the presented
# front hemisphere always shows the whole dramatic split:
#
#   insolation  sol = -cy   (cy = y component of the unit-sphere point)
#     sol = +1  -> sub-stellar point   (hottest molten dayside)  at lon = -90
#     sol =  0  -> terminator ribbon   (survivable seam)         at lon =   0 / 180
#     sol = -1  -> anti-stellar point  (coldest frozen nightside) at lon = +90
#
# The front hemisphere (centred on lon = 0) therefore reads fire (left limb) ->
# ribbon (centre) -> ice (right limb): the dayside+terminator+nightside split the
# brief calls for, seen from any presented longitude near the front.
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

import os
import sys
import numpy as np
from PIL import Image

W, H = 2048, 1024          # equirectangular, 2:1
SEED = 51001                # deterministic; change for a different world
OUT = sys.argv[1] if len(sys.argv) > 1 else "mods/cindra/graphics/space"

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


# ---------------------------------------------------------------------------
# Sphere sample points for every equirectangular texel.
# ---------------------------------------------------------------------------
xs = (np.arange(W) + 0.5) / W
ys = (np.arange(H) + 0.5) / H
lon = xs * 2.0 * np.pi - np.pi           # (W,)
lat = np.pi / 2.0 - ys * np.pi           # (H,)
LON, LAT = np.meshgrid(lon, lat)         # (H,W)
cx = np.cos(LAT) * np.cos(LON)
cy = np.cos(LAT) * np.sin(LON)
cz = np.sin(LAT)
unit = np.stack([cx, cy, cz], axis=-1).reshape(-1, 3).astype(np.float32)


def field(seed, **kw):
    return fbm(unit, seed, **kw).reshape(H, W)


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def to_img(arr, mode):
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), mode)


os.makedirs(OUT, exist_ok=True)

# ---------------------------------------------------------------------------
# The tidally-locked axis. sol in [-1, 1]: +1 sub-stellar (fire), 0 terminator
# ribbon, -1 anti-stellar (ice). A little noise warps the boundary so the
# terminator is a ragged coastline, not a clean line of latitude.
# ---------------------------------------------------------------------------
sol = (-cy).reshape(H, W)                                   # base insolation
warp = (field(SEED + 400, base_freq=3.0, octaves=4) - 0.5)  # ragged terminator
sol = np.clip(sol + 0.14 * warp, -1.0, 1.0)

# Thin ribbon: the hemispheres reach full strength quickly past the terminator,
# leaving only a narrow temperate seam (the survivable band) around sol = 0.
day = smoothstep(0.02, 0.30, sol)                           # molten hemisphere
night = smoothstep(0.02, 0.30, -sol)                        # frozen hemisphere
ribbon = np.clip(1.0 - day - night, 0.0, 1.0)               # temperate seam
heat = np.clip(sol, 0.0, 1.0)                               # 0..1 toward substellar
cold = np.clip(-sol, 0.0, 1.0)                              # 0..1 toward antistellar

# ---------------------------------------------------------------------------
# Height / relief field. Dayside is a magma ocean with floating crust rafts,
# nightside is a fractured ice sheet, the ribbon is broken rock. One shared
# height field, read differently per zone.
# ---------------------------------------------------------------------------
height = field(SEED, base_freq=2.2, octaves=7)
height = np.clip(height + 0.10 * (field(SEED + 500, base_freq=4.0, octaves=4) - 0.5), 0, 1)
detail = field(SEED + 900, base_freq=18.0, octaves=5)

# Lava channels (ridged filaments) trace the hottest cracks on the dayside.
lava = ridged(unit, SEED + 111, base_freq=3.0, octaves=6).reshape(H, W)
lava = np.power(lava, 2.6)                                  # thin bright veins
# Ice fractures: a second ridged network for the nightside frost cracks.
frost = ridged(unit, SEED + 222, base_freq=4.0, octaves=5).reshape(H, W)
frost = np.power(frost, 3.0)

# ---------------------------------------------------------------------------
# Albedo (RGBA): dark basalt dayside, blue-white ice nightside, slate ribbon.
# The molten glow lives in the EMISSION map; albedo stays dark on the dayside so
# the emission reads as light, not paint.
# ---------------------------------------------------------------------------
# Dayside: near-black basalt crust, faintly warm, brighter on raised rafts.
day_v = 0.035 + 0.045 * height + 0.02 * (detail - 0.5)
day_rgb = np.stack([day_v * 1.30, day_v * 0.95, day_v * 0.80], -1)   # warm charcoal
# Nightside: bright ice, blue-white, high in raised drifts, deep-blue in hollows.
ice_v = 0.45 + 0.40 * height + 0.10 * (detail - 0.5)
ice_rgb = np.stack([ice_v * 0.80, ice_v * 0.92, ice_v * 1.15], -1)   # cold blue-white
deep_ice = np.stack([np.full_like(height, 0.05),
                     np.full_like(height, 0.09),
                     np.full_like(height, 0.20)], -1)
icemix = smoothstep(0.35, 0.60, height)[..., None]
ice_rgb = deep_ice * (1 - icemix) + ice_rgb * icemix
# Ribbon: temperate slate, the survivable ground, a touch of warm ochre.
rib_v = 0.16 + 0.12 * height + 0.05 * (detail - 0.5)
rib_rgb = np.stack([rib_v * 1.05, rib_v * 1.00, rib_v * 0.92], -1)

D, N, R = day[..., None], night[..., None], ribbon[..., None]
albedo = day_rgb * D + ice_rgb * N + rib_rgb * R
alpha = np.full((H, W), 255.0)
albedo = np.concatenate([np.clip(albedo, 0, 1) * 255.0, alpha[..., None]], -1)
to_img(albedo, "RGBA").save(f"{OUT}/cindra.png")

# ---------------------------------------------------------------------------
# Emission (RGBA): the identity. Molten dayside glow, hottest (white/yellow) at
# the sub-stellar point, cooling to orange and deep red toward the terminator.
# The nightside is dark; only a faint cold aurora shimmer near the ribbon.
# ---------------------------------------------------------------------------
# Broad magma-ocean glow over the whole dayside, strongest at the hottest core.
ocean = np.clip(day * (0.30 + 0.70 * heat), 0, 1)
# Bright lava veins concentrated on the dayside, brightest near the substellar core.
veins = np.clip(lava * day * (0.40 + 0.90 * heat), 0, 1)
# Low ground pools glow more (heat collects in the hollows).
pools = np.clip((0.55 - height) / 0.55, 0, 1) * day
glow = np.clip(0.55 * ocean + veins + 0.35 * pools * heat, 0, 1)

# Temperature colour ramp: deep red (cool terminator cracks) -> magma orange
# across most of the dayside -> white-hot only in the very hottest sub-stellar
# core, so the dayside reads as rich molten orange, not a pale wash.
hot_white = np.array([1.00, 0.93, 0.72])       # sub-stellar white-hot (only the peak)
orange = np.array([1.00, 0.42, 0.06])          # magma orange (the dayside body)
deep_red = np.array([0.72, 0.09, 0.02])        # cooling terminator lava
t_hot = heat[..., None]
# red -> orange over the first two-thirds of the heat range.
mid = deep_red[None, None, :] * (1 - np.clip(t_hot * 1.5, 0, 1)) + orange[None, None, :] * np.clip(t_hot * 1.5, 0, 1)
# white only in the hottest fifth (heat > 0.80).
white_t = np.clip((t_hot - 0.80) / 0.20, 0, 1)
warm = mid * (1 - white_t) + hot_white[None, None, :] * white_t
em = glow[..., None] * warm

# Faint cold aurora over the nightside near the ribbon: a thin blue-green shimmer
# where the last starlight grazes the frozen edge (subtle, keeps the dark vault).
aurora = np.clip(frost * night * smoothstep(0.0, 0.5, ribbon + 0.35 * night), 0, 1) * 0.12
aur_col = np.array([0.30, 0.65, 1.00])
em += aurora[..., None] * aur_col[None, None, :]

em = np.clip(em, 0, 1)
em_mask = np.clip(em.max(-1), 0, 1)
emission = np.concatenate([em * 255.0, (em_mask * 255.0)[..., None]], -1)
to_img(emission, "RGBA").save(f"{OUT}/cindra-emission.png")

# ---------------------------------------------------------------------------
# Reflectivity (RGB): ice nightside is a glossy mirror; basalt dayside is matte;
# the ribbon sits in between. Drives roughness in the Blender bake / specular in
# the orbital backdrop.
# ---------------------------------------------------------------------------
refl = (0.85 * night * (0.6 + 0.4 * height)
        + 0.10 * day
        + 0.30 * ribbon)
refl = np.clip(refl, 0, 1) * 255.0
to_img(np.stack([refl, refl, refl], -1), "RGB").save(f"{OUT}/cindra-reflectivity.png")


# ---------------------------------------------------------------------------
# Normal map from a height field.
# ---------------------------------------------------------------------------
def normal_map(h, strength):
    gy, gx = np.gradient(h.astype(np.float32))
    nx, ny, nz = -gx * strength, -gy * strength, np.ones_like(h)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    n = np.stack([nx / ln, ny / ln, nz / ln], -1)
    return (n * 0.5 + 0.5) * 255.0


# Rocky relief on the dayside/ribbon, smoother ice on the nightside.
relief = height * (0.6 * day + 1.0 * ribbon + 0.35 * night)
relief += 0.15 * lava * day + 0.10 * frost * night
to_img(normal_map(relief, 55.0), "RGB").save(f"{OUT}/cindra-normal.png")

# ---------------------------------------------------------------------------
# Clouds (global_cloud, RGBA coloured): the TERMINATOR band. Where the molten
# dayside air meets the frozen nightside, convection throws up a ragged band of
# steam/ash cloud along the ribbon. It drifts (flow map + cloud_panning_rate) so
# the seam looks alive, but the GLOBE underneath never rotates.
# ---------------------------------------------------------------------------
cloudfield = field(SEED + 6200, base_freq=3.2, octaves=5)
# Concentrate cloud on the terminator, feathering a little onto both sides.
band = np.exp(-((sol) / 0.30) ** 2)
cloud_cov = np.clip(band * smoothstep(0.35, 0.75, cloudfield), 0, 1) * 0.85
# Warm steam on the day edge, cold haze on the night edge of the band.
steam = np.array([0.95, 0.80, 0.62])
haze = np.array([0.70, 0.82, 1.00])
edge = np.clip(sol / 0.3 * 0.5 + 0.5, 0, 1)[..., None]
cloud_rgb = np.clip(haze[None, None, :] * (1 - edge) + steam[None, None, :] * edge, 0, 1)
cloud_rgb = cloud_rgb * (0.5 + 0.5 * cloud_cov[..., None])
aurora_cloud = np.concatenate([cloud_rgb * 255.0, (cloud_cov * 255.0)[..., None]], -1)
to_img(aurora_cloud, "RGBA").save(f"{OUT}/cindra-cloud.png")
to_img(normal_map(cloud_cov, 40.0), "RGB").save(f"{OUT}/cindra-cloud-normal.png")

# --- Cloud flow (RGB): smooth vector field driving the cloud panning ---------
fa = field(SEED + 3000, base_freq=2.0, octaves=3)
fb = field(SEED + 4000, base_freq=2.0, octaves=3)
fx = (fa - 0.5) * 2.0
fy = (fb - 0.5) * 2.0
flow = np.stack([(fx * 0.5 + 0.5) * 255.0,
                 (fy * 0.5 + 0.5) * 255.0,
                 np.full((H, W), 128.0)], -1)
to_img(flow, "RGB").save(f"{OUT}/cindra-cloud-flow.png")

# ---------------------------------------------------------------------------
# Solar-flare hero spritesheet (cindra-flare.png). The star is perilously close,
# so it periodically throws flare arcs off the dayside limb. This is the "solar-
# flare drama as an in-place animated flourish": placed at the dayside limb with
# rotate_with_planet = false, it loops in place while the GLOBE stays static
# (tidally locked). White-hot core -> orange -> red, arcing loops that rise and
# fall on a seamless loop (phase advances 2*pi across the sheet, frame N==frame 0).
# ---------------------------------------------------------------------------
AN_N, AN_FS, AN_COLS = 24, 256, 6
AN_ROWS = -(-AN_N // AN_COLS)  # ceil
sheet = np.zeros((AN_ROWS * AN_FS, AN_COLS * AN_FS, 4), np.float32)
ax = (np.arange(AN_FS) + 0.5) / AN_FS
AX, AY = np.meshgrid(ax, ax)
col_white = np.array([1.00, 0.97, 0.85])   # white-hot flare core
col_orange = np.array([1.00, 0.50, 0.10])  # mid flare
col_red = np.array([0.85, 0.12, 0.04])     # cooling outer arc
# (base_x, height, wavenumber, phase, thickness) for a few flare loops rooted at
# the bottom (the limb) and arcing upward. Tall and thick so they read as
# dramatic solar prominences, not faint threads.
loops = [
    (0.28, 0.78, 1.6, 0.0, 0.070),
    (0.50, 0.92, 1.2, 2.3, 0.080),
    (0.72, 0.68, 2.0, 4.1, 0.060),
]
for fr in range(AN_N):
    p = 2.0 * np.pi * fr / AN_N
    rgb = np.zeros((AN_FS, AN_FS, 3), np.float32)
    a = np.zeros((AN_FS, AN_FS), np.float32)
    # Breathing amplitude so the flares surge and subside over the loop.
    surge = 0.55 + 0.45 * np.sin(p)
    for (bx, ph_h, k, ph, sig) in loops:
        # An arc: x sweeps, y follows a rising-then-falling parabola modulated by
        # the loop phase so the arc pulses outward from the limb.
        arc_h = ph_h * (0.6 + 0.4 * np.sin(p + ph)) * surge
        xc = bx + 0.10 * np.sin(2 * np.pi * k * AY + p + ph)
        yc_top = 1.0 - arc_h                       # how high this arc reaches
        # distance from a vertical-ish arced core line
        d = AX - xc
        core = np.exp(-(d / sig) ** 2)
        # Fade with height: bright at the limb (bottom), fading toward the top,
        # cut off above the arc's reach.
        vfade = np.clip((AY - yc_top) / (1.0 - yc_top + 1e-3), 0, 1)
        core = core * vfade
        # Colour by height: white-hot at the base, orange, red at the tip.
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
to_img(sheet, "RGBA").save(f"{OUT}/cindra-flare.png")

print("wrote equirectangular maps to", OUT)
for f in sorted(os.listdir(OUT)):
    print("  ", f)
