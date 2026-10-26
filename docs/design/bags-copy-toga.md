# TG7: Toga on bags (Michal)

Map098 event 10, `7a2a022c`. Nothing existing is changed. The idea is Michal's; Yotam can polish the wording.

## The idea (scaffolding, not for the page)

A bag is the only object defined entirely by what it is not yet holding. A cup, a barrel, a bag: each is a boundary around an absence. That is why a bag is the right gift from a man in a barrel. His barrel is a bag that grew a spine and refused to fold. The question "when does a bag stop being a bag" has a clean answer inside Toga's world: when it stops being able to hold. Not when it is empty, because an empty bag is at maximum bagness. Emptiness is the capacity. So an empty bag is not nothing; it is a promise, and Toga's simulation theory loves promises: they are cheap to compute and they cost nothing to keep.

The "bag of bags" is then not a joke about recursion only. One bag that holds every bag it could be is the same shape as his simulation inside a simulation: a container whose content is more containers. He ends where he always ends, with the sun. The player earns the gift by staying for the whole thing and asking about a bag rather than about God.

The one player choice (empty bag: "still a bag" or "just air in a wrapper") does not change the outcome, but Toga answers each in character. Both lead to the same question and the same gift.

## Menu wiring

`MSG_7A2A022C_CHOOSE` currently has 3 options (EXIST, MEAN, ENOUGH), so there is one free slot. Suggested order: EXIST, MEAN, BAG, ENOUGH (ENOUGH stays last). No menu text changes.

## Flow

BAG_1, BAG_2, BAG_3, then the question BAG_Q with a 2-option choice (A/B), then reply 4A or 4B, then BAG_5 and BAG_6, then GIFT. On later visits (`:toga_gift` set): one of AGAIN_1..3, rotating or random. If the player holds a Desert Bag and `:toga_desert_seen` is not set, the branch first offers the DESERTBAG exchange (always after the gift).

## A. The branch (first visit)

| key | he | en |
|---|---|---|
| CHOICE_7A2A022C_BAG | שאלה על שקית | A question about a bag |
| MSG_7A2A022C_BAG_1 | שקית? אתה שואל אותי על שקית. סוף סוף. כולם שואלים על אלוהים. | A bag? You're asking me about a bag. Finally. Everyone asks about God. |
| MSG_7A2A022C_BAG_2 | שקית היא חלל עם כתובת. ממלאים אותה, זה חפץ. מרוקנים אותה, זה עדיין חפץ. מה השתנה? רק התקווה. | A bag is a space with an address. Fill it, it's an object. Empty it, still an object. What changed? Only the hope. |
| MSG_7A2A022C_BAG_3 | והחבית שלי? גם היא שקית. פשוט כזו שהתעקשה. שקית עם עמוד שדרה, שהחליטה לא להתקפל. | And my barrel? It's a bag too. Just one that insisted. A bag with a spine that decided not to fold. |
| MSG_7A2A022C_BAG_Q | אז תגיד לי, מהצד של מי שלא יושב בחבית: שקית ריקה, מה היא? | So tell me, from the side of someone who isn't sitting in a barrel: an empty bag, what is it? |
| CHOICE_7A2A022C_BAG_A | עדיין שקית | Still a bag |
| CHOICE_7A2A022C_BAG_B | אוויר בעטיפה | Air in a wrapper |
| MSG_7A2A022C_BAG_4A | נכון. מה שהיא יכולה להחזיק קובע מה היא, לא מה שהחזיקה. גם אני ריק, ועדיין טוגה. | Right. What it can hold decides what it is, not what it held. I'm empty too, and I'm still Toga. |
| MSG_7A2A022C_BAG_4B | אוויר בעטיפה. יפה. אבל גם אתה, אם תחשוב על זה. פשוט עם יותר דעות. | Air in a wrapper. Nice. But so are you, if you think about it. Just with more opinions. |
| MSG_7A2A022C_BAG_5 | עכשיו הקשה. הרבה שקיות, או שקית אחת של כל השקיות שיכולות להיות? | Now the hard one. Many bags, or one bag of every bag there could be? |
| MSG_7A2A022C_BAG_6 | אני אומר אחת. הסימולציה לא תבזבז זיכרון על הרבה כשאפשר שקית שמחזיקה את כולן. | I say one. The simulation won't waste memory on many when one bag can hold them all. |
| MSG_7A2A022C_BAG_GIFT | ישבת עד הסוף ושאלת על שקית, לא על אלוהים. אין לי הרבה, אבל יש לי את זו. | You sat through to the end and asked about a bag, not about God. I don't have much, but I have this. |
| MSG_7A2A022C_BAG_GIFT_2 | שקית של שקיות. אל תפחד, היא לא נגמרת. ישבתי עליה שנה והיא לא התלוננה. | A bag of bags. Don't worry, it doesn't run out. I sat on it for a year and it never complained. |
| MSG_7A2A022C_BAG_GIFT_3 | אל תודה לי. תזוז, אתה מסתיר לי את השמש. | Don't thank me. Move, you're blocking my sun. |

Game note: `pbReceiveItem(:BAGOFBAGS)` fires between GIFT_2 and GIFT_3. The player-facing "got the item" line comes from the engine.

## A2. Repeat visits after the gift (no new item)

Pick one at random, or rotate.

