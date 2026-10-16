# The narrator's voice

When nobody at the table is the narrator, the phone speaks the script itself
with pre-recorded clips: Kokoro TTS (`kokoro-onnx`), Italian voice
`im_nicola`, English voice `am_adam`, speed 0.86, then the "godfather" effect
chain (`fx.py`: low-shelf warmth, saturation, a small room, faint crackle).

## Regenerate

After changing any text in `lib/narration/*_pack.dart`:

    tool/voice/regenerate.sh

It dumps every speakable segment to `lines.json` (via
`flutter test tool/voice/dump_lines_test.dart`), records only what is new or
changed into `assets/voice/<lang>/<key>.m4a`, updates `assets/voice/index.json`
(key -> duration in ms) and deletes clips whose text left the packs.
`--force` re-records everything; `--lang it` does one language.

To hear one phrase as the voice will say it:

    tool/voice/.venv/bin/python tool/voice/generate.py --lang it --say "Chicago, 1929." --out /tmp/try.wav

## One-time setup (macOS)

    brew install espeak-ng
    python3 -m venv tool/voice/.venv
    tool/voice/.venv/bin/pip install -r tool/voice/requirements.txt
    mkdir -p tool/voice/models
    curl -L -o tool/voice/models/kokoro-v1.0.onnx \
      https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.onnx
    curl -L -o tool/voice/models/voices-v1.0.bin \
      https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin

The venv and the models (~350 MB) are git-ignored: never commit them. Paths
can be overridden with `VOICE_PYTHON`, `KOKORO_MODELS`,
`PHONEMIZER_ESPEAK_LIBRARY` (default `/opt/homebrew/lib/libespeak-ng.1.dylib`)
and `ESPEAK_DATA_PATH` (default `/opt/homebrew/share/espeak-ng-data`).
Encoding uses macOS `afconvert` (AAC, mono, 48 kbps).

## How a line is cut

A segment is a pack template with `{city}` filled for each city, split at the
dynamic placeholders `{name}`, `{role}`, `{minutes}`. Role labels, the numbers
1..20 (for the minutes) and the city titles are recorded on their own. The key
is FNV-1a 64 of the UTF-8 bytes of `"<lang>|<normalized text>"`
(`voiceKey` in `lib/narration/voice_lines.dart`).

At runtime (`lib/sound/narrator_voice.dart`) a line plays its segment clips in
order; where a player's name is, the voice leaves a short silence and the name
lights up on screen; `{role}` plays the role label, `{minutes}` the number.

## Pronunciation

`pronunciation_it.json` and `pronunciation_en.json` respell words only in the
text sent to the voice; the screen never shows them. Whole words,
case-sensitive, longest first. Italian marks stress with accents
(`Chicago` -> `Scicàgo`); English respellings must be lowercase, because the
phonemizer spells capitals out letter by letter. Numbers and years are spelled
out by `spoken_numbers.py` (1929 -> millenovecentoventinove / nineteen
twenty-nine). Changing the dictionary re-records only the affected clips
(`manifest.json` keeps a fingerprint of what each clip actually says).
