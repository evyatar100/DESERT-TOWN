"""TG57 Batch 4: the circus fight art. Writes the circus battleback and recolours the battle, Party and Summary UI.

Recolours read the untouched stock copies in stock_battle/, so the script is re-runnable. Light fills stay light
(the stock dark text colours keep their contrast); blue/green/teal go amber; greys go warm; reds and oranges stay.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from boot import CREAM, DEEP_RED, FRAME_DARK, GF, GOLD, INK, RED, SAND  # noqa: E402

STOCK = Path(__file__).resolve().parent / "stock_battle"
DARK_BROWN = np.array([58, 30, 10], float)
PALE = np.array([253, 243, 222], float)
# Luminance 0..1 -> amber ramp used for the saturated blue/green/teal fills.
RAMP_L = [0.0, 0.35, 0.55, 1.0]
RAMP_C = [(92, 48, 16), (168, 106, 34), (214, 156, 72), (250, 226, 168)]


def ramp(lum):
    return np.stack([np.interp(lum, RAMP_L, [c[i] for c in RAMP_C]) for i in range(3)], axis=-1)


def recolour(img):
    """Map stock colours into the Desert Town palette; alpha is untouched."""
    a = np.asarray(img.convert("RGBA"), float)
    rgb, alpha = a[..., :3], a[..., 3:]
    mx, mn = rgb.max(-1), rgb.min(-1)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1), 0)
    lum = (0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]) / 255
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    # Warm family (red, orange, yellow): r is the strongest channel and b the weakest.
    warm = (r >= g) & (g >= b) & (sat > 0.25)
    bluish = (b > r + 6) & (sat > 0.08)
    grey = (sat <= 0.25) & ~bluish
    out = rgb.copy()
    out[grey] = (DARK_BROWN + (PALE - DARK_BROWN) * np.clip(lum[grey, None] * 1.0, 0, 1))
    cool = ~grey & ~warm
    out[cool] = ramp(lum[cool])
    return Image.fromarray(np.dstack([out.clip(0, 255), alpha]).astype(np.uint8), "RGBA")


def stripes_wedges(d, apex, y_end, x0, x1, n, cols):
    step = (x1 - x0) / n
    for i in range(n):
        xa, xb = x0 + i * step, x0 + (i + 1) * step
        d.polygon([apex, (xa, y_end), (xb, y_end)], fill=cols[i % 2])


def circus_bg():
    img = Image.new("RGBA", (512, 288), SAND)
    d = ImageDraw.Draw(img)
    # Canopy: red and cream wedges meeting at a pole above the screen.
    stripes_wedges(d, (256, -50), 150, -128, 640, 24, [RED, CREAM])
    shade = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shade)
    for y in range(150):
        sd.line((0, y, 512, y), fill=(58, 30, 10, int(110 * (1 - y / 150))))
    img.alpha_composite(shade)
    d = ImageDraw.Draw(img)
    # Scalloped valance, ring fence, then the sand floor.
    for x in range(0, 512, 32):
        d.pieslice((x, 128, x + 32, 176), 0, 180, fill=RED if (x // 32) % 2 == 0 else CREAM, outline=INK)
    d.rectangle((0, 150, 512, 168), fill=GOLD)
    d.rectangle((0, 168, 512, 174), fill=FRAME_DARK)
    for y in range(174, 288):
        t = (y - 174) / 114
        d.line((0, y, 512, y), fill=tuple(int(c0 + (c1 - c0) * t) for c0, c1 in zip((226, 180, 100), (192, 128, 48))) + (255,))
    for x in range(0, 512, 32):
        d.line((x, 168, x, 150), fill=INK, width=2)
    return img


def circus_base(size, box, rim):
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse(box, fill=FRAME_DARK)
    d.ellipse((box[0] + 3, box[1] + 3, box[2] - 3, box[3] - 5), fill=rim)
    d.ellipse((box[0] + 9, box[1] + 8, box[2] - 9, box[3] - 11), fill=SAND)
    d.ellipse((box[0] + 20, box[1] + 14, box[2] - 20, box[3] - 18), fill=(226, 180, 100, 255))
    return img


def circus_message():
    img = Image.new("RGBA", (512, 96), FRAME_DARK)
    d = ImageDraw.Draw(img)
    for i, x in enumerate(range(0, 512, 16)):
        d.rectangle((x, 0, x + 15, 7), fill=RED if i % 2 == 0 else CREAM)
    d.rectangle((0, 8, 512, 10), fill=INK)
    d.rectangle((0, 11, 512, 13), fill=GOLD)
    return img


# Rel path under game-files -> stock copy under stock_battle (None = drawn here).
RECOLOURS = {
    **{f"Graphics/UI/Battle/{n}.png": f"Battle__{n}.png" for n in (
        "overlay_message", "overlay_command", "overlay_fight", "cursor_command", "cursor_fight",
        "databox_normal", "databox_normal_foe", "databox_thin", "databox_thin_foe")},
    "Graphics/UI/Party/bg.png": "Party__bg.png",
    **{f"Graphics/UI/Summary/bg_{i}.png": f"Summary__bg_{i}.png" for i in range(1, 6)},
}
for _p in sorted(STOCK.glob("Party__panel_*.png")):
    RECOLOURS["Graphics/UI/Party/" + _p.name.split("__", 1)[1]] = _p.name

DRAWN = {
    "Graphics/Battlebacks/circus_bg.png": circus_bg,
    "Graphics/Battlebacks/circus_base0.png": lambda: circus_base((512, 64), (36, 14, 476, 64), RED),
    "Graphics/Battlebacks/circus_base1.png": lambda: circus_base((256, 128), (4, 36, 252, 96), DEEP_RED),
    "Graphics/Battlebacks/circus_message.png": circus_message,
}


def main():
    for rel, make in DRAWN.items():
        out = make()
        out.save(GF / rel)
        print("wrote", rel, out.size)
    for rel, stock in RECOLOURS.items():
        out = recolour(Image.open(STOCK / stock))
        out.save(GF / rel)
        print("recoloured", rel, out.size)


if __name__ == "__main__":
    main()
