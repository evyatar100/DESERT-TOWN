Noam Peretz | 2026-10-27 | TG10 planetarium narration classification

Source: `docs/source/planetarium-kusomo-source.md` (verbatim export of the founder's Google Doc; the PDF copy `external_files/פלנטריום קוסומו ושאריות.pdf` was read page by page and matches it). Line numbers below are that file's.

This file is the single source of truth for the on-screen and aligned narration. The passage block below is byte-identical to the list Claudet sent Kerem (ticket TKT-20261027-001044-remote-dt-game, P01..P13). Only the line endings differ: Claudet's scratch file uses CRLF, and this file uses LF. Converters and tests parse the `## Spoken passages` block with `^### (P\d\d): (.*)$` followed by exactly one text line.

## Rules

| Rule | Decision |
|---|---|
| Spoken | A plain paragraph of the script, outside any `[...]`, after the equipment list. Each paragraph is one passage, in source order. |
| Not spoken | The doc title, the equipment list, every `[...]` direction or section label, and the inline pronunciation hints. |
| Pronunciation hints | Delete the space before the hint together with the bracketed hint: regex ` \[(?:מבוטא [^\]]+\|rotter)\]` replaced by nothing. The word before the hint is kept unchanged (נורדנשטאר, כף, הפרסאידים, רוטר). The space after the hint stays, so exactly one space separates the neighbours. Example: `נורדנשטאר [מבוטא Norden-shtar] בשיא` becomes `נורדנשטאר בשיא`. |
| Other text | No other character changes: punctuation, quotes (`"`), dashes (`–`, `-`), the stray `התגייר ,עלה` spacing, Latin words and digits stay as written. Trailing whitespace at the end of a source line is not text (P12's two trailing spaces are dropped). |
| Labels | A passage's label is its section label without brackets. Labels are metadata for the timing file's `section` field and are never shown on screen. |
| Verified | A script check rebuilt all 13 passages from the source lines with the rule above. All 13 equal Claudet's text byte for byte, and P12 differs only by the dropped trailing spaces. |

## Spoken passages (13)

| ID | Source line | Words | Section |
|---|---|---|---|
| P01 | 25 | 57 | מבוא/כניסה |
| P02 | 29 | 59 | חלק 1, כניסה לאווירה עם מוזיקת עולם/חלל ברקע, אולי קצת רעשים של מדורה |
| P03 | 33 | 30 | חלק 2 – הירח |
| P04 | 35 | 68 | חלק 2 – הירח |
| P05 | 37 | 55 | חלק 2 – הירח |
| P06 | 41 | 105 | חלק 3 - כוכב הצפון |
| P07 | 45 | 116 | חלק 4 – מאדים |
| P08 | 47 | 35 | חלק 4 – מאדים |
| P09 | 51 | 71 | חלק 5 - כוכב בולט כלשהו - לווין של פייסבוק |
| P10 | 53 | 49 | חלק 5 - כוכב בולט כלשהו - לווין של פייסבוק |
| P11 | 57 | 16 | מעברון |
| P12 | 61 | 168 | חלק 6 – מטאורים וסוף העולם |
| P13 | 65 | 30 | אחרי ההפעלה מחדש (after the recording restarts) |

### P01: מבוא/כניסה
ברוכים הבאים לפלנטריום האוויר הפתוח של מחנה Kusumo ושאריות. המופע הינו מופע אור-קולי תלת מימדי. אם ידועה לכם בעיה בריאותית המונעת מכם השתתפות בפעילות זו יש לצאת מהאולם דרך דלת החירום המסומנת באור ירוק בקצה האחורי של האולם. נא לשכב בנוח, עוד דקות אחדות יתחיל הסיור. הנכם מתבקשים לכבות טלפונים ניידים, לשמור על השקט ולהישמע להוראות הסדרנים.

### P02: חלק 1, כניסה לאווירה עם מוזיקת עולם/חלל ברקע, אולי קצת רעשים של מדורה
מאז שחר האנושות נשא האדם את עיניו לכוכבים. חיפש תשובות, העלה תהיות לגבי המרקע השחור והאינסופי שניצב מול עיניו. בגלקסיה שלנו יש בין 200 ל 400 מיליארד כוכבים, וישנן מאות מיליארדי גלקסיות ביקום. אנחנו בעצם טיפה קטנה באוקיינוס אינסופי שמתפרש ברגעים אלה מול עיניכם. היום, נצא למסע וירטואלי בין כוכבים ונעמיק את הידע שלכם במיצג המלהיב ששמו – החלל.

### P03: חלק 2 – הירח
שאו עיניכם תחילה לכיוון העצם הידוע לכל ילד בתור "הירח". רבות נכתב אודות הירח, אך גילויים חדשים ומרעישים של חוקרי אסטרונומיה ממכללת יבניאל-עילית מטילים ספק על רוב המידע הידוע לנו.

### P04: חלק 2 – הירח
על פי המחקר, שפורסם לא מזמן בכתב העת Nature Astrology, הירח אינו קיים באמת והוא בעצם תוצר של אשליה אופטית הנגרמת משבירת אור השמש ע"י גזים מיוחדים באטמוספרה. עובדה זו מעלה עוד ספקות לגבי הנחיתה המתוקשרת של ארה"ב על הירח בחללית אפולו 11 בשנת 1969, ומחזקת את העדויות כי הצילומים של הנחיתה בוימו באולפן בהוליווד כחלק מתעמולה אמריקאית שנועדה להדגים עליונות טכנולוגית על ברית המועצות במהלך המלחמה הקרה.

### P05: חלק 2 – הירח
עוד על פי כתב העת, החוקרים התחקו אחר מקור השם "הירח" וגילו כי מקורות פרסיים עתיקים ידעו על הגזים והצליחו לאסוף מהן דגימה. רוב המידע האנליטי שאספו נאבד אך אחת העדויות דיברה על תכונה של ארומה איומה וצורבת של הגזים, ועל כן קראו לגזים "fa", אשר בתרגום לעברית הוא "היה ריח" שעם השנים התקצר ל"הירח".

### P06: חלק 3 - כוכב הצפון
עוד עצם בולט ברקיע הוא כוכב הצפון. כוכב זה נתגלה בשנת 1942 ע"י אסטרונום נאצי בשם ארנולד פון נורדנשטאר בשיא מלחמת העולם השנייה. ישנה אגדה אורבנית המדברת על זה שכוכב זה תמיד נמצא בצפון אך מקור השם הוא תרגום ישיר של שם האסטרונום בלבד. קל להפריך את האגדה, מכיוון שכדור הארץ מסתובב ועל כן אין באמת כוכב שתמיד יופיע מצפון כל נקודה על כדור הארץ. קוריוז מעניין הוא שאותו אסטרונום בעקבות המלחמה החליט כי חיי הכוכבים איבדו את קסמם, התגייר ,עלה לישראל ב-1948 על ספינת המעפילים אקסודוס והקים בבוא העת ממניעים ציוניים את רשת המסעדות קפולסקי הידועה לשימצה שלימים נסגרה בשל לחצים פוליטים של הממשלה.

### P07: חלק 4 – מאדים
כוכב לכת נוסף בשמי ארצינו בתקופה זו של השנה הוא כוכב מאדים, וניתן לזהותו ע"י הצבע האדום האופייני לו כל כך. מאדים הוא הכוכב הרביעי מהשמש, ומוכר בשמו הנוסף Mars, על שם אל המלחמה הרומי. באסטרולוגיה הוא מקושר לאנרגיה כועסת, ואין זה בכדי. הרומים קישרו את צבעו האדום הנגרם מכמות גבוהה של תחמוצות ברזל באדמת הכוכב לווסת הנשית, ועל כן הרבו להעניק לכוכב תכונות נוספות אשר התרבות הפטריארכלית קישרה עם הווסת כגון כעס, חוסר עצבים והרס. דוגמא נוספת לקשר היא הימצאותו של הר הגעש הגבוה ביותר בכל כוכבי הלכת של מערכת השמש על מאדים, שמו בלטינית – Olympus Mons. השם מקושר בתרבות הרומית ל- Mons Pubis, הלא הוא כף הערבה, הגבעה המעוגלת מעל איבר המין הנשי.

### P08: חלק 4 – מאדים
בני-האדם לא הצליחו לפענח עד היום כיצד להגיע ולהתיישב על כוכב מאדים. לאחרונה נאס"א גייסה למשימה אסטרונאוטיות רבות, תוך הבנה שאף בן-אדם לא התגבר על האתגרים אך כנראה שבנות אדם ימצאו את דרך המלך לנחלה.

### P09: חלק 5 - כוכב בולט כלשהו - לווין של פייסבוק
שימו לב לאן הסדרן מכוון כעת את הסמן. עצם בוהק זה אינו כוכב או מערכת כוכבים רחוקה אלא לווין ריגול סודי של חברת פייסבוק העולמית. לווין זה נועד להקליט את כל השיחות וההודעות שלנו בכל רגע נתון באפליקציית וואצאפ ולהעביר את המידע לפרסום בפייסבוק, למרות שהחברה מתכחשת לקשר זה בין שתי הרשתות החברתיות ומפרסמת שאפליקציית וואצאפ מוצפנת מקצה לקצה. אפילו את הקלטה זו, המשודרת גם בלייב, הלוויין מקליט ברגעים אילו ממש.

### P10: חלק 5 - כוכב בולט כלשהו - לווין של פייסבוק
באתר החדשות הבטחוניות רוטר התפרסם לא מזמן כי הסיבה האמיתית לנפילותן של כלל מערכות חברת פייסבוק לפני מספר ימים היא לכאורה מתקפת טילים על אותו לווין מלוויין מתחרה מתוצרת כחול לבן של חברת רמי לוי תקשורת וחלל, בניסיון לשבור את שוק הפרסום המוכוון ולהציע את אותו שירות בחצי מחיר.

### P11: מעברון
אנו מתקרבים כעת לסוף המופע. בסיומו הנכם מתבקשים להישאר ישובים עד קבלת הסימון מהסדרן בכניסה, תודה.

### P12: חלק 6 – מטאורים וסוף העולם
התבוננו כעת לכיוון קבוצת כוכבים זו. כנראה שאינכם רואים דבר בכיוון המסומן. ירידה לאיזור מצפה רמון בזמן מטר מטאורים הפרסאידים במטרה לצפות בכוכבים נופלים היא כבר מסורת לאומית. מה שהעין האנושית שלנו לא מסוגלת לתפוס ברגעים אילו ממש הוא מטר של עשרות מטאורים בדקה הזוהרים ממעל מעל ראשכם. המטאורים המכונים Firyuza על פי גלגל המזלות האוזבקי זוהרים בקרינה באורכי גל שלא בטווח האור הנראה ועל כן אינכם מסוגלים לראותם. על פי תחזיותיה של האסטרולוגיה האוזבקית, כדור הארץ ייחרב ע"י התקרבות יתר של המטאורים לכדור הארץ והצתת האטמוספירה כתגובה לקרינה הרבה שתיווצר מהתלקחות המטאורים בשכבת האוזון. על פי התחזיות, מאורע זה עתיד לקרות ממש בעוד דקה וכמה שניות מרגע זה, וזהו זמן טוב לרגע של התבוננות פנימית. אנא קחו רגע לחשוב על מה עשיתם בחייכם ומי הם האנשים שהשאירו חותם על חייכם. אנא הישמעו להוראות ושמרו על הסדר והרוגע בזמן שאנו מחכים לפגיעה. בשם פלנטריום האוויר הפתוח של מחנה Kusumo ושאריות אנו מודים לכם שבחרתם להצטרף אלינו למסע זה ומצטערים שמופע זה צריך להתקצר על חשבונכם. מקווים לראותכם בעתיד.

### P13: אחרי ההפעלה מחדש (after the recording restarts)
אם הינכם שומעים הודעה זו, משמע העולם לא הוחרב. לא כל התחזיות מדוייקות וכנראה נותרו לנו עוד כמה ימים, שבועות, חודשים או שנים לחיות. חיו כל רגע כאילו זה הסוף...

## Excluded: not spoken, never on screen, never aligned (22)

| ID | Source line | Item | Why |
|---|---|---|---|
| X01 | 11 | `**פלנטריום :**` | Document title. |
| X02 | 13 | `ציוד :` | Equipment-list heading (production note). |
| X03 | 15 | `מרק` | Equipment list. |
| X04 | 16 | `רמקול של העגלה או רמקול נוסף` | Equipment list. |
| X05 | 17 | `מחצלות וכריות` | Equipment list. |
| X06 | 18 | `לייזר פוינטר` | Equipment list. |
| X07 | 19 | `הקלטה מוכנה להשמעה בפלאפון טעון.` | Equipment list. |
| X08 | 21 | `[לפני שמתחילה ההקלטה מושיבים אותם ומחלקים להם מרק "בראשיתי" …]` | Pre-show direction for the live crew (soup, seating, the "shows start on the hour" bluff). |
| X09 | 23 | `[מבוא/כניסה]` | Section label, used as P01's `section`. |
| X10 | 27 | `[חלק 1, כניסה לאווירה עם מוזיקת עולם/חלל ברקע, אולי קצת רעשים של מדורה]` | Section label plus a sound direction, used as P02's `section`. The music is in the recording (see Audio facts). |
| X11 | 31 | `[חלק 2 – הירח]` | Section label (P03–P05). |
| X12 | 39 | `[חלק 3 - כוכב הצפון]` | Section label (P06). |
| X13 | 41 | `[מבוטא Norden-shtar]` | Inline pronunciation hint inside P06, stripped by the Rules. |
| X14 | 43 | `[חלק 4 – מאדים]` | Section label (P07–P08). |
| X15 | 45 | `[מבוטא Kef]` | Inline pronunciation hint inside P07, stripped. |
| X16 | 49 | `[חלק 5 - כוכב בולט כלשהו - לווין של פייסבוק]` | Section label (P09–P10). |
| X17 | 53 | `[rotter]` | Inline transliteration hint inside P10, stripped. |
| X18 | 55 | `[מעברון]` | Section label (P11). |
| X19 | 59 | `]חלק 6 – מטאורים וסוף העולם]` | Section label (P12), with a malformed opening bracket. See F07. |
| X20 | 61 | `[מבוטא perseidim]` | Inline pronunciation hint inside P12, stripped. |
| X21 | 63 | `[פה עוצרים את ההקלטה והסדרן נכנס … "אז בואו נחזיק ידיים לקראת המוות ההולך ובא ונספור אחורה 10 שניות. 10…1…" בשלב זה מפעילים מחדש את ההקלטה]` | Live usher direction, including the quoted countdown. See F01 and F02. |
| X22 | 67 | `[שיר סיום intergalactic של beastie boys לתת להם חזרה אנרגיות להמשך הלילה]` | Closing-song direction. See F03. |

Lines 1–7 of the source file are the repo's wrapper (title and provenance note), not the founder's document, and are not counted.

## Flagged ambiguities (12), each decided

| ID | Where | Ambiguity | Decision (reversible) |
|---|---|---|---|
| F01 | X21 | The quoted countdown ("אז בואו נחזיק ידיים … 10…1…") is in quotation marks, so it reads like a spoken line. | **Not narration.** It is the live usher's line, spoken while the recording is stopped. The recording cannot contain it by construction, and showing it would put words on screen with no audio, which the brief forbids. The game honours the staging visually: the digits 10..1 appear in the last 10 s of the silent gap (digits only, no words), then a sparkler ring stands in for the fireworks. If Kerem hears it in the audio, it moves to a new passage P12b with no code change. |
| F02 | X21 | The stop and restart of the recording. | **The break is already in the recording**: sound falls below −45 dB from about 474 s, and the samples are exact zeros from 491.70 to 533.72 s in the mp3 (489.21–533.72 s in the ogg the game plays); P13's voice starts at about 534.5 s. Roughly a minute of quiet, which matches P12's own "בעוד דקה וכמה שניות". The game never stops the audio. It plays straight through and shows the end-of-the-world visuals during the gap (see the spec, Visual). |
| F03 | X22 | Beastie Boys "Intergalactic" closing song. | **No song.** It is copyrighted, and the recording ends after P13 (measured ~23 s of sound after the gap, about P13's length plus a short tail). After the audio ends, the map's own music returns and Eyal's after-show line is the "energy back" beat. A `CLOSING_BGM` constant (nil) lets a cleared track be added later. |
| F04 | P09 | "שימו לב לאן הסדרן מכוון כעת את הסמן" refers to a live usher with a laser pointer. | **Kept verbatim** (it is in the recording). The game draws a red pointer dot that circles the satellite, standing in for the usher. |
| F05 | P01, X08 | "עוד דקות אחדות יתחיל הסיור" goes with the crew's "a few more minutes" bluff. | Kept verbatim. The game adds no wait: the joke lands as written. |
| F06 | P11 | "עד קבלת הסימון מהסדרן בכניסה": there is no usher in the game. | Kept verbatim. No in-game action. |
| F07 | X19 | `]חלק 6 …]` opens with `]`. | It is a label: the closing bracket and its position make that clear. P12's `section` is the label without brackets. |
| F08 | P13 | The source has no label for the after-restart paragraph. | It keeps Claudet's synthesized label "אחרי ההפעלה מחדש (after the recording restarts)" and is marked synthesized here. Labels are never shown. |
| F09 | P12 | The source line ends with two spaces. | Not text. Dropped, as Claudet did. |
| F10 | X01 | Could the recording open by saying "פלנטריום"? | Not narration. If Kerem hears extra speech, it is reported in `discrepancies.md`, and the founder decides whether it becomes a passage. |
| F11 | P01, P12 | The source spells the camp "Kusumo", while repo docs say "Kusomo"/"קוסומו". | The narration keeps "Kusumo" byte-exact. Game copy (Eyal, Hagar) uses the existing "קוסומו". |
| F12 | whole | The "about ten minutes" duration. | **Measured: 558.14 s (9 min 18 s)**, from 21,369 MPEG frames at 320 kbps, 44.1 kHz stereo. The warning keeps "בערך עשר דקות". Recheck it against Kerem's ogg duration when the ogg arrives. |

## Audio facts (measured 2026-10-27 from `external_files/planetarium.mp3`)

Measured with Python `soundfile` (libsndfile 1.2.2) as RMS in 0.25 s windows. These are anchors for the placeholder only, not alignment.

| Span (s) | What | Matches |
|---|---|---|
| 0.0–29.2 | speech, quiet bed | P01 (57 words) |
| 29.2–34.0 | near-silence | pause |
| 34.0–71.0 | speech over a music bed | P02 (59 words) |
| 71.0–76.5 | near-silence | pause |
| 76.5–~466 | continuous speech over a music bed (noise floor about −27 dB, never silent) | P03–P12 (713 words) |
| ~460–474 | fade-out | end of P12 / bed |
| ~474–491.70 | below −45 dB, not yet zero (ogg: zeros from 489.21) | the stop/restart gap begins |
| 491.70–533.72 | **digital silence (exact zeros) in the mp3, 42.0 s**; the ogg has exact zeros 489.21–533.72 (44.5 s) | the stop/restart gap |
| 533.72–~534.5 | sound returns | lead-in to P13 |
| ~534.5–558.1 | sound, speech-like envelope | P13 (30 words) plus a tail of up to ~8 s, content unknown |
