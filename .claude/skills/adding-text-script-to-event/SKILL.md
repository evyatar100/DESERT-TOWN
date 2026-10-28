---
name: adding-text-script-to-event
description: >-
  Comprehensive guide for adding, editing, and managing event text scripts, bilingual English/Hebrew dialogue,
  translation dictionary entries in PBS/translations.json, and verifying event scripts in Pokémon Essentials (v21.x) running on mkxp-z.
---

# Adding Text Script to Event Skill

This skill provides a complete procedure for authoring, updating, and localizing event dialogue and text scripts in Pokémon Essentials (v21.x) projects with Hebrew support.

---

## 1. Architecture Overview

In RPG Maker XP / Pokémon Essentials with `HebrewSupport`:

```
┌─────────────────────────────────────────────────────────────┐
│                 RPG Maker XP Event / Script                 │
│       Uses symbolic translation key in event commands       │
│             e.g., pbMessage(_INTL("MSG_SHONTAL_INTRO"))     │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│                    PBS/translations.json                    │
│      Contains structured key-to-language entry mappings     │
│             "MSG_SHONTAL_INTRO": {                          │
│               "en": "Yesterday Shontal Netz...",            │
│               "he": "אתמול שונטל נץ..."                     │
│             }                                               │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│                    HebrewSupport Plugin                     │
│    Intercepts key, resolves active language string (en/he), │
│      applies RTL character reversal & Right Alignment        │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Event Script Formatting Rules

When writing event dialogue in RPG Maker XP event pages or Ruby scripts:

### Standard Dialogue
```ruby
# In Event Script Command or RGSS Script:
pbMessage(_INTL("MSG_SHONTAL_INTRO"))
```

### Choice Menus & Choices
```ruby
choice = pbMessage(_INTL("MSG_HELP_CAMP_QUESTION"), [_INTL("CHOICE_YES"), _INTL("CHOICE_NO")], 2)
if choice == 0
  pbMessage(_INTL("MSG_THANK_YOU_POWDER"))
end
```

### Formatting Guidelines
1. **Use symbolic translation keys in event script commands**: Use descriptive key constants like `MSG_SHONTAL_INTRO`, `CHOICE_YES`, or `UI_SAVE`.
2. **Wrap key strings with `_INTL(...)` or `_MAPINTL(...)`**: Allows `HebrewSupport` plugin hooks to intercept the key and resolve the translation.
3. **Define both English and Hebrew strings in `PBS/translations.json`**: Ensure `"en"` and `"he"` fields are populated for every key.

---

## 3. Adding Translations to `PBS/translations.json`

Add the symbolic key and language dictionary entry directly into `PBS/translations.json`:

```json
{
  "meta": {
    "version": "2.0.0",
    "description": "Key-based multi-language translation dictionary for Pokémon Essentials"
  },
  "translations": {
    "NAME_SHONTAL": {
      "en": "Shontal",
      "he": "שונטל"
    },
    "MSG_SHONTAL_INTRO": {
      "en": "Yesterday Shontal Netz plugged her straightener into the power grid and ran out our supply! She is a sparkling unicorn and refuses to go outside to get electricity powder from the Karahana because there is too much dust and it ruins her facial skin. Save the camp and go get us electricity powder before we have to see Shontal furious with curly hair!",
      "he": "אתמול שונטל נץ חיברה את המחליק שלה לחשמל ונגמרה לנו האספקה, היא חד קרן מנצנץ ולא מוכנה לצאת וללכת להביא אבקת חשמל מהקראחנה כי יש יותר מידי פודרה וזה הורס לה את העור פנים. תציל את המחנה ולך תביא לנו אבקת חשמל לפני שנצטרף לראות את שונטאל עם תלתלים עצבנית"
    }
  }
}
```

---

## 4. Verification & Compilation Procedure

After adding or editing event text and translation entries, follow this validation pipeline:

### 1. Validate `translations.json` & Event Text Coverage
Run the validation scripts to verify UTF-8 JSON structure, Hebrew encoding, and event text coverage:
```bash
python validate_translations.py
python test_event_translations.py
```

### 2. Add Unit Test (Optional but Recommended)
In `Plugins/HebrewSupport/test_translations.rb`, add a unit test case for the new event translation:
```ruby
def self.test_shontal_translation
  translated_name = HebrewText.translate("Shontal")
  translated_text = HebrewText.translate("Yesterday Shontal Netz plugged her straightener into the power grid...")
  return translated_name == "שונטל" && translated_text.include?("אתמול שונטל נץ")
