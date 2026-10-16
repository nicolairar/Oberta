#!/bin/sh
# Rewrites the narrator's script from the packs and records whatever is new
# or changed, for both languages. Unchanged clips are kept; clips whose text
# left the packs are deleted. See tool/voice/README.md for the one-time setup.
set -e
cd "$(dirname "$0")/../.."

PYTHON="${VOICE_PYTHON:-tool/voice/.venv/bin/python}"
if [ ! -x "$PYTHON" ]; then
  echo "No Python at $PYTHON: set up the venv (tool/voice/README.md) or set VOICE_PYTHON." >&2
  exit 1
fi

flutter test tool/voice/dump_lines_test.dart
"$PYTHON" tool/voice/generate.py "$@"
