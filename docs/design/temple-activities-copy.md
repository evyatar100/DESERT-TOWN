# TG3 Temple Inside: copy for the mockup slots (Yotam)

Slots follow Maya's `temple-activities-screens.md` as amended by Michal's review (end of `docs/research/temple-activities-concepts.md`): no statue name plates (each fact names the person in the third person), new C2_S1_CLICK, C1_S1 is now Parton's gift dot, C1_S1_LEND is the Kusama crop, and C2_S1 / C3_S2 carry one FACT (and END in C3) per honoree.
Lengths are checked against Maya's box (68 chars, 2 lines of up to 34). Every Hebrew line wraps to 2 lines at 34, and the English does too. Lines at 60 or more should get a pixel check in the render.
Keys are suggestions only; translations.json is untouched.

| Slot ID | Hebrew | English | Note | Key |
|---|---|---|---|---|
| C1_S1_FACT | הספרייה של דולי פרטון נתנה בחינם יותר מ-300 מיליון ספרים. | Dolly Parton's library has given away over 300 million books. | Parton's gift dot. Imagination Library, 300M passed in 2025 (V). | MSG_TEMPLE_C1_S1_FACT |
| C1_S1_LEND | הפסל של יאיוי קוסאמה משאיל לך דרך להניח נקודה. | Yayoi Kusama's statue lends you a way to place a dot. | Kusama crop. | MSG_TEMPLE_C1_S1_LEND |
| C1_S2_HINT | להניח   לצאת | place   leave | Glyph Z before the first word, X before the second. | UI_TEMPLE_C1_S2_HINT |
| C1_S3_FACT | בערך 25,000 ניסיונות, ואז, ב-1980, הגבישים הראשונים של עדה יונת. | About 25,000 attempts, then, in 1980, Ada Yonath's first crystals. | Shown at the first crystal. Order follows the screen: ghosts, then crystal. | MSG_TEMPLE_C1_S3_FACT |
| C1_S4_LINE | הקיר ימשיך בלעדיך | The wall goes on without you | Michal's line. Band caption, no period. | MSG_TEMPLE_C1_S4_LINE |
| C2_S1_PROMPT | לאיזה כיס המפתח נכנס? | Which pocket does the key fit? | Yonath only. | MSG_TEMPLE_C2_S1_PROMPT |
| C2_S1_FACT_YONATH | עדה יונת הראתה איך אנטיביוטיקות נקשרות לכיסים בריבוזום. יותר מ-20. | Ada Yonath showed how antibiotics bind to ribosome pockets. Over 20. | "Showed how", per the brief. The number is moved to the end so the line fits in 2 lines. | MSG_TEMPLE_C2_S1_FACT_YONATH |
| C2_S1_FACT_KUSAMA | מאז שנות החמישים, נקודות היו השפה של יאיוי קוסאמה. | From the 1950s on, dots were Yayoi Kusama's language. | Before the sticker sheet. | MSG_TEMPLE_C2_S1_FACT_KUSAMA |
| C2_S1_FACT_CURRY | הסרט של טים קארי נכשל. ואז הגיע קהל בתחפושות, בחצות. | Tim Curry's film flopped. Then came midnight crowds in costume. | Costume gift. No labels. | MSG_TEMPLE_C2_S1_FACT_CURRY |
| C2_S1_FACT_PARTON | מ-1995 דולי פרטון שלחה ספר חינם בכל חודש לילדים עד גיל 5. | From 1995 Dolly Parton sent a free book monthly to children under 5. | Book gift. | MSG_TEMPLE_C2_S1_FACT_PARTON |
| C2_S1_AGAIN | עוד פעם. | Once more. | Wrong pocket. | MSG_TEMPLE_C2_S1_AGAIN |
| C2_S1_CLICK | נכנס. לגבישים הראשונים שלה קדמו בערך 25,000 ניסיונות. | It fits. Her first crystals took about 25,000 attempts. | Third pocket. "שלה" refers back to FACT_YONATH. | MSG_TEMPLE_C2_S1_CLICK |
| C2_S1_GOT | המתנה נכנסה לתיק. | The gift is in your bag. | Generic, so it works for all four statues. It leaves "can't keep it" to the arch. | MSG_TEMPLE_C2_S1_GOT |
| C2_S1_HINT | לבחור   לחזור | choose   back | Arrows, then Z, then X. | UI_TEMPLE_C2_S1_HINT |
| C2_S2_TITLE | דף של נקודות | A sheet of dots | | UI_TEMPLE_C2_S2_TITLE |
| C2_S2_HINT | להדביק   לצאת | stick   leave | Colour glyphs, then Z before the first word and X before the second. | UI_TEMPLE_C2_S2_HINT |
| C2_S2_DONE | ב-2002 יאיוי קוסאמה נתנה לילדים חדר לבן לכסות בנקודות. | In 2002 Kusama gave children a white room to cover in dots. | Obliteration Room, which began as a children's project at QAG (V). Not "a sheet that became a room", because that isn't sourced. | MSG_TEMPLE_C2_S2_DONE |
| C2_S3_RULE | אי אפשר לשמור. אפשר רק לתת. | It can't be kept. It can only be given. | Michal's line, no plate. | MSG_TEMPLE_C2_S3_RULE |
| C2_S4_PLATE | ילדה | Little girl | The child who gets Parton's book. If Adi's sprite is a boy: ילד / Little boy. | NAME_TEMPLE_C2_CHILD |
| C2_S4_THANKS | זה בשבילי? תודה. | For me? Thank you. | The whole reward. Gender-neutral. | MSG_TEMPLE_C2_S4_THANKS |
| C3_S2_HINT | ללחוץ עם הטבעת | Press with the ring | No target wording, since the guide ellipse is deleted. | UI_TEMPLE_C3_S2_HINT |
| C3_S2_FACT_YONATH | עדה יונת מיפתה את הריבוזום, בית החרושת לחלבונים של התא. | Ada Yonath mapped the ribosome, the cell's protein factory. | Calcalist's phrasing (V). | MSG_TEMPLE_C3_S2_FACT_YONATH |
| C3_S2_END_YONATH | הגבישים הראשונים שלה הגיעו אחרי בערך 25,000 ניסיונות. | Her first crystals came after about 25,000 attempts. | No player count next to it. | MSG_TEMPLE_C3_S2_END_YONATH |
| C3_S2_FACT_KUSAMA | יאיוי קוסאמה ציירה רשתות אינסוף: סימן קטן, שוב ושוב. | Kusama painted Infinity Nets: one small mark, again and again. | | MSG_TEMPLE_C3_S2_FACT_KUSAMA |
| C3_S2_END_KUSAMA | ב-1977 היא בחרה לגור בבית חולים בטוקיו, ולעבוד כל יום. | In 1977 she chose to live in a Tokyo hospital and work every day. | V. "Chose" carries "voluntarily". No illness wording, no suicide quote. Founder should OK it. | MSG_TEMPLE_C3_S2_END_KUSAMA |
| C3_S2_FACT_CURRY | הסרט של טים קארי נכשל. ב-1976 הוא חזר, בהקרנות חצות. | Tim Curry's film flopped. In 1976 it came back at midnight. | Waverly, April 1976 (V). | MSG_TEMPLE_C3_S2_FACT_CURRY |
| C3_S2_END_CURRY | ואז צופה קבוע אחד התחיל לצעוק תשובות אל המסך. אחרים הצטרפו. | Then one regular began shouting back at the screen. Others joined. | The call-back (Sept 1976, V). Fits the echo ring. | MSG_TEMPLE_C3_S2_END_CURRY |
| C3_S2_FACT_PARTON | דולי פרטון כתבה את '9 to 5' על הסט, ותופפה את הקצב בציפורניים. | Dolly Parton wrote "9 to 5" on set. Her nails tapped the beat. | V. Latin inside RTL, so check the render (see flags). | MSG_TEMPLE_C3_S2_FACT_PARTON |
| C3_S2_END_PARTON | ספר חינם בכל חודש לילדים. עד 2025, יותר מ-300 מיליון. | A free book a month to children. Over 300 million by 2025. | | MSG_TEMPLE_C3_S2_END_PARTON |

