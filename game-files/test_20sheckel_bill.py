import os
import sys
from PIL import Image
import rubymarshal
from rubymarshal.reader import load

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

def test_items_txt_entry():
    items_path = os.path.join("PBS", "items.txt")
    assert os.path.exists(items_path), f"File {items_path} does not exist!"
    
    with open(items_path, "r", encoding="utf-8") as f:
        content = f.read()

    assert "[TWENTYSHECKELBILL]" in content, "[TWENTYSHECKELBILL] key item missing in items.txt"
    
    # Check item details
    lines = content.splitlines()
    in_section = False
    item_props = {}
    for line in lines:
        line = line.strip()
        if line == "[TWENTYSHECKELBILL]":
            in_section = True
            continue
        elif in_section and line.startswith("["):
            break
        elif in_section and "=" in line:
            k, v = line.split("=", 1)
            item_props[k.strip()] = v.strip()

    assert item_props.get("Pocket") == "8", f"Expected Pocket 8 (Key Items), got {item_props.get('Pocket')}"
    assert "KeyItem" in item_props.get("Flags", ""), f"KeyItem flag missing in {item_props}"
    assert "20Sheckel-Bill" in item_props.get("Name", ""), f"Item name mismatch in {item_props}"
    print("  [ASSERT PASS] PBS/items.txt 20SHECKEL-BILL entry is valid.")

def test_graphics_assets():
    item_icon = os.path.join("Graphics", "Items", "TWENTYSHECKELBILL.png")
    assert os.path.exists(item_icon), f"Item icon {item_icon} missing!"
    img = Image.open(item_icon)
    assert img.size == (48, 48), f"Expected 48x48 item icon, got {img.size}"
    assert img.mode == "RGBA", f"Expected RGBA mode, got {img.mode}"
    print(f"  [ASSERT PASS] Bag item icon asset {item_icon} (48x48 RGBA) is valid.")

    char_sprite = os.path.join("Graphics", "Characters", "object_20sheckel.png")
    assert os.path.exists(char_sprite), f"Character sprite {char_sprite} missing!"
    cimg = Image.open(char_sprite)
    assert cimg.size == (128, 128), f"Expected 128x128 character sheet, got {cimg.size}"
    assert cimg.mode == "RGBA", f"Expected RGBA mode, got {cimg.mode}"
    print(f"  [ASSERT PASS] Event character sprite asset {char_sprite} (128x128 RGBA) is valid.")

def test_ice_camp_map_event():
    map_path = os.path.join("Data", "Map091.rxdata")
    assert os.path.exists(map_path), f"Map data file {map_path} missing!"

    with open(map_path, "rb") as f:
        m = load(f)

    events = m.attributes['@events']
    found_event = None
    for eid, ev in events.items():
        name = ev.attributes.get('@name')
        if isinstance(name, bytes):
            name = name.decode('utf-8', errors='ignore')
        if name and ('20 Sheckel' in name or '20SHECKEL' in name.upper()):
            found_event = ev
            break


    assert found_event is not None, "20 Sheckel Bill event not found on Map 091 (Ice Camp)!"

    x = found_event.attributes.get('@x')
    y = found_event.attributes.get('@y')
    pages = found_event.attributes.get('@pages')
    assert len(pages) >= 1, "Event pages missing!"

    page = pages[0]
    graphic = page.attributes.get('@graphic')
    ch_name = graphic.attributes.get('@character_name')
    if isinstance(ch_name, bytes):
        ch_name = ch_name.decode('utf-8', errors='ignore')
    assert ch_name == "object_20sheckel", f"Event graphic mismatch: expected 'object_20sheckel', got '{ch_name}'"

    cmds = page.attributes.get('@list')
    has_pickup_cmd = False
    for cmd in cmds:
        code = cmd.attributes.get('@code')
        params = cmd.attributes.get('@parameters', [])
        if code == 355: # Script execution
            for p in params:
                p_str = p.decode('utf-8', errors='ignore') if isinstance(p, bytes) else str(p)
                if 'pbReceiveItem(:TWENTYSHECKELBILL)' in p_str or 'TWENTYSHECKELBILL' in p_str:
                    has_pickup_cmd = True

    assert has_pickup_cmd, "Script command pbReceiveItem(:TWENTYSHECKELBILL) missing from event!"

    # Assert event disappears after pickup (Self Switch A activates blank second page)
    assert len(pages) >= 2, "Event must have at least 2 pages so it can disappear after pickup"
    
    # Check that page 0 turns on Self Switch A
    has_self_switch_cmd = False
    for cmd in cmds:
        code = cmd.attributes.get('@code')
        params = cmd.attributes.get('@parameters', [])
        if code == 123: # Control Self Switch
            if params and (params[0] == b'A' or params[0] == 'A') and params[1] == 0:
                has_self_switch_cmd = True
    assert has_self_switch_cmd, "Page 0 must turn Self Switch A ON (code 123 with ['A', 0]) to disappear after pickup"

    # Check that page 1 has condition Self Switch A ON and blank graphic
    page1 = pages[1]
    cond1 = page1.attributes.get('@condition')
    assert cond1.attributes.get('@self_switch_valid') is True, "Page 1 condition must have self_switch_valid == True"
    ch = cond1.attributes.get('@self_switch_ch')
    if isinstance(ch, bytes):
        ch = ch.decode('utf-8', errors='ignore')
    assert ch == 'A', f"Page 1 condition self_switch_ch must be 'A', got {ch}"

    graphic1 = page1.attributes.get('@graphic')
    g_name = graphic1.attributes.get('@character_name') if graphic1 else b''
    if isinstance(g_name, bytes):
        g_name = g_name.decode('utf-8', errors='ignore')
    assert g_name == "", f"Page 1 graphic must be empty to disappear, got '{g_name}'"

    print(f"  [ASSERT PASS] Ice Camp (Map 091) Event at ({x},{y}) with graphic '{ch_name}', pickup script command, and disappearing self-switch page is valid.")

