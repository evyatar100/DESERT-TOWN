import build_catalog as b

chars = b.load_characters()
places = b.load_placements()
world = b.real_placements(places)
placed_ids = {p.get("character_id") for p in world}
demo_ids = {p.get("character_id") for p in places if b.is_char_demo(p)}
unplaced = [c for c in chars if c["id"] not in placed_ids]
print("TOTAL", len(chars))
print("PLACED", sum(1 for c in chars if c["id"] in placed_ids))
print("UNPLACED", len(unplaced))
print("DEMO_ONLY", sum(1 for c in unplaced if c["id"] in demo_ids))
print("NOWHERE", sum(1 for c in unplaced if c["id"] not in demo_ids))
print("---")
for c in unplaced:
    where = "char-demo only" if c["id"] in demo_ids else "nowhere"
    name = c["name_he"] or c["name_en"]
    print(
        f"{c['id']}\t{c['kind']}\t{where}\t{c['camp'] or '-'}\t{name}\t{c['donor']}\tquest={c['quest_usable']}"
    )
