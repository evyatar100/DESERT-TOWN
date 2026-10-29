"""TG57 Batch 3: the Desert Town card. Writes UI/Trainer Card card, card_f, bg, bg_f in place.

Four sand row bars sit where the stock bars were, so the text positions in 004_card.rb line up.
No Badges strip, no Pokedex bar, no Poke Ball. Latin text only (Handjet). Re-runnable.
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from boot import AMBER, CREAM, DEEP_RED, FRAME_DARK, GF, GOLD, INK, RED, SAND, draw_logo, font  # noqa: E402

SIZE = (512, 384)
BAR_X = (28, 308)
BAR_Y = (64, 112, 160, 208)
BAR_H = 30


def body(accent):
    img = Image.new("RGBA", SIZE, AMBER)
    px = img.load()
    for y in range(SIZE[1]):
        t = y / SIZE[1]
        row = tuple(int(a + (b - a) * t) for a, b in zip((214, 150, 64), (170, 106, 34)))
        for x in range(SIZE[0]):
            px[x, y] = row + (255,)
    d = ImageDraw.Draw(img)
    d.ellipse((330, 250, 450, 370), fill=GOLD)
    for k, (base, amp, col) in enumerate([(300, 10, (168, 106, 34)), (330, 9, (142, 88, 28)), (356, 7, (116, 70, 22))]):
        pts = [(x, base + amp * math.sin(x / (50 + 21 * k) + k * 1.9)) for x in range(0, SIZE[0] + 8, 8)]
        d.polygon(pts + [(SIZE[0], SIZE[1]), (0, SIZE[1])], fill=col + (255,))
    d.rounded_rectangle((3, 3, 508, 380), radius=14, outline=FRAME_DARK, width=5)
    d.rounded_rectangle((11, 11, 500, 372), radius=10, outline=accent, width=2)
    return img


def bars(img):
    d = ImageDraw.Draw(img)
    for y in BAR_Y:
        d.rounded_rectangle((BAR_X[0], y, BAR_X[1], y + BAR_H), radius=7, fill=SAND, outline=FRAME_DARK, width=2)
        d.rectangle((BAR_X[0] + 5, y + BAR_H - 5, BAR_X[1] - 5, y + BAR_H - 3), fill=GOLD)


def tent(img, accent):
    """A striped circus tent in the right panel, where the stock trainer picture was."""
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((326, 64, 474, 248), radius=10, fill=(70, 38, 12, 255), outline=GOLD, width=3)
    cx, base, top = 400, 214, 98
    d.polygon([(cx, top), (cx - 52, 156), (cx + 52, 156)], fill=CREAM, outline=INK)
    for i in range(-2, 3):
        x0 = cx + i * 21
        d.polygon([(cx, top), (x0 - 10, 156), (x0 + 10, 156)], fill=accent if i % 2 == 0 else CREAM)
    d.rectangle((cx - 52, 156, cx + 52, base), fill=CREAM, outline=INK)
    for i in range(-2, 3):
        d.rectangle((cx + i * 21 - 10, 156, cx + i * 21 + 10, base), fill=accent if i % 2 == 0 else CREAM)
    d.polygon([(cx - 12, base), (cx, 172), (cx + 12, base)], fill=INK)
    d.line((cx, top, cx, top - 16), fill=INK, width=3)
    d.polygon([(cx, top - 16), (cx + 16, top - 11), (cx, top - 6)], fill=GOLD, outline=INK)


def header(img):
    face = font("handjet.ttf", 34)
    d = ImageDraw.Draw(img)
    d.text((36, 36), "DESERT TOWN", font=face, fill=CREAM, anchor="lm", stroke_width=3, stroke_fill=INK)
    for i, x in enumerate(range(326, 474, 12)):
        d.rectangle((x, 30, min(x + 11, 473), 42), fill=RED if i % 2 == 0 else CREAM)
    d.rectangle((326, 29, 473, 43), outline=INK, width=2)


def card(accent):
    img = body(accent)
    header(img)
    bars(img)
    tent(img, accent)
    return img


def tile(color):
    return Image.new("RGB", (8, 8), color)


TARGETS = {
    "Graphics/UI/Trainer Card/card.png": lambda: card(RED),
    "Graphics/UI/Trainer Card/card_f.png": lambda: card(DEEP_RED),
    "Graphics/UI/Trainer Card/bg.png": lambda: tile((58, 30, 10)),
    "Graphics/UI/Trainer Card/bg_f.png": lambda: tile((58, 30, 10)),
}


def main():
    for rel, make in TARGETS.items():
        out = make()
        out.save(GF / rel)
        print("wrote", rel, out.size)


if __name__ == "__main__":
    main()
