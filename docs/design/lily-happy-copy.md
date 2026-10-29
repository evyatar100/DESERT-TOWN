Yotam Carmeli | 2026-10-29 | TG64 "מה ישמח את לילי?": final copy for every LILY_* key

Spec: `docs/specs/lily-happy-quest.md` (D4, D5, D7, D9, "Translation keys"). Content: Michal, `docs/specs/lily-happy-concept.md`, recast to Noam's D5 characters.

## Conventions

- Lily (`648b924a`) is feminine throughout (founder ruling): יודעת, רושמת, אוהבת, צריכה, חייבת.
- The player is addressed in the plural imperative (תבדקו, תשאלו, תנו) or impersonal plural (מספרים, מסובבים), never singular.
- Camp speakers keep the gender of their charset and metadata: Mor (shy young man) masculine; Bakina (NPC, female sprite) feminine; Polaroider (bearded photographer) masculine; Changa (a dog, "הכלבה") feminine. Neta Lubnash has no gender in the metadata, so Neta's lines use only gender-unmarked first person (past tense, גאה).
- Wheel seat lines (C/HALF/N) can be spoken by any of the 6 seats, so they are gender-neutral first person or impersonal. REACT_1..5 follow any order of camps, so they never name or gender the person reported.
- "הכל" (not הכול) everywhere in this quest, to match Lily's own line "הכל בסדר סעמק" printed right before. MOOP = חשל"ש (dec:tg-32). Gershayim and geresh are ASCII `"` `'`, ellipsis is ASCII `...`, the separator in control hints is ` · `, as in TUTA/DJRUSH.
- Running thread: Lily treats the quest as a survey (סקר, מדגם מייצג, נרשם בסקר, הסקר הושלם). The idea "complaining together is being together" stays under the text: only REALIZE (Michal's quoted line) and IDLE come near it, and nobody states it as a lesson.
- Limits: dialogue ≤ 90 characters (2 message lines of ~45). Strip line 1 is name + C/HALF, so C ≤ 22; strip line 2 (F, N, COMP, MOOP, NOCOMP*) ≤ 44 and measured in Handjet 22 px under the 480 px strip text width (widest: N4 he 311 px, en 464 px). Card lines measured against the 400 px card (REALIZE wraps to 2 lines). `{1}`/`{2}` are `_INTL` placeholders.
- `en`: written English for every key (the camp characters' own default lines stay he=en, as they already ship).
- Default lines play first (hook `after_talk`), so each speaker's first key continues their own line.
- A1 speakers, checked in metadata: Shorty (f9348fd0, "גבוה מאוד ושובב") masculine; Loooo (6b53f14c, "כלבה", a dog) feminine; Sea Turtle (8d654949, "כשאני הייתי קטן") masculine; Razit (64aeedbe, "מביאה אור") feminine. Gufak (1be29576) and Sushi (b201fb8a) have no gender in their metadata, so, as with Neta, their lines use only gender-unmarked forms (past tense, first person plural). Gufak's REPORT is about his meeting, not him.
- "אספה" (Academy spelling of אֲסֵפָה), not "אסיפה".



## Lily: the ask

| key | speaker | he | en | limit |
|---|---|---|---|---|
| LILY_MIRROR | Lily | רגע, זאת אני? לא נחשב. אני לא מדגם מייצג. | Hold on, is that me? Doesn't count. I'm not a representative sample. | ≤ 90: 41 |
| LILY_INTRO_1 | Lily | החול בגרביים, הכוכבים מבולגנים, והשקט שלי מתחיל רק בשש בבוקר. | Sand in my socks, the stars are a mess, and my quiet starts at six a.m. | ≤ 90: 61 |
| LILY_INTRO_2 | Lily | ומסביב כולם מנצנצים ומתחבקים. מה הם יודעים שאני לא יודעת? | And everyone around me sparkles and hugs. What do they know that I don't? | ≤ 90: 57 |
| LILY_INTRO_3 | Lily | תבדקו לי מה משמח אנשים פה. אולי אעתיק. | Find out what makes people happy here. Maybe I'll copy it. | ≤ 90: 38 |
| LILY_ACCEPT_Q | Lily | תעשו לי סקר קטן בקאמפים? | Run a little survey of the camps for me? | ≤ 90: 24 |
| LILY_ACCEPT_YES | choice | אני אברר | I'll find out | ≤ 14: 8 |
| LILY_ACCEPT_NO | choice | לא עכשיו | Not now | ≤ 14: 8 |
| LILY_GO_1 | Lily | יופי. תשאלו מה עושה להם טוב, ותרשמו הכל. אני אחכה פה, בסדר גמור. | Good. Ask what does them good, and write it all down. I'll wait here. Totally fine. | ≤ 90: 64 |
| LILY_GO_CAMPS | Lily | תלונות יש בכל מקום. מעל מי שמתלונן יש "!". הכי קרוב: הפלאיה, תור הקרח ופינת קים. | Complaints are everywhere. Anyone with one has a "!" over them. Closest: the Playa, the ice line, Kim corner. | ≤ 90: 80 (A1) |
| LILY_DECLINE | Lily | בסדר. גם זה בסדר. הכל בסדר. | Fine. That's fine too. Everything's fine. | ≤ 90: 27 |

## Lily: back too early

| key | speaker | he | en | limit |
|---|---|---|---|---|
| LILY_NOT_YET | Lily | עוד לא? אז כולם מאושרים חוץ ממני. מעולה. סעמק. | Not yet? So everyone's happy except me. Great. Damn. | ≤ 90: 46 |
| LILY_PROGRESS | Lily | בסקר יש בינתיים {1} מתוך 4. | So far the survey has {1} of 4. | ≤ 90: 27 |
| LILY_LEFT | Lily | חסרים לי עדיין: {1}. | Still missing: {1}. | ≤ 90: 20 |
| LILY_CAMP_KUSOMO | list | קוסומו | Kusomo | ≤ 16: 6 |
| LILY_CAMP_CIRCUS | list | אמאל'ה ואבאל'ה | Mom-and-Dad | ≤ 16: 14 |
| LILY_CAMP_CATS | list | קאמפ החתולים | the Cats camp | ≤ 16: 12 |
| LILY_CAMP_ESCHER | list | הבית של אשר | Escher's house | ≤ 16: 11 |
| LILY_CAMP_GLASS | list | גן הזכוכית | the Glass Garden | ≤ 16: 10 |

## Lily: ready, the wheel

| key | speaker | he | en | limit |
|---|---|---|---|---|
| LILY_SKEPTIC_1 | Lily | ארבע תלונות? אולי פשוט אף אחד לא ניסה לתקן להם. | Four complaints? Maybe nobody ever tried fixing things for them. | ≤ 90: 47 |
| LILY_SKEPTIC_2 | Lily | תנו לכל אחד בדיוק מה שביקש. אז נראה מי מתלונן. | Give each of them exactly what they asked for. Then we'll see who complains. | ≤ 90: 46 |
| LILY_WHEEL_Q | Lily | בניתי לזה גלגל. גלגל האושר. מסובבים? | I built a wheel for this. The Wheel of Happiness. Shall we spin? | ≤ 90: 36 |
| LILY_WHEEL_YES | choice | לסובב את גלגל האושר | Spin the Wheel of Happiness | ≤ 20: 19 |
| LILY_WHEEL_LATER | choice | אחר כך | Later | ≤ 14: 6 |
| LILY_WHEEL_QUIT | Lily | עצרתם באמצע? הגלגל לא נעלב. הוא היחיד פה שלא מתלונן. | Stopped halfway? The wheel isn't offended. It's the only one here that doesn't complain. | ≤ 90: 52 |
| LILY_LATER | Lily | בסדר. הגלגל יחכה. הוא בנוי לחזור לאותה נקודה. | Fine. The wheel will wait. It's built to come back to the same spot. | ≤ 90: 45 |

## Lily: after the quest

| key | speaker | he | en | limit |
|---|---|---|---|---|
| LILY_IDLE | Lily | השמש פה מטורפת. איזה כיף שיש עם מי להתלונן. | The sun here is insane. So nice to have someone to complain with. | ≤ 90: 43 |
| LILY_REPLAY_Q | Lily | עוד סיבוב בגלגל? אולי הפעם זה יעבוד. סתם. אבל בואו. | Another spin? Maybe this time it'll work. Kidding. Come on, though. | ≤ 90: 51 |
| LILY_REPLAY_YES | choice | לסובב | Spin | ≤ 14: 5 |
| LILY_REPLAY_NO | choice | לא עכשיו | Not now | ≤ 14: 8 |
| LILY_REPLAY_AFTER | Lily | {1} מתוך 6 מאושרים. חצי גלגל. הכל בסדר. | {1} of 6 happy. Half a wheel. Everything's fine. | ≤ 90: 39 |
| LILY_REPLAY_AFTER_LOW | Lily | {1} מתוך 6 מאושרים. פחות מחצי גלגל. עדיין הכל בסדר. | {1} of 6 happy. Less than half a wheel. Still fine. | ≤ 90: 47 |

## Kusomo: Mor (a715ed37), masculine, after his line "ואהבת לרעך כמוך"

| key | speaker | he | en | limit |
|---|---|---|---|---|
| LILY_KUSOMO_1 | Mor | אז התחלתי מהחלק של "כמוך". באתי למדבר להתחבר לעצמי. | So I started with the "as yourself" part. I came to the desert to connect with myself. | ≤ 90: 51 |
| LILY_KUSOMO_2 | Mor | התחברנו. עברנו על הכל. מסתבר שאני בן אדם שבעיקר רוצה מזגן. | We connected. We went through everything. Turns out I mostly want air conditioning. | ≤ 90: 58 |
| LILY_KUSOMO_3 | Mor | עכשיו אני אוהב את השכן שלי כמוני. גם הוא רוצה מזגן. | Now I love my neighbour as myself. He wants air conditioning too. | ≤ 90: 51 |
| LILY_KUSOMO_AGAIN | Mor | עדיין אין מזגן. השכן הציע לנשוף עליי. אני שוקל. | Still no air conditioning. My neighbour offered to blow on me. I'm considering it. | ≤ 90: 47 |

## Mom-and-Dad inside: Neta Lubnash (a4012984), gender-unmarked first person, after "אימוש חמודה שלי"

| key | speaker | he | en | limit |
|---|---|---|---|---|
| LILY_CIRCUS_1 | Neta | אין מי שישמע. תכננתי לילדים פסטיבל מושלם, והוא עבד. | Nobody's here to hear it. I planned the kids a perfect festival, and it worked. | ≤ 90: 51 |
| LILY_CIRCUS_2 | Neta | הם נהנים כל כך שהם לא חוזרים לקאמפ. אפילו לא בשביל חטיף. | They're having so much fun they don't come back to camp. Not even for a snack. | ≤ 90: 56 |
| LILY_CIRCUS_3 | Neta | חיכיתי להם עם קרם הגנה עד הזריחה. בסוף מרחתי את עצמי. פעמיים. | I waited up for them with sunscreen until sunrise. In the end I put it on myself. Twice. | ≤ 90: 61 |
| LILY_CIRCUS_AGAIN | Neta | עדיין לא חזרו. גאה בהם. הקרם כולו עליי. | Still not back. Proud of them. The sunscreen is all on me. | ≤ 90: 39 |

## Cats camp: Bakina (3dc31934), feminine, after "איפה המרפאה? יש לי כוויה"

| key | speaker | he | en | limit |
|---|---|---|---|---|
| LILY_CATS_1 | Bakina | מצאתי את המרפאה. יש שם חיבוקים וקרם הגנה. | I found the clinic. They have hugs and sunscreen. | ≤ 90: 41 |
| LILY_CATS_2 | Bakina | ביקשתי חובש. קיבלתי חיבוק ארוך ושאלה: מה הכוויה מנסה להגיד לי? | I asked for a medic. I got a long hug and a question: what is the burn trying to tell me? | ≤ 90: 62 |
| LILY_CATS_3 | Bakina | הכוויה אומרת "אאוץ'". זה כל מה שהיא אומרת. | The burn says "ouch". That's all it says. | ≤ 90: 42 |
| LILY_CATS_AGAIN | Bakina | עדיין כוויה. אבל עכשיו היא מחובקת. | Still a burn. But now it's been hugged. | ≤ 90: 34 |

## Escher's house: Polaroider (b3fb6767), masculine, after "תהנו מהרגע!"

| key | speaker | he | en | limit |
|---|---|---|---|---|
| LILY_ESCHER_1 | Polaroider | ביקשתי מהזריחה הסכמה לצלם אותה. היא לא ענתה. | I asked the sunrise for consent to photograph it. It didn't answer. | ≤ 90: 44 |
| LILY_ESCHER_2 | Polaroider | אז לא צילמתי. נהניתי מהרגע, כמו שאני אומר לכולם. | So I didn't shoot. I enjoyed the moment, like I tell everyone to. | ≤ 90: 48 |
| LILY_ESCHER_3 | Polaroider | הרגע נגמר ונשאר לי רק זיכרון. זה כמו תמונה, רק שאי אפשר להראות לאף אחד. | The moment's gone and all I have is a memory. A photo you can't show anyone. | ≤ 90: 71 |
| LILY_ESCHER_AGAIN | Polaroider | מחר אני מבקש שוב. הפעם השארתי לזריחה פתק. | Tomorrow I ask again. This time I left the sunrise a note. | ≤ 90: 41 |

## Glass Garden: Changa (661f55e6, a dog), feminine, after "האוווו האוווו"

| key | speaker | he | en | limit |
|---|---|---|---|---|
| LILY_GLASS_1 | Changa | כל האמנות פה נשרפת בסוף. זה כל הקטע. אבל זכוכית לא נשרפת. | All the art here burns at the end. That's the whole point. But glass doesn't burn. | ≤ 90: 57 |
| LILY_GLASS_2 | Changa | היא פשוט... קיימת. יללתי עליה כל הלילה. היא עדיין קיימת. | It just... exists. I howled at it all night. It still exists. | ≤ 90: 56 |
| LILY_GLASS_3 | Changa | ובכל זכוכית יש עוד כלבה שמייללת עליי בחזרה. גם היא לא מרוצה. | And in every pane there's another dog howling back at me. She's not happy either. | ≤ 90: 60 |
| LILY_GLASS_AGAIN | Changa | האוווו. גם הכלבה בזכוכית עדיין פה. אנחנו מייללות במשמרות. | Hawoooo. The dog in the glass is still here too. We howl in shifts. | ≤ 90: 57 |

## Camp toasts (no plate)

| key | speaker | he | en | limit |
|---|---|---|---|---|
| LILY_HEARD | narration | נרשם בסקר: {1} מתוך 4. | Logged in the survey: {1} of 4. | ≤ 90: 22 |
| LILY_HEARD_ALL | narration | 4 מתוך 4. הסקר מלא. חוזרים ללילי. | 4 of 4. The survey is full. Back to Lily. | ≤ 90: 33 |
| LILY_HEARD_EXTRA | narration | נרשם בסקר. כבר יש מספיק, אפשר לחזור ללילי. | Logged in the survey. That's already enough; you can head back to Lily. | ≤ 90: 42 (A1) |

## Payoff (D9)

| key | speaker | he | en | limit |
|---|---|---|---|---|
| LILY_REPORT_OPEN | narration | מספרים ללילי על הסקר, מההתחלה. | You tell Lily about the survey, from the start. | ≤ 90: 30 |
| LILY_REPORT_KUSOMO | narration | בקוסומו, מור התחבר לעצמו וגילה שהוא רוצה מזגן. | At Kusomo, Mor connected with himself and found out he wants air conditioning. | ≤ 90: 46 |
| LILY_REPORT_CIRCUS | narration | באמאל'ה ואבאל'ה, הפסטיבל של הילדים הצליח כל כך שהם לא חוזרים. | At Mom-and-Dad, the kids' festival worked so well they never come back. | ≤ 90: 61 |
| LILY_REPORT_CATS | narration | בקאמפ החתולים, בקינה ביקשה חובש וקיבלה חיבוק. | At the Cats camp, Bakina asked for a medic and got a hug. | ≤ 90: 45 |
| LILY_REPORT_ESCHER | narration | בבית של אשר, הזריחה לא הסכימה להצטלם. | At Escher's house, the sunrise wouldn't agree to be photographed. | ≤ 90: 37 |
| LILY_REPORT_GLASS | narration | בגן הזכוכית, צ'אנגה מייללת על אמנות שלא נשרפת. | In the Glass Garden, Changa howls at art that won't burn. | ≤ 90: 46 |
| LILY_REACT_1 | Lily | רגע. גם שם? תמשיכו. | Wait. There too? Keep going. | ≤ 90: 19 |
| LILY_REACT_2 | Lily | עוד אחת? חכו, אני רושמת. | Another one? Hold on, I'm writing this down. | ≤ 90: 24 |
| LILY_REACT_3 | Lily | שלוש. זה כבר דפוס. אני אוהבת דפוסים. | Three. That's a pattern now. I love a pattern. | ≤ 90: 36 |
| LILY_REACT_4 | Lily | ארבע. תמשיכו. כבר שתי דקות לא התלוננתי על כלום. | Four. Keep going. I haven't complained about anything for two minutes. | ≤ 90: 47 |
| LILY_REACT_5 | Lily | חמש. אני צריכה לשבת. זה לא החום. | Five. I need to sit down. It's not the heat. | ≤ 90: 32 (A1) |
| LILY_REPORT_WHEEL | narration | ואז גלגל האושר. שיא: {1} מתוך 6 מאושרים בבת אחת. סיבובים: {2}. | Then the Wheel of Happiness. Best: {1} of 6 happy at once. Laps: {2}. | ≤ 90: 62 |
| LILY_REACT_WHEEL | Lily | חצי גלגל? גם כשנותנים לכל אחד בדיוק מה שביקש? | Half a wheel? Even when everyone gets exactly what they asked for? | ≤ 90: 45 |
| LILY_REACT_WHEEL_LOW | Lily | פחות מחצי גלגל? גם זה ממצא. אני רושמת. | Less than half a wheel? That's a finding too. I'm writing it down. | ≤ 90: 38 |
| LILY_PAYOFF_1 | Lily | רגע. כולם? גם אלה שמנצנצים?... הכל בסדר סעמק. לא, באמת. הכל בסדר. | Wait. Everyone? Even the sparkly ones?... Everything's fine, damn. No, really. Fine. | ≤ 90: 65 |
| LILY_PAYOFF_2 | Lily | יש לי חול בגרביים. אני חייבת לספר למישהו. | I've got sand in my socks. I have to tell someone. | ≤ 90: 41 |
| LILY_PAYOFF_3 | narration | מה ישמח את לילי? הסקר הושלם. | What will make Lily happy? Survey complete. | ≤ 90: 28 |

## Wheel: title screen

| key | speaker | he | en | limit |
|---|---|---|---|---|
| LILY_W_TITLE | title | גלגל האושר | Wheel of Happiness | ≤ 16: 10 |
| LILY_W_HOW_1 | how | ג'ויסטיק ימינה/שמאלה: מסובבים את הגלגל | Joystick left/right: turn the wheel | ≤ 40: 38 |
| LILY_W_HOW_2 | how | צהוב: נותנים למי שמקדימה בדיוק מה שביקש | Yellow: give the one in front exactly what they asked for | ≤ 40: 39 |
| LILY_W_HOW_3 | how | למעלה: מתפשרים עם מי שממול | Up: compromise with the one opposite | ≤ 40: 26 |
| LILY_W_HOW_4 | how | למטה: זורקים את הבעיה | Down: throw the problem away | ≤ 40: 21 |
| LILY_W_HOW_GOAL | how | המטרה: 6 מאושרים מתוך 6 | Goal: 6 happy out of 6 | ≤ 40: 23 |
| LILY_W_HOW_PAUSE | how | כחול: עצירה | Blue: pause | ≤ 40: 11 |
| LILY_W_START | how | צהוב: מתחילים · כחול: חזרה | Yellow: start · Blue: back | ≤ 40: 26 |

## Wheel: the chain (C = bubble complaint, F = the fix, N = the new complaint; N11 wraps to C1)

| key | speaker | he | en | limit |
|---|---|---|---|---|
| LILY_W_C1 | strip | חם. | Hot. | ≤ 22: 3 |
| LILY_W_F1 | strip | מקימים צל. | Put up shade. | ≤ 30: 10 |
| LILY_W_N1 | strip | עכשיו לא רואים את השקיעה. | Now I can't see the sunset. | ≤ 40: 25 |
| LILY_W_C2 | strip | לא רואים שקיעה. | Can't see the sunset. | ≤ 22: 15 |
| LILY_W_F2 | strip | בונים מגדל תצפית. | Build a lookout tower. | ≤ 30: 17 |
| LILY_W_N2 | strip | יש תור לשקיעה. | There's a queue for the sunset. | ≤ 40: 14 |
| LILY_W_C3 | strip | יש תור. | There's a queue. | ≤ 22: 7 |
| LILY_W_F3 | strip | גיליון הרשמה מראש. | A sign-up sheet. | ≤ 30: 18 |
| LILY_W_N3 | strip | מי הביא ביורוקרטיה? באנו להשתחרר. | Who brought bureaucracy? We came to let go. | ≤ 40: 33 |
| LILY_W_C4 | strip | ביורוקרטיה. | Bureaucracy. | ≤ 22: 11 |
| LILY_W_F4 | strip | מבטלים את כל הכללים. | Scrap all the rules. | ≤ 30: 20 |
| LILY_W_N4 | strip | לקחו לי את הכיסא, ואין כלל להתלונן לפיו. | Someone took my chair, and there's no rule to complain under. | ≤ 40: 40 |
| LILY_W_C5 | strip | אין למי להתלונן. | No one to complain to. | ≤ 22: 16 |
| LILY_W_F5 | strip | מקימים ועדת תלונות. | Set up a complaints committee. | ≤ 30: 19 |
| LILY_W_N5 | strip | הוועדה מתכנסת באמצע הסט שלי. | The committee meets in the middle of my set. | ≤ 40: 28 |
| LILY_W_C6 | strip | ועדה באמצע הסט. | Committee mid-set. | ≤ 22: 15 |
| LILY_W_F6 | strip | הוועדה עוברת לרחבה. | Move the committee to the dance floor. | ≤ 30: 19 |
| LILY_W_N6 | strip | עכשיו כולם רוקדים, ולי אין קצב. | Now everyone's dancing, and I've got no rhythm. | ≤ 40: 31 |
| LILY_W_C7 | strip | אין לי קצב. | No rhythm. | ≤ 22: 11 |
| LILY_W_F7 | strip | סדנת ריקוד. | A dance workshop. | ≤ 30: 11 |
| LILY_W_N7 | strip | הסדנה מלאה באנשים שיש להם קצב. | The workshop is full of people with rhythm. | ≤ 40: 30 |
| LILY_W_C8 | strip | לכולם יש קצב חוץ ממני. | Everyone has rhythm but me. | ≤ 22: 22 |
| LILY_W_F8 | strip | מסיבה פרטית, רק בשבילך. | A private party, just for you. | ≤ 30: 23 |
| LILY_W_N8 | strip | מסיבה של אחד. איפה כולם? | A party of one. Where is everyone? | ≤ 40: 24 |
| LILY_W_C9 | strip | איפה כולם? | Where is everyone? | ≤ 22: 10 |
| LILY_W_F9 | strip | מזמינים את כל דזרטאון. | Invite all of Desert Town. | ≤ 30: 22 |
| LILY_W_N9 | strip | צפוף, ויש יותר מדי כוכבים. זה מקטין אותי. | Crowded, and too many stars. They make me feel small. | ≤ 44: 41 |
| LILY_W_C10 | strip | יותר מדי כוכבים. | Too many stars. | ≤ 22: 16 |
| LILY_W_F10 | strip | מכבים כמה כוכבים. | Switch off a few stars. | ≤ 30: 17 |
| LILY_W_N10 | strip | חושך. מישהו יכול להדליק את השמש? | Dark. Can someone switch on the sun? | ≤ 40: 32 |
| LILY_W_C11 | strip | תדליקו את השמש. | Switch on the sun. | ≤ 22: 15 |
| LILY_W_F11 | strip | מדליקים את השמש. | Switch on the sun. | ≤ 30: 16 |
| LILY_W_N11 | strip | חם. | Hot. | ≤ 40: 3 |

## Wheel: compromise, MOOP and nudges

| key | speaker | he | en | limit |
|---|---|---|---|---|
| LILY_W_HALF | strip | קיבלתי רק חצי. | I only got half. | ≤ 22: 14 |
| LILY_W_COMP_1 | strip | חצי צל: חם רק מצד אחד, ורואים חצי שקיעה. | Half shade: hot on one side, half a sunset. | ≤ 44: 40 |
| LILY_W_COMP_2 | strip | בס בלי מלודיה. נשמע כמו דופק של מישהו אחר. | Bass, no melody. Sounds like someone else's heartbeat. | ≤ 44: 42 |
| LILY_W_COMP_3 | strip | כלל אחד: אין כללים. אז מי אוכף את זה? | One rule: no rules. So who enforces it? | ≤ 44: 37 |
| LILY_W_MOOP | strip | זה חשל"ש. | That's MOOP. | ≤ 22: 9 |
| LILY_W_NOCOMPLAINT | strip | פה אין תלונה. עדיין. | No complaint here. Yet. | ≤ 40: 20 |
| LILY_W_NOCOMP | strip | לפשרה צריך שני צדדים שמתלוננים. | A compromise needs two sides complaining. | ≤ 40: 31 |
| LILY_W_ALL | strip | כולם מתלוננים. בבת אחת. | Everyone's complaining. All at once. | ≤ 40: 23 |

## Wheel: HUD and hub

| key | speaker | he | en | limit |
|---|---|---|---|---|
| LILY_HUD_HAPPY | hud | מאושרים: {1}/6 | Happy: {1}/6 | ≤ 16: 14 |
| LILY_HUD_GOAL | hud | המטרה: 6/6 | Goal: 6/6 | ≤ 16: 10 |
| LILY_HUB_LAP | hud | סיבוב {1} | Lap {1} | ≤ 12: 9 |

## Wheel: end card (400x220)

| key | speaker | he | en | limit |
|---|---|---|---|---|
| LILY_W_REALIZE | card | הגלגל עשה סיבוב שלם. כולם מתלוננים בדיוק כמו בהתחלה, רק ביחד. | The wheel went all the way round. Everyone complains just like at the start, only together. | ≤ 76: 61 |
| LILY_W_PEAK | card | שיא מאושרים: {1}/6 | Most happy at once: {1}/6 | ≤ 30: 18 |
| LILY_W_LAPS | card | סיבובים: {1} | Laps: {1} | ≤ 30: 12 |
| LILY_W_FIXES | card | תיקונים: {1} | Fixes: {1} | ≤ 30: 12 |
| LILY_W_CAP | card | הגלגל לא עולה מעל חצי. ככה הוא בנוי. | The wheel never gets past half. That's how it's built. | ≤ 76: 36 |
| LILY_W_CONTINUE | card | צהוב: ממשיכים | Yellow: continue | ≤ 30: 13 |

## Wheel: pause

| key | speaker | he | en | limit |
|---|---|---|---|---|
| LILY_PAUSE | pause | עצירה | Paused | ≤ 30: 5 |
| LILY_PAUSE_RESUME | pause | ממשיכים | Resume | ≤ 16: 7 |
| LILY_PAUSE_RESTART | pause | מתחילים מחדש | Restart | ≤ 16: 12 |
| LILY_PAUSE_QUIT | pause | יוצאים | Quit | ≤ 16: 6 |
| LILY_PAUSE_HINT | pause | צהוב: בוחרים · כחול: ממשיכים | Yellow: choose · Blue: resume | ≤ 40: 27 |

## Notes for the coder

- Added beyond the spec's key list (spec says "+ the scaffold's pause/card keys"): `LILY_W_START` (title screen "Yellow starts · Blue back"), `LILY_W_CONTINUE` (end card), `LILY_PAUSE`, `LILY_PAUSE_HINT` (the scaffold's two-button pause), and `LILY_PAUSE_RESUME/RESTART/QUIT` for the D7 three-row pause menu. Use whichever matches the pause you build.
- Not written: the scaffold tap-game placeholders `LILY_HUD`, `LILY_HELP`, `LILY_PROMPT`, `LILY_WIN`, `LILY_LOSE`. D7 replaces them (HUD_HAPPY/HUD_GOAL, HOW_*, WHEEL_Q, no win/lose). `test_lily_happy.CopyTests` will fail on them until the scaffold code that uses them is gone.
- `LILY_LEFT` takes the joined `LILY_CAMP_*` names as `{1}`; the camp names carry no prefix letter, so the join stays grammatical.
- `LILY_LATER` doubles as the busy line (bags song); it reads fine for both.
- `LILY_HEARD_ALL` says "4 מתוך 4", so it must fire only on the talk that first reaches `ready?` (as D5 says). A 5th complaint heard while still `:asked` says `LILY_HEARD_EXTRA` instead.
- QA follow-up (TG64): `LILY_REACT_WHEEL` / `LILY_REPLAY_AFTER` keep "half a wheel" only for a peak of 3; a lower peak uses the `_LOW` variants. `LILY_PAUSE_HINT` now matches the pause (Yellow picks a row, Blue resumes) and is drawn on the pause panel.

Wordplay that might not land on a skim: KUSOMO_1 "התחלתי מהחלק של 'כמוך'" picks up Mor's own line "ואהבת לרעך כמוך" (love your neighbour *as yourself*: he started with the self). GLASS_3: the "other dog" howling back is Changa's reflection in the glass.

# Amendment 1 (2026-10-29): six more complainers

Spec: `docs/specs/lily-happy-quest.md` Amendment 1 (D4 LEFT, D5 A1 rows, D9 report cap). The three rewritten keys (GO_CAMPS, REACT_5, HEARD_EXTRA) are changed in place above and marked A1.

## Lily: places (A1)

| key | speaker | he | en | limit |
|---|---|---|---|---|
| LILY_LEFT_MORE | Lily | חסרים לי עדיין: {1} ועוד. | Still missing: {1} and more. | ≤ 90: 25 |
| LILY_CAMP_SHORTY | list | תור הקרח | the ice line | ≤ 16: 8 |
| LILY_CAMP_LOOOO | list | הפלאיה | the Playa | ≤ 16: 6 |
| LILY_CAMP_GUFAK | list | פינת קים | Kim corner | ≤ 16: 8 |
| LILY_CAMP_TURTLE | list | פינת קים | Kim corner | ≤ 16: 8 |
| LILY_CAMP_RAZIT | list | מקדש הנקודות | the Temple of Dots | ≤ 16: 12 |
| LILY_CAMP_SUSHI | list | קוסומו | Kusomo | ≤ 16: 6 |

## Ice line and Playa: Shorty (f9348fd0), masculine, after "אבל הכי חשוב שתצליח לסלוח לעצמך…"

| key | speaker | he | en | limit |
|---|---|---|---|---|
| LILY_SHORTY_1 | Shorty | שעה שלישית בתור לקרח. סלחתי לעצמי. סלחתי למוכר. סלחתי לקרח. | Third hour in the ice line. I forgave myself. I forgave the ice guy. I forgave the ice. | ≤ 90: 59 |
| LILY_SHORTY_2 | Shorty | ואז הקרח נמס. על זה עוד אין לי סליחה. אני עובד על זה. | Then the ice melted. That one I haven't forgiven yet. I'm working on it. | ≤ 90: 53 |
| LILY_SHORTY_AGAIN | Shorty | עדיין בתור. סלחתי כבר לכולם. לא נשאר פה למי לסלוח. | Still in line. I've forgiven everyone already. There's no one left to forgive. | ≤ 90: 50 |

## Playa: Loooo (6b53f14c, a dog), feminine, after "Nope"

| key | speaker | he | en | limit |
|---|---|---|---|---|
| LILY_LOOOO_1 | Loooo | פה כולם אומרים כן להכל. אני אמרתי פעם אחת Nope. | Here everyone says yes to everything. I said Nope once. | ≤ 90: 47 |
| LILY_LOOOO_2 | Loooo | אז רשמו אותי לשלוש סדנאות על איך להגיד לא. לא הצלחתי להגיד לא. | So they signed me up for three workshops on how to say no. I couldn't say no. | ≤ 90: 62 |
| LILY_LOOOO_3 | Loooo | בסדנה הראשונה אמרתי Nope. רשמו אותי לעוד אחת. | At the first workshop I said Nope. They signed me up for another one. | ≤ 90: 45 |
| LILY_LOOOO_AGAIN | Loooo | Nope. זאת כבר סדנה חמישית. | Nope. That's workshop number five. | ≤ 90: 26 |

## Kim corner: Gufak (1be29576), gender-unmarked, after "לפעמים אין תקוה"

| key | speaker | he | en | limit |
|---|---|---|---|---|
| LILY_GUFAK_1 | Gufak | באספת הקאמפ הגענו להסכמה מלאה: לקיים עוד אספה. | At the camp meeting we reached full consensus: hold another meeting. | ≤ 90: 46 |
| LILY_GUFAK_2 | Gufak | באספה ההיא נסכים מתי האספה הבאה. אף אחד לא התנגד. אף פעם אף אחד לא מתנגד. | At that one we'll agree when the next one is. Nobody objected. Nobody ever objects. | ≤ 90: 73 |
| LILY_GUFAK_AGAIN | Gufak | האספה עוד נמשכת. הגענו לסעיף הראשון: מה בסדר היום. | The meeting's still going. We've reached item one: what's on the agenda. | ≤ 90: 50 |

## Kim corner: Sea Turtle (8d654949), masculine, after "כשאני הייתי קטן, הייתי גור דינוזאורים"

| key | speaker | he | en | limit |
|---|---|---|---|---|
| LILY_TURTLE_1 | Sea Turtle | בשנה הראשונה היה פה הרבה יותר טוב. | It was much better here in the first year. | ≤ 90: 34 |
| LILY_TURTLE_2 | Sea Turtle | לא הייתי פה בשנה הראשונה. אבל כולם אומרים. | I wasn't here in the first year. But everyone says so. | ≤ 90: 42 |
| LILY_TURTLE_3 | Sea Turtle | גם מי שאומרים את זה לא היו. ככה זה עם השנה הראשונה. אף אחד לא היה בה. | The ones who say it weren't there either. That's the first year for you. Nobody was there. | ≤ 90: 69 |
| LILY_TURTLE_AGAIN | Sea Turtle | בשנה הראשונה היו פה גם דינוזאורים. ככה מספרים. | In the first year there were dinosaurs here too. So they say. | ≤ 90: 46 |

## Temple of Dots: Razit (64aeedbe), feminine, after "מביאה אור לכל מקום זאת נכנסת אליו"

| key | speaker | he | en | limit |
|---|---|---|---|---|
| LILY_RAZIT_1 | Razit | הבאתי אור לכל מקום. גם כולם הביאו. | I brought light everywhere. So did everyone else. | ≤ 90: 34 |
| LILY_RAZIT_2 | Razit | עכשיו כל כך מואר שאף אחד לא רואה אף אחד. | Now it's so bright nobody can see anybody. | ≤ 90: 40 |
| LILY_RAZIT_3 | Razit | אז הבאתי משקפי שמש. גם כולם הביאו. | So I brought sunglasses. So did everyone else. | ≤ 90: 34 |
| LILY_RAZIT_AGAIN | Razit | עדיין מואר. אני מחפשת פינה חשוכה להביא אליה אור. | Still bright. I'm looking for a dark corner to bring light to. | ≤ 90: 48 |

## Kusomo: Sushi (b201fb8a), gender-unmarked, after "לא אבק, זה גליטר של המדבר."

| key | speaker | he | en | limit |
|---|---|---|---|---|
| LILY_SUSHI_1 | Sushi | באתי עם אפס חשל"ש. בלי גליטר, בלי נוצות, בלי כלום. | I came with zero MOOP. No glitter, no feathers, nothing. | ≤ 90: 50 |
| LILY_SUSHI_2 | Sushi | ואז גיליתי שהמדבר עצמו גליטר. כל הפלאיה. | Then I found out the desert itself is glitter. The whole Playa. | ≤ 90: 40 |
| LILY_SUSHI_3 | Sushi | אספתי שלושה ימים. נשאר עוד קצת. בערך מדבר. | Three days of collecting. There's a little left. About one desert. | ≤ 90: 42 |
| LILY_SUSHI_AGAIN | Sushi | עוד יום של איסוף. אם תמצאו נוצה, היא לא שלי. | Another day of collecting. If you find a feather, it isn't mine. | ≤ 90: 44 |

## Payoff (A1)

| key | speaker | he | en | limit |
|---|---|---|---|---|
| LILY_REPORT_SHORTY | narration | בתור לקרח, שורטי סלח לעצמו, למוכר ולקרח. ואז הקרח נמס. | In the ice line, Shorty forgave himself, the ice guy and the ice. Then the ice melted. | ≤ 90: 54 |
| LILY_REPORT_LOOOO | narration | בפלאיה, Loooo אמרה פעם אחת Nope, ורשמו אותה לשלוש סדנאות על איך להגיד לא. | On the Playa, Loooo said Nope once and got signed up for three workshops on saying no. | ≤ 90: 73 |
| LILY_REPORT_GUFAK | narration | בפינת קים, האספה של גופק החליטה פה אחד: עוד אספה. | At Kim corner, Gufak's meeting decided unanimously: another meeting. | ≤ 90: 49 |
| LILY_REPORT_TURTLE | narration | בפינת קים, צב-הים מתגעגע לשנה הראשונה. הוא לא היה בה. | At Kim corner, the Sea Turtle misses the first year. He wasn't there. | ≤ 90: 53 |
| LILY_REPORT_RAZIT | narration | ליד מקדש הנקודות, כולם הביאו אור כמו רזית. עכשיו אף אחד לא רואה אף אחד. | By the Temple of Dots, everyone brought light like Razit. Now nobody can see anybody. | ≤ 90: 71 |
| LILY_REPORT_SUSHI | narration | בקוסומו, אצל סושי אפס חשל"ש. חוץ מהמדבר, שהוא גליטר. | At Kusomo, Sushi has zero MOOP. Except the desert, which is glitter. | ≤ 90: 52 |
| LILY_REPORT_MORE | narration | תלונות נוספות בסקר: {1}. בערך אותו דבר, רק במקום אחר. | More complaints in the survey: {1}. Roughly the same, just somewhere else. | ≤ 90: 53 |
| LILY_REACT_MORE | Lily | עוד? אני צריכה מחברת חדשה. | More? I need a new notebook. | ≤ 90: 26 |

## Notes for the coder (A1)

- `LILY_CAMP_SUSHI` is the exact text of `LILY_CAMP_KUSOMO` in both languages, and `LILY_CAMP_GUFAK` equals `LILY_CAMP_TURTLE`, so the dedupe in LEFT shows each place once.
- `LILY_LEFT_MORE` takes the same `{1}` as LEFT; the places join with ", " and the line itself adds " ועוד" (no comma before ו).
- `LILY_REPORT_MORE` takes `{1}` = `heard.size - 5`. It is phrased as a count label so it reads right for 1 through 6.
- `LILY_HEARD_EXTRA` now opens with "נרשם בסקר": the 5th to 11th complaints are logged and reach the payoff (D9), and the old "already enough" alone read as if they weren't. No count, as the spec says.
- `_3` is written for Loooo, Turtle, Razit and Sushi; Shorty and Gufak have `_1..2` only.
- Loooo's metadata says "Quest usable: no". The spec already seats her on the wheel and now makes her an encounter, so I wrote her lines; flagging it in case that field is meant to block this.

Wordplay that might not land on a skim: GUFAK_AGAIN, the meeting reached item one, "what's on the agenda" (מה בסדר היום). TURTLE_AGAIN calls back his own line about being a dinosaur cub.
