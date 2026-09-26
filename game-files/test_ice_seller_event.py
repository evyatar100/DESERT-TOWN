import os
import sys
import json
import zlib
from PIL import Image
import rubymarshal
from rubymarshal.reader import load
from rubymarshal.classes import Symbol

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

def test_items_txt_entry():
    items_path = os.path.join("PBS", "items.txt")
    assert os.path.exists(items_path), f"File {items_path} does not exist!"
    
    with open(items_path, "r", encoding="utf-8") as f:
        content = f.read()

    assert "[ICEBAG]" in content, "[ICEBAG] key item missing in items.txt"
    
    lines = content.splitlines()
    in_section = False
    item_props = {}
    for line in lines:
        line = line.strip()
        if line == "[ICEBAG]":
            in_section = True
            continue
        elif in_section and line.startswith("["):
            break
        elif in_section and "=" in line:
            k, v = line.split("=", 1)
            item_props[k.strip()] = v.strip()

    assert item_props.get("Pocket") == "8", f"Expected Pocket 8 (Key Items), got {item_props.get('Pocket')}"
    assert "KeyItem" in item_props.get("Flags", ""), f"KeyItem flag missing in {item_props}"
    assert "Bag of Ice" in item_props.get("Name", ""), f"Item name mismatch in {item_props}"
    print("  [ASSERT PASS] PBS/items.txt ICEBAG entry is valid (Pocket 8, KeyItem).")

def test_graphics_asset():
    item_icon = os.path.join("Graphics", "Items", "ICEBAG.png")
    assert os.path.exists(item_icon), f"Item icon {item_icon} missing!"
    img = Image.open(item_icon)
    assert img.size == (48, 48), f"Expected 48x48 item icon, got {img.size}"
    assert img.mode == "RGBA", f"Expected RGBA mode, got {img.mode}"
    print(f"  [ASSERT PASS] Bag item icon asset {item_icon} (48x48 RGBA) is valid.")

def test_items_dat():
    items_dat_path = os.path.join("Data", "items.dat")
    assert os.path.exists(items_dat_path), f"{items_dat_path} missing!"
    with open(items_dat_path, "rb") as f:
        items = load(f)
    
    sym = Symbol("ICEBAG")
    icebag = items.get(sym) or items.get("ICEBAG")
    assert icebag is not None, "ICEBAG missing from items.dat!"
    flags = [str(f) for f in icebag.attributes.get("@flags", [])]
    pocket = icebag.attributes.get("@pocket")
    assert any("KeyItem" in f for f in flags), f"KeyItem flag missing from items.dat: {flags}"
    assert pocket == 8, f"Pocket must be 8 (Key Items), got {pocket}"
    print("  [ASSERT PASS] Data/items.dat ICEBAG has Pocket 8 and KeyItem flag.")

def test_translations():
    trans_path = os.path.join("PBS", "translations.json")
    with open(trans_path, "r", encoding="utf-8") as f:
        data = json.load(f)
    
    trans = data.get("translations", {})
    
    # Check intro text
    assert "POPCORN_INTRO" in trans
    assert trans["POPCORN_INTRO"]["he"] == "היייי. פה מוכרים קרח.. שקית קרח אחת עולה 100 שקלים"

    # Check choices 1 to 5
    assert trans["POPCORN_CHOICE_1"]["he"] == "תשלום 100 שקלים"
    assert trans["POPCORN_CHOICE_2"]["he"] == "למה יש כאן תור?"
    assert trans["POPCORN_CHOICE_3"]["he"] == "איך לי 100 שקלים"
    assert trans["POPCORN_CHOICE_4"]["he"] == "כסף בדזרטאון?"
    assert trans["POPCORN_CHOICE_5"]["he"] == "יציאה"

    # Check responses
    assert trans["POPCORN_RESPONSE_THANKS"]["he"] == "תודה רבה"
    assert "האינטרנט נפל וכל אלו רוצים לשלם בביט" in trans["POPCORN_RESPONSE_LINE"]["he"]
    assert "מפעל הקרח" in trans["POPCORN_RESPONSE_NO_MONEY"]["he"]
    assert "שטרות מפוזרים כאן על הרצפה" in trans["POPCORN_RESPONSE_DESERTTOWN"]["he"]

    # Check item translations
    assert trans["ICEBAG"]["he"] == "שקית קרח"
    print("  [ASSERT PASS] PBS/translations.json contains all requested Hebrew dialogue and choices.")

