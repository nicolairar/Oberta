// Le facce dello specchio del barbiere, per guardarle senza telefono:
// `flutter test tool/render/face_render_test.dart` scrive i PNG in OUT.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/ui/avatar/avatar_look.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/ui/avatar/face_presets.dart';
import 'package:oberta/ui/screens/avatar/barber_mirror_screen.dart';
import 'package:oberta/ui/theme/app_theme.dart';
import 'package:oberta/ui/widgets/noir_avatar.dart';
import 'package:oberta/ui/widgets/player_avatar.dart';

final out = Platform.environment['OUT'] ?? 'build/render/face';

const _names = ['Ada', 'Bruno', 'Carla', 'Dino', 'Elio', 'Fabio', 'Gina', 'Ugo', 'Rosa', 'Vito', 'Lucia', 'Nino'];

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('facce', (tester) async {
    tester.view.physicalSize = const Size(900, 1080) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    final base = AvatarLook.fallback('Ada').copyWith(hat: AvatarHead.slicked);
    final presets = [for (final p in FacePreset.all) p.applyTo(base)];
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Container(
            color: const Color(0xFF14110F),
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 6, runSpacing: 6, children: [for (final l in presets) PlayerAvatar(seed: 'x', look: l, size: 120)]),
                const SizedBox(height: 8),
                Wrap(spacing: 6, children: [for (final l in presets) PlayerAvatar(seed: 'x', look: l, size: 40)]),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [for (final n in _names) PlayerAvatar(seed: n, size: 64)]),
                const SizedBox(height: 8),
                Wrap(spacing: 4, runSpacing: 4, children: [
                  for (final h in HairStyle.values)
                    PlayerAvatar(seed: h.name, look: presets[h.index % presets.length].copyWith(
                      features: presets[h.index % presets.length].features.copyWith(hair: h)), size: 70),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await capture(tester, key, 'faces');
  });

  testWidgets('specchio', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final online = FakeOnline()..signInReady(handle: 'anna');
    final profile = await online.profiles.me();
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: BarberMirrorScreen(services: online.services, profile: profile, firstTime: true),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const Key('mirror.preset.lucia')));
    await tester.tap(find.text('Capelli'));
    await tester.pump(const Duration(seconds: 1));
    await capture(tester, key, 'mirror');
  });
}
