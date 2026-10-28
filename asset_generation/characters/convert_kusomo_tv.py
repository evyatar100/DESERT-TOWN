"""Convert external_files/kusomo-tv/*.mp4 to Theora/Vorbis .ogv in game-files/Movies (TG20, TG49).

Output is 512x288 letterboxed in 512x384 (the game screen), 24 fps, so play_movie
looks right whether or not it keeps the aspect ratio.
Usage: python convert_kusomo_tv.py [--ffmpeg PATH] [--out DIR] [--only ID ...]
"""
import argparse
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "external_files" / "kusomo-tv"
DST = ROOT / "game-files" / "Movies"
FFMPEG = Path(
    "C:/Users/toozi/AppData/Local/Packages/PythonSoftwareFoundation.Python.3.10_qbz5n2kfra8p0/"
    "LocalCache/local-packages/Python310/site-packages/imageio_ffmpeg/binaries/"
    "ffmpeg-win-x86_64-v7.1.exe")
# video id -> source file stem; the ids are the ones pbKusomoTV takes.
VIDEOS = {
    "midburn": "kusumo_tv_midburn",
    "mushrooms": "mushrooms_V2",
    "grandma": "tasty_grandma_V2",
    "mohel": "the_mohel_V2",
}
VF = "scale=512:288,pad=512:384:0:48:black,fps=24"
VIDEO_ARGS = ["-c:v", "libtheora", "-q:v", "VQ"]
# TG49: mkxp-z segfaults at the end of a movie whose audio stops before its video, so the
# audio gets 0.6 s of silence and always outlasts the picture.
AUDIO_ARGS = ["-af", "apad=pad_dur=0.6", "-c:a", "libvorbis", "-q:a", "3", "-ac", "2", "-ar", "44100"]
VIDEO_Q = "5"
# TG49: mushrooms ships as two back-to-back parts, cut at the source keyframe at 22.633 s.
SPLITS = {"mushrooms": [(None, 22.633333), (22.633333, None)]}


def command(ffmpeg, src, out, vq=VIDEO_Q, start=None, end=None):
    video = [vq if a == "VQ" else a for a in VIDEO_ARGS]
    # Input-side -ss/-t, so apad still runs past the cut end.
    cut = (["-ss", str(start)] if start else []) + (["-t", str(end - (start or 0))] if end else [])
    cut += ["-i", str(src)]
    return [str(ffmpeg), "-y", "-v", "error", *cut, "-vf", VF, *video, *AUDIO_ARGS, str(out)]


def outputs(vid):
    """(file name, start, end) per output file of one video id."""
    parts = SPLITS.get(vid)
    if not parts:
        return [(f"kusomo_{vid}.ogv", None, None)]
    return [(f"kusomo_{vid}_{i}.ogv", a, b) for i, (a, b) in enumerate(parts, 1)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ffmpeg", type=Path, default=FFMPEG)
    ap.add_argument("--out", type=Path, default=DST)
    ap.add_argument("--only", nargs="*", choices=sorted(VIDEOS))
    ap.add_argument("--vq", default=VIDEO_Q, help="Theora -q:v (0-10)")
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    for vid in args.only or VIDEOS:
        for name, start, end in outputs(vid):
            out = args.out / name
            subprocess.run(command(args.ffmpeg, SRC / f"{VIDEOS[vid]}.mp4", out, args.vq, start, end), check=True)
            print(out.name, out.stat().st_size)


if __name__ == "__main__":
    main()
