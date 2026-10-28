"""Build the TG37 world-map regen references at 4x the in-game slide (2048x1536), same geometry as render_world_map_slide.py.

Writes reference_clean.png, reference_labeled.png and layout_final_px.json next to this file. Read-only on maps/.
"""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
MAPS = REPO / "maps"
FONT = REPO / "game-files" / "Fonts" / "power clear bold.ttf"
K = 4  # reference px per final slide px
SCREEN = (512, 384)
AMBER, FRAME, FRAME_HI = (192, 128, 48, 255), (92, 48, 16, 255), (232, 184, 96, 255)
WINDOW = (18, 40, SCREEN[0] - 18, SCREEN[1] - 42)  # map window in final px, from the render script

# Legend numbers: top-to-bottom, then left-to-right (same order as brief.md).
ORDER = [
    "deep-playa-9", "deep-playa-8", "deep-playa-7", "deep-playa-4", "deep-playa-5", "deep-playa-6",
    "deep-playa-1b", "deep-playa-1a", "deep-playa-2", "deep-playa-3", "Squere-road-temple", "playa",
    "kim-area", "Piramid", "flamingods-out", "spacesheep-camp-b", "mom-dad", "ice-out", "Old-City",
    "Freecamp", "kusomo2", "demo-camp4", "PARTY", "cats", "Echer", "glass-a",
]


def placed() -> list[dict]:
    layout = json.loads((MAPS / "world_layout.json").read_text(encoding="utf-8"))["maps"]
    out = []
    for mid in ORDER:
        meta = json.loads((MAPS / mid / "meta.json").read_text(encoding="utf-8"))
        assert meta.get("is_outside") and not meta.get("deprecated"), mid
        e = layout[mid]
        out.append({"id": mid, "x": e["x"], "y": e["y"], "w": e["tiles_w"], "h": e["tiles_h"], "map_id": meta["map_id"]})
    return out


def composite(mid: str) -> Image.Image:
    img = Image.open(MAPS / mid / "base.png").convert("RGBA")
    for name in ("layer3.png", "layer3b.png"):
        p = MAPS / mid / name
        if p.exists():
            lay = Image.open(p).convert("RGBA")
            if lay.size != img.size:
                lay = lay.resize(img.size, Image.Resampling.NEAREST)
            img.alpha_composite(lay)
    return img


def geometry(items: list[dict]) -> tuple[float, float, float, int, int]:
    min_x = min(i["x"] for i in items)
    min_y = min(i["y"] for i in items)
    ww = max(i["x"] + i["w"] for i in items) - min_x
    wh = max(i["y"] + i["h"] for i in items) - min_y
    left, top, right, bottom = WINDOW
    scale = min((right - left) / ww, (bottom - top) / wh)
    ox = left + ((right - left) - ww * scale) / 2
    oy = top + ((bottom - top) - wh * scale) / 2
    return scale, ox, oy, min_x, min_y


def main() -> None:
    items = placed()
    scale, ox, oy, min_x, min_y = geometry(items)
    big = Image.new("RGBA", (SCREEN[0] * K, SCREEN[1] * K), AMBER)
    d = ImageDraw.Draw(big)
    d.rectangle((6 * K, 6 * K, (SCREEN[0] - 7) * K, (SCREEN[1] - 7) * K), outline=FRAME, width=4 * K)
    d.rectangle((12 * K, 12 * K, (SCREEN[0] - 13) * K, (SCREEN[1] - 13) * K), outline=FRAME_HI, width=2 * K)
    rows = []
    for n, it in enumerate(items, 1):
        fx, fy = ox + (it["x"] - min_x) * scale, oy + (it["y"] - min_y) * scale
        fw, fh = it["w"] * scale, it["h"] * scale
        box = (round(fx * K), round(fy * K), round((fx + fw) * K), round((fy + fh) * K))
        art = composite(it["id"]).resize((box[2] - box[0], box[3] - box[1]), Image.Resampling.LANCZOS)
        big.alpha_composite(art, box[:2])
        rows.append({"n": n, "id": it["id"], "map_id": it["map_id"], "tiles": [it["x"], it["y"], it["w"], it["h"]],
                     "final_px": [round(fx, 1), round(fy, 1), round(fw, 1), round(fh, 1)],
                     "final_center": [round(fx + fw / 2), round(fy + fh / 2)], "ref_box": list(box)})
    big.save(HERE / "reference_clean.png")

    lab = big.copy()
    d = ImageDraw.Draw(lab)
    f_num = ImageFont.truetype(str(FONT), 34)
    f_id = ImageFont.truetype(str(FONT), 20)
    f_band = ImageFont.truetype(str(FONT), 28)
    for band in ((14 * K, 14 * K, (SCREEN[0] - 14) * K, WINDOW[1] * K - 2), (14 * K, WINDOW[3] * K + 2, (SCREEN[0] - 14) * K, (SCREEN[1] - 14) * K)):
        for x in range(band[0], band[2], 24):
            d.line((x, band[1], x + (band[3] - band[1]), band[3]), fill=(150, 95, 30, 255), width=2)
        d.text(((band[0] + band[2]) // 2, (band[1] + band[3]) // 2), "TEXT BAND - drawn by code, keep plain, no art",
               font=f_band, fill=(40, 20, 8, 255), anchor="mm")
    d.rectangle(tuple(v * K for v in WINDOW), outline=(255, 255, 255, 255), width=3)
    for r in rows:
        b = r["ref_box"]
        d.rectangle(b, outline=(20, 10, 10, 255), width=6)
        d.rectangle(b, outline=(255, 40, 200, 255), width=3)
        cx, cy = r["final_center"][0] * K, r["final_center"][1] * K
        d.ellipse((cx - 26, cy - 26, cx + 26, cy + 26), fill=(255, 255, 255, 235), outline=(20, 10, 10, 255), width=4)
        d.text((cx, cy), str(r["n"]), font=f_num, fill=(200, 0, 120, 255), anchor="mm")
        d.text((b[0] + 8, b[1] + 6), r["id"], font=f_id, fill=(255, 255, 255, 255), anchor="la",
               stroke_width=3, stroke_fill=(20, 10, 10, 255))
    lab.save(HERE / "reference_labeled.png")
    meta = {"scale_final_px_per_tile": round(scale, 4), "origin_final_px": [round(ox, 2), round(oy, 2)],
            "world_min_tile": [min_x, min_y], "map_window_final_px": WINDOW, "ref_px_per_final_px": K, "maps": rows}
    (HERE / "layout_final_px.json").write_text(json.dumps(meta, indent=1), encoding="utf-8")
    print("scale", scale, "origin", ox, oy)


if __name__ == "__main__":
    main()
