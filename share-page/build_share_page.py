"""Build the shareable Desert Town page: every character plus a world map of where to meet them.

python share-page/build_share_page.py                  real build, fails on missing area text
python share-page/build_share_page.py --dump-area-brief PATH   writer brief + area pictures, no page
python share-page/build_share_page.py --placeholder-text       dev check only, never shippable
"""
from __future__ import annotations

import argparse
import base64
import collections
import glob
import html
import json
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import share_areas  # noqa: E402
import share_pictures as pics  # noqa: E402

FAIL_MB, TARGET_MB = 12.0, 9.0
UI_KEYS = ("map_intro", "where_to_meet", "not_on_map")
JUNK_CAMPS = {"dfdf", "adad", "qa camp"}
CAMP_ALIAS = {
    "happy hour": "Happy Hour", "flow&glow": "Flow&Glow", "הארט -ביט": "הארט-ביט",
    "sakit": "שקית הקסם", "sakit hakesem": "שקית הקסם", "spacesheep": "Spacesheep",
    "פריקמפ": "פרי קאמפ",  # founder spelling: קאמפ everywhere
}


def field(t: str, name: str) -> str:
    m = re.search(r"\*\*%s:\*\*\s*```\s*\n(.*?)\n```" % re.escape(name), t, re.S)
    return m.group(1).strip() if m else ""


def title(t: str) -> str:
    m = re.search(r"^# `\s*(.*?)\s*`", t, re.M)
    return m.group(1).strip() if m else ""


def load_characters(root: Path) -> list[dict]:
    """Catalog characters (same filters as the old scratchpad script); 'cid' stays in memory only."""
    chars: dict[str, dict] = {}
    for meta in sorted(glob.glob(os.path.join(root, "desert-town-chars*", "**", "metadata.md"), recursive=True)):
        folder = os.path.dirname(meta)
        sheet = os.path.join(folder, "sheet.png")
        if not os.path.exists(sheet):
            continue
        cid = os.path.basename(folder).rsplit("-", 1)[-1]
        if cid in chars and "staging" not in meta:
            continue
        t = open(meta, encoding="utf-8").read()
        he = field(t, "Name (Hebrew)") or title(t)
        en = field(t, "Name (English)")
        camp_raw = field(t, "Camp").strip()
        if camp_raw.lower() in JUNK_CAMPS or "qa_field" in folder.lower():
            continue
        desc = field(t, "Description")
        if desc.lower().startswith("a visitor to the desert town stand"):
            desc = ""
        chars[cid] = {
            "cid": cid, "kind": "npc" if "**Type:** NPC" in t else "player", "he": he,
            "en": en if en.lower() != he.lower() else "",
            "camp": CAMP_ALIAS.get(camp_raw.lower(), CAMP_ALIAS.get(camp_raw, camp_raw)),
            "line": field(t, "Line"), "desc": desc, "abilities": field(t, "Abilities"),
            "img": base64.b64encode(open(sheet, "rb").read()).decode(),
        }
    return sorted(chars.values(), key=lambda c: (c["camp"] == "", c["he"]))


