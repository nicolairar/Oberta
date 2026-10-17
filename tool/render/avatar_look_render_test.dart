// Il guardaroba, per guardarlo senza telefono:
// `flutter test tool/render/avatar_look_render_test.dart` scrive i PNG in OUT.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/ui/avatar/avatar_look.dart';
import 'package:oberta/ui/avatar/seated_character.dart';
import 'package:oberta/ui/widgets/player_avatar.dart';

final out = Platform.environment['OUT'] ?? 'build/render/avatar';

const _names = [
  'Ada', 'Bruno', 'Carla', 'Dino', 'Elio', 'Fabio', 'Gina', 'Ugo', //
  'Massimiliano', 'Rosa', 'Teresa', 'Vito', 'Lucia', 'Nino', 'Ottavio', 'Pia',
];

void main() {
  testWidgets('guardaroba', (tester) async {
    tester.view.physicalSize = const Size(840, 980) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Container(
            color: const Color(0xFF14110F),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final name in _names) SeatedCharacter(look: AvatarLook.fallback(name), size: 76, seed: name),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final name in _names) PlayerAvatar(seed: name, size: 64),
                    for (final name in _names.take(4)) PlayerAvatar(seed: name, size: 64, fallen: true),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final name in ['Ada', 'Rosa', 'Vito'])
                      SeatedCharacter(look: AvatarLook.fallback(name), size: 200, seed: name),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$out/wardrobe.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    for (final name in _names) {
      debugPrint('$name ${AvatarLook.fallback(name).toJson()}');
    }
  });
}