Dropped slots (Michal's review): C1_S3_PLATE, C2_S1_PLATE, C2_S2_PLATE, C3_S2_PLATE. C1_S1_PLATE goes too, since the C1_S1 box has no plate.

## Flags
- Unslotted lines: the C1 statues still need a fact and lend line for Yonath, Curry and Parton, and C2 needs re-skin prompts for Curry and Parton. The C1 facts can reuse the C2_S1_FACT_* keys. The other lines need slots from Maya.
- '9 to 5' in the Hebrew string: HebrewSupport reverses characters, so a Latin run inside the sentence may come out mirrored. If it does, the fallback is: דולי פרטון כתבה את 'מתשע עד חמש' על הסט, ותופפה את הקצב בציפורניים.
- Spellcheck (Windows he-IL): קוסאמה (press spelling, per the brief), ריבוזום / בריבוזום / הריבוזום (correct term), אנטיביוטיקות (common press plural; the dictionary wants אנטיביוטיות). All are kept and should go into `.claude/skills/hebrew-spellcheck/allowlist.txt`. I didn't add them, because this dispatch let me write to one file only. Hspell and aspell don't run on Windows, so proofread needs a pass on the office server.

## Style decisions (for docs/style-sheet.md, which doesn't exist yet)
- Names: עדה יונת, יאיוי קוסאמה, טים קארי, דולי פרטון. Full name on first mention in each screen; after that, היא / she. English uses the bare surname "Kusama" where length forces it.
- Numbers: 25,000 with a comma. Always "בערך" / "about".
- Prefix plus digit: ASCII hyphen (ב-1980), as in the existing translations.json.
- Titles of works in Hebrew text take single quotes ('9 to 5'). English uses straight double quotes.
- Temple register: no exclamation marks, no plates on statues, and no second-person gendered verbs. UI hints use infinitives.
- UI hint strings: three spaces between the two verbs, because the glyphs sit in those gaps.
