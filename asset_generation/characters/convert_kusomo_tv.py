"""Convert external_files/kusomo-tv/*.mp4 to Theora/Vorbis .ogv in game-files/Movies (TG20).

Output is 512x288 letterboxed in 512x384 (the game screen), 24 fps, so play_movie
looks right whether or not it keeps the aspect ratio.
"""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "external_files" / "kusomo-tv"
DST = ROOT / "game-files" / "Movies"
FFMPEG = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(
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


def main():
    DST.mkdir(exist_ok=True)
    for vid, stem in VIDEOS.items():
        out = DST / f"kusomo_{vid}.ogv"
        cmd = [str(FFMPEG), "-y", "-i", str(SRC / f"{stem}.mp4"), "-vf", VF,
               "-c:v", "libtheora", "-q:v", "5", "-c:a", "libvorbis", "-q:a", "3",
               "-ac", "2", "-ar", "44100", str(out)]
        subprocess.run(cmd, check=True)
        print(out.name, out.stat().st_size)


if __name__ == "__main__":
    main()
