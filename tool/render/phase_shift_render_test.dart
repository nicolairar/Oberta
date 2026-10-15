// Fotogrammi del passaggio giorno/notte: `OUT=<dir> flutter test tool/render/phase_shift_render_test.dart`.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/ui/widgets/phase_shift.dart';

final out = Platform.environment['OUT'] ?? 'build/render';

void main() {
  test('passaggi', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final toNight in [true, false]) {
      for (final t in [0.0, 0.3, 0.5, 0.65, 0.8, 1.0]) {
        const size = Size(340, 150);
        final recorder = ui.PictureRecorder();
        PhaseShiftPainter(t: t, toNight: toNight).paint(Canvas(recorder), size);
        final image = await recorder.endRecording().toImage(340, 150);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/phase_${toNight ? 'night' : 'dawn'}_$t.png')
          ..createSync(recursive: true)
          ..writeAsBytesSync(bytes!.buffer.asUint8List());
      }
    }
  });
}
