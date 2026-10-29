"""TG57 Batch 2: boot art. Writes Titles/splash1, title, start and UI/Load/bg, panels in place.

Batch 5: title = generated illustration + official logo (splash keeps the code wordmark).
Latin text only (Handjet); the one Hebrew line uses the arcade slide helper. Re-runnable.
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
GF = ROOT / "game-files"
sys.path.insert(0, str(GF / "Plugins" / "DesertTownArcade"))
from slide_text import draw_text, font  # noqa: E402

ART = ROOT / "assets-factory" / "desert_screens" / "art"
TITLE_ART = ART / "title_call02_g2_master_2048x1536.png"
LOGO_ART = ART / "desertown-logo-transparent_1370x483.png"
LOGO_WIDTH = 390
LOGO_TOP = 44
SIZE = (512, 384)
INK = (42, 22, 8, 255)
FRAME_DARK = (92, 48, 16, 255)
AMBER = (192, 128, 48, 255)
GOLD = (232, 184, 96, 255)
SAND = (241, 203, 138, 255)
CREAM = (255, 248, 236, 255)
RED = (204, 44, 47, 255)
DEEP_RED = (158, 42, 52, 255)
START_TEXT = "לחצו על הכפתור הצהוב"
CREDITS = ["Built with Pokémon Essentials v21.1", "Engine: mkxp-z by Roza, based on mkxp by Ancurio et al."]


def frame(draw, inset=6):
    w, h = SIZE
    draw.rectangle((inset, inset, w - inset - 1, h - inset - 1), outline=FRAME_DARK, width=4)
    draw.rectangle((inset + 6, inset + 6, w - inset - 7, h - inset - 7), outline=GOLD, width=2)


def draw_logo(img, cx, cy, px):
    """Desert Town wordmark: cream letters, ink outline, tent-stripe ribbon below."""
    d = ImageDraw.Draw(img)
    face = font("handjet.ttf", px)
    text = "DESERT TOWN"
    d.text((cx, cy), text, font=face, fill=CREAM, anchor="mm", stroke_width=max(2, px // 18), stroke_fill=INK)
    left, top, right, bottom = d.textbbox((cx, cy), text, font=face, anchor="mm")
    stripe = max(6, px // 9)
    y0, y1 = bottom + px // 8, bottom + px // 8 + max(6, px // 9)
    for i, x in enumerate(range(left, right, stripe)):
        d.rectangle((x, y0, min(x + stripe - 1, right), y1), fill=RED if i % 2 == 0 else CREAM)
    d.rectangle((left, y0 - 2, right, y1 + 2), outline=INK, width=2)


def splash1():
    img = Image.new("RGBA", SIZE, INK)
    d = ImageDraw.Draw(img)
    frame(d)
    draw_logo(img, SIZE[0] // 2, 150, 84)
    face = font("handjet.ttf", 20)
    for i, line in enumerate(CREDITS):
        d.text((SIZE[0] // 2, 268 + i * 26), line, font=face, fill=SAND, anchor="mm")
    return img


def title():
    """Generated illustration (no text) with the official logo composited in the calm zone."""
    img = Image.open(TITLE_ART).convert("RGBA").resize(SIZE, Image.LANCZOS)
    logo = Image.open(LOGO_ART).convert("RGBA")
    lw = LOGO_WIDTH
    logo = logo.resize((lw, round(logo.height * lw / logo.width)), Image.LANCZOS)
    pos = ((SIZE[0] - lw) // 2, LOGO_TOP)
    shadow = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    mask = logo.getchannel("A").point(lambda a: a * 0.55)
    shadow.paste((26, 12, 4, 255), (pos[0] + 2, pos[1] + 3), mask)
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(2)))
    img.alpha_composite(logo, pos)
    return img


def start():
    img = Image.new("RGBA", (SIZE[0], 24), (0, 0, 0, 0))
    ImageDraw.Draw(img).rounded_rectangle((176, 1, 336, 22), radius=8, fill=(54, 28, 8, 210))
    draw_text(ImageDraw.Draw(img), START_TEXT, (SIZE[0] // 2, 12), font("hebrew.ttf", 16), CREAM, True, "mm", shadow=INK)
    return img


def load_bg():
    img = Image.new("RGBA", SIZE, AMBER)
    px = img.load()
    for y in range(SIZE[1]):
        t = y / SIZE[1]
        row = tuple(int(a + (b - a) * t) for a, b in zip((214, 150, 64), (176, 112, 36)))
        for x in range(SIZE[0]):
            px[x, y] = row + (255,)
    d = ImageDraw.Draw(img)
    d.ellipse((318, 22, 438, 142), fill=GOLD)
    for k, (base, amp, col) in enumerate([(300, 14, (170, 108, 36)), (330, 12, (146, 90, 28)), (356, 9, (118, 70, 22))]):
        pts = [(x, base + amp * math.sin(x / (60 + 23 * k) + k * 1.7)) for x in range(0, SIZE[0] + 8, 8)]
        d.polygon(pts + [(SIZE[0], SIZE[1]), (0, SIZE[1])], fill=col + (255,))
    frame(d, inset=0)
    return img


def panels():
    """Four 408-wide states: Continue off/on (222 tall), other off/on (46 tall)."""
    sheet = Image.new("RGBA", (408, 536), (0, 0, 0, 0))
    d = ImageDraw.Draw(sheet)
    for i, (y0, h, sel) in enumerate([(0, 222, False), (222, 222, True), (444, 46, False), (490, 46, True)]):
        border = GOLD if sel else (150, 96, 32, 255)
        fill = (96, 52, 18, 255) if sel else (70, 38, 12, 255)
        head = 44 if h > 100 else h
        d.rounded_rectangle((0, y0, 407, y0 + h - 1), radius=8, fill=border)
        d.rounded_rectangle((3, y0 + 3, 404, y0 + h - 4), radius=6, fill=fill)
        if h > 100:
            d.rectangle((3, y0 + 3, 404, y0 + head), fill=(54, 28, 8, 255))
            d.rectangle((3, y0 + head, 404, y0 + head + 2), fill=RED if sel else DEEP_RED)
        else:
            d.rectangle((3, y0 + h - 8, 404, y0 + h - 4), fill=RED if sel else DEEP_RED)
    return sheet


TARGETS = {
    "Graphics/Titles/splash1.png": splash1,
    "Graphics/Titles/title.png": title,
    "Graphics/Titles/start.png": start,
    "Graphics/UI/Load/bg.png": load_bg,
    "Graphics/UI/Load/panels.png": panels,
}


def main():
    for rel, make in TARGETS.items():
        out = make()
        out.save(GF / rel)
        print("wrote", rel, out.size)


if __name__ == "__main__":
    main()