class Pictures:
    """One composite per area (merged areas as a mosaic) plus the 6 px/tile world tiles."""

    def __init__(self, maps_dir: Path, game: share_areas.GameData):
        self.maps_dir, self.game = maps_dir, game
        self.world_tiles: list = []
        self._cache: dict[str, object] = {}

    def single(self, folder: str, mid: int):
        d = self.maps_dir / folder
        img = pics.composite(d)
        if img is None and d.is_dir():  # art folder without base.png: draw it from the game's own tiles
            img = pics.render_tiles(*self.game.tiles(mid))
        return img

    def area(self, a: share_areas.Area):
        if a.key in self._cache:
            return self._cache[a.key]
        if not a.folders:
            img = None
        elif len(a.folders) == 1:
            img = self.single(a.folders[0], a.map_ids[0])
            if img is not None and a.is_outside:
                self.world_tiles.append((a.rects[0], pics.fit(img, max(img.size) // 4)))
            img = None if img is None else pics.fit(img)
        else:
            tiles = []
            for folder, mid, rect in zip(a.folders, a.map_ids, a.rects):
                full = self.single(folder, mid)
                if full is not None:
                    tiles.append((rect, pics.fit(full, max(full.size) // 4)))
            self.world_tiles.extend(tiles)
            img = pics.fit(pics.mosaic(tiles, pics.WORLD_PX_PER_TILE)) if tiles else None
        self._cache[a.key] = img
        return img


def load_text(path: Path, areas, placeholder: bool) -> tuple[dict, dict]:
    raw = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}
    texts, ui = raw.get("areas", {}), raw.get("ui", {})
    if placeholder:
        texts = {a.key: {"name": "אזור %d" % (i + 1), "desc": "טקסט זמני לבדיקה בלבד, לא לפרסום."}
                 for i, a in enumerate(areas)}
        ui = {"map_intro": "[זמני] מפת העולם: לוחצים על אזור כדי לראות מי שם.",
              "where_to_meet": "[זמני] איפה פוגשים", "not_on_map": "[זמני] עוד לא על המפה"}
    missing = ["areas.%s.%s" % (a.key, f) for a in areas for f in ("name", "desc")
               if not str(texts.get(a.key, {}).get(f, "")).strip()]
    missing += ["ui.%s" % k for k in UI_KEYS if not str(ui.get(k, "")).strip()]
    if missing:
        raise SystemExit("missing text in %s:\n  %s" % (path, "\n  ".join(missing)))
    for a in areas:
        t = texts[a.key]
        if len(t["desc"]) > 140 or len(t["name"].split()) > 3:
            print("warning: %s text is over the spec limits (name <=3 words, desc <=140 chars)" % a.key)
    extra = set(texts) - {a.key for a in areas}
    if extra:
        print("warning: areas.he.json keys not used: %s" % sorted(extra))
    return texts, ui


def dump_brief(path: Path, areas, chars, pictures: Pictures) -> None:
    pic_dir = path.parent / "area_pictures"
    pic_dir.mkdir(parents=True, exist_ok=True)
    he = {c["cid"]: c["he"] for c in chars}
    by_key = {a.key: a for a in areas}
    lines = ["# Share page: area brief for areas.he.json (%d areas)" % len(areas), "",
             "Write `share-page/areas.he.json` as `{\"areas\": {<key>: {\"name\", \"desc\"}}, \"ui\": {%s}}`."
             % ", ".join('"%s"' % k for k in UI_KEYS),
             "Name: Hebrew, at most 3 words. Desc: 1-2 lines, at most 140 characters, game voice, no quest spoilers.", "",
             "UI strings (`ui`): `map_intro` (one line above the map), `where_to_meet` (label over a character's "
             "area chips), `not_on_map` (shown for a character who stands nowhere yet).",
             "Fixed labels already in the page: 'נכנסים מכאן', 'מי פה · N דמויות', 'אין פה אף אחד כרגע.', "
             "'→ חזרה אל <parent>', 'בתוך <parent>', 'המקומות', 'האנשים'.", ""]
    for a in areas:
        img = pictures.area(a)
        pic = "(no picture)"
        if img is not None:
            pic = str(pic_dir / (a.key + ".png"))
            img.save(pic)
        lines += ["## `%s`%s" % (a.key, "" if a.is_outside else "  (inside place)"),
                  "- folder: %s" % (", ".join(a.folders) or "(no maps/ folder)"),
                  "- map_id: %s" % ", ".join(map(str, a.map_ids)),
                  "- English name now: %s" % a.english,
                  "- is_outside: %s" % a.is_outside]
        if a.parent:
            lines.append("- inside: `%s` (%s)" % (a.parent, by_key[a.parent].english))
        if a.kids:
            lines.append("- inside places: %s" % ", ".join("`%s`" % k for k in a.kids))
        names = sorted(he[c] for c in a.people)
        lines += ["- people (%d): %s" % (len(names), ", ".join(names) or "nobody"), "- picture: %s" % pic, ""]
    path.write_text("\n".join(lines), encoding="utf-8", newline="\n")


def percent(v: float, total: float) -> float:
    return round(100.0 * v / total, 3)


def page_data(areas, chars, pictures: Pictures, texts: dict) -> tuple[dict, dict]:
    idx = {a.key: i for i, a in enumerate(areas)}
    cidx = {c["cid"]: i for i, c in enumerate(chars)}
    imgs = {a.key: pictures.area(a) for a in areas}
    world = pics.mosaic(pictures.world_tiles, pics.WORLD_PX_PER_TILE)
    wx, wy, ww, wh = pics.bounds([r for r, _ in pictures.world_tiles])
    out_areas = []
    for a in areas:
        img = imgs[a.key]
        if img is None and not a.people:
            raise SystemExit("area %s has no picture and nobody in it" % a.key)
        entry = {"n": texts[a.key]["name"], "d": texts[a.key]["desc"],
                 "img": base64.b64encode(pics.webp(img, pics.AREA_Q)).decode() if img is not None else "",
                 "th": base64.b64encode(pics.webp(pics.fit(img, pics.THUMB_PX), pics.THUMB_Q)).decode()
                 if img is not None else "",
                 "parent": idx[a.parent] if a.parent else -1, "kids": [idx[k] for k in a.kids],
                 "people": sorted(cidx[c] for c in a.people)}
        if a.is_outside:
            bx, by, bw, bh = pics.bounds(a.rects)
            entry["box"] = [percent(bx - wx, ww), percent(by - wy, wh), percent(bw, ww), percent(bh, wh)]
            entry["poly"] = " ".join("%s,%s" % (percent(x - bx, bw), percent(y - by, bh))
                                     for x, y in pics.union_outline(a.rects))
        out_areas.append(entry)
    out_chars = []
    for c in chars:
        at = [i for i, a in enumerate(areas) if c["cid"] in a.people]
        out_chars.append({k: v for k, v in c.items() if k != "cid"} | {"at": at})
    world_b64 = base64.b64encode(pics.webp(world, pics.WORLD_Q)).decode()
    return {"chars": out_chars, "areas": out_areas,
            "world": {"img": world_b64, "w": world.width, "h": world.height}}, {"world_kb": len(world_b64) / 1e3}


def main(argv=None) -> int:
    repo = HERE.parent
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--repo", type=Path, default=repo)
    ap.add_argument("--text", type=Path, default=HERE / "areas.he.json")
    ap.add_argument("--out", type=Path, default=HERE / "out" / "desert-town-characters.html")
    ap.add_argument("--dump-area-brief", type=Path, metavar="PATH")
    ap.add_argument("--placeholder-text", action="store_true",
                    help="dev only: fill obvious placeholder text, write under share-page/out/ only")
    args = ap.parse_args(argv)
    chars = load_characters(args.repo / "asset_generation" / "characters")
    game = share_areas.GameData(args.repo / "game-files")
    maps_dir = args.repo / "maps"
    pictures = Pictures(maps_dir, game)
    areas = share_areas.build_areas(game, maps_dir, {c["cid"] for c in chars},
                                    lambda a: pictures.area(a) is not None)
    if args.dump_area_brief:
        dump_brief(args.dump_area_brief, areas, chars, pictures)
        print("brief:", args.dump_area_brief)
        return 0
    out = args.out
    if args.placeholder_text:
        out = HERE / "out" / "PLACEHOLDER-not-for-sharing.html"
    texts, ui = load_text(args.text, areas, args.placeholder_text)
    data, sizes = page_data(areas, chars, pictures, texts)
    data["ui"] = {k: ui[k] for k in UI_KEYS}
    camps = collections.Counter(c["camp"] for c in chars if c["camp"])
    template = (HERE / "template.html").read_text(encoding="utf-8")
    page = (template.replace("__DATA__", json.dumps(data, ensure_ascii=False).replace("</", "<\\/"))
            .replace("__COUNT__", str(len(chars))).replace("__CAMPS__", str(len(camps)))
            .replace("__MAP_INTRO__", html.escape(ui["map_intro"])))
    leaked = [c["cid"] for c in chars if c["cid"] in page] + [w for w in ("dt_", "users-chars") if w in page]
    if leaked:
        raise SystemExit("internal ids would leak into the page: %s" % leaked[:5])
    mb = len(page.encode("utf-8")) / 1e6
    if mb > FAIL_MB:
        raise SystemExit("page is %.2f MB, over the %.0f MB limit" % (mb, FAIL_MB))
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(page, encoding="utf-8", newline="\n")
    report(areas, chars, mb, sizes, data, out)
    return 0


def report(areas, chars, mb, sizes, data, out) -> None:
    placed = set().union(*(a.people for a in areas))
    multi = sum(1 for c in data["chars"] if len(c["at"]) > 1)
    area_kb = sum(len(a["img"]) for a in data["areas"]) / 1e3
    thumb_kb = sum(len(a["th"]) for a in data["areas"]) / 1e3
    print("areas: %d outdoor, %d interiors" % (sum(a.is_outside for a in areas), sum(not a.is_outside for a in areas)))
    print("people: %d on the page, %d placed, %d unplaced, %d in more than one area"
          % (len(chars), len(placed), len(chars) - len(placed), multi))
    for a in areas:
        print("  %-20s %3d%s" % (a.key, len(a.people), "" if a.is_outside else "  (inside %s)" % a.parent))
    print("size: %.2f MB (target %.0f, limit %.0f); world %.0f KB, area pictures %.0f KB, thumbnails %.0f KB"
          % (mb, TARGET_MB, FAIL_MB, sizes["world_kb"], area_kb, thumb_kb))
    if mb > TARGET_MB:
        print("warning: over the %.0f MB target" % TARGET_MB)
    print("wrote", out)


if __name__ == "__main__":
    sys.exit(main())
