"""Mix the Flamingo Band stems into four cumulative BGM stage files (OGG Vorbis).

Run from anywhere: python mastolit-stems-quest/build_band_stages.py [--se-only]
"""
import os
import sys

import numpy as np
import soundfile as sf

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
BGM_DIR = os.path.join(REPO, "game-files", "Audio", "BGM")
SE_DIR = os.path.join(REPO, "game-files", "Audio", "SE")
SE_SOURCE = os.path.join(HERE, "tom_baum_finish.mp3")
SE_TARGET = os.path.join(SE_DIR, "tom_baum_finish.ogg")

STAGES = [
    ("Flamingo Band stage_1", ["drums"]),
    ("Flamingo Band stage_2", ["other", "drums", "bass"]),
    ("Flamingo Band stage_3", ["other", "drums", "bass", "piano", "guitar"]),
    ("Flamingo Band stage_4", ["other", "drums", "bass", "piano", "guitar", "vocals"]),
]
HEADROOM = 0.95
SE_PEAK = 0.95
SAMPLE_RATE = 44100
BLOCK = 1 << 16


def load_stems(names):
    stems = {}
    for name in names:
        data, rate = sf.read(os.path.join(HERE, name + ".wav"), dtype="float32", always_2d=True)
        if rate != SAMPLE_RATE or data.shape[1] != 2:
            sys.exit(f"{name}.wav: expected {SAMPLE_RATE} Hz stereo, got {rate} Hz x {data.shape[1]}")
        stems[name] = data
    lengths = {n: len(d) for n, d in stems.items()}
    if len(set(lengths.values())) != 1:
        sys.exit(f"stem lengths differ: {lengths}")
    return stems


def check_vocals_only_in_last(stages):
    for name, parts in stages[:-1]:
        assert "vocals" not in parts, f"{name} must not contain vocals"
    assert "vocals" in stages[-1][1], "the last stage must contain vocals"


def rms(x):
    return float(np.sqrt(np.mean(np.square(x, dtype=np.float64))))


def report_vocals(title, parts, decoded, expected, vocals):
    # Measured check on the decoded file: which hypothesis (with / without vocals) it matches.
    n = min(len(decoded), len(expected))
    decoded, expected, vocals = decoded[:n], expected[:n], vocals[:n]
    if "vocals" in parts:
        err_match, err_other = rms(decoded - expected), rms(decoded - (expected - vocals))
    else:
        err_match, err_other = rms(decoded - expected), rms(decoded - (expected + vocals))
    has = "vocals" in parts
    print(f"  vocals {'present' if has else 'absent'}: residual {err_match:.5f} vs {err_other:.5f} "
          f"if {'removed' if has else 'added'}")
    assert err_match < err_other * 0.5, f"{title}: decoded audio does not match its vocal layout"


def write_ogg(path, mix):
    with sf.SoundFile(path, "w", samplerate=SAMPLE_RATE, channels=2, format="OGG", subtype="VORBIS") as out:
        for start in range(0, len(mix), BLOCK):
            out.write(mix[start:start + BLOCK])


def build_se():
    data, rate = sf.read(SE_SOURCE, dtype="float32", always_2d=True)
    source_peak = float(np.abs(data).max())
    data = data * (SE_PEAK / source_peak)
    os.makedirs(SE_DIR, exist_ok=True)
    sf.write(SE_TARGET, data, rate, format="OGG", subtype="VORBIS")
    written, _ = sf.read(SE_TARGET, dtype="float32", always_2d=True)
    info = sf.info(SE_TARGET)
    print(f"SE {os.path.basename(SE_TARGET)}: {info.samplerate} Hz x {info.channels}, {info.duration:.3f} s | "
          f"source peak {source_peak:.3f} -> {SE_PEAK} | decoded peak {float(np.abs(written).max()):.3f}")


def main():
    check_vocals_only_in_last(STAGES)
    names = sorted({n for _, parts in STAGES for n in parts})
    stems = load_stems(names)
    mixes = [(title, parts, sum(stems[p] for p in parts)) for title, parts in STAGES]
    raw_peaks = [float(np.abs(m).max()) for _, _, m in mixes]
    gain = HEADROOM / max(raw_peaks)
    print(f"raw peaks: {', '.join(f'{p:.3f}' for p in raw_peaks)}; common gain {gain:.4f}")
    os.makedirs(BGM_DIR, exist_ok=True)
    frame_counts = []
    for (title, parts, mix), raw in zip(mixes, raw_peaks):
        path = os.path.join(BGM_DIR, title + ".ogg")
        write_ogg(path, (mix * gain).astype(np.float32))
        written, rate = sf.read(path, dtype="float32", always_2d=True)
        frame_counts.append(len(written))
        print(f"{title}: {'+'.join(parts)} | mixed peak {raw * gain:.3f} | decoded peak "
              f"{float(np.abs(written).max()):.3f} | {len(written)} frames = {len(written) / rate:.3f} s")
        report_vocals(title, parts, written, mix * gain, stems["vocals"] * gain)
    assert len(set(frame_counts)) == 1, f"stage frame counts differ: {frame_counts}"
    assert frame_counts[0] == len(next(iter(stems.values()))), "stage length differs from the stems"
    build_se()


if __name__ == "__main__":
    if "--se-only" in sys.argv[1:]:
        build_se()
    else:
        main()
