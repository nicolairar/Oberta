// The frames and the name inks at the table's size: a long name is always
// written whole on the plate (narrowed, never cut), and a frame stays close
// around its card, whatever it is.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/online/online_services.dart' show Profile, WornLooks;
import 'package:oberta/ui/avatar/avatar_look.dart';
import 'package:oberta/ui/screens/online/game/seat_card.dart';
import 'package:oberta/ui/widgets/cosmetics/seat_frame.dart';

void main() {
  testWidgets('every ink writes a twelve-letter name whole on the 74 px plate', (tester) async {
    // The real serif where the machine has it: its capitals are wide.
    final georgia = File('/System/Library/Fonts/Supplemental/Georgia Bold.ttf');
    if (georgia.existsSync()) {
      await tester.runAsync(() => (FontLoader('Georgia')..addFont(Future.value(ByteData.sublistView(georgia.readAsBytesSync())))).load());
    }
    final failures = <String>[];
    for (final ink in NameStyle.values) {
      for (final name in ['massimiliano', 'bartolomeo12', 'wwwwwwwwwwww']) {
        WornLooks.clear();
        WornLooks.remember(Profile(id: name, handle: name, avatar: AvatarLook.fallback(name).copyWith(nameStyle: ink).toJson()));
        await tester.pumpWidget(MaterialApp(home: Center(child: SeatCard(name: name, number: 3, width: 74))));
        await tester.pump(const Duration(milliseconds: 50));
        for (final p in tester.renderObjectList<RenderParagraph>(find.byType(RichText))) {
          if (p.text.toPlainText().toLowerCase() == name && p.didExceedMaxLines) failures.add('${ink.name}: $name is cut');
        }
      }
    }
    await tester.pumpWidget(const SizedBox());
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('every frame stays close around its card', () async {
    const card = Size(74, 74 * 1.32 - 20 * 0.45);
    const pad = 40.0;
    final failures = <String>[];
    for (final border in SeatBorder.values) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..translate(pad, pad);
      SeatFramePainter(border, radius: card.width / 2, thickness: SeatFrame.thicknessFor(card.width)).paint(canvas, card);
      final image = await recorder.endRecording().toImage((card.width + pad * 2).ceil(), (card.height + pad * 2).ceil());
      final bytes = (await image.toByteData())!.buffer.asUint8List();
      // How far past the card the farthest visible pixel lies.
      var reach = 0.0;
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          if (bytes[(y * image.width + x) * 4 + 3] < 40) continue;
          final dx = (x < pad ? pad - x : x - pad - card.width).clamp(0.0, double.infinity);
          final dy = (y < pad ? pad - y : y - pad - card.height).clamp(0.0, double.infinity);
          reach = [reach, dx, dy].reduce((a, b) => a > b ? a : b);
        }
      }
      image.dispose();
      // Neighbouring seats sit a dozen points apart: a frame may glow or
      // flicker past the card, not reach into the next one.
      if (reach > 12) failures.add('${border.name} reaches ${reach.toStringAsFixed(1)} px past the card');
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('the four suits are drawn, not typed', () {
    for (var suit = 0; suit < 4; suit++) {
      final bounds = SeatFramePainter.suitPath(suit, const Offset(10, 10), 5).getBounds();
      expect(bounds.isEmpty, isFalse);
      expect(const Rect.fromLTRB(4, 4, 16, 16).contains(bounds.topLeft) && const Rect.fromLTRB(4, 4, 16, 16).contains(bounds.bottomRight), isTrue, reason: 'suit $suit');
    }
  });
}