end
```

### 3. Recompile Plugins
Compile all plugin scripts into `Data/PluginScripts.rxdata`:
```bash
python compile_plugins.py
```

### 4. Verify Ruby Parser Compatibility
```bash
python test_ruby_parser.py
```

---

## 5. Map Event Text Extraction & Concatenation Rules

When translating map events (e.g., "translate all events in map-name"):

### 1. Map Name to Map ID Resolution
Map IDs are mapped in `PBS/map_metadata.txt`:
```
[084]
Name = demo-camp4
```
Map file location: `Data/Map084.rxdata`

### 2. RPG Maker Event Command Codes & Essentials Concatenation
- **Code 101**: Start of `Show Text` command.
- **Code 401**: Continuation line of `Show Text`.
- **Code 102**: `Show Choices` options array.

**CRITICAL Essentials Concatenation Behavior (`Interpreter_Commands`):**
When code 101 is followed by code 401, Essentials joins the text strings:
```ruby
message += " " if text != "" && message[message.length - 1, 1] != " "
message += text
```
* Note: If code 101's string ends with a space (e.g., `"until "`) and code 401 is `"she comes back."`, Essentials appends them without adding an extra space, yielding `"until  she comes back."` (double space).
* **CRITICAL RULE**: Each translation string must be added **EXACTLY ONCE** to `PBS/translations.json` without repetitive entries, duplicate keys, or space variants. The `HebrewSupport` plugin automatically normalizes multiple spaces (`gsub(/\s+/, ' ')`) to match the single clean key.

### 3. Quick Map Event Text Extractor Snippet
To inspect all text commands in any map file (`Data/MapXXX.rxdata`):

```python
import rubymarshal
from rubymarshal.reader import load

with open('Data/Map084.rxdata', 'rb') as f:
    map_data = load(f)

events = map_data.attributes.get(b'@events') or map_data.attributes.get('@events')
for event_id in sorted(events.keys()):
    event = events[event_id]
    name = event.attributes.get(b'@name') or event.attributes.get('@name')
    pages = event.attributes.get(b'@pages') or event.attributes.get('@pages')
    for p_idx, page in enumerate(pages):
        list_cmds = page.attributes.get(b'@list') or page.attributes.get('@list')
        for c_idx, cmd in enumerate(list_cmds):
            code = cmd.attributes.get(b'@code') or cmd.attributes.get('@code')
            params = cmd.attributes.get(b'@parameters') or cmd.attributes.get('@parameters')
            if code in [101, 401, 102]:
                print(f"Event {event_id} ({name}) P{p_idx+1} Code {code}: {params}")
```

---

## 6. Checklist for Translating Map Events

- [ ] Look up Map ID in `PBS/map_metadata.txt` matching map name.
- [ ] Extract event strings from `Data/MapXXX.rxdata` (handling 101/401/102 codes).
- [ ] Add English keys and Hebrew values to `PBS/translations.json` (each key added **ONCE** without repetitions or duplicate space variants).
- [ ] `python validate_translations.py` exits with code 0.
- [ ] `python test_event_translations.py` exits with code 0.
- [ ] Add unit test case in `Plugins/HebrewSupport/test_translations.rb`.
- [ ] `python compile_plugins.py` executes successfully.
- [ ] `python test_ruby_parser.py` executes successfully.
