// Il pannello Missioni e i pezzi che si sbloccano solo con gli obiettivi, per
// guardarli senza telefono: `flutter test tool/render/missions_render_test.dart`
// scrive i PNG in OUT.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/l10n/app_strings.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/ui/avatar/avatar_look.dart';
import 'package:oberta/ui/screens/online/missions_screen.dart';
import 'package:oberta/ui/theme/app_theme.dart';
import 'package:oberta/ui/widgets/cosmetics/seat_preview.dart';
import 'package:oberta/ui/widgets/player_avatar.dart';

final out = Platform.environment['OUT'] ?? 'build/render/missions';

Future<void> _loadFonts() async {
  for (final (family, files) in [
    ('Georgia', ['Supplemental/Georgia.ttf', 'Supplemental/Georgia Bold.ttf']),
    ('serif', ['Supplemental/Georgia.ttf', 'Supplemental/Georgia Bold.ttf']),
    ('Courier', ['Supplemental/Courier New.ttf', 'Supplemental/Courier New Bold.ttf']),
    ('Roboto', ['Supplemental/Arial.ttf', 'Supplemental/Arial Bold.ttf']),
  ]) {
    final loader = FontLoader(family);
    for (final file in files) {
      final f = File('/System/Library/Fonts/$file');
      if (f.existsSync()) loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
    await loader.load();
  }
  final icons = File('${Platform.environment['FLUTTER_ROOT'] ?? ''}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())))).load();
  }
}

Future<void> _shot(WidgetTester tester, Size size, Widget child, String file, {Duration settle = Duration.zero}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  final key = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        locale: AppLanguage.it.locale,
        supportedLocales: AppLanguage.locales,
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: child,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(settle);
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

  testWidgets('il pannello Missioni: oggi, settimana, obiettivi', (tester) async {
    final online = FakeOnline()..signInReady(handle: 'anna');
    final me = online.accountId;
    online.progress.stats[me] = {'role_win:detective': 5, 'nights': 7, 'lynch_hits': 3, 'wins': 12, 'reputation': 86};
    final daily = online.progress.missions[me] = [...FakeProgress.pool];
    daily[0] = daily[0].copyWith(progress: daily[0].target, completed: true);
    daily[1] = daily[1].copyWith(progress: 1);
    for (final (i, tab) in [(0, 'oggi'), (1, 'settimana'), (2, 'obiettivi')]) {
      await _shot(tester, const Size(390, 844), MissionsScreen(progress: online.progress, tab: i), 'missioni_$tab.png',
          settle: const Duration(milliseconds: 600));
    }
  });

  testWidgets('i pezzi delle missioni', (tester) async {
    Widget card(SeatBorder border, NameStyle style) => SizedBox(
          width: 120,
          child: SeatPreview(
            name: 'Vito',
            look: AvatarLook.fallback('Vito').wearing(LookSlot.border, border.name)!.wearing(LookSlot.nameStyle, style.name)!,
          ),
        );
    await _shot(
      tester,
      const Size(420, 300),
      ColoredBox(
        color: const Color(0xFF120C08),
        child: Center(
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              card(SeatBorder.badge, NameStyle.siren),
              card(SeatBorder.noose, NameStyle.moonlight),
              card(SeatBorder.laurel, NameStyle.bloodInk),
              PlayerAvatar(seed: 'Vito', look: AvatarLook.fallback('Vito').wearing(LookSlot.hat, 'sbirro'), size: 140),
            ],
          ),
        ),
      ),
      'pezzi_missioni.png',
    );
  });
}