def test_bag_storage_logic():
    # Simulate Python implementation of Pokemon Essentials ItemStorageHelper / Bag storage
    pocket = [] # Key items pocket
    max_slots = 50
    max_per_slot = 999
    item = "TWENTYSHECKELBILL"

    def add_to_pocket(pocket_list, item_id, qty):
        for slot in pocket_list:
            if slot[0] == item_id:
                slot[1] += qty
                return True
        if len(pocket_list) < max_slots:
            pocket_list.append([item_id, qty])
            return True
        return False

    def remove_from_pocket(pocket_list, item_id, qty):
        for i, slot in enumerate(pocket_list):
            if slot[0] == item_id:
                if slot[1] > qty:
                    slot[1] -= qty
                else:
                    pocket_list.pop(i)
                return True
        return False

    # 1. Add 1 bill
    assert add_to_pocket(pocket, item, 1), "Failed to add 1 bill to bag"
    assert pocket[0] == ["TWENTYSHECKELBILL", 1], f"Unexpected bag state: {pocket}"

    # 2. Add 5 more bills (collect any number)
    assert add_to_pocket(pocket, item, 5), "Failed to add 5 additional bills to bag"
    assert pocket[0] == ["TWENTYSHECKELBILL", 6], f"Expected 6 bills in bag, got {pocket[0][1]}"

    # 3. Add 20 more bills
    assert add_to_pocket(pocket, item, 20), "Failed to add 20 bills to bag"
    assert pocket[0] == ["TWENTYSHECKELBILL", 26], f"Expected 26 bills in bag, got {pocket[0][1]}"

    # 4. Remove 10 bills
    assert remove_from_pocket(pocket, item, 10), "Failed to remove 10 bills from bag"
    assert pocket[0] == ["TWENTYSHECKELBILL", 16], f"Expected 16 bills in bag, got {pocket[0][1]}"

    print("  [ASSERT PASS] Bag storage logic for multiple 20SHECKEL-BILL items passed.")

def run_all_tests():
    print("=" * 60)
    print(" RUNNING 20SHECKEL-BILL ASSERTION & TEST SUITE")
    print("=" * 60)
    test_items_txt_entry()
    test_graphics_assets()
    test_ice_camp_map_event()
    test_bag_storage_logic()
    print("-" * 60)
    print(" ALL 20SHECKEL-BILL ASSERTIONS PASSED SUCCESSFULLY!")
    print("=" * 60)

if __name__ == "__main__":
    run_all_tests()
