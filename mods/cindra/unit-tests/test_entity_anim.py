#!/usr/bin/env python3
# Pixel test for the animated working lights on Cindra's flare-storage kit
# (scripts/gen-entity-anim.py, ci-z94).
#
# ci-pru shipped the capacitor, molten-salt battery and dissipator as SINGLE
# STATIC FRAMES. On a planet whose power game is "route the flare surplus", the
# thing the player actually does is look across a field of storage and read which
# units are taking the surge -- so a still building is a gameplay bug, not a
# cosmetic one. These sheets are what fixed it, and the generator is pure and
# deterministic, so what the player will SEE is measurable off-game:
#
#   • IT MOVES. Consecutive frames genuinely differ, and the sheet is not the
#     same picture sixteen times -- an "animation" nobody can see move is exactly
#     the bug being fixed.
#   • THE CYCLE CLOSES. For the looping states the last frame flows back into the
#     first with no jump bigger than an ordinary step, so a running machine does
#     not visibly hitch once per cycle. The capacitor's DISCHARGE is the one
#     deliberate exception: it strobes, so the test demands the strobe instead.
#   • NOTHING GLOWS OFF THE BUILDING. Zero emission outside the body silhouette:
#     stray alpha renders as light hanging in the air beside the machine.
#   • IT LANDS ON THE ROOF. The lit pixels sit on the top face, on the motif the
#     static art already draws, not down the walls.
#   • THE COLOUR SAYS WHAT IT STORES. The capacitor is violet (charge), the
#     battery and dissipator ember (heat) -- the Cindra family's own reading.
#   • THE SHIPPED FILE IS THE GENERATED ONE. Regenerating reproduces the
#     committed PNG byte-for-byte, so the art in the mod is the art measured here.
#
# Run (numpy + pillow):
#   nix-shell -p "python3.withPackages(ps: with ps; [numpy pillow])" \
#     --run "python3 mods/cindra/unit-tests/test_entity_anim.py"

import importlib.util
import io
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
GEN = os.path.join(ROOT, "scripts", "gen-entity-anim.py")

spec = importlib.util.spec_from_file_location("gen_entity_anim", GEN)
gea = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gea)

passed = failed = 0


def check(name, cond, detail=""):
    global passed, failed
    if cond:
        passed += 1
        print("ok - " + name)
    else:
        failed += 1
        print("not ok - " + name + ("  [" + detail + "]" if detail else ""))


def load(path):
    return np.asarray(Image.open(path).convert("RGBA"), np.uint8)


