# Desert Town controls

The game is played two ways. On a dev machine the keys below are the keyboard.
On the arcade cabinet, each physical button will later be mapped to one of
these keys. GPIO wiring is not part of this game code. The color-to-key table
lives in `game-files/Plugins/DesertTownArcade/000_controls.rb` (`DesertTownControls::COLORS`).

## Color buttons

| Color | Key | What it does |
| --- | --- | --- |
| Red | H | Talk, confirm, and every other place C works. Same input as C (`Input::USE`). |
| Blue | J | Run while walking, and cancel, the same way X does. Same input as X (`Input::BACK`). Hold to run. Running shoes and the run style option still apply. |
| Orange | K | Opens the Bag. Press again while the Bag is open to close it. |
| White | F | Help slide. Any button closes it. Music keeps playing. |
| Green | G | World map slide. Any button closes it. Music keeps playing. |

Red and Blue are extra keys on the existing inputs. They do not replace C or X.

## Unchanged keys

| Key | What it does |
| --- | --- |
| C, Enter, Space | Talk / confirm (`Input::USE`) |
| X, Esc | Run (hold) and cancel (`Input::BACK`) |
| Z, Shift | Pause menu (`Input::ACTION`) |
| B | Opens the Bag. This is the older arcade key. It does not close the Bag. Orange (K) is the toggle. |
| Arrows | Walk |
| A | Page up (`Input::JUMPUP`) |
| S | Page down (`Input::JUMPDOWN`) |
| D | Ready menu (`Input::SPECIAL`) |
| Q, W | Unused Essentials inputs (`Input::AUX1`, `Input::AUX2`) |

## Why not A, S, D, F, G as first proposed

The first proposal was Red A, Blue S, Orange D, White F, Green G.

F and G are not used by the input system, so White and Green kept them.

A, S, and D are the default RGSS1 bindings (mkxp `keybindings.cpp`, confirmed against `Input` and the in-game controls help):

| Proposed | Already does |
| --- | --- |
| A | Jump Up: page up in lists, and the map-connection editor |
| S | Jump Down: page down in lists, and the map-connection editor |
| D | Special: opens the Ready menu |

Those three colors moved to the next free letters, H, J, and K. Also left alone: C, X, Z, Q, W, B, and the animation-editor keys E, L, R, and P.

## Slides

Help text is `game-files/Plugins/DesertTownArcade/help_slide.txt`. Rebuild the picture with:

```bash
python3 game-files/Plugins/DesertTownArcade/render_help_slide.py
```

That writes `game-files/Graphics/Pictures/DesertTownHelp.png`. The game shows the PNG. It does not draw the Hebrew itself.

The world map picture is rebuilt from `maps/world_layout.json` and each outside map's `base.png`:

```bash
python3 game-files/Plugins/DesertTownArcade/render_world_map_slide.py
```

That writes `game-files/Graphics/Pictures/DesertTownWorldMap.png`. The stock Town Map graphics (`mapRegion0.png`, `mapRegion1.png`) are the Essentials regions Essen and Tiall, not Desert Town. PR #10's `mapRegion2.png` is not on main.

While either slide is up, any keyboard button closes it (arrows, C, X, Z, A, S, D, the color keys, Enter, Esc, Space). The slide code does not call `Audio`, `pbBGMPlay`, `pbBGMStop`, or `pbBGMFade`.

## Cabinet wiring later

Map each button to one key:

| Button | Send this key |
| --- | --- |
| Red | H |
| Blue | J |
| Orange | K |
| White | F |
| Green | G |
| (existing) action | C |
| (existing) run | X |
| (existing) menu | Z |
