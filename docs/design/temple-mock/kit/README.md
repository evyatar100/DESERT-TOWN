# temple-mock kit (Map113 Temple Inside)

Real-asset building blocks for in-game mockups. PIL only, no paid generation.
Regenerate: `python kit.py` (writes the PNGs below). Needs Pillow; reads game-files directly.

- map113_full.png      13x24 tiles = 416x768, layers 1-3 of Map113 over temple-inside_ts.png
- player_up/down.png   32x48 frames from idi4.png (step 0, standing)
- kit_sample.png       512x384 composite: camera, player facing up, msgbox, name plate

API (import kit):
- render_map(sprites=[(img, tx, ty)])   sprite feet on tile bottom; priority tiles overlay it
- camera_crop(center_tile, sprites)     512x384, map centred horizontally, black outside, y clamped
- camera_offset(center_tile, size)      screen pos of map (0,0), for overlays
- player_frame(dir, step=0)             dir: down/left/right/up
- msgbox(lines=[..]) -> (img, (x,y))    pbCreateMessageWindow geometry: x=0, 512 wide, 96 high, y=288
- name_plate(name, msg_pos) -> (img, (x,y))   pbDesertSpeaker plate, right-aligned above the box
- compose_screen(center, sprites, text, speaker)

Facts used: skin `speech hgss 1` (Settings::SPEECH_WINDOWSKINS[0], PokemonSystem.textskin=0),
font Handjet 27px, dark text (80,80,88) + shadow (160,160,168) drawn at +2/+2 offsets.
Hebrew: PIL has no raqm here, so words are reversed manually (same rule as HebrewText.visual_reverse).
Not verified against a live engine frame: vertical glyph placement (FONT_Y_OFFSET 8 ignored).
