"""TG57 Batch 1: cut the Desert Town reward stings from Calm Camps Area (read-only).

Writes new 44100 Hz files over Audio/ME/Item get, Key item get and GUI save game.
The BGM is only read, never modified. Re-runnable.
"""
from pathlib import Path

import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parents[2]
AUDIO = ROOT / "game-files" / "Audio"
SOURCE = AUDIO / "BGM" / "Calm Camps Area.ogg"
RATE = 44100
FADE_IN = 0.01
FADE_OUT = 0.4
STINGS = [("Item get.ogg", 2.5), ("Key item get.ogg", 2.5), ("GUI save game.ogg", 1.3)]


def resample(x, src, dst):
    """FFT resample (band-limits when downsampling), per channel."""
    n_out = int(round(len(x) * dst / src))
    spec = np.fft.rfft(x, axis=0)
    keep = n_out // 2 + 1
    out = np.zeros((keep, x.shape[1]), dtype=complex)
    m = min(keep, spec.shape[0])
    out[:m] = spec[:m]
    return np.fft.irfft(out, n=n_out, axis=0) * (n_out / len(x))


def cut(data, rate, seconds):
    seg = data[: int(seconds * rate)].astype(np.float64)
    seg = resample(seg, rate, RATE)
    n = len(seg)
    fi, fo = int(FADE_IN * RATE), int(FADE_OUT * RATE)
    seg[:fi] *= np.linspace(0, 1, fi)[:, None]
    seg[n - fo:] *= np.linspace(1, 0, fo)[:, None]
    return np.clip(seg, -1, 1)


def main():
    with sf.SoundFile(SOURCE) as f:
        rate = f.samplerate
        data = f.read(int(2.6 * rate), always_2d=True)
    for name, seconds in STINGS:
        out = cut(data, rate, seconds)
        sf.write(AUDIO / "ME" / name, out, RATE, format="OGG", subtype="VORBIS")
        print("wrote", name, round(len(out) / RATE, 2), "s")


if __name__ == "__main__":
    main()
