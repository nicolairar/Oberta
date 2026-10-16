"""Records the automatic narrator's voice clips.

Reads tool/voice/lines.json (written by dump_lines_test.dart), rewrites each
text for the ear with pronunciation_<lang>.json, speaks it with Kokoro, runs
the godfather chain and encodes AAC into assets/voice/<lang>/<key>.m4a. The
durations go to assets/voice/index.json.

Incremental: a clip is recorded again only when what the voice has to say
(or how it says it) changed. Clips whose text left the packs are deleted.

    python tool/voice/generate.py            # everything missing or changed
    python tool/voice/generate.py --lang it  # one language
    python tool/voice/generate.py --say "Scicàgo, millenovecentoventinove" --lang it
                                             # just hear one phrase (out.wav)
"""

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
import soundfile as sf

import fx
import spoken_numbers

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
LINES = HERE / "lines.json"
MANIFEST = HERE / "manifest.json"
ASSETS = ROOT / "assets" / "voice"
INDEX = ASSETS / "index.json"
MODELS = Path(os.environ.get("KOKORO_MODELS", HERE / "models"))

ESPEAK_LIB = os.environ.get("PHONEMIZER_ESPEAK_LIBRARY", "/opt/homebrew/lib/libespeak-ng.1.dylib")
ESPEAK_DATA = os.environ.get("ESPEAK_DATA_PATH", "/opt/homebrew/share/espeak-ng-data")
os.environ["PHONEMIZER_ESPEAK_LIBRARY"] = ESPEAK_LIB

# The owner's choice. Changing any of this re-records every clip.
VOICES = {
    "it": {"voice": "im_nicola", "lang": "it"},
    "en": {"voice": "am_adam", "lang": "en-us"},
}
SPEED = 0.86
CHAIN = "godfather-1"  # bump when fx.py or the levelling below changes
BITRATE = 48000

LEAD_IN = 0.04  # seconds of silence kept before the first word
TARGET_RMS = 0.11  # loudness of the voiced part, so short and long clips match


def load_words(lang):
    data = json.loads((HERE / f"pronunciation_{lang}.json").read_text(encoding="utf-8"))
    words = data["words"]
    return sorted(words.items(), key=lambda item: -len(item[0]))


def for_the_ear(text, lang, words):
    """What the voice reads: the on-screen text, respelled where needed."""
    # A segment that starts right after a player's name: drop the joining
    # punctuation and the English possessive, the name itself is not spoken.
    text = re.sub(r"^[\s.,;:!?…'’]*(s\b)?\s*", "", text) if re.match(r"^[\s.,;:!?…'’]", text) else text
    for word, ear in words:
        text = re.sub(r"(?<![\w])" + re.escape(word) + r"(?![\w])", ear, text)

    def number(match):
        n = int(match.group(0))
        if lang == "it":
            return spoken_numbers.italian(n)
        return spoken_numbers.english(n, year=1100 <= n <= 1999)

    text = re.sub(r"\d+", number, text)
    # Guillemets and curly quotes are just pauses to the ear.
    text = text.replace("«", "").replace("»", "").replace("“", "").replace("”", "")
    return text.strip()


def fingerprint(lang, ear):
    setup = VOICES[lang]
    raw = f"{setup['voice']}|{setup['lang']}|{SPEED}|{CHAIN}|{BITRATE}|{ear}"
    return hashlib.sha1(raw.encode("utf-8")).hexdigest()[:16]


def kokoro():
    from kokoro_onnx import Kokoro
    from kokoro_onnx.config import EspeakConfig

    model, voices = MODELS / "kokoro-v1.0.onnx", MODELS / "voices-v1.0.bin"
    for path in (model, voices):
        if not path.exists():
            sys.exit(f"Missing {path}. See tool/voice/README.md for the download.")
    config = EspeakConfig(lib_path=ESPEAK_LIB, data_path=ESPEAK_DATA)
    return Kokoro(str(model), str(voices), espeak_config=config)


def trim(x, sr, threshold=0.012):
    loud = np.flatnonzero(np.abs(x) > threshold * max(np.abs(x).max(), 1e-9))
    if loud.size == 0:
        return x
    start = max(0, loud[0] - int(sr * LEAD_IN))
    end = min(len(x), loud[-1] + int(sr * 0.03))
    return x[start:end]


