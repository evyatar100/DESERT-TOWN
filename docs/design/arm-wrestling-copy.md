# TG14: arm-wrestling copy (cowboy Shirpaz)

TG14 · 2026-10-27 · Yotam Carmeli. Spec: `docs/specs/arm-wrestling.md`, section "Copy". Speaker for every dialogue line is cowboy Shirpaz (`670f79e3`), feminine first person as in her own line "באתי לכבוש יצאתי כבושה". The player is addressed only in unmarked forms (impersonal plural, unvocalized past "נזרקת", "לך", "בינך"). Limits are characters including spaces. A "line" is about 45 Hebrew characters (the TG5 wrap test), so 1 line ≤ 45 and 2 lines ≤ 90, word-wrapped at 45. English was wrap-tested at the same 45, which is stricter than the font needs.

## Challenge and choices

| key | he | en | limit check |
|---|---|---|---|
| AW_CHALLENGE | הורדת ידיים. מורידים לי את היד, ושקית ההפתעה עוברת ידיים. מתחת לשולחן. | Arm wrestling. Pin my hand, and the surprise bag changes hands. Under the table. | ≤ 2 lines: he 70 (2 lines), en 80 (2 lines) |
| AW_CHOICE_PLAY | בואי נראה | Bring it | ≤ 12: he 9, en 8 |
| AW_CHOICE_LATER | לא עכשיו | Not now | ≤ 12: he 8, en 7 |
| AW_LATER | השולחן לא בורח. גם השקיות לא. | The table's staying put. So are the bags. | 1 line: he 29, en 41 |
| AW_BUSY | לא באמצע השיר. מול חד קרן שרה אין לי סיכוי. | Not mid-song. No beating a singing unicorn. | 1 line: he 43, en 43 |

## How-to card

| key | he | en | limit check |
|---|---|---|---|
| AW_HOWTO_1 | צהוב על הקצב: דוחפים | Yellow on the beat: push | ≤ 36: he 20, en 24 |
| AW_HOWTO_2 | כחול כשהיא נדרכת: מחזיקים | Blue when she tenses: brace | ≤ 36: he 25, en 27 |
| AW_HOWTO_START | צהוב: מתחילים · כחול: חזרה | Yellow: start · Blue: back | ≤ 36: he 26, en 26 |

## In the bout

| key | he | en | limit check |
|---|---|---|---|
| AW_GO | יאללה! | GO! | ≤ 8: he 6, en 3 |
| AW_PERFECT | מושלם! | PERFECT! | ≤ 8: he 6, en 8 |
| AW_GOOD | יפה | GOOD | ≤ 8: he 3, en 4 |
| AW_SLIP | החלקה | SLIP | ≤ 8: he 5, en 4 |
| AW_BLOCK | חסימה! | BLOCKED! | ≤ 8: he 6, en 8 |
| AW_HIT | אאוץ' | OOF | ≤ 8: he 5, en 3 |
| AW_TAUNT | רודיאו קצר, אה? | Short rodeo, huh? | ≤ 22: he 15, en 17 |
| AW_STRAIN | תחזיקו לי את הכובע! | Somebody hold my hat! | ≤ 22: he 19, en 21 |

## End cards

| key | he | en | limit check |
|---|---|---|---|
| AW_WIN_CARD | כבושה! | Conquered! | ≤ 16: he 6, en 10 |
| AW_LOSE_CARD | נזרקת מהאוכף | Bucked off | ≤ 16: he 12, en 10 |
| AW_TIMEUP | נגמר הזמן | Time's up | ≤ 16: he 9, en 9 |

## Win lines (she lost and hands the bag over; keys kept, rotating 1 → 2 → 3)

| key | he | en | limit check |
|---|---|---|---|
| BAGS_SHIRPAZ_COWBOY_GIFT_1 | מגיע לך. השקית שלך. מה שיש בפנים, זה כבר בינך לבין השקית. *(TG14: reworded)* | You earned it. The bag's yours. What's inside is between you and the bag. *(TG14: reworded)* | 1–2 lines: he 57 (2 lines), en 73 (2 lines) |
| BAGS_SHIRPAZ_COWBOY_GIFT_2 | עוד אחת? תמיד יש עוד אחת. הבאתי לאירוע ארגז אחד, והוא עדיין לא נגמר. לא בדקתי למה. ולא אבדוק. *(unchanged)* | Another one? There's always another one. I brought one box to the burn and it still hasn't run out. I haven't checked why. I won't. *(unchanged)* | 1–2 lines: **over**, he 93 (3 lines), en 131. Kept as is per the brief; it already ships at this length |
| BAGS_SHIRPAZ_COWBOY_GIFT_3 | אומרים שיש פה עוד שירפז, חד קרן, שגובה מראש. אצלי משלמים ביד. ככה יודעים להבדיל בינינו. *(TG14: reworded)* | They say the unicorn Shirpaz charges up front. Me, you pay by hand. Big difference. *(TG14: reworded)* | 1–2 lines: he 87 (2 lines), en 83 (2 lines) |

## Loss lines (she teases and invites a rematch)

| key | he | en | limit check |
|---|---|---|---|
| AW_LOSE_1 | נופלים מהסוס, עולים בחזרה. | Fall off the horse, get back on. | 1 line: he 26, en 32 |
| AW_LOSE_2 | השקית נשארת אצלי. היא לא מתלוננת. | The bag stays with me. It's not complaining. | 1 line: he 33, en 44 |
| AW_LOSE_3 | באתי לכבוש. לפעמים זה אפילו עובד. | I came to conquer. Sometimes it even works. | 1 line: he 33, en 43 |

## Notes

- **Old win-line text, for the diff.** GIFT_1: שקית הפתעה בשבילך. בפלאיה לא סוחרים, מעניקים. זה עיקרון. השני מתוך עשרה. / A surprise bag for you. On the playa we don't trade, we gift. It's a principle. Number two of ten. GIFT_3: אומרים שיש פה עוד שירפז, חד קרן, שגובה שתי שקיות מראש. פה זה בחינם. ככה יודעים להבדיל בינינו. / They say there's another Shirpaz here, a unicorn, who charges two bags up front. Here it's free. That's how you tell us apart.
- **Style.** ASCII geresh in "אאוץ'" and ASCII "·" separator on the how-to card, as in the rest of the game. "חד קרן" with a space, as in `bags-copy.md`. Pop words in English are upper case, end cards in title case. Only the pop words, GO, STRAIN and the win card carry "!"; her dialogue lines don't.
- **May not land on a skim.** "כבושה!" on the win card and LOSE_3 call back her own line "באתי לכבוש יצאתי כבושה"; the English shows her line in Hebrew, so the callback only lands in Hebrew. "עוברת ידיים. מתחת לשולחן" is literal (the spool table) and also the under-the-table deal, the light baggie wink of rev 3, as are GIFT_1 ("what's inside is between you and the bag") and LOSE_2. TAUNT and LOSE_CARD are rodeo (the rider thrown early); "משלמים ביד" in GIFT_3 is payment by arm-wrestling.
