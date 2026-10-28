Yotam Carmeli | 2026-10-27 | TG11 Temple hoop: final he + en for the 8 HOOP_* UI keys

Replaces the "draft": "Dor, for Yotam" values in `game-files/PBS/translations.json`; Claudet merges and drops the `draft` field. `HOOP_EVYATAR_LINE` is not in this file and is not touched. All lines are gender-neutral (infinitives or nouns, no second-person verbs). Placeholders `{1}` `{2}` are unchanged.

| key | he | en | note |
|---|---|---|---|
| HOOP_APPROACH | חישוק כדורסל, בין הפסלים. לזרוק? | A hoop among the statues. Shoot? | Limit 34: he 32, en 32. Yes/No comes from the confirm box. The hoop stands between the Kusama and Yonath statues; no Hebrew name for the Temple exists in the game yet, so the line does not name it. |
| HOOP_HINT | צהוב: זריקה / כחול: יציאה | Yellow: shoot / Blue: leave | Limit 40: he 25, en 27. Same shape as TEMPLE_HINT_* (noun after the colon in he, " / " separator). The draft's "·" is replaced to match. |
| HOOP_SHOT | {1}/{2} | {1}/{2} | Kept. The label box is 80 px wide at size 24, too narrow for a word. |
| HOOP_MADE | סל. | In. | Limit 10. A period, not "!": the Temple speaks quietly, and the orange colour carries the cheer. |
| HOOP_SWISH | רק רשת. | Swish. | Limit 10: he 7, en 6. "רק רשת" is the Hebrew commentator's "nothing but net"; the English idiom is 16 characters, so en keeps "Swish." |
| HOOP_MISSED | החטאה. | Miss. | Limit 10. |
| HOOP_RESULT | {1} מתוך {2} | {1} out of {2} | Kept. Limit 24. |
| HOOP_BEST | השיא עד כה: {1} | Best so far: {1} | Limit 24: he 15, en 16. Replaces "this game", which could mean the round, the mini-game or the cabinet run. "So far" holds for a per-run best. |
