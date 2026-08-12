#!/usr/bin/env python3
# Pixel test for the procedural planet maps (scripts/gen-planet-maps.py).
#
# The map generator is pure and deterministic, so its output is testable off-game
# without Blender or Factorio.
#
# THE HEADLINE CONTRACT (ci-4qyj): the globe shows the THREE-PART planet the
# ci-wly/ci-oe83 heightmap actually generates -- a broad hot LAVA OCEAN, a
# habitable MIDDLE, and a broad cold ICE OCEAN, in that order across the disc, at
# the widths the terrain really has. Everything the player can see about Cindra
# before landing has to be true after landing:
#
#   • ORDER + BREADTH. Lava ocean -> hot belt -> habitable -> cold belt -> ice
#     ocean, sunward to nightward, with each OCEAN a broad sheet (a quarter of the
#     axis) rather than a thin rim at the limb.
#   • PAINTED WITH THE GROUND. The surface colour is terrain.lua's own map colour
#     for the tile at that point of the ribbon axis, times a greyscale relief
#     shade -- not an independent ramp that can drift from the terrain (which is
#     exactly what happened between ci-6i1 and ci-oe83).
#   • THE GLOW IS THE LETHAL GROUND. What lights up from orbit is the molten
#     ocean and its belt; the habitable middle emits NOTHING at all.
#
# It also guards the ci-i9m REDESIGN of the from-space look, which SUPERSEDES the
# ci-fg6 painted-sandy-seam contract per the mayor, and the ci-6i1 recolour of the
# terminator belt (dark volcanic rock, NOT a gray/tan sandy blur):
#
#   • NO PAINTED SEAM. The terminator is a SMOOTH hot->cold albedo ramp (mirroring
#     the in-game terrain ramp), not a bright self-lit stripe down the middle.
#     The old bug was a hard vertical line; here the terminator carries almost
#     no self-glow, so the day/night falloff comes from the parallel KEY LIGHT.
#   • DARK VOLCANIC MOUNTAINS AT THE TERMINATOR (ci-6i1). The middle third between
#     fire and ice is a BROAD band of dark reddish-brown / near-black basalt: LOW
#     luminance and WARM (R>G>B, R clearly above B), NOT the old gray/tan sandy
#     ribbon (which read as an ugly gray stripe from space) and NOT a neutral gray
#     (R != B). The gray/tan neutrals are gone from the ramp entirely.
#   • ICE READS AS ICE. The frozen hemisphere is PALE cyan-white frost (our terrain),
#     NOT a near-black vault laced with saturated electric-blue cracks (which read
#     as Fulgora lightning). It goes dark via the LIGHT falloff, not a black albedo.
#   • LAVA STILL GLOWS. The fiery hemisphere is a strongly glowing molten emission;
#     the terminator and ice do not self-light a bright band.
#
# Run (numpy only, ~1s at test resolution):
#   nix-shell -p "python3.withPackages(ps: with ps; [numpy])" \
#     --run "python3 mods/cindra/unit-tests/test_planet_maps.py"

import importlib.util
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
GEN = os.path.normpath(os.path.join(HERE, "..", "..", "..", "scripts", "gen-planet-maps.py"))

spec = importlib.util.spec_from_file_location("gen_planet_maps", GEN)
gpm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gpm)

# Small, fast resolution: the zones are analytic (from longitude), so the split
# holds at any resolution; noise detail just gets coarser.
layers = gpm.generate_maps(W=256, H=128, seed=gpm.SEED)
masks = layers["_masks"]

albedo = layers["cindra.png"][0][..., :3]          # (H,W,3) float 0..255
emission = layers["cindra-emission.png"][0][..., :3]
emax = emission.max(axis=-1)                        # per-pixel emissive strength

# Select pixels that belong firmly to each region (avoid the blend borders).
fire = masks["day"] > 0.85
ice = masks["night"] > 0.85
seam = masks["ribbon"] > 0.85

passed = failed = 0


def check(name, cond, detail=""):
    global passed, failed
    if cond:
        passed += 1
        print("ok - " + name)
    else:
        failed += 1
        print("not ok - " + name + ("  [" + detail + "]" if detail else ""))


