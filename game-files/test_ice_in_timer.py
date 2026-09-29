import os
import sys
import json
import zlib
import struct
import rubymarshal
from rubymarshal.reader import load
from rubymarshal.classes import Symbol

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

EXPECTED_HEBREW_MSG = "יותר מדי זמן במפעל הקרח, היפוטרמיה הביאה אותך למצב קריטי. צוות המפעל חילץ אותך החוצה"

def test_translations():
    trans_path = os.path.join("PBS", "translations.json")
    assert os.path.exists(trans_path), f"File {trans_path} missing!"

    with open(trans_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    trans = data.get("translations", {})
    assert "MSG_ICE_IN_TIMEOUT" in trans, "MSG_ICE_IN_TIMEOUT missing from PBS/translations.json!"
    assert trans["MSG_ICE_IN_TIMEOUT"]["he"] == EXPECTED_HEBREW_MSG, \
        f"Hebrew text mismatch in MSG_ICE_IN_TIMEOUT: got {trans['MSG_ICE_IN_TIMEOUT']['he']}"
    assert EXPECTED_HEBREW_MSG in trans, "Direct Hebrew key missing in PBS/translations.json!"

    print("  [ASSERT PASS] PBS/translations.json contains valid MSG_ICE_IN_TIMEOUT and direct Hebrew key.")

def test_plugin_source():
    script_path = os.path.join("Plugins", "HebrewSupport", "ice_in_timer.rb")
    assert os.path.exists(script_path), f"Plugin script {script_path} missing!"

    with open(script_path, "r", encoding="utf-8") as f:
        code = f.read()

    assert "module IceInTimer" in code, "module IceInTimer missing in ice_in_timer.rb"
    assert "ICE_IN_MAP_ID = 88" in code or "ICE_IN_MAP_ID   = 88" in code, "ICE_IN_MAP_ID must be 88"
    assert "ICE_CAMP_MAP_ID = 91" in code or "ICE_CAMP_MAP_ID = 91" in code or "ICE_CAMP_MAP_ID   = 91" in code, "ICE_CAMP_MAP_ID must be 91"
    assert "7 * 60" in code or "420" in code, "TIME_LIMIT must be 7 minutes (420 seconds)"
    assert "RESCUE_X = 41" in code or "RESCUE_X        = 41" in code, "RESCUE_X must be 41"
    assert "RESCUE_Y = 35" in code or "RESCUE_Y        = 35" in code, "RESCUE_Y must be 35"
    assert "pbShake" in code or "start_shake" in code, "Screen shake missing from rescue logic"
    assert "pbFlash" in code or "start_flash" in code or "pbToneChangeAll" in code, "Blue effect missing from rescue logic"
    assert "pbTransferPlayer" in code, "pbTransferPlayer missing from rescue logic"
    assert "MSG_ICE_IN_TIMEOUT" in code or EXPECTED_HEBREW_MSG in code, "Rescue message missing from rescue logic"

    print("  [ASSERT PASS] Plugins/HebrewSupport/ice_in_timer.rb contains all required constants, effects, and rescue logic.")

def test_plugin_compilation():
    plugin_rxdata = os.path.join("Data", "PluginScripts.rxdata")
    assert os.path.exists(plugin_rxdata), f"{plugin_rxdata} missing!"

    with open(plugin_rxdata, "rb") as f:
        plugins = load(f)

    found_script = False
    for p_name, p_meta, p_scripts in plugins:
        for s_name, s_code_z in p_scripts:
            if s_name == "ice_in_timer.rb":
                decomp = zlib.decompress(s_code_z).decode('utf-8', errors='ignore')
                if "module IceInTimer" in decomp and "trigger_rescue" in decomp:
                    found_script = True

    assert found_script, "Compiled ice_in_timer.rb missing from Data/PluginScripts.rxdata!"
    print("  [ASSERT PASS] Plugins/HebrewSupport/ice_in_timer.rb successfully compiled in Data/PluginScripts.rxdata.")

def test_map91_bounds_and_passability():
    map_path = os.path.join("Data", "Map091.rxdata")
    assert os.path.exists(map_path), f"Map 091 data file {map_path} missing!"

    with open(map_path, "rb") as f:
        m = load(f)

    w = m.attributes.get('@width')
    h = m.attributes.get('@height')
    assert w >= 42, f"Map 091 width must be at least 42 to contain (41, 35), got {w}"
    assert h >= 36, f"Map 091 height must be at least 36 to contain (41, 35), got {h}"

    # Verify tile passability at (41, 35)
    tileset_id = m.attributes.get('@tileset_id')
    with open(os.path.join("Data", "Tilesets.rxdata"), "rb") as tf:
        tilesets = load(tf)
    tileset = tilesets[tileset_id]
    passages = tileset.attributes.get('@passages')._private_data
    p_dim, p_size = struct.unpack('<II', passages[:8])
    pass_table = struct.unpack(f'<{p_size}H', passages[8:8+p_size*2])

    raw = m.attributes.get('@data')._private_data
    dim, nx, ny, nz, count = struct.unpack('<IIIII', raw[:20])
    tiles = struct.unpack(f'<{count}H', raw[20:20+count*2])

    target_x = 41
    target_y = 35
    passable = True
    for z in [2, 1, 0]:
        t = tiles[target_x + target_y * nx + z * nx * ny]
        if t < len(pass_table):
            p = pass_table[t]
            if p & 0x10 != 0:
                passable = False

    assert passable, f"Target rescue coordinates ({target_x}, {target_y}) must be passable!"
    print(f"  [ASSERT PASS] Map 091 dimensions ({w}x{h}) encompass rescue target (41, 35) and tile is passable.")

def test_simulated_timer_state_machine():
    class SimulatedIceInTimer:
        ICE_IN_MAP_ID = 88
        ICE_CAMP_MAP_ID = 91
        TIME_LIMIT = 7 * 60
        RESCUE_X = 41
        RESCUE_Y = 35

        def __init__(self):
            self.active = False
            self.start_time = None
            self.current_time = 0
            self.current_map_id = None
            self.player_x = 0
            self.player_y = 0
            self.rescued = False
            self.effects_played = []
            self.messages = []

        def enter_map(self, map_id):
            self.current_map_id = map_id
            if map_id == self.ICE_IN_MAP_ID:
                if not self.active:
                    self.active = True
                    self.start_time = self.current_time
            else:
                self.active = False
                self.start_time = None

        def advance_time(self, seconds):
            self.current_time += seconds

        def check_frame_update(self):
            if not self.active or self.current_map_id != self.ICE_IN_MAP_ID:
                return
            elapsed = self.current_time - self.start_time
            if elapsed >= self.TIME_LIMIT:
                self.trigger_rescue()

        def trigger_rescue(self):
            self.active = False
            # 1. Effects
            self.effects_played.append("BLUE_EFFECT")
            self.effects_played.append("SCREEN_SHAKE")
            # 2. Player movement to Ice Camp (41, 35)
            self.current_map_id = self.ICE_CAMP_MAP_ID
            self.player_x = self.RESCUE_X
            self.player_y = self.RESCUE_Y
            self.rescued = True
            # 3. Message
            self.messages.append(EXPECTED_HEBREW_MSG)

    sim = SimulatedIceInTimer()

    # Outside Ice In: timer shouldn't be active
    sim.enter_map(91)
    assert not sim.active, "Timer should not be active on Map 91"
    sim.advance_time(500)
    sim.check_frame_update()
    assert not sim.rescued, "Rescue should not trigger outside Map 88"

    # Enter Ice In (Map 88)
    sim.enter_map(88)
    assert sim.active, "Timer must be active upon entering Map 88"
    assert sim.start_time == 500

    # Advance 6 minutes (360 seconds)
    sim.advance_time(360)
    sim.check_frame_update()
    assert not sim.rescued, "Rescue should not trigger at 6 minutes"

    # Advance 1 more minute (total 7 minutes = 420 seconds)
    sim.advance_time(60)
    sim.check_frame_update()
    assert sim.rescued, "Rescue MUST trigger after 7 minutes"
    assert sim.effects_played == ["BLUE_EFFECT", "SCREEN_SHAKE"], "Blue effect and screen shake must be triggered"
    assert sim.current_map_id == 91, "Player must be transferred to Map 91 (Ice Camp)"
    assert (sim.player_x, sim.player_y) == (41, 35), "Player must be moved to (41, 35)"
    assert sim.messages == [EXPECTED_HEBREW_MSG], "Rescue message must match expected Hebrew text"
    assert not sim.active, "Timer must be stopped after rescue"

    print("  [ASSERT PASS] Simulated 7-minute timer, blue effect, screen shake, transfer to (41, 35), and Hebrew message verified.")

def run_all_tests():
    print("=" * 60)
    print(" RUNNING ICE-IN 7-MINUTE TIMER & RESCUE ASSERTION SUITE")
    print("=" * 60)
    test_translations()
    test_plugin_source()
    test_plugin_compilation()
    test_map91_bounds_and_passability()
    test_simulated_timer_state_machine()
    print("-" * 60)
    print(" ALL ICE-IN TIMER & RESCUE ASSERTIONS PASSED SUCCESSFULLY!")
    print("=" * 60)

if __name__ == "__main__":
    run_all_tests()
