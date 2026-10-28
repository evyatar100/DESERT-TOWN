# Character records and location ledger

## Character id

Path: `asset_generation/production/char/<donor>/<name>-<id>/metadata.md`

`<id>` is the last hyphen-separated token and must match `[0-9a-f]{8}`. Donor folder name is the owner, not the id. Staging (`asset_generation/staging/char`) is empty and is not a source.

## metadata.md fields

Every file has these labels. Empty values are the literal `_(not set)_`.

| Label | Use |
|---|---|
| Title (`# …`) | Heading. Prefer **Name (Hebrew)**, then **Name (English)**. |
| Name (Hebrew) | `NAME_<ID>` → `he` |
| Name (English) | `NAME_<ID>` → `en`. If unset, `en` is the Hebrew name. |
| Camp | Catalog filter. Not a map id. |
| Line | Default spoken line. `MSG_<ID>_LINE`. |
| Description | Catalog only, unless a placement adds it as an extra action. |
| Abilities | Catalog only, unless a placement adds it as an extra action. |
| Quest usable | `yes` or `no`. Mention `no` before placing. |
| Placement | Donor text such as `camp` or `deep_field,camp`. Hint only, not a coordinate. |
| Symmetrical | Donor `yes` / `no`. |
| Asymmetric | `yes`, `no`, or `not reviewed`. Missing on older files; treat missing as `not reviewed`. |
| Asymmetric notes | Curator note. Missing on the same older files. |
| Notes | Extra note. |
| Created at | UTC timestamp. |
| Push count / version | Integer. |

Older files with no Asymmetric fields: BoneRunner870, BoneScout152, ChemiBebo, dt148 QA, Evyatar, Flamazing461, Flaminga, SivaNavy, WindScout164, YONIK.

## Translation keys

`<ID>` is the character id in uppercase.

```json
"NAME_11EAF4FA": { "en": "ZIG-ZAG", "he": "זיג-זאד" },
"MSG_11EAF4FA_LINE": { "en": "It is what it is", "he": "It is what it is" }
```

A line that exists only at one spot gets its own key, named for the place: `MSG_11EAF4FA_KUSUMO`. Add each key once. Follow `game-files/.agents/skills/adding-text-script-to-event` for validation.

## locations.json

Path: `asset_generation/characters/locations.json`

```json
{
  "placements": [
    {
      "character_id": "11eaf4fa",
      "map_id": 94,
      "event_id": 12,
      "x": 10,
      "y": 15,
      "line_key": null,
      "actions": []
    }
  ]
}
```

| Field | Rule |
|---|---|
| character_id | 8-hex id. Must match a production folder. |
| map_id | Integer in `game-files/PBS/map_metadata.txt`. |
| event_id | `RPG::Event` id on that map. Unique per map. |
| x, y | Tile coordinates of that event. |
| line_key | `null` when the event uses default `pbDesertTalk(id)` (also when extra lines are Show Text 101). Otherwise the override key passed as the second argument of `pbDesertTalk`. |
| actions | Short labels for the catalog, in order. Example: `["offers a choice", "gives powder"]`, or `["shows MSG_834AEF17_SQUARE"]` for an extra Show Text line. The script itself stays on the event. |

One object per standing spot. The same `character_id` may appear in several objects. Do not copy name, camp, or description into this file.

## Generated files

`python asset_generation/characters/build_catalog.py` writes `asset_generation/characters/catalog.html`.

While `locations.json` is missing or empty, the page lists characters and the first sprite frame only. It does not show map stops.

When the DesertTalk plugin is added, the same script also writes:

```ruby
module DesertTalk
  CHARACTERS = {
    "11eaf4fa" => { name_key: "NAME_11EAF4FA", line_key: "MSG_11EAF4FA_LINE" }
  }
end
```

The Ruby hash includes every production character, placed or not, so `pbDesertTalk` works as soon as an event exists. Placement overrides are arguments on the event, not extra hash entries.

## Event command

Two Script commands (code 355), then command code 0. A longer script continues with code 655:

```ruby
pbDesertSpeaker("11eaf4fa")
pbDesertTalk("11eaf4fa")
```

`pbDesertSpeaker` sets the name plate for the rest of the event. `pbDesertTalk` only shows the default line. Do not also add Show Text (101/401) for that same default line.

**Append a map-specific line (preferred):** default `pbDesertTalk` with no second argument, then Show Text (code 101) with the translation key as the sole parameter. Example (Squere Road Temple promoters):

| Step | Code | Parameter |
|---|---|---|
| Speaker | 355 | `pbDesertSpeaker("834aef17")` |
| Default line | 355 | `pbDesertTalk("834aef17")` |
| Extra line | 101 | `MSG_834AEF17_SQUARE` |
| End | 0 | — |

`line_key` in `locations.json` stays `null`. Note the Show Text key in `actions`. Do not append extras with `pbDesertTalk(id, "MSG_…")`.

**Replace** the default line at one spot (no default talk): second argument of `pbDesertTalk`, and set `line_key` to that key:

```ruby
pbDesertSpeaker("11eaf4fa")
pbDesertTalk("11eaf4fa", "MSG_11EAF4FA_KUSUMO")
```

Further lines are more Show Text (101/401), more `pbDesertTalk` calls, or Script `pbMessage` commands. Every message window while the speaker is set shows the character's name plate. The speaker clears automatically when the event ends. Call `pbDesertSpeaker` again with a different id to switch speaker mid-event.
