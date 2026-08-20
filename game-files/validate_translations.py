import json
import os
import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

def test_translations_json():
    json_path = os.path.join("PBS", "translations.json")
    assert os.path.exists(json_path), f"{json_path} does not exist!"
    
    with open(json_path, "r", encoding="utf-8") as f:
        data = json.load(f)
        
    assert "translations" in data, "'translations' key missing from JSON"
    translations = data["translations"]
    assert isinstance(translations, (dict, list)), "'translations' should be a dictionary or list"
    assert len(translations) > 0, "Translations collection is empty"
    
    entries = {}
    if isinstance(translations, list):
        for item in translations:
            assert isinstance(item, dict) and "key" in item, "List items must be dicts with 'key'"
            entries[item["key"]] = item
    else:
        entries = translations

    print(f"Loaded {len(entries)} translation key entries from {json_path}:")
    hebrew_found = False
    for k, v in entries.items():
        assert isinstance(v, dict), f"Entry for key '{k}' must be an object with language variants"
        assert "en" in v and "he" in v, f"Entry for key '{k}' must contain 'en' and 'he' fields"
        assert isinstance(v["en"], str) and v["en"].strip(), f"Key '{k}' has empty 'en' text"
        assert isinstance(v["he"], str) and v["he"].strip(), f"Key '{k}' has empty 'he' text"
        print(f"  '{k}' -> [en: '{v['en'][:30]}...', he: '{v['he'][:30]}...']")
        if any('\u0590' <= char <= '\u05FF' for char in v["he"]):
            hebrew_found = True

    assert hebrew_found, "No Hebrew characters found in translation values!"
    print("\n[VALIDATION SUCCESS] translations.json is valid and contains UTF-8 key-based translations.")

if __name__ == "__main__":
    test_translations_json()