def level(x, sr):
    voiced = x[np.abs(x) > 0.02]
    rms = float(np.sqrt(np.mean(voiced**2))) if voiced.size else 0.0
    if rms > 0:
        x = x * (TARGET_RMS / rms)
    # A soft ceiling instead of a hard clip, for the loudest syllables.
    return np.tanh(x * 1.1) / np.tanh(1.1) * 0.95 if np.abs(x).max() > 0.95 else x


def end_of_ring(x, sr):
    """Cuts the reverb tail where it falls into the crackle, with a short fade."""
    env = np.abs(x)
    loud = np.flatnonzero(env > 0.01)
    end = min(len(x), (loud[-1] if loud.size else len(x)) + int(sr * 0.08))
    x = x[:end].copy()
    fade = min(len(x), int(sr * 0.08))
    x[len(x) - fade :] *= np.linspace(1, 0, fade)
    return x


def record(tts, lang, ear, seed):
    setup = VOICES[lang]
    samples, sr = tts.create(ear, voice=setup["voice"], speed=SPEED, lang=setup["lang"])
    x = trim(np.asarray(samples, dtype=np.float64), sr)
    x = fx.godfather(x, sr, seed=seed)
    x = end_of_ring(level(x, sr), sr)
    return x, sr


def encode(x, sr, out):
    out.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "clip.wav"
        # afconvert does not take float WAV: 16-bit PCM first.
        sf.write(wav, x, sr, subtype="PCM_16")
        subprocess.run(
            ["afconvert", "-f", "m4af", "-d", "aac", "-b", str(BITRATE), "-c", "1", str(wav), str(out)],
            check=True,
            capture_output=True,
        )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--lang", choices=sorted(VOICES), action="append")
    parser.add_argument("--say", help="speak one phrase to out.wav and stop")
    parser.add_argument("--out", default="out.wav", help="where --say writes")
    parser.add_argument("--force", action="store_true", help="re-record everything")
    args = parser.parse_args()
    langs = args.lang or sorted(VOICES)

    if args.say:
        tts = kokoro()
        x, sr = record(tts, langs[0], for_the_ear(args.say, langs[0], load_words(langs[0])), 5)
        sf.write(args.out, x, sr)
        print(f"{args.out} {len(x) / sr:.2f}s")
        return

    lines = json.loads(LINES.read_text(encoding="utf-8"))
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() else {}
    index = json.loads(INDEX.read_text(encoding="utf-8")) if INDEX.exists() else {}
    tts = None

    for lang in langs:
        words = load_words(lang)
        done = manifest.setdefault(lang, {})
        durations = index.setdefault(lang, {})
        entries = lines[lang]
        wanted = {entry["key"] for entry in entries}
        todo = []
        for entry in entries:
            ear = for_the_ear(entry["text"], lang, words)
            mark = fingerprint(lang, ear)
            clip = ASSETS / lang / f"{entry['key']}.m4a"
            if args.force or done.get(entry["key"]) != mark or not clip.exists() or entry["key"] not in durations:
                todo.append((entry, ear, mark, clip))
        print(f"{lang}: {len(entries)} clips, {len(todo)} to record")
        for i, (entry, ear, mark, clip) in enumerate(todo, 1):
            if tts is None:
                tts = kokoro()
            seed = int(entry["key"][:8], 16)
            x, sr = record(tts, lang, ear, seed)
            encode(x, sr, clip)
            durations[entry["key"]] = int(round(len(x) / sr * 1000))
            done[entry["key"]] = mark
            print(f"  [{i}/{len(todo)}] {durations[entry['key']]:>6} ms  {ear}")
            if i % 20 == 0:
                save(index, manifest)
        # Clips of lines that are no longer in the packs.
        for key in [key for key in durations if key not in wanted]:
            durations.pop(key)
            done.pop(key, None)
            (ASSETS / lang / f"{key}.m4a").unlink(missing_ok=True)
        for path in (ASSETS / lang).glob("*.m4a"):
            if path.stem not in wanted:
                path.unlink()
        save(index, manifest)

    total = sum(path.stat().st_size for path in ASSETS.rglob("*.m4a"))
    count = sum(len(v) for v in index.values())
    print(f"{count} clips, {total / 1e6:.1f} MB")


def save(index, manifest):
    ASSETS.mkdir(parents=True, exist_ok=True)
    ordered = {lang: dict(sorted(index[lang].items())) for lang in sorted(index)}
    INDEX.write_text(json.dumps(ordered, indent=1) + "\n", encoding="utf-8")
    ordered = {lang: dict(sorted(manifest[lang].items())) for lang in sorted(manifest)}
    MANIFEST.write_text(json.dumps(ordered, indent=1) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