| key | he | en |
|---|---|---|
| MSG_7A2A022C_BAG_AGAIN_1 | שוב שקיות? טוב. שקית ריקה מחכה. שקית מלאה כבר החליטה. איזו מהן חופשית יותר? | Bags again? Fine. An empty bag waits. A full bag has already decided. Which one is freer? |
| MSG_7A2A022C_BAG_AGAIN_2 | אם שמים חבית בתוך שקית, היא נשארת חבית? או שהשקית עכשיו היא העולם? | If you put a barrel inside a bag, is it still a barrel? Or is the bag now the world? |
| MSG_7A2A022C_BAG_AGAIN_3 | יש לך שקית של שקיות. זה אומר שיש לך כל מה שאין לך עדיין. לא רע לאדם בלי חבית. | You have a bag of bags. That means you have everything you don't have yet. Not bad for a man without a barrel. |

(`MSG_7A2A022C_BAG_AGAIN` as the base key: use `_AGAIN_1` as the default if one key is required.)

## B. Desert Bag, once (`:toga_desert_seen`)

Offered inside the bag branch when the player holds a DESERTBAG. 1 is removed.

| key | he | en |
|---|---|---|
| MSG_7A2A022C_DESERTBAG_1 | רגע. מה יש לך שם בשקית? חול? רוח? זה... זה המדבר. בשקית. | Wait. What have you got in that bag? Sand? Wind? That's... that's the desert. In a bag. |
| CHOICE_7A2A022C_DESERTBAG_GIVE | תן לו את שקית המדבר | Give him the Desert Bag |
| CHOICE_7A2A022C_DESERTBAG_KEEP | עוד לא | Not yet |
| MSG_7A2A022C_DESERTBAG_KEEP | אל תמהר. מדבר טוב לא בורח. זה הכישרון שלו. | Don't rush. A good desert doesn't run away. That's its talent. |
| MSG_7A2A022C_DESERTBAG_2 | הבאת לי את החוץ, פנימה. אני יושב בתוך חבית כבר שנים ואף אחד לא חשב להביא לי את מה שמחוץ לה. | You brought me the outside, inside. I've been in this barrel for years and nobody thought to bring me what's outside it. |
| MSG_7A2A022C_DESERTBAG_3 | עכשיו יש לי חבית, שמש ושקית עם מדבר. שלושה עולמות, אחד בתוך השני. | Now I have a barrel, a sun, and a bag with a desert in it. Three worlds, one inside the other. |
| MSG_7A2A022C_DESERTBAG_4 | והשאלה הנוראה: האם המדבר בשקית הוא עדיין המדבר, או רק דוגמה? אל תענה. תן לי ליהנות. | And the terrible question: is the desert in the bag still the desert, or just a sample? Don't answer. Let me enjoy it. |
| MSG_7A2A022C_DESERTBAG_SEEN | המדבר שלך עדיין אצלי. הוא מתנהג יפה, לא מלכלך. בדיוק כמו בסימולציה. | Your desert is still with me. It behaves nicely, doesn't make a mess. Just like in the simulation. |

`DESERTBAG_SEEN` is the line on later visits when the player offers the bag branch (shown once at the start of the branch, no second reward).

## C. Use-from-bag text, Bag of Bags (rotating)

| key | he | en |
|---|---|---|
| BAGS_BAGOFBAGS_USE_1 | שולפים שקית מתוך השקית. ממלאים אותה בחול. עכשיו יש לך מדבר בכיס. | You pull a bag out of the bag. Fill it with sand. Now you have a desert in your pocket. |
| BAGS_BAGOFBAGS_USE_2 | השקית הפנימית נפתחה, נמלאה ברוח ובחול, ונסגרה לבד. שקית מדבר. | The inner bag opened, filled with wind and sand, and closed by itself. A desert bag. |
| BAGS_BAGOFBAGS_USE_3 | הושטת יד, שלפת שקית, והמדבר נשפך פנימה. אל תשאל איך. | You reached in, pulled out a bag, and the desert poured inside. Don't ask how. |
| BAGS_BAGOFBAGS_USE_FULL | כבר יש לך מדבר בכיס. אחד מספיק, אחרת זה כבר נכס. | You already have a desert in your pocket. One is enough, more than that is real estate. |

`USE_FULL` is an extra line for the "you already carry the desert" case in the spec. Drop it if the coder has its own.

## D. Item descriptions

| key | he | en |
|---|---|---|
| BAGS_ITEM_BAGOFBAGS_DESC | שקית אחת שמחזיקה את כל השקיות האפשריות. מתנה מטוגה. אפשר לשלוף ממנה שקית. | One bag that holds every bag there could be. A gift from Toga. You can pull a bag out of it. |
| BAGS_ITEM_DESERTBAG_DESC | שקית מלאה בחול ובמדבר. שוקלת כמו חוץ. טוגה אוהב כאלה. | A bag full of sand and desert. Weighs about as much as outside. Toga likes these. |

## Notes for Yotam and Noam

- The three lines inside the existing graph that this branch echoes on purpose: "אתה מסתיר לי את השמש" (closing gift line), the barrel as a border ("בחבית רואים את הגבול"), and the desert "that doesn't make a mess" (`EXIST`).
- Nothing here asks the coder to change any key. All new keys sit next to the existing `*_7A2A022C_*` ones.
- A Desert Bag can only come from the Bag of Bags, so the desert exchange always happens after the gift.
- Length check: every message above is under 120 characters.
