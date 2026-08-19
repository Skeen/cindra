#!/usr/bin/env python3
# Pixel test for the CREATED frozen layers (scripts/gen-frost-layer.py, ci-u92y).
#
# The arc furnace freezes for real on Cindra's nightside but its bespoke art ships
# no frozen layer, so one had to be authored. The generator is pure and
# deterministic, so what the player will SEE is testable off-game -- and the
# things that make a frost patch right or wrong are all measurable:
#
#   • IT SITS ON THE MACHINE. Zero frost outside the body silhouette: a patch with
#     stray alpha renders as ice floating in the air beside the furnace.
#   • THE MACHINE STILL READS AS ITSELF. The crust covers a good part of the body
#     but is nowhere near a solid repaint -- a frozen machine must still be
#     recognisable as an arc furnace, not an ice cube.
#   • IT READS AS ICE, NOT DIRT. Cool pale colour (blue >= green >= red, high
#     value, low saturation), in the same range as the vanilla frost sprites this
#     patch sits beside on the same base.
#   • IT LANDS ON UP-FACING SURFACES. Frost crusts the tops/ledges, not the
#     down-facing flanks -- which is what makes it read as settled rime rather
#     than a blue wash over the whole machine.
#   • THE SHIPPED FILE IS THE GENERATED ONE. Regenerating reproduces the committed
#     PNG byte-for-byte, so the art in the mod is the art this test measured.
#
# Run (numpy + pillow):
#   nix-shell -p "python3.withPackages(ps: with ps; [numpy pillow])" \
#     --run "python3 mods/cindra/unit-tests/test_frost_layer.py"

import importlib.util
import io
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
GEN = os.path.join(ROOT, "scripts", "gen-frost-layer.py")

spec = importlib.util.spec_from_file_location("gen_frost_layer", GEN)
gfl = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gfl)

passed = failed = 0


def check(name, cond, detail=""):
    global passed, failed
    if cond:
        passed += 1
        print("ok - " + name)
    else:
        failed += 1
        print("not ok - " + name + ("  [" + detail + "]" if detail else ""))


def hsv_of(rgb):
    """Value + saturation of a mean RGB triple (0..255)."""
    mx, mn = float(rgb.max()), float(rgb.min())
    return mx / 255.0, (0.0 if mx == 0 else (mx - mn) / mx)


def cool_and_pale(name, patch, accreted):
    """The colour invariants every Cindra frost asset shares."""
    mean_rgb = patch[..., :3][accreted].mean(axis=0)
    value, sat = hsv_of(mean_rgb)
    check(f"[{name}] frost is COOL (blue >= green >= red)",
          mean_rgb[2] >= mean_rgb[1] >= mean_rgb[0], f"rgb={mean_rgb.round(1)}")
    check(f"[{name}] frost is PALE (high value, low saturation)",
          value > 0.70 and sat < 0.30, f"value={value:.2f} sat={sat:.2f}")
    # Not a saturated electric blue (the Fulgora-lightning look the planet art
    # was already pulled back from): blue may lead, but only just.
    check(f"[{name}] frost is not saturated electric blue (B < 1.5*R)",
          mean_rgb[2] < 1.5 * mean_rgb[0], f"B/R={mean_rgb[2] / max(mean_rgb[0], 1e-6):.2f}")


