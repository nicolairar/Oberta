"""Writes lib/sound/sound_onsets.dart: where each recording really starts.

Many of the downloaded effects (and a few Kenney samples and memes) open
with silence or room noise: the creak of the noose starts 160 ms in, a kiss
190 ms, some screams a quarter of a second. Fired on the frame of the hit,
they are heard late by exactly that much. The game seeks past it.

For every file in assets/sfx, assets/sounds and assets/meme: decode to
16-bit mono with afconvert (macOS), take the RMS of 5 ms windows, find the
first window within 20 dB of the loudest one and walk back down its attack
while it keeps rising. The onset is there minus 8 ms of pre-roll, so no
attack is clipped; under 12 ms it is left at 0.
Also records the length, which the cue deck uses to plan its players.

    python3 tool/sound/onsets.py
"""

import array
import math
import os
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
FOLDERS = ["sfx", "sounds", "meme"]
OUT = ROOT / "lib" / "sound" / "sound_onsets.dart"

WINDOW_MS = 5
THRESHOLD_DB = -20
PRE_ROLL_MS = 8
MIN_ONSET_MS = 12


def decode(src: Path, tmp: Path):
    dst = tmp / "x.wav"
    subprocess.run(
        ["afconvert", "-f", "WAVE", "-d", "LEI16", "-c", "1", str(src), str(dst)],
        check=True,
        capture_output=True,
    )
    raw = dst.read_bytes()
    i, rate, data = 12, None, None
    while i < len(raw):
        cid = raw[i : i + 4]
        size = struct.unpack("<I", raw[i + 4 : i + 8])[0]
        body = raw[i + 8 : i + 8 + size]
        if cid == b"fmt ":
            rate = struct.unpack("<I", body[4:8])[0]
        if cid == b"data":
            data = array.array("h", body[: len(body) // 2 * 2])
        i += 8 + size + (size & 1)
    return rate, data


def shape(rate, data):
    n = max(1, rate * WINDOW_MS // 1000)
    rms = []
    for start in range(0, len(data), n):
        chunk = data[start : start + n]
        rms.append(math.sqrt(sum(x * x for x in chunk) / len(chunk)) if chunk else 0)
    loudest = max(rms) if rms else 0
    length = round(len(data) / rate * 1000)
    if loudest <= 0:
        return 0, length
    limit = loudest * 10 ** (THRESHOLD_DB / 20)
    first = next(i for i, r in enumerate(rms) if r >= limit)
    # Back down the slope of the attack, as long as it keeps rising: a
    # swell stays whole, the silence (or the hiss) before it does not.
    while first > 0 and rms[first - 1] < rms[first]:
        first -= 1
    onset = first * WINDOW_MS - PRE_ROLL_MS
    return (onset if onset >= MIN_ONSET_MS else 0), length


def main():
    rows = []
    with tempfile.TemporaryDirectory() as tmp:
        for folder in FOLDERS:
            for name in sorted(os.listdir(ROOT / "assets" / folder)):
                if not name.endswith((".m4a", ".wav")):
                    continue
                rate, data = decode(ROOT / "assets" / folder / name, Path(tmp))
                onset, length = shape(rate, data)
                rows.append((f"{folder}/{name}", onset, length))
    lines = [
        "// Generato da tool/sound/onsets.py: non si modifica a mano.",
        "",
        "/// Dove comincia davvero ogni registrazione, e quanto dura, in",
        "/// millisecondi: `(inizio, durata)`. Molti file si aprono con un po' di",
        "/// silenzio (lo scricchiolio del cappio dopo 160 ms, certi urli dopo un",
        "/// quarto di secondo): chi suona sul fotogramma del colpo salta lì.",
        "const soundShapes = <String, (int, int)>{",
    ]
    lines += [f"  '{path}': ({onset}, {length})," for path, onset, length in rows]
    lines += ["};", ""]
    OUT.write_text("\n".join(lines))
    late = sum(1 for _, onset, _ in rows if onset)
    print(f"{len(rows)} files, {late} with a late start -> {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    sys.exit(main())