def rgb_mean(arr, mask):
    return arr[mask].mean(axis=0)


def bright(arr, mask):
    return arr[mask].mean(axis=-1)


# All three regions must actually exist on the presented face.
check("each region is present (fire / terminator / ice)",
      fire.sum() > 50 and seam.sum() > 50 and ice.sum() > 50,
      f"fire={int(fire.sum())} seam={int(seam.sum())} ice={int(ice.sum())}")

fire_bright = float(np.median(bright(albedo, fire)))
seam_bright = float(np.median(bright(albedo, seam)))
ice_bright = float(np.median(bright(albedo, ice)))

# --- NO PAINTED SEAM (ci-i9m supersedes ci-fg6) -----------------------------
# The terminator must NOT be a bright self-lit stripe: its emission is near-zero,
# so it falls dark where the key light does not reach it (the natural terminator).
seam_emax = float(np.median(emax[seam]))
fire_emax = float(np.median(emax[fire]))
ice_emax = float(np.median(emax[ice]))
check("terminator carries NO bright self-glow band (median emax < 20)",
      seam_emax < 20.0,
      f"seam median emax={seam_emax:.1f}")
# The terminator is a DARK belt, not a bright albedo spike: the mountain band is
# dimmer than the pale ice and no brighter than the fiery limb.
check("terminator is a dark belt, not a bright albedo spike",
      seam_bright < ice_bright and seam_bright <= fire_bright + 20.0,
      f"seam={seam_bright:.1f} fire={fire_bright:.1f} ice={ice_bright:.1f}")

# --- DARK VOLCANIC MOUNTAINS AT THE TERMINATOR (ci-6i1) ---------------------
# The middle third is a broad band of dark reddish-brown / near-black basalt.
seam_alb = rgb_mean(albedo, seam)
# LOW luminance: the belt is dark rock, well below the pale ice and not a bright
# neutral. (The old sandy/grey stops sat around ~150; dark mountains are far below.)
check("terminator is DARK volcanic rock (mean brightness < 90, << ice)",
      seam_bright < 90.0 and seam_bright < 0.5 * ice_bright,
      f"seam={seam_bright:.1f} ice={ice_bright:.1f}")
# WARM, not gray/tan: red clearly dominates blue (basalt reddish-brown), the
# opposite of the old cool-grey-dust neutral (R ~= G ~= B).
check("terminator albedo is WARM basalt (R>G>B, R clearly above B: R-B > 12)",
      seam_alb[0] > seam_alb[1] > seam_alb[2] and (seam_alb[0] - seam_alb[2]) > 12.0,
      f"albedo={seam_alb.round(1)}  R-B={(seam_alb[0] - seam_alb[2]):.1f}")
# NOT a neutral gray: reject the cool-grey-dust look (R within ~15% of B).
check("terminator is NOT neutral gray (R > 1.3*B)",
      seam_alb[0] > 1.3 * seam_alb[2],
      f"albedo={seam_alb.round(1)}  R/B={seam_alb[0] / max(seam_alb[2], 1e-6):.2f}")

# --- FIRE HEMISPHERE: lava / volcanic, strongly glowing ---------------------
fire_alb = rgb_mean(albedo, fire)
check("fire albedo is lava orange-red (R>G>B, R>150)",
      fire_alb[0] > fire_alb[1] > fire_alb[2] and fire_alb[0] > 150,
      f"albedo={fire_alb.round(1)}")
fire_em = rgb_mean(emission, fire)
check("dayside is a STRONGLY GLOWING emission (median emax > 150)",
      fire_emax > 150,
      f"median emax={fire_emax:.1f}")
check("dayside emission is warm (R dominant, R>B)",
      fire_em[0] > fire_em[2],
      f"emission={fire_em.round(1)}")
check("dayside glows hotter than the terminator AND the ice",
      fire_emax > seam_emax and fire_emax > ice_emax,
      f"fire={fire_emax:.1f} seam={seam_emax:.1f} ice={ice_emax:.1f}")

