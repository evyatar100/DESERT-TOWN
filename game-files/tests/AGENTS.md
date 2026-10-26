# Event and plugin tests

Run this suite after any change to a map event, a translation key, `PBS/items.txt`, `PBS/pokemon.txt`, or the HebrewSupport and BurningManBag plugins. The checks do not launch the game. They compare event commands with a saved snapshot and run the custom NPC rules with the engine stubbed out.

From `game-files`:

```bash
pip install -r tests/requirements.txt
python tests/run_tests.py
```

Exit code 0 is required before the change is done. `python test_starter_items.py` and `python validate_translations.py` call the same checks.

Ruby is optional. When `ruby` is on `PATH`, `tests/plugin_rules_test.rb` loads the real plugin files. Without Ruby, `tests/test_plugin_rules.py` runs the same cases in Python.

## What is covered

| File | What a failure means |
| --- | --- |
| `test_event_snapshot.py` | An event name, position, page condition, or command list differs from `golden/MapNNN.json`. |
| `test_event_contracts.py` | A translation key, transfer, item, species, choice branch, or page switch no longer lines up with the rest of the game. |
| `test_plugin_rules.py` | The ice seller, ice-factory timer, or starter-item quantity rule changed. |
| `test_starter_items.py` | The bottle or USB disk is missing from PBS, `items.dat`, icons, or the toss guard. |
| `test_translations.py` | `PBS/translations.json` is missing `en` or `he` text, or has no Hebrew. |

Snapshots record event id, name, x, y, page conditions, and the command list (code, indent, parameters). Page graphics and map tiles are not included, so an art-only edit should stay green.

`test_event_contracts.py` treats a string as a translation key when it is `_INTL("KEY")` with a symbolic key, or a whole text or choice string matching `MSG_`, `POPCORN_`, `CHOICE_`, `UI_`, or `NAME_`. It checks those keys in map scripts and in `Plugins/HebrewSupport` and `Plugins/BurningManBag`. Item symbols come from `pbReceiveItem` and `$bag.add` / `remove` / `quantity`. Species symbols come from `pbAddPokemon`, `pbAddPokemonSilent`, `pbWildBattle`, and `pbDoubleWildBattle`. Direct player transfers (command 201) must land inside the destination map. The ice rescue must stay on the tile named by `ICE_CAMP_MAP_ID`, `RESCUE_X`, and `RESCUE_Y` in `ice_in_timer.rb`.

A page switch must be turned ON somewhere on that same map, or its id must be in `golden/switch_allowlist.json`. A self-switch must be turned ON on that same event, or that event must be in the allowlist. Stock Essentials doors and berry plants are already listed because scripts outside the map set them.

Map 084 contains a circular move route. Load maps with `tests/rx_loader.py`. The stock `rubymarshal` reader raises on that file.

## When a test fails

Fix the game data when the failure is a mistake. Refresh a golden file only when the new event behavior is intentional.

- Snapshot mismatch: read the reported map, event, page, and command. Revert an accidental edit. For an intentional one, from `game-files` run `python tests/run_tests.py --update 91` (or `--update` for every map) and commit the golden file with the map change. Do not hand-edit the JSON.
- Missing translation: add the key to `PBS/translations.json` with non-empty `en` and `he`.
- Transfer outside the map: correct the event or the ice-timer constants. Do not widen the check.
- Unknown item or species: add the PBS section or fix the symbol in the script.
- Choice branch mismatch: each Show Choices option needs a branch. Cancel type 5 needs the cancel branch. Any other cancel type must not have one.
- Switch or self-switch: turn it ON in that map or event. If another map or the engine sets it on purpose, add that exception with `python tests/run_tests.py --update-allowlist` and commit `golden/switch_allowlist.json`. Do not refresh the allowlist just to silence a new wait.

## Plugin rules

Keep the decisions separate from messages and screen effects:

- `IceSellerRules.decide(choice, bill_count)` in `Plugins/HebrewSupport/ice_seller.rb`. Five `TWENTYSHECKELBILL` is a purchase and gives `ICEBAG`. Fewer bills is `:not_enough`. Choices 4 and 5 leave the bag unchanged.
- `IceInTimer.seconds_remaining` and `IceInTimer.rescue_destination` in `Plugins/HebrewSupport/ice_in_timer.rb`. The timer expires at 420 seconds on map 88. Rescue transfers once to map 91 at (41, 35) and must not start a second rescue while one is running.
- `BurningManBag.normalize_starter_quantity` in `Plugins/BurningManBag/burning_man_bag.rb`. Zero, one, or many of `WHITEWATERBOTTLE` and `USBDISK` each end at one.
- `DesertTalk.start_speaker` / `pbDesertSpeaker` in `Plugins/DesertTalk/desert_talk.rb`. The speaker survives every message in the event, including `pbDesertTalk`, and clears on the first frame after the map interpreter stops. `pbDesertTalk` only shows the default line and does not set or clear the speaker. Unknown ids raise.
- `DesertTownControls` in `Plugins/DesertTownArcade/000_controls.rb`. Color keys are H, J, K, F, G and none of them is a key the stock input system already uses. Red mirrors Use (C). Blue mirrors Back (X). Nothing mirrors the menu (Z). Orange toggles the Bag. B is still the old Bag key. A slide closes for Use, Back, Action, the arrows, A/S/D, and the color keys, and stays up with no button. The slide methods do not call audio or BGM. The help PNG is 512×384 with the red circle on the right.

- `TempleStickers` in `Plugins/TempleStickers/000`-`004`. A hand is 4 stickers, one per honoree, and all 81 hands occur. A tab is one Inception depth (`DesertTownArcade.depth`). Every run at that depth shares the tab, a full tab grows a new sheet, and tabs sort by depth. A placement is final, and a run cannot place a sticker twice. A failed save leaves the wall and the hand unchanged. A corrupt or missing main file falls back to `.bak`, and the `.bak` is written back as the main file. Boards cap at 300 pages and drop the lowest depth first, also on load. A v1 wall migrates to depth 0. The keyboard has no digits or `@` and caps at 12 and 40 characters. Staff mode needs `temple_staff.cfg`. The staff warning never shows the code, and the name flow never checks it. Tests write the cfg to a temp folder with a random code, and a code never goes in a tracked file. The Python mirror lives in `tests/temple_rules.py`.

`tests/plugin_rules_test.rb` is the behavior test. It stubs `PokemonBag`, `EventHandlers`, messages, and the bag, then loads the plugin files. If you change a rule, update that file and the Python fallback in `test_plugin_rules.py` so a machine without Ruby still checks the same cases.

## Adding a test

Put a `unittest` module in `tests/test_*.py`. Register it by name in the list inside `tests/run_tests.py`. The runner does not discover files, because `game-files/test_starter_items.py` would shadow `tests/test_starter_items.py`.

New golden data belongs in `tests/golden/` and is produced by `--update`, not written by hand.

## What still needs a person in the game

These tests do not walk tiles, play animations, or fight battles. After a visual or movement change, play the map once. A green suite means the commands and the plugin decisions did not drift.
