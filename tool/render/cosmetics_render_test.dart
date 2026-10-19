// Le cornici e gli inchiostri della bottega, per guardarli senza telefono:
// `flutter test tool/render/cosmetics_render_test.dart` scrive i PNG in OUT.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/ui/avatar/avatar_look.dart';
import 'package:oberta/ui/theme/app_theme.dart';
import 'package:oberta/ui/widgets/cosmetics/seat_preview.dart';
import 'package:oberta/ui/widgets/cosmetics/styled_name.dart';

final out = Platform.environment['OUT'] ?? 'build/render/cosmetics';

Future<void> _loadFonts() async {
  for (final (family, files) in [
    ('Georgia', ['Supplemental/Georgia.ttf', 'Supplemental/Georgia Bold.ttf']),
    ('serif', ['Supplemental/Georgia.ttf', 'Supplemental/Georgia Bold.ttf']),
    ('Roboto', ['Supplemental/Arial.ttf', 'Supplemental/Arial Bold.ttf']),
    ('Apple Symbols', ['Apple Symbols.ttf']),
  ]) {
    final loader = FontLoader(family);
    for (final file in files) {
      final f = File('/System/Library/Fonts/$file');
      if (f.existsSync()) loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
    await loader.load();
  }
}

const _names = ['Vito', 'Rosa', 'Nino', 'Lucia', 'Ugo', 'Carla', 'Dino', 'Gina', 'Elio', 'Pia', 'Ottavio', 'Teresa'];

Future<void> _shot(WidgetTester tester, Size size, Widget child, String file) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  final key = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: DefaultTextStyle(style: const TextStyle(fontFamily: 'Roboto'), child: child),
      ),
    ),
  );
  await tester.pump();
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$file')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('cornici e nomi', (tester) async {
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await _shot(
      tester,
      const Size(760, 760),
      Container(
        color: const Color(0xFF14110F),
        padding: const EdgeInsets.all(18),
        child: Wrap(
          spacing: 26,
          runSpacing: 22,
          children: [
            for (final (i, border) in SeatBorder.values.indexed)
              SizedBox(
                width: 150,
                child: Column(
                  children: [
                    SizedBox(
                      width: 118,
                      child: SeatPreview(
                        name: _names[i],
                        look: AvatarLook.fallback(_names[i]).copyWith(border: border),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(border.name, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
          ],
        ),
      ),
      'borders.png',
    );

    await _shot(
      tester,
      const Size(560, 560),
      Container(
        color: const Color(0xFF14110F),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final style in NameStyle.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(style.name, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ),
                    StyledName('Vito', text: 'DON VITO', style: style, base: AppText.display(26, color: AppColors.textPrimary)),
                    const SizedBox(width: 24),
                    StyledName('rosa', text: 'rosa:', style: style, base: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
          ],
        ),
      ),
      'names.png',
    );

    await _shot(
      tester,
      const Size(520, 260),
      Container(
        color: const Color(0xFF14110F),
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final (name, border, style) in [
              ('Ottavio', SeatBorder.flame, NameStyle.inferno),
              ('Lucia', SeatBorder.neonPulse, NameStyle.shimmer),
              ('Rosa', SeatBorder.roseThorns, NameStyle.tramonto),
            ])
              SizedBox(
                width: 140,
                child: SeatPreview(name: name, look: AvatarLook.fallback(name).copyWith(border: border, nameStyle: style)),
              ),
          ],
        ),
      ),
      'legendary.png',
    );
  });
}
