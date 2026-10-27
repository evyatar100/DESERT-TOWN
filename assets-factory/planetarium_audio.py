"""Convert the founder's planetarium recording (mp3) to the game's BGM ogg (TG10, interim).

Untrimmed, 44.1 kHz stereo, so the timeline equals the timing file's offset 0.
Kerem's ogg overwrites the output later. Needs soundfile (libsndfile >= 1.1 reads MP3).

    python assets-factory/planetarium_audio.py [SOURCE] [--quality 0.3]
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

REPO = Path(__file__).resolve().parents[1]
SOURCE = REPO / "external_files" / "planetarium.mp3"
OUT = REPO / "game-files" / "Audio" / "BGM" / "planetarium.ogg"
MAX_BYTES = 10 * 1024 * 1024
BLOCK = 44100 * 10


GAIN_DB = -4.5    # source is ~4-5 dB hotter than the map BGM and peaks over full scale
PEAK_MAX = 10 ** (-1.0 / 20)   # keep at least 1 dB headroom


def convert(src: Path, out: Path, quality: float, gain_db: float = GAIN_DB) -> tuple[float, float, float, float]:
    """Writes the ogg; returns (duration s, first zero s, last zero s, output peak) for the longest exact-zero run."""
    gain = 10 ** (gain_db / 20)
    peak = 0.0
    best = (0.0, 0.0)
    run_from = None   # sample index where the open zero run started
    in_zero = False
    pos = 0
    with sf.SoundFile(str(src)) as inp:
        rate = inp.samplerate
        with sf.SoundFile(str(out), "w", samplerate=rate, channels=inp.channels, format="OGG",
                          subtype="VORBIS", compression_level=1.0 - quality) as dst:
            for block in inp.blocks(blocksize=BLOCK, dtype="float32", always_2d=True):
                scaled = block * gain
                peak = max(peak, float(np.abs(scaled).max()))
                dst.write(scaled)
                silent = np.all(block == 0, axis=1)
                flips = np.flatnonzero(np.diff(np.r_[in_zero, silent].astype(np.int8)))
                for i in flips:
                    if run_from is None:
                        run_from = pos + i
                    else:
                        if (pos + i - run_from) / rate > best[1] - best[0]:
                            best = (run_from / rate, (pos + i) / rate)
                        run_from = None
                in_zero = bool(silent[-1])
                pos += len(block)
    if run_from is not None and (pos - run_from) / rate > best[1] - best[0]:
        best = (run_from / rate, pos / rate)
    return pos / rate, best[0], best[1], peak


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("source", nargs="?", type=Path, default=SOURCE)
    parser.add_argument("--quality", type=float, default=0.3, help="Vorbis quality 0..1 (default 0.3)")
    parser.add_argument("--gain-db", type=float, default=GAIN_DB, help="level change in dB (default %.1f)" % GAIN_DB)
    args = parser.parse_args(argv)
    if not args.source.exists():
        print("missing %s" % args.source)
        return 2
    duration, z0, z1, peak = convert(args.source, OUT, args.quality, args.gain_db)
    size = OUT.stat().st_size
    print("wrote %s: %.3f s, %d bytes, gain %.1f dB, peak %.1f dBFS; longest exact silence %.2f-%.2f s"
          % (OUT, duration, size, args.gain_db, 20 * np.log10(peak + 1e-12), z0, z1))
    if peak > PEAK_MAX:
        print("peak above -1 dBFS: rerun with a lower --gain-db")
        return 1
    if size > MAX_BYTES:
        print("over the 10 MB target: rerun with a lower --quality")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