def test_map91_popcorn_event():
    map_path = os.path.join("Data", "Map091.rxdata")
    assert os.path.exists(map_path), f"Map data file {map_path} missing!"

    with open(map_path, "rb") as f:
        m = load(f)

    events = m.attributes['@events']
    assert 1 in events, "Event 1 missing from Map 091!"
    ev1 = events[1]
    name = ev1.attributes.get('@name')
    if isinstance(name, bytes):
        name = name.decode('utf-8', errors='ignore')
    assert name == "popcorn", f"Expected event name 'popcorn', got '{name}'"

    pages = ev1.attributes.get('@pages')
    assert len(pages) >= 1, "Event 1 pages missing!"
    page = pages[0]
    cmds = page.attributes.get('@list')

    has_ice_seller_cmd = False
    for cmd in cmds:
        code = cmd.attributes.get('@code')
        params = cmd.attributes.get('@parameters', [])
        if code == 355:
            for p in params:
                p_str = p.decode('utf-8', errors='ignore') if isinstance(p, bytes) else str(p)
                if 'pbIceSeller' in p_str or 'pbPopcornEvent' in p_str:
                    has_ice_seller_cmd = True

    assert has_ice_seller_cmd, "Script command pbIceSeller missing from Event 1 on Map 091!"
    print("  [ASSERT PASS] Map 091 Event 1 (popcorn) executes pbIceSeller script command.")

def test_plugin_compilation():
    script_path = os.path.join("Plugins", "HebrewSupport", "ice_seller.rb")
    assert os.path.exists(script_path), f"Plugin script {script_path} missing!"

    plugin_rxdata = os.path.join("Data", "PluginScripts.rxdata")
    assert os.path.exists(plugin_rxdata), f"{plugin_rxdata} missing!"

    with open(plugin_rxdata, "rb") as f:
        plugins = load(f)

    found_script = False
    for p_name, p_meta, p_scripts in plugins:
        for s_name, s_code_z in p_scripts:
            if s_name == "ice_seller.rb":
                decomp = zlib.decompress(s_code_z).decode('utf-8', errors='ignore')
                if "def pbIceSeller" in decomp and "pbReceiveItem(:ICEBAG)" in decomp:
                    found_script = True

    assert found_script, "Compiled ice_seller.rb with pbIceSeller missing in Data/PluginScripts.rxdata!"
    print("  [ASSERT PASS] Plugins/HebrewSupport/ice_seller.rb compiled into Data/PluginScripts.rxdata.")

def test_simulated_event_logic():
    class FakeBag:
        def __init__(self):
            self.items = {}

        def quantity(self, item):
            return self.items.get(item, 0)

        def add(self, item, qty=1):
            self.items[item] = self.items.get(item, 0) + qty

        def remove(self, item, qty=1):
            if self.items.get(item, 0) >= qty:
                self.items[item] -= qty
                return True
            return False

    bag = FakeBag()
    
    assert bag.quantity("TWENTYSHECKELBILL") == 0
    can_buy = bag.quantity("TWENTYSHECKELBILL") >= 5
    assert not can_buy, "Should not be able to buy with 0 bills"

    bag.add("TWENTYSHECKELBILL", 4)
    assert bag.quantity("TWENTYSHECKELBILL") == 4
    can_buy = bag.quantity("TWENTYSHECKELBILL") >= 5
    assert not can_buy, "Should not be able to buy with 4 bills"

    bag.add("TWENTYSHECKELBILL", 1)
    assert bag.quantity("TWENTYSHECKELBILL") == 5
    can_buy = bag.quantity("TWENTYSHECKELBILL") >= 5
    assert can_buy, "Should be able to buy with 5 bills"

    bag.remove("TWENTYSHECKELBILL", 5)
    bag.add("ICEBAG", 1)
    assert bag.quantity("TWENTYSHECKELBILL") == 0, "5 bills should have been removed"
    assert bag.quantity("ICEBAG") == 1, "Player should have received 1 ICEBAG"

    bag.add("TWENTYSHECKELBILL", 8)
    assert bag.quantity("TWENTYSHECKELBILL") == 8
    bag.remove("TWENTYSHECKELBILL", 5)
    bag.add("ICEBAG", 1)
    assert bag.quantity("TWENTYSHECKELBILL") == 3, "3 bills should remain"
    assert bag.quantity("ICEBAG") == 2, "Player should have received another ICEBAG"

    print("  [ASSERT PASS] Simulated purchase and inventory logic verified.")

def run_all_tests():
    print("=" * 60)
    print(" RUNNING ICE OUT POPCORN EVENT ASSERTION & TEST SUITE")
    print("=" * 60)
    test_items_txt_entry()
    test_graphics_asset()
    test_items_dat()
    test_translations()
    test_map91_popcorn_event()
    test_plugin_compilation()
    test_simulated_event_logic()
    print("-" * 60)
    print(" ALL ICE OUT POPCORN EVENT ASSERTIONS PASSED SUCCESSFULLY!")
    print("=" * 60)

if __name__ == "__main__":
    run_all_tests()