# --- ICE HEMISPHERE: PALE ICE, not a Fulgora-electric vault -----------------
ice_alb = rgb_mean(albedo, ice)
# PALE: bright frost, NOT a near-black base. Darkness on the ice limb is supplied
# by the light falloff in the bake / orbit, not by a black albedo.
check("ice albedo is PALE frost, not near-black (mean brightness > 140)",
      ice_bright > 140,
      f"ice brightness={ice_bright:.1f}")
# COOL, but NOT the saturated electric-blue-on-black that reads as lightning: the
# channels are close (pale cyan-white), blue leads but only modestly.
check("ice albedo is cool pale cyan-white (B>R and G>R)",
      ice_alb[2] > ice_alb[0] and ice_alb[1] > ice_alb[0],
      f"albedo={ice_alb.round(1)}")
check("ice is NOT electric-blue-on-black (B < 1.7*R -- pale, not saturated)",
      ice_alb[2] < 1.7 * ice_alb[0],
      f"albedo={ice_alb.round(1)}  B/R={ice_alb[2] / max(ice_alb[0], 1e-6):.2f}")
# A faint icy-blue shimmer is still present, kept DIM so the frozen hemisphere
# stays dark overall and well below the fiery glow.
check("ice shimmer is faint but present (3 < median emax < 80)",
      3 < ice_emax < 80,
      f"ice emax={ice_emax:.1f}")
ice_em = rgb_mean(emission, ice)
check("ice shimmer is icy-blue (B dominant, B>R)",
      ice_em[2] > ice_em[0],
      f"emission={ice_em.round(1)}")

# --- THE THREE-PART PLANET, SEEN FROM ORBIT (ci-4qyj) -----------------------
# The regions are the ones terrain.lua partitions the ground into, so these are
# assertions about the planet, not about the art's private idea of it.
regions = ["lava_ocean", "hot_belt", "habitable", "cold_belt", "ice_ocean"]
reg = {k: masks[k].astype(bool) for k in regions}
share = {k: float(reg[k].mean()) for k in regions}

check("all five terrain regions are visible on the globe",
      all(share[k] > 0.02 for k in regions),
      "  ".join(f"{k}={share[k]:.3f}" for k in regions))

# Ordered sunward -> nightward across the disc: lava ocean on one limb, ice ocean
# on the other, habitable dead centre. (sol is the insolation axis: +1 substellar.)
mean_sol = [float(masks["sol"][reg[k]].mean()) for k in regions]
check("regions run lava ocean -> hot belt -> habitable -> cold belt -> ice ocean",
      all(a > b for a, b in zip(mean_sol, mean_sol[1:])),
      "  ".join(f"{k}={s:+.2f}" for k, s in zip(regions, mean_sol)))

# BROAD oceans, not thin rims at the limb -- the ci-wly headline. Each ocean is a
# ~26% slab of the ribbon axis; projected onto the equirect sphere that is a
# double-digit share of the surface, and the two are symmetric by construction.
check("both oceans are BROAD sheets, not limb rims (each > 15% of the surface)",
      share["lava_ocean"] > 0.15 and share["ice_ocean"] > 0.15,
      f"lava={share['lava_ocean']:.3f} ice={share['ice_ocean']:.3f}")
check("the two oceans are symmetric (within 2 percentage points)",
      abs(share["lava_ocean"] - share["ice_ocean"]) < 0.02,
      f"lava={share['lava_ocean']:.3f} ice={share['ice_ocean']:.3f}")
check("a broad habitable middle survives between them (> 20% of the surface)",
      share["habitable"] > 0.20, f"habitable={share['habitable']:.3f}")

# Each region LOOKS like the ground it is.
lava_alb = rgb_mean(albedo, reg["lava_ocean"])
ice_alb = rgb_mean(albedo, reg["ice_ocean"])
hab_alb = rgb_mean(albedo, reg["habitable"])
check("the lava ocean is a molten orange-red sheet (R>G>B, R>200)",
      lava_alb[0] > lava_alb[1] > lava_alb[2] and lava_alb[0] > 200,
      f"albedo={lava_alb.round(1)}")
check("the ice ocean is pale cyan-white (B>G>R, brightness > 150)",
      ice_alb[2] > ice_alb[1] > ice_alb[0] and ice_alb.mean() > 150,
      f"albedo={ice_alb.round(1)}")