for asset in [s for s in gfl.SPECS if s.get("generic")]:
    # --- THE GENERIC RIME DECAL (ci-de55) ------------------------------------
    # The script freeze covers buildings whose art is VANILLA (the sunward solar
    # bands are deep-copies of the base game's panel), so there is no body sprite
    # of ours to derive a patch from and nothing we may ship a derivative of. Those
    # wear this free-standing crust instead, scaled to their own footprint by
    # prototypes/frozen-twins.lua. It has no body to sit on, so the geometry
    # invariants above do not apply -- but it still has to read as ICE, still has
    # to let the building through, and must not overhang the footprint it is
    # scaled to (which would put frost on the ground beside the panel).
    name = asset["name"]
    shipped_path = os.path.join(ROOT, asset["out"])
    check(f"[{name}] the decal ships", os.path.exists(shipped_path), shipped_path)
    shipped = Image.open(shipped_path)
    check(f"[{name}] shipped as truecolour RGBA", shipped.mode == "RGBA", shipped.mode)
    patch = np.asarray(shipped.convert("RGBA"), np.uint8)
    alpha = patch[..., 3]
    accreted = alpha > 25

    size = gfl.SLAB_PX
    check(f"[{name}] canvas is the square the twin builder scales ({size}x{size})",
          patch.shape[:2] == (size, size), f"{patch.shape[1]}x{patch.shape[0]}")

    # Rounded footprint: the extreme corners stay clear, so a decal scaled onto a
    # 3x3 building never bleeds ice onto the tiles beside it.
    corner = max(int(alpha[0, 0]), int(alpha[0, -1]), int(alpha[-1, 0]), int(alpha[-1, -1]))
    check(f"[{name}] corners are clear (no ice off the building's footprint)",
          corner == 0, f"max corner alpha={corner}")

    cover = float(accreted.sum()) / float(alpha.size)
    check(f"[{name}] the crust covers a real part of the footprint (25% - 75%)",
          0.25 <= cover <= 0.75, f"cover={cover:.3f}")
    check(f"[{name}] the crust is never fully opaque (the building reads through)",
          int(alpha.max()) < 255, f"max alpha={int(alpha.max())}")
    thick = float((alpha > 200).sum()) / float(alpha.size)
    check(f"[{name}] not an ice cube: <25% is under near-opaque ice",
          thick < 0.25, f"thick={thick:.3f}")

    # Rime lies heaviest on the upper face and thins downward -- the same read as
    # snow on a roof, and what stops it looking like fog.
    top = float(alpha[: size // 3].mean())
    bottom = float(alpha[-size // 3:].mean())
    check(f"[{name}] rime lies heaviest up top and thins downward",
          top > 1.3 * bottom, f"top={top:.1f} bottom={bottom:.1f}")

    cool_and_pale(name, patch, accreted)

    regenerated = gfl.generic_rime()
    check(f"[{name}] shipped PNG is exactly what the generator produces",
          np.array_equal(regenerated, patch),
          "regenerate with ./scripts/render-frost-layer.sh")


for asset in [s for s in gfl.SPECS if not s.get("generic")]:
    name = asset["name"]
    sheet = Image.open(os.path.join(ROOT, asset["sheet"])).convert("RGBA")
    x, y, w, h = asset["frame"]
    body = np.asarray(sheet.crop((x, y, x + w, y + h)), np.uint8)
    shipped_path = os.path.join(ROOT, asset["out"])

    check(f"[{name}] the frozen layer ships", os.path.exists(shipped_path), shipped_path)
    shipped = Image.open(shipped_path)
    patch = np.asarray(shipped.convert("RGBA"), np.uint8)

    # --- Geometry: the patch registers on the body it is drawn over -----------
    # Factorio draws the frozen patch as its own sprite at the machine's scale and
    # shift; if its canvas is not the body frame's canvas the ice lands offset.
    check(f"[{name}] patch canvas matches the body frame ({w}x{h})",
          patch.shape[:2] == (h, w), f"{patch.shape[1]}x{patch.shape[0]}")
    # Factorio renders indexed/greyscale PNGs as a black box (the ci-8r6 bug).
    check(f"[{name}] shipped as truecolour RGBA", shipped.mode == "RGBA", shipped.mode)

    body_a = body[..., 3]
    frost_a = patch[..., 3]
    on_body = body_a > 10
    off_body = body_a == 0
    accreted = frost_a > 25

    # --- IT SITS ON THE MACHINE ----------------------------------------------
    check(f"[{name}] NO frost outside the body silhouette",
          int(frost_a[off_body].max()) == 0,
          f"max alpha off-body={int(frost_a[off_body].max())}")

    # --- THE MACHINE STILL READS AS ITSELF -----------------------------------
    # The range spans two very different shapes on purpose: the arc furnace is a
    # tall riveted vessel whose whole upper half catches rime, while the flare
    # storage kit (ci-de55) is a flat-topped box that sheets over on top and keeps
    # its down-facing sides bare -- correctly, since that is where rime does not
    # settle. Both are unmistakably iced; neither is repainted.
    cover = float((accreted & on_body).sum()) / float(on_body.sum())
    check(f"[{name}] frost covers a real part of the body (20% - 70%)",
          0.20 <= cover <= 0.70, f"cover={cover:.3f}")
    # Nowhere near a solid repaint: most of the body is not under thick ice, so
    # the silhouette, the rust and the machine's own colour still come through.
    thick = float((frost_a > 200).sum()) / float(on_body.sum())
    check(f"[{name}] not an ice cube: <20% of the body is under near-opaque ice",
          thick < 0.20, f"thick={thick:.3f}")
    check(f"[{name}] the crust is never fully opaque (body reads through)",
          int(frost_a.max()) < 255, f"max alpha={int(frost_a.max())}")

    # --- IT READS AS ICE, NOT DIRT -------------------------------------------
    cool_and_pale(name, patch, accreted)

    # --- IT LANDS ON UP-FACING SURFACES --------------------------------------
    # The model: an up-facing surface is brighter than what lies just below it.
    # Frost must clearly prefer those over the down-facing flanks, otherwise it is
    # a flat blue wash and the machine's form disappears under it.
    rgb = body[..., :3].astype(np.float32) / 255.0
    lum = gfl.luminance(rgb) * (body_a.astype(np.float32) / 255.0)
    slope = lum - gfl._shift_y(lum, -gfl.UPFACE_PROBE)
    up = on_body & (slope > 0.04)
    down = on_body & (slope < -0.04)
    up_cover = float((accreted & up).sum()) / max(int(up.sum()), 1)
    down_cover = float((accreted & down).sum()) / max(int(down.sum()), 1)
    check(f"[{name}] frost settles on up-facing surfaces, not down-facing flanks",
          up_cover > 2.0 * down_cover,
          f"up={up_cover:.3f} down={down_cover:.3f}")

    # --- THE SHIPPED FILE IS THE GENERATED ONE -------------------------------
    regenerated = gfl.frost_layer(body)
    check(f"[{name}] shipped PNG is exactly what the generator produces",
          np.array_equal(regenerated, patch),
          "regenerate with ./scripts/render-frost-layer.sh")
    buf = io.BytesIO()
    Image.fromarray(gfl.frost_layer(body), "RGBA").save(buf, format="PNG")
    with open(shipped_path, "rb") as fh:
        check(f"[{name}] deterministic: re-running writes byte-identical bytes",
              buf.getvalue() == fh.read())

print(f"\n{passed} passed, {failed} failed")
sys.exit(0 if failed == 0 else 1)
