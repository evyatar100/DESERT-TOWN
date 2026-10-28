# DT2019 world map regen: call log

Model gemini-3.1-flash-image, aspect 4:3, image_size 2K (set per call by the work script, no repo edit). Raw output is 2400x1792 (the model snaps to its own grid); resized LANCZOS to 2048x1536 for the master (0.4% aspect squeeze). Ledger: scratch DB `dt2019_ledger`, cap 5, reserved before each call, a call that went out burns its slot.

Spend is an estimate at the 2K tier (about $0.101 per call; the dispatch figure of $0.067 is the 1K price). Billed amount is not verifiable from here: at $0.101 the total is $0.404, at $0.067 it would be $0.268.

| Call | Model / prompt source | Refs | no_visible_text | geometry | palette | Kept / retried | Running count, est. spend |
|---|---|---|---|---|---|---|---|
| 1 | gemini-3.1-flash-image; /home/oded/desert-town/work/dt2019/p1.txt (brief sec. 7 core + sec. 5 heroes) | reference_clean, style_playa, style_kusomo2 | PASS | PASS (max drift 2 master px) | PASS | kept as candidate | 1/5, $0.101 |
| 2 | same prompt, second sample | same | PARTIAL (calligraphy-like marks in mandala) | FAIL (flamingo anchor 78 px; invented chairs/cats/galaxy crate in the void) | PASS | kept as candidate (rejected-quality control) | 2/5, $0.202 |
| 3 | edit pass on call 1: p3.txt | call 1 output, reference_clean | FAIL (circus sign gained glyph-like text) | FAIL (giant chameleon disc invented in the void; hot dog and flamingos lost; anchors still 2 px) | PASS | rejected, regressed; retried with call 4 | 3/5, $0.303 |
| 4 | localized edit of a 3x crop of call 1's mandala: p4.txt, then deterministic composite onto call 1 master (patch.py) | crop of call 1 only | PASS | PASS (max drift 2 px) | PASS | kept as candidate | 4/5, $0.404 |

Call 5: not used (1 slot left unspent).

Notes
- Palette lint: the slide is forced onto the 32 locked colours by nearest-colour quantize with no dither, so palette PASS means that step ran clean (mean RGB error 12.2 before snapping), not that the raw art was on-palette.
- Geometry lint: NCC template match of 8 anchors (brief sec. 6) at half resolution, search +-96 master px. Anchors cannot see invented content in empty areas (calls 2 and 3), so those were judged by eye.
- Text lint: 1:1 crops of circus, mandala, palace, Kusomo, arch, ice camp, flamingo tent, hot dog area on every call.
- Registry: all four calls are registered as `generated_map` (ids in /home/oded/desert-town/work/dt2019/scratch/call0N.json). Call 4's registered image is the raw patch crop; the composite is a post file.
- No winner is picked.