# Dark warm rock: far dimmer than the pale ice sheet, and nothing like the molten
# sheet's red. (Compared per-channel where each ocean actually lives -- the lava
# ocean's mean over RGB is dragged down by its near-zero blue.)
check("the habitable middle is DARK WARM rock between two bright oceans",
      hab_alb[0] > hab_alb[1] > hab_alb[2]
      and hab_alb.mean() < 0.5 * ice_alb.mean()
      and hab_alb[0] < 0.5 * lava_alb[0],
      f"habitable={hab_alb.round(1)} lavaR={lava_alb[0]:.1f} ice={ice_alb.mean():.1f}")

# --- THE GLOW IS THE LETHAL GROUND ------------------------------------------
# A player reads danger off the globe: the radiant part is the molten ocean and
# its belt. The band we build on must be utterly dark in the emission map, so the
# terminator comes from the LIGHT and never from a self-lit stripe.
check("the habitable middle emits NOTHING (max emission == 0)",
      float(emax[reg["habitable"]].max()) == 0.0,
      f"max emax over habitable={float(emax[reg['habitable']].max()):.1f}")
burning = masks["heat"] >= gpm.TERRAIN.hot_dmg
freezing = masks["heat"] <= gpm.TERRAIN.cold_dmg
check("NOTHING on safe ground emits any light at all",
      bool(((emax > 0) & ~(burning | freezing)).sum() == 0),
      f"{int(((emax > 0) & ~(burning | freezing)).sum())} emitting pixels on safe ground")
warm_lit = (emax > 40) & (emission[..., 0] > emission[..., 2])
check("every strongly-radiant WARM pixel is heat-lethal ground",
      bool((warm_lit & ~burning).sum() == 0),
      f"{int((warm_lit & ~burning).sum())} warm-radiant pixels outside the heat belt")
cool_lit = (emax > 0) & (emission[..., 2] > emission[..., 0])
check("every icy-blue shimmer pixel is cold-lethal ground",
      bool((cool_lit & ~freezing).sum() == 0),
      f"{int((cool_lit & ~freezing).sum())} shimmer pixels outside the cold belt")
check("the lava ocean is the brightest thing on the planet",
      float(np.median(emax[reg["lava_ocean"]])) > float(np.median(emax[reg["hot_belt"]])) > 0,
      f"ocean={np.median(emax[reg['lava_ocean']]):.1f} belt={np.median(emax[reg['hot_belt']]):.1f}")

# --- PAINTED WITH THE GROUND ------------------------------------------------
# The albedo must be terrain.lua's map colour for that spot times a GREYSCALE
# relief shade -- i.e. the art contributes brightness, never hue. Checked across
# the habitable middle, where no vein/frost overlay is applied, so any hue of the
# art's own would show up immediately. (unit-tests/test_terrain_ramp_lockstep.py
# proves the colours themselves are terrain.lua's.)
ground = gpm.TERRAIN.color_at_heat(masks["heat"]) * 255.0
sel = reg["habitable"]
ratio = albedo[sel] / np.maximum(ground[sel], 1e-6)          # (n,3) per-channel scale
spread = np.abs(ratio - ratio.mean(axis=-1, keepdims=True)).max(axis=-1)
check("the habitable band is the TERRAIN colour under a greyscale shade "
      "(no hue of the art's own)",
      float(spread.max()) < 1e-4,
      f"max per-channel hue drift={float(spread.max()):.2e}")
check("that shade only darkens/brightens within the documented range",
      0.5 < float(ratio.mean(axis=-1).min()) and float(ratio.mean(axis=-1).max()) < 1.2,
      f"shade range=[{ratio.mean(axis=-1).min():.2f}, {ratio.mean(axis=-1).max():.2f}]")

# --- Determinism ------------------------------------------------------------
again = gpm.generate_maps(W=256, H=128, seed=gpm.SEED)["cindra.png"][0]
check("deterministic: same seed -> identical albedo",
      np.array_equal(again, layers["cindra.png"][0]))

print(f"\n{passed} passed, {failed} failed")
sys.exit(0 if failed == 0 else 1)
