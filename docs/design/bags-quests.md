# TG7: further bag quests (ideas only)

Michal, 2026-10-26. Nothing here is built. Characters are all in `asset_generation/characters/locations.json` (map, event in brackets).

## The thread

A bag is the one object you hand over before you know what is in it. Hebrew knows this: חתול בשק (a cat in a sack, buying blind), שק ועפר (sackcloth and dust, mourning, and also sandbags that hold a tent down), שק חבטות (punching bag, who takes the hits), שקית ניילון (plastic bag, the thing that drifts across the playa and breaks the Leave No Trace rule), לשים בשק (to bag someone, to put them away), שק שינה (sleeping bag). Each idea below turns one idiom into a choice with a cost.

## Status

| Quest | Status |
|---|---|
| Surprise bags + Inbar's birthday + song "שקיות הפתעה" (Inbar, Shirpaz & Esther unicorns) | Implemented in TG7 |
| Toga: "what is a bag" and the Bag of Bags gift | Implemented in TG7 |
| Toga: the Desert Bag, once | Implemented in TG7 |
| Pixel's חתול בשק trade | Implemented in TG7 |
| Desert bag loop (Bag of Bags to Desert Bag to Pixel to Surprise Bag) | Implemented in TG7 |
| Surprise bag random opening | Implemented in TG7 |
| Candidates 1 to 7 below | Not built |

## Candidates

**1. שק ועפר: the sandbag choice.** Sash (Map099 event 2) keeps asking where her shade cloth is; her tent will fly off in the next wind. Hook: she needs a bag of desert to anchor it. Choice: weigh down her tent, or her neighbour Sivanbi's (Map099 event 3), who is standing right there. Consequence: the next dust storm blows the other one away, and that character's line changes for the rest of the run. A real cost, no wrong answer.

**2. שקית ניילון: the bag in the wind.** Johnny (Map098 event 9), obsessed with the WiFi password, watches a plastic bag circle over the playa. Choice: chase it and pick it up (Leave No Trace, small reward, loses a minute of the "show"), or let it fly. If you let it go, it shows up later, snagged somewhere on another map. Toga's closing line: "גם זו שקית. פשוט כזו שבחרה לטוס."

**3. שק חבטות: who takes the hits.** Yaeli-bli (Map033 event 1) is held in the detention cell until the end of the event for losing a battle. Hook: she wants a punching bag. Choice: give her a Surprise Bag (she punches it, random outcome, possibly confetti) or keep it. The idiom does the work: the person punched, not the bag, is the player who picked the wrong fight.

**4. הצצה בשקית: the polaroid peek.** Polaroider (Map110 event 1) will photograph anything in your bag, "enjoy the moment". Choice: photograph a closed Surprise Bag and see what is inside before opening it, losing the surprise, or photograph something else for a keepsake. A genuine tension between knowing and surprise, no fetch.

**5. שקית ריקה: the empty-bag mark.** ה-מסחריות (Map096 event 9; "ads in Desertown work!") sells "premium air" in a bag. Choice: buy it and carry an empty bag, a worse deal that pays off later, because Toga treats the empty bag as the best bag in the game and gives one unique line. Chain between characters, no map travel beyond what is there.

**6. שק שינה: the mummy.** Moomia (Map094 event 1) lives in a sleeping bag, which is the right size for a sarcophagus. Choice: unzip it or leave it. If unzipped, a gentle joke and a one-time "found sleeping bag" line. If left shut, nothing, and she says "בההה" like she always does. The player is rewarded for leaving someone's private shape alone, or not.

**7. חמור עם שקים: the donkey.** Elias (Map098 event 4) is asking "איפה חמוריקו?". Hook: his donkey is found wandering with a sack on its back. Choice: open the sack (random, like a Surprise Bag, with a small chance it holds something of Elias's) or return it unopened. Consequence: Elias's reaction differs, and the unopened sack becomes a reward he gives later.

## Notes

- Ideas 4 and 5 use items that already exist (Surprise Bag, Desert Bag). 1, 3 and 7 want one small new flag each in `bags_quest`.
- No idea needs new music or sprites beyond the founder's pending unicorn art.
- Pick by tone: 1 and 4 have the sharpest choices; 2 is the most Burning-Man-specific.
