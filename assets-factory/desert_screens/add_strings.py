"""TG57 Batch 1: append the draft Hebrew labels to PBS/translations.json.

Text insert (no re-dump) so the file's formatting and any unrelated working-tree edit
stay as they are. Skips keys that already exist, so it is re-runnable.
"""
import json
from pathlib import Path

PATH = Path(__file__).resolve().parents[2] / "game-files" / "PBS" / "translations.json"

STRINGS = {
    # Load screen
    "Continue": "המשך",
    "New Game": "משחק חדש",
    "Options": "אפשרויות",
    "Quit Game": "יציאה מהמשחק",
    "Badges:": "תגים:",
    "Pokédex:": "פוקדקס:",
    "Time:": "זמן משחק:",
    "{1}h {2}m": "{1} ש' {2} ד'",
    "{1}m": "{1} ד'",
    # Save screen and pause menu
    "Save": "שמירה",
    "Player": "שחקן",
    "Time": "זמן משחק",
    "Badges": "תגים",
    "Pokédex": "פוקדקס",
    "Would you like to save the game?": "לשמור את המשחק?",
    "{1} saved the game.": "המשחק של {1} נשמר.",
    "The game was saved.": "המשחק נשמר.",
    "The previous save file has been backed up.": "השמירה הקודמת גובתה.",
    "Save failed.": "השמירה נכשלה.",
    "WARNING!": "שימו לב!",
    "There is a different game file that is already saved.": "כבר קיימת שמירה אחרת של משחק.",
    "If you save now, the other file's adventure, including items and Pokémon, will be entirely lost.":
        "אם תשמרו עכשיו, כל מה שיש בשמירה האחרת, כולל חפצים, יימחק לגמרי.",
    "Are you sure you want to save now and overwrite the other save file?":
        "בטוחים שרוצים לשמור עכשיו ולדרוס את השמירה האחרת?",
    "Are you sure you want to quit the game?": "בטוחים שרוצים לצאת מהמשחק?",
    # Options: labels, descriptions, values
    "Music Volume": "עוצמת מוזיקה",
    "Adjust the volume of the background music.": "קובעים את עוצמת מוזיקת הרקע.",
    "SE Volume": "עוצמת אפקטים",
    "Adjust the volume of sound effects.": "קובעים את עוצמת האפקטים.",
    "Text Speed": "מהירות טקסט",
    "Choose the speed at which text appears.": "בוחרים באיזו מהירות הטקסט מופיע.",
    "Slow": "איטי",
    "Mid": "בינוני",
    "Fast": "מהיר",
    "Inst": "מיידי",
    "Battle Effects": "אפקטי קרב",
    "Choose whether you wish to see move animations in battle.": "בוחרים אם להציג אנימציות של מהלכים בקרב.",
    "Battle Style": "סגנון קרב",
    "Choose whether you can switch Pokémon when an opponent's Pokémon faints.":
        "בוחרים אם אפשר להחליף פוקימון כשהיריב מפיל פוקימון.",
    "Switch": "החלפה",
    "Set": "קבוע",
    "Default Movement": "תנועה רגילה",
    "Choose your movement speed. Hold Back while moving to move at the other speed.":
        "בוחרים את מהירות התנועה. מחזיקים אחורה תוך כדי תנועה כדי לנוע במהירות השנייה.",
    "Walking": "הליכה",
    "Running": "ריצה",
    "Send to Boxes": "שליחה לקופסאות",
    "Choose whether caught Pokémon are sent to your Boxes when your party is full.":
        "בוחרים אם פוקימון שנתפסו נשלחים לקופסאות כשהצוות מלא.",
    "Manual": "ידני",
    "Automatic": "אוטומטי",
    "Give Nicknames": "מתן כינויים",
    "Choose whether you can give a nickname to a Pokémon when you obtain it.":
        "בוחרים אם אפשר לתת כינוי לפוקימון כשמקבלים אותו.",
    "Give": "לתת",
    "Don't give": "לא לתת",
    "Speech Frame": "מסגרת דיבור",
    "Choose the appearance of dialogue boxes.": "בוחרים את מראה תיבות הדיבור.",
    "Menu Frame": "מסגרת תפריט",
    "Choose the appearance of menu boxes.": "בוחרים את מראה תיבות התפריט.",
    "Text Entry": "הזנת טקסט",
    "Choose how you want to enter text.": "בוחרים איך להזין טקסט.",
    "Cursor": "סמן",
    "Keyboard": "מקלדת",
    "Screen Size": "גודל מסך",
    "Choose the size of the game window.": "בוחרים את גודל חלון המשחק.",
    "Full": "מלא",
    "Close": "סגירה",
    "Close the screen.": "סוגרים את המסך.",
}


def main():
    raw = PATH.read_bytes().decode("utf-8")
    nl = "\r\n" if "\r\n" in raw else "\n"
    existing = json.loads(raw)["translations"]
    new = {k: v for k, v in STRINGS.items() if k not in existing}
    if not new:
        print("nothing to add")
        return
    entries = []
    for en, he in new.items():
        entries.append(nl.join([
            f"    {json.dumps(en, ensure_ascii=False)}: {{",
            f'      "en": {json.dumps(en, ensure_ascii=False)},',
            f'      "he": {json.dumps(he, ensure_ascii=False)},',
            '      "draft": "Yotam"',
            "    }",
        ]))
    idx = raw.rstrip().rfind("  }")
    head = raw[:idx].rstrip()
    out = head + "," + nl + ("," + nl).join(entries) + nl + "  }" + nl + "}" + (nl if raw.endswith("\n") else "")
    json.loads(out)
    PATH.write_bytes(out.encode("utf-8"))
    print("added", len(new), "skipped", len(STRINGS) - len(new))


if __name__ == "__main__":
    main()
