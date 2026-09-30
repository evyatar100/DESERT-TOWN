import os
import sys
import json
from PIL import Image
import rubymarshal
from rubymarshal.reader import load
from rubymarshal.classes import Symbol

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

def test_items_txt():
    items_path = os.path.join("PBS", "items.txt")
    assert os.path.exists(items_path), "PBS/items.txt missing!"
    with open(items_path, "r", encoding="utf-8") as f:
        content = f.read()
    
    assert "[WHITEWATERBOTTLE]" in content, "WHITEWATERBOTTLE missing in items.txt"
    assert "[USBDISK]" in content, "USBDISK missing in items.txt"
    print("  [PASS] PBS/items.txt contains [WHITEWATERBOTTLE] and [USBDISK].")

def test_items_dat_and_keyitem_flags():
    dat_path = os.path.join("Data", "items.dat")
    assert os.path.exists(dat_path), "Data/items.dat missing!"
    with open(dat_path, "rb") as f:
        items = load(f)
    
    bottle = items.get(Symbol("WHITEWATERBOTTLE"))
    assert bottle is not None, "WHITEWATERBOTTLE missing from items.dat"
    assert bottle.attributes.get("@pocket") == 8, f"WHITEWATERBOTTLE pocket is {bottle.attributes.get('@pocket')}, expected 8"
    assert "KeyItem" in bottle.attributes.get("@flags", []), "WHITEWATERBOTTLE must have KeyItem flag"

    usb = items.get(Symbol("USBDISK"))
    assert usb is not None, "USBDISK missing from items.dat"
    assert usb.attributes.get("@pocket") == 8, f"USBDISK pocket is {usb.attributes.get('@pocket')}, expected 8"
    assert "KeyItem" in usb.attributes.get("@flags", []), "USBDISK must have KeyItem flag"
    print("  [PASS] Data/items.dat contains WHITEWATERBOTTLE and USBDISK with Pocket 8 and KeyItem flag.")

def test_item_icons():
    for name in ["WHITEWATERBOTTLE.png", "USBDISK.png"]:
        p = os.path.join("Graphics", "Items", name)
        assert os.path.exists(p), f"Icon {p} missing!"
        im = Image.open(p)
        assert im.size == (48, 48), f"Icon {name} size is {im.size}, expected (48, 48)"
        assert im.mode == "RGBA", f"Icon {name} mode is {im.mode}, expected RGBA"
        print(f"  [PASS] Graphics/Items/{name} is a valid 48x48 RGBA icon.")

def test_translations():
    trans_path = os.path.join("PBS", "translations.json")
    with open(trans_path, "r", encoding="utf-8") as f:
        data = json.load(f)
    tr = data.get("translations", {})
    
    assert "WHITEWATERBOTTLE" in tr
    assert tr["WHITEWATERBOTTLE"]["he"] == "בקבוק מים (לבן)"
    
    assert "USBDISK" in tr
    assert tr["USBDISK"]["he"] == "דיסק און קי"
    assert "למקרה הצורך" in tr["USBDISK_DESC"]["he"]
    print("  [PASS] PBS/translations.json contains correct Hebrew translations for bottle and disk on key.")

def test_cannot_be_thrown_or_tossed():
    plugin_path = os.path.join("Plugins", "BurningManBag", "burning_man_bag.rb")
    with open(plugin_path, "r", encoding="utf-8") as f:
        rb_code = f.read()

    assert "PokemonBagScreen" in rb_code, "PokemonBagScreen override missing"
    assert "!itm.is_important? && !itm.is_key_item?" in rb_code, "Toss condition must exclude key items without debug bypass"
    assert "That's too important to toss out!" in rb_code, "Toss guard message missing"
    print("  [PASS] PokemonBagScreen strictly forbids tossing Key Items (no debug bypass).")

def test_single_item_guarantee():
    plugin_path = os.path.join("Plugins", "BurningManBag", "burning_man_bag.rb")
    with open(plugin_path, "r", encoding="utf-8") as f:
        rb_code = f.read()

    assert "ensure_single_starter_items" in rb_code
    assert "while bag.quantity(item_id) > 1" in rb_code
    assert "bag.add(item_id) if bag.quantity(item_id) == 0" in rb_code
    print("  [PASS] Single instance guarantee & deduplication logic verified in BurningManBag.")

if __name__ == "__main__":
    print("--- Running Starter Items & Key Item Rules Test Suite ---")
    test_items_txt()
    test_items_dat_and_keyitem_flags()
    test_item_icons()
    test_translations()
    test_cannot_be_thrown_or_tossed()
    test_single_item_guarantee()
    print("--- All Starter Items Tests Passed Successfully! ---")
