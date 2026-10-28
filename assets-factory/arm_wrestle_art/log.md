# DT2016 arm-wrestling generation log
Model gemini-3.1-flash-image (aspects 4:3 / 3:2 / 2:3; API returns ~1200x896, 1264x848, 848x1264, not the brief's native sizes). Spend is an ESTIMATE, $0.067/call. No post-processing. Registry: scratch DB /home/oded/desert-town/work/dt2016/scratch/scratch.db (generated_map for G1, generated_sprite_sheet for G2/G3). Generator: /home/oded/desert-town/work/dt2016/gen.py. Prompt = one preface line + brief text byte-identical + " " + style lock.

| call | image | ref | prompt | lint verdict | kept/retried | count | spend |
|---|---|---|---|---|---|---|---|
| 1 | aw_g1_backdrop_call01.png | dt037 arcade icon (brief names none for G1) | brief byte-identical + style-ref preface | PARTIAL-PASS: table, 2 red pads, shade cloth, lights, dusk OK; centre above table edge reasonably calm but cloth edge/pole nearby; dark spool hole in table centre | kept | 1/6 | ~$0.067 |
| 2 | aw_g2_shirpaz_call02.png | dt_670f79e3.png | brief byte-identical + sprite-match preface | PASS-PARTIAL: 6 cells same size, hat/beard/tattoos/skin match, no green in character; bg is flat ~#319F40 not #00FF00 (keyable by distance) | kept | 2/6 | ~$0.067 |
| 3 | aw_g3_arms_call03.png | dt_670f79e3.png | brief byte-identical + "do not draw him" preface | FAIL: output is a 4x4 character sprite sheet copy, no forearms | rejected (retried) | 3/6 | ~$0.067 |
| 4 | aw_g3_arms_call04.png | dt_670f79e3.png | brief byte-identical + stronger "single object, two arms only" preface | FAIL: same sprite-sheet copy, bg ~#3AA14C | rejected, not retried (1-retry rule) | 4/6 | ~$0.067 |


| 5 | aw_g3_arms_call05.png | single front frame of dt_670f79e3.png, 8x nearest (work/dt2016/ref_frame_front_x8.png) | brief byte-identical + single-object preface (same as call 4) | PARTIAL/FAIL: true #00FF00 bg, forearms not sprite sheet, clasped hands read as gripping, blue cuff + green wristband + tattoos present; but elbows do NOT meet at one point (arms splay in a V, both clipped by frame edges, tattooed arm runs off right) | kept as best available, not retried (founder: stop) | 5/6 | ~$0.067 |

Total 5/6 calls, ~$0.34 est. Call 6 unused by instruction.