def frames_of(sheet):
    """Split a strip into its FRAMES cells, in play order."""
    px, per_row = gea.FRAME_PX, gea.LINE_LENGTH
    out = []
    for i in range(gea.FRAMES):
        x, y = (i % per_row) * px, (i // per_row) * px
        out.append(sheet[y:y + px, x:x + px])
    return out


# The capacitor dumping its charge is a STROBE by design (flash, ring, gone), so
# it is exempt from the seamless-loop rule and gets its own check instead.
STROBE = {("capacitor", "discharge")}


for s in gea.SPECS:
    building, state = s["building"], s["state"]
    tag = "%s/%s" % (building, state)
    path = gea.dest_of(s, ROOT)

    if not os.path.exists(path):
        check(tag + ": sheet ships", False, path + " missing -- run ./scripts/render-entity-anim.sh")
        continue

    sheet = load(path)
    px, per_row = gea.FRAME_PX, gea.LINE_LENGTH
    rows = -(-gea.FRAMES // per_row)
    check(tag + ": sheet is exactly the declared %dx%d grid" % (per_row, rows),
          sheet.shape[:2] == (rows * px, per_row * px),
          "got %dx%d" % (sheet.shape[1], sheet.shape[0]))

    cells = frames_of(sheet)
    alpha = np.stack([c[..., 3].astype(np.float32) / 255.0 for c in cells])

    # --- IT MOVES ----------------------------------------------------------
    steps = [float(np.abs(alpha[i + 1] - alpha[i]).mean()) for i in range(gea.FRAMES - 1)]
    check(tag + ": consecutive frames differ (it is not a still image)",
          min(steps) > 1e-4, "smallest step %.6f" % min(steps))
    lit = alpha.reshape(gea.FRAMES, -1).sum(axis=1)
    spread = (lit.max() - lit.min()) / max(lit.max(), 1e-6)
    check(tag + ": the cycle has visible dynamic range",
          spread > 0.05, "brightest-to-dimmest spread %.3f" % spread)

    # --- THE CYCLE CLOSES --------------------------------------------------
    seam = float(np.abs(alpha[0] - alpha[-1]).mean())
    if (building, state) in STROBE:
        # A dump: the flash is hottest on the first frame and spent by the last.
        # Measured on PEAK brightness, not the total -- the shock ring covers more
        # pixels as it expands, so the sum keeps climbing while the light fades.
        peak = alpha.reshape(gea.FRAMES, -1).max(axis=1)
        check(tag + ": strobes (hottest first frame, spent last)",
              peak[0] == peak.max() and peak[-1] < 0.3 * peak.max()
              and lit[-1] < 0.25 * lit.max(),
              "peak first %.3f max %.3f last %.3f" % (peak[0], peak.max(), peak[-1]))
    else:
        check(tag + ": loops seamlessly (no hitch at the wrap)",
              seam <= 1.6 * max(steps),
              "seam %.6f vs largest in-cycle step %.6f" % (seam, max(steps)))

    # --- NOTHING GLOWS OFF THE BUILDING ------------------------------------
    body = load(os.path.join(ROOT, "mods/cindra/graphics/entity",
                             building, building + ".png"))[..., 3]
    off_body = (alpha > 0) & (body[None, ...] == 0)
    check(tag + ": no emission outside the body silhouette",
          not off_body.any(), "%d stray lit pixels" % int(off_body.sum()))

    # --- IT LANDS ON THE ROOF ----------------------------------------------
    u, v, roof = gea.roof_space(px)
    total = alpha.sum()
    on_roof = (alpha * (roof > 0)[None, ...]).sum()
    check(tag + ": the light sits on the top face, not down the walls",
          on_roof >= 0.98 * total, "%.1f%% of the emission is on the roof" % (100.0 * on_roof / total))

    # --- THE COLOUR SAYS WHAT IT STORES ------------------------------------
    # Weight the hue by emission so unlit pixels (whose RGB is the ramp's floor)
    # do not vote. The capacitor stores CHARGE (violet: blue leads, green trails);
    # the battery and dissipator store HEAT (ember: red leads, blue trails).
    w = alpha[..., None]
    mean_rgb = (np.stack([c[..., :3].astype(np.float32) for c in cells]) * w).sum(axis=(0, 1, 2))
    mean_rgb /= max(float(w.sum()), 1e-6)
    r, g, b = (float(x) for x in mean_rgb)
    if building == "capacitor":
        check(tag + ": reads as stored CHARGE (violet)", b > r > g,
              "rgb %.0f/%.0f/%.0f" % (r, g, b))
    else:
        check(tag + ": reads as stored HEAT (ember)", r > g > b,
              "rgb %.0f/%.0f/%.0f" % (r, g, b))

    # --- THE SHIPPED FILE IS THE GENERATED ONE -----------------------------
    buf = io.BytesIO()
    gea.sheet(s, ROOT).save(buf, format="PNG")
    with open(path, "rb") as f:
        on_disk = f.read()
    check(tag + ": regenerating reproduces the committed PNG byte-for-byte",
          buf.getvalue() == on_disk,
          "%d generated vs %d committed bytes" % (len(buf.getvalue()), len(on_disk)))


# --- The kit reads as three DIFFERENT machines ------------------------------
# Same-coloured, same-shaped lights would defeat the point: the player has to be
# able to tell a working capacitor from a working battery across a field.
sig = {}
for s in gea.SPECS:
    path = gea.dest_of(s, ROOT)
    if os.path.exists(path):
        sig[(s["building"], s["state"])] = frames_of(load(path))[0][..., 3].astype(np.float32)
pairs = list(sig.items())
distinct = all(np.abs(a - b).mean() > 1.0
               for i, (_, a) in enumerate(pairs) for (_, b) in pairs[i + 1:])
check("every state has its own distinct light", distinct and len(pairs) == len(gea.SPECS),
      "%d sheets compared" % len(pairs))

print("\n%d passed, %d failed" % (passed, failed))
sys.exit(0 if failed == 0 else 1)
