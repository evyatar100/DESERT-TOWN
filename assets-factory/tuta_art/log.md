# DT2017 Tuta generation log (model gemini-3.1-flash-image, est $0.067/call)

| call | gen | model | prompt source | lint verdict | kept/retried | running /20 | spend |
|---|---|---|---|---|---|---|---|
| 01 | G1 run sheet | gemini-3.1-flash-image | brief core + Tuta text + style lock, work/dt2017/prompts.py; refs: crop1 (sitting), crop2 (face) | PASS-PARTIAL: 4x4 correct, 18 colours, no green, binary alpha; row 3 had one cell facing left (fixed in PIL by mirroring row 2); cloudy eye NOT readable at 32 px | kept | 1/20 | $0.067 |
| 02 | G2 poses | gemini-3.1-flash-image | same, work/dt2017/prompts.py | PASS-PARTIAL: 2x2 correct, 26 colours, cloudy eye visible at 64 px; strawberry leaves quantize to grey | kept | 2/20 | $0.067 |

Total: 2 paid calls, est $0.134. B1 budget 5 (3+2), 3 unused. A no-key start-up failure before call 1 sent no request; its ledger slot was released.

| call | gen | model | prompt source | lint verdict | kept/retried | running /20 | spend |
|---|---|---|---|---|---|---|---|
| 03 | G3 man run | gemini-3.1-flash-image | work/dt2017/prompts.py + pixel-sprite anchors and cropped photos as refs; source_type generated_sprite_sheet | PASS: 4x4, 16 colours, rows face viewer/left/right/away, red shirt and goatee readable | kept | 3/20 | $0.201 |
| 04 | G4 woman run | gemini-3.1-flash-image | work/dt2017/prompts.py + pixel-sprite anchors and cropped photos as refs; source_type generated_sprite_sheet | PASS: 4x4, 24 colours, curls and blue top readable (blue quantizes dark navy) | kept | 4/20 | $0.268 |
| 05 | G5 owner poses | gemini-3.1-flash-image | work/dt2017/prompts.py + pixel-sprite anchors and cropped photos as refs; source_type generated_sprite_sheet | PARTIAL: 3x2, 20 colours, all 6 poses read; phone and heart thin at 32x40 (uniform scale shrinks figures to fit the heart) | kept | 5/20 | $0.335 |
| 06 | G6 pickups | gemini-3.1-flash-image | work/dt2017/prompts.py + pixel-sprite anchors and cropped photos as refs; source_type generated_sprite_sheet | PASS: 4x1, 27 colours, leaves stay green, binary alpha | kept | 6/20 | $0.402 |
| 07 | G7 statue | gemini-3.1-flash-image | work/dt2017/prompts.py + pixel-sprite anchors and cropped photos as refs; source_type generated_sprite_sheet | PASS: 48x80 frame tiled 4x4 to 192x320, 27 colours, cloudy eye visible, plaque quantizes orange not gold | kept | 7/20 | $0.469 |
| 08 | G8 win card | gemini-3.1-flash-image | work/dt2017/prompts.py + pixel-sprite anchors and cropped photos as refs; source_type generated_sprite_sheet | PASS: 256x192, 32 colours, bottom quarter plain dark floor; wall carvings are hieroglyph-like glyphs, no letters | kept | 8/20 | $0.536 |
| 09 | G9 lose card | gemini-3.1-flash-image | work/dt2017/prompts.py + pixel-sprite anchors and cropped photos as refs; source_type generated_sprite_sheet | PARTIAL: likeness good (goatee kept) but bottom quarter is busy, not calm | kept as alt | 9/20 | $0.603 |
| 10 | G9 lose card retry | gemini-3.1-flash-image | work/dt2017/prompts.py + pixel-sprite anchors and cropped photos as refs; source_type generated_sprite_sheet | PASS on calm bottom quarter; man loses moustache/goatee, kiss lands on the dog's head | kept (recommended) | 10/20 | $0.670 |

B2-B4: 8 calls (calls 03-10), $0.536 est; total 10/20, $0.670. B2 3, B3 2, B4 3 (1 retry, G9). Registry source_type for every call: generated_sprite_sheet (cards and pickups are not sheets; label kept for the one registry enum).
