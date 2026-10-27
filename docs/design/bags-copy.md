# TG7: bags copy (Inbar, Shirpaz & Esther, Pixel, surprise bag, song)

TG7 · 2026-10-26 · Yotam Carmeli. Spec: `docs/specs/bags.md`. Toga's lines are Michal's and live in `docs/design/bags-copy-toga.md`.

Cast: Inbar (ענבר) is the birthday girl. Shirpaz & Esther (שירפז ואסתר) are the 90s kids-TV duo and appear only as the unicorns, Esther pink and Shirpaz purple (the founder's sticker art, dec:tg-14). The cowboy camper Shirpaz (`670f79e3`) is a different person. Every Hebrew line is under 120 characters. `{1}` is the number of surprise bags held. Lines marked *optional* can be cut without breaking the flow.

## Inbar (ענבר), Map095 event 15, `c414cf08`

Her existing `MSG_C414CF08_LINE` plays first, then these.

| key | speaker | he | en |
|---|---|---|---|
| BAGS_INBAR_ASK_1 | ענבר | היום יש לי יום הולדת! ואני רוצה רק דבר אחד: שירפז ואסתר. כן, ההן. מהטלוויזיה. מהניינטיז. | It's my birthday today! And I want just one thing: Shirpaz & Esther. Yes, those two. From TV. From the nineties. |
| BAGS_INBAR_ASK_2 | ענבר | הסוכן שלהן אמר שהן באות רק תמורת שקיות הפתעה. בדיוק שתיים. זה כתוב בחוזה. | Their agent said they only come for surprise bags. Exactly two. It's in the contract. |
| BAGS_INBAR_ASK_3 | ענבר | יש פה כלב פושטק אחד, פיקסל, שסוחר בשקיות. מה בדיוק הוא מוכר? אף אחד לא יודע. גם הוא לא. | There's a punk dog around here, Pixel, who deals in bags. What exactly does he sell? Nobody knows. Neither does he. |
| BAGS_INBAR_NOTENOUGH | ענבר | שקיות הפתעה אצלך: {1}. הן צריכות שתיים. לא אחת יותר, לא אחת פחות. ככה זה עם כוכבות. | Surprise bags on you: {1}. They need two. Not one more, not one less. That's stars for you. |
| BAGS_INBAR_GIVE_ASK | ענבר | יש לך מספיק! לתת לי שתיים ולהזמין את שירפז ואסתר? | You've got enough! Give me two and summon Shirpaz & Esther? |
| BAGS_INBAR_CHOICE_GIVE | (choice) | לתת שתיים | Give two |
| BAGS_INBAR_CHOICE_NOTYET | (choice) | עוד לא | Not yet |
| BAGS_INBAR_NOTYET | ענבר | בסדר. אני מחכה. יום הולדת זה כל היום. *(optional)* | Fine. I'll wait. A birthday lasts all day. *(optional)* |
| BAGS_INBAR_SUMMON | ענבר | שירפז! אסתר! שירפז! אסתר! *(optional, after the hand-over, before the unicorns appear)* | Shirpaz! Esther! Shirpaz! Esther! *(optional)* |
| BAGS_INBAR_PARTY_1 | ענבר | זה יום ההולדת הכי טוב שהיה לי. וגם הראשון שבו חד קרן סגולה חתמה לי על המצח. | Best birthday I've ever had. Also the first one where a purple unicorn signed my forehead. |
| BAGS_INBAR_PARTY_2 | ענבר | הפזמון עדיין בראש שלי. הוא לא יוצא. נראה לי שהוא גר שם עכשיו. | The chorus is still in my head. It won't leave. I think it lives there now. |

## Shirpaz & Esther, the unicorns

Speakers: אסתר (pink), שירפז (purple), or both together. Name plates use the keys below; narration clears the plate. They talk like 90s kids-TV hosts who never stopped.

### Arrival and star demands

| key | speaker | he | en |
|---|---|---|---|
| BAGS_UNICORN_ARRIVE_1 | שירפז ואסתר | שלוווום ילדים! שלום שלום! זוכרים אותנו? אנחנו זוכרות אתכם. בערך. | Hellooo kids! Hello hello! Remember us? We remember you. Roughly. |
| BAGS_UNICORN_ARRIVE_2 | שירפז | אני שירפז, הסגולה! כן, אנחנו חדות קרן עכשיו. היה לנו סוכן מאוד יצירתי. | I'm Shirpaz, the purple one! Yes, we're unicorns now. We had a very creative agent. |
| BAGS_UNICORN_ARRIVE_3 | אסתר | ואני אסתר, הוורודה! אנחנו לא מצטלמות בלי איפור ולא שרות בלי שקיות. ככה כתוב בחוזה. | And I'm Esther, the pink one! We don't go on camera without makeup and we don't sing without bags. It's in the contract. |
| BAGS_UNICORN_STAR_1 | שירפז | פעם היו לנו אלפי שקיות הפתעה. חילקנו וחילקנו וחילקנו, ואז יום אחד פתחנו את הארגז... | We used to have thousands of surprise bags. We gave and gave and gave, and then one day we opened the box... |
| BAGS_UNICORN_STAR_2 | אסתר | ...ונגמרו לנו כל שקיות ההפתעה. בלי שום הפתעה. מאז אנחנו מקבלות שתיים מראש. אחת לשירפז, אחת לי. | ...and we ran out of all the surprise bags. No surprise at all. Since then we take two up front. One for Shirpaz, one for me. |

### Accepting the bags

| key | speaker | he | en |
|---|---|---|---|
| BAGS_UNICORN_GIVEN | (narration) | מסרת שתי שקיות הפתעה. | You handed over two surprise bags. |
| BAGS_UNICORN_ACCEPT_1 | שירפז | שתיים! בדיוק שתיים! אסתר, תבדקי את הסחורה. בעיקר שאין בה חתול. *(rev 3: wink)* | Two! Exactly two! Esther, check the goods. Mainly that there's no cat in them. *(rev 3: wink)* |
| BAGS_UNICORN_ACCEPT_2 | אסתר | אין חתול. כולם לעמוד בשורה, ידיים למעלה, וחיוך של קלטת VHS. | No cat. Everyone line up, hands in the air, and a VHS-cassette smile. |

### Payoff, before the song (first time only) *(rev 2: moved before the song)*

| key | speaker | he | en |
|---|---|---|---|
| BAGS_UNICORN_AFTER_1 | שירפז | רגע, לפני השיר! אסתר, תוציאי את השקית שלך. כמו שאומרים בשיר... *(rev 2: changed)* | Wait, before the song! Esther, get your bag out. Like the song says... *(rev 2: changed)* |
| BAGS_UNICORN_AFTER_2 | אסתר | ..."יַעֲנִיק שַׂקִּית הַפְתָּעָה לְכֹל אוֹרֵחַ". הנה. אחת. לכל אורח. ספרנו. | ..."he'll give a surprise bag to every guest." Here. One. For every guest. We counted. |
| BAGS_UNICORN_AFTER_3 | שירפז | הבאת שתיים, קיבלת אחת. זה נקרא תעשיית הבידור, מותק. | You brought two, you got one. That's show business, sweetie. |
| BAGS_UNICORN_AFTER_4 | אסתר | והשנייה? לשימוש אישי. מאיפה לדעתך מגיעה כל האנרגיה הזאת? *(optional)* *(rev 3: wink)* | And the other one? Personal use. Where do you think all this energy comes from? *(optional)* *(rev 3: wink)* |

The item grant itself uses the standard receive message; no extra line is needed for it.

Then the song starts:

| key | speaker | he | en |
|---|---|---|---|
| BAGS_UNICORN_PRESONG | שירפז ואסתר | ואחת, ושתיים, ושלוש... מוזיקה! | And a one, and a two, and a three... music! *(rev 2: moved here, text unchanged)* |

### Encore (later visits, `:done`)

| key | speaker | he | en |
|---|---|---|---|
| BAGS_UNICORN_ENCORE_ASK | שירפז | הקהל רוצה הדרן? שקיות אין, אבל הדרן יש! | The crowd wants an encore? We're out of bags, but we've got an encore! |
| BAGS_UNICORN_CHOICE_ENCORE | (choice) | הדרן! | Encore! |
| BAGS_UNICORN_CHOICE_NO | (choice) | לא, תודה | No, thanks |
| BAGS_UNICORN_ENCORE_YES | אסתר | שירפז, למקומות! מוזיקה! | Shirpaz, places! Music! |
| BAGS_UNICORN_ENCORE_NO | אסתר | בסדר. אנחנו פה עד סוף האירוע. חתימות רק בטוש ורוד. | Fine. We're here till the end of the burn. Autographs in pink marker only. |

## Shirpaz the cowboy, Map095 event 2, `670f79e3` (optional)

| key | speaker | he | en |
|---|---|---|---|
| BAGS_SHIRPAZ_COWBOY_CLASH | שירפז | חד קרן סגולה בשם שירפז? העיר הזאת קטנה מדי לשני שירפזים. | A purple unicorn called Shirpaz? This town ain't big enough for two Shirpazes. |

### Gift lines (every talk, one Surprise Bag each, rotating 1 → 2 → 3)

| key | speaker | he | en |
|---|---|---|---|
| *(TG14 pointer)* | שירפז | The bag is now won by arm-wrestling her (dec:tg-29). GIFT_1 and GIFT_3 are reworded as win lines, and the AW_* copy lives in `docs/design/arm-wrestling-copy.md`. That file supersedes this table. | |
| BAGS_SHIRPAZ_COWBOY_GIFT_1 | שירפז | שקית הפתעה בשבילך. בפלאיה לא סוחרים, מעניקים. זה עיקרון. השני מתוך עשרה. | A surprise bag for you. On the playa we don't trade, we gift. It's a principle. Number two of ten. |
| BAGS_SHIRPAZ_COWBOY_GIFT_2 | שירפז | עוד אחת? תמיד יש עוד אחת. הבאתי לאירוע ארגז אחד, והוא עדיין לא נגמר. לא בדקתי למה. ולא אבדוק. | Another one? There's always another one. I brought one box to the burn and it still hasn't run out. I haven't checked why. I won't. |
| BAGS_SHIRPAZ_COWBOY_GIFT_3 | שירפז | אומרים שיש פה עוד שירפז, חד קרן, שגובה שתי שקיות מראש. פה זה בחינם. ככה יודעים להבדיל בינינו. | They say there's another Shirpaz here, a unicorn, who charges two bags up front. Here it's free. That's how you tell us apart. |

## Pixel (פיקסל), Map109 event 3, `d5383627`

His existing `MSG_D5383627_LINE` ("אני פושטק!") plays first, then these.

| key | speaker | he | en |
|---|---|---|---|
| BAGS_PIXEL_OFFER_1 | פיקסל | רוצה חתול בשק? משלמים קודם, מסתכלים אחר כך. זה כל הקטע. | Want a cat in a sack? You pay first, you look later. That's the whole point. |
| BAGS_PIXEL_OFFER_2 | פיקסל | כן, אני כלב שמוכר חתול. איך החתול נכנס לשקית? לא שאלתי. בפלורנטין לא שואלים. | Yes, I'm a dog selling a cat. How did the cat get in the bag? I didn't ask. In Florentin you don't ask. |
| BAGS_PIXEL_CHOOSE | פיקסל | במה משלמים? | What are you paying with? |
| BAGS_PIXEL_CHOICE_BILL | (choice) | שטר של 20 | 20-sheckel bill |
| BAGS_PIXEL_CHOICE_DESERT | (choice) | שקית מדבר | Desert bag |
| BAGS_PIXEL_CHOICE_ICE | (choice) | שקית קרח | Bag of ice |
| BAGS_PIXEL_CHOICE_NEVERMIND | (choice) | עזוב | Never mind |
| BAGS_PIXEL_CHOOSE_ONE | פיקסל | יש לך בדיוק דבר אחד שאני לוקח. חסכת לי תפריט. עסקה? *(optional, instead of CHOOSE when one payable item is held)* | You've got exactly one thing I take. Saved me a menu. Deal? *(optional)* |
| BAGS_PIXEL_CHOICE_DEAL | (choice) | עסקה | Deal |
| BAGS_PIXEL_PAID_BILL | פיקסל | עשרים שקל. בפלורנטין זה כמעט חצי בירה. | Twenty sheckels. In Florentin that's almost half a beer. |
| BAGS_PIXEL_PAID_DESERT | פיקסל | שקית מדבר! אני אוהב שקיות. גם כשיש בהן מדבר. | A desert bag! I love bags. Even with desert in them. |
| BAGS_PIXEL_PAID_ICE | פיקסל | שקית תמורת שקית. העסקה הכי הוגנת שתעשה היום. | A bag for a bag. The fairest deal you'll make today. |
| BAGS_PIXEL_MEOW | (narration, with the meow SE) | מתוך השקית: "מיאו." | From inside the bag: "Meow." |
| BAGS_PIXEL_REVEAL | פיקסל | שמעת? מיאו. זה סימן טוב. או רע. בגלל זה זו שקית הפתעה. החזרות אין. | Hear that? Meow. That's a good sign. Or a bad one. That's why it's a surprise bag. No returns. |
| BAGS_PIXEL_NEVERMIND | פיקסל | בסדר. החתול לא הולך לשום מקום. הוא בשק. | Fine. The cat's not going anywhere. It's in the sack. |
| BAGS_PIXEL_NOTHING | פיקסל | אין לך כלום בשבילי. טוגה, זה מהחבית בפלאיה, מסתובב עם שקית של שקיות. שווה לשאול אותו מה זאת שקית. | You've got nothing for me. Toga, the barrel guy on the Playa, has a bag of bags. Worth asking him what a bag is. |

## Item names

Keys follow the engine's item lookup (spec, Items): the ID, the English name and the English plural. Descriptions for BAGOFBAGS and DESERTBAG are Michal's (`bags-copy-toga.md`), re-keyed to `<ID>_DESC`.

| key | speaker | he | en |
|---|---|---|---|
| BAGOFBAGS | (item) | שקית של שקיות | Bag of Bags |
| Bag of Bags | (item) | שקית של שקיות | Bag of Bags |
| Bags of Bags | (item, plural) | שקיות של שקיות | Bags of Bags |
| DESERTBAG | (item) | שקית מדבר | Desert Bag |
| Desert Bag | (item) | שקית מדבר | Desert Bag |
| Desert Bags | (item, plural) | שקיות מדבר | Desert Bags |

## Surprise bag item

| key | speaker | he | en |
|---|---|---|---|
| SURPRISEBAG | (item) | שקית הפתעה | Surprise Bag |
| Surprise Bag | (item) | שקית הפתעה | Surprise Bag |
| Surprise Bags | (item, plural) | שקיות הפתעה | Surprise Bags |
| SURPRISEBAG_DESC | (item) | שקית זיפ קטנה ומבריקה. משהו בפנים מרשרש. אין דרך לדעת מה, חוץ מדרך אחת. *(rev 3: wink)* | A small shiny zip bag. Something inside rustles. There's no way to know what, except one. *(rev 3: wink)* |
| BAGS_SURPRISE_WARN_INBAR | (narration, before the confirm) | רגע. ענבר צריכה שתיים בשביל שירפז ואסתר. לא אחת פחות. | Wait. Inbar needs two for Shirpaz & Esther. Not one less. |
| BAGS_SURPRISE_CONFIRM | (narration) | לפתוח את שקית ההפתעה? אחרי זה היא כבר לא הפתעה. | Open the surprise bag? After that it's not a surprise anymore. |
| BAGS_SURPRISE_BILL | (narration) | בפנים: שטר של 20 שקלים, מגולגל לגליל קטן והדוק. כמו שצריך. *(rev 3: wink)* | Inside: a 20-sheckel bill, rolled into a tight little tube. The proper way. *(rev 3: wink)* |
| BAGS_SURPRISE_RECURSE | (narration) | בפנים: שקית הפתעה. שאולי יש בה שקית הפתעה. שאולי יש בה... | Inside: a surprise bag. Which might have a surprise bag in it. Which might have... |
| BAGS_SURPRISE_CONFETTI | (narration) | פוף! קונפטי לכל עבר, וזה הכול. מעכשיו זה ה-MOOP שלך. | Poof! Confetti everywhere, and that's it. From now on it's your MOOP. |
| BAGS_SURPRISE_NOTE | (narration) | בפנים: פתק. כתוב עליו "הפתעה!". טכנית, נכון. | Inside: a note. It says "Surprise!". Technically true. |

## Song scene

| key | speaker | he | en |
|---|---|---|---|
| BAGS_SONG_SKIP | (narration) | לדלג על השיר? שירפז ואסתר ייעלבו. אבל יעשו כאילו לא. | Skip the song? Shirpaz & Esther will be offended. But they'll act like they're not. |

## Notes

- **Lyrics.** AFTER_2 quotes the Verse 3 line from `docs/design/sakiyot-haftaa-lyrics.md` byte for byte, niqqud and the song's own "לְכֹל" included; it is the only pointed text in the file. STAR_2 echoes the bridge ("נגמרו להם כל שקיות ההפתעה") in the unicorns' own first person, unpointed. The opening table no longer has an ice outcome, so BAGS_SURPRISE_ICE is gone.
- **Inbar's existing line is a stub.** `MSG_C414CF08_LINE` is just her name, "ענבר", in both languages. It stays as briefed, so her first talk opens with her saying her own name. If the line gets replaced later, ASK_1 still reads as an opener.
- **Cowboy Shirpaz's gender.** The spec calls him a cowboy and "he", but his existing line ends "יצאתי כבושה" (feminine). CLASH has no gender marking, so it works either way. The GIFT lines keep him unmarked too: first-person past and future only ("הבאתי", "אבדוק"), no present-tense verbs or adjectives about himself. GIFT_3 says "אומרים" so it works before the player has met the unicorns.
- **Style choices for this file.** "חד קרן" is written with a space, as in the existing Shontal line. ASCII hyphen before Latin ("ה-MOOP", as in "ל-WiFi"). "שקל" spelled as the game spells it in `TWENTYSHECKELBILL` ("sheckel" in English). The player is mostly addressed in unmarked forms (past tense, "יש לך", infinitives); the rest follows the game's masculine default ("תעשה" in PAID_ICE).
- **Rev 2 payoff order.** STAR_2 set it up as one bag each. AFTER_1 has Shirpaz tell Esther to hand over *her* bag, so Esther's end line "נגמרה השקית?" (`BAGS_UNICORN_SONG_END`, Claudet's, verbatim) lands on the one person who should have noticed. AFTER_2's "ספרנו" now pays off too: they counted and still missed it.
- **May not land on a skim.** "חתול בשק" is the idiom for buying something sight unseen, so a dog selling one is the joke. "פושטק" echoes Pixel's own line. MOOP is the Burning Man term for litter left on the playa ("Matter Out Of Place"). Cowboy GIFT_1: gifting is the second of Burning Man's Ten Principles. GIFT_2's box that never runs out is the reverse of the unicorns' STAR lines, where theirs did.
- **Rev 3 (wink pass, founder 2026-10-26).** Four lines sharpened toward the baggie reference; surface stays a kids' party bag. Old text, for the diff:
  - BAGS_UNICORN_ACCEPT_1: שתיים! בדיוק שתיים! אסתר, תבדקי שאין בהן חתול. / Two! Exactly two! Esther, check there's no cat in them.
  - BAGS_UNICORN_AFTER_4: והשנייה? דמי הופעה. גם חד קרן צריכה לשלם שכירות. / And the other one? Appearance fee. Even a unicorn has rent to pay.
  - SURPRISEBAG_DESC: שקית מבריקה סגורה בסלוטייפ. משהו בפנים מרשרש. אין דרך לדעת מה, חוץ מדרך אחת. / A shiny bag sealed with tape. Something inside rustles. There's no way to know what, except one.
  - BAGS_SURPRISE_BILL: בפנים: שטר של 20 שקלים, מקופל שמונה פעמים, כמו שצריך. / Inside: a 20-sheckel bill, folded eight times, the proper way.
