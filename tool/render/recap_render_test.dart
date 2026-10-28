// «Il resoconto» di fine partita e i biglietti al tavolo, sul telefono
// (393x852) e sul desktop (1920x1080). `flutter test
// tool/render/recap_render_test.dart` scrive i PNG in OUT.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/l10n/app_strings.dart';
import 'package:oberta/l10n/recap_strings.dart';
import 'package:oberta/rules/game_engine.dart';
import 'package:oberta/rules/game_recap.dart';
import 'package:oberta/rules/game_setup.dart';
import 'package:oberta/rules/player.dart';
import 'package:oberta/ui/desktop/desktop_frame.dart';
import 'package:oberta/ui/desktop/desktop_platform.dart';
import 'package:oberta/settings/display_settings.dart';
import 'package:oberta/ui/screens/online/recap_screen.dart';
import 'package:oberta/ui/theme/app_theme.dart';
import 'package:oberta/ui/widgets/noir_notice.dart';

import '../../test/support/random_game.dart';

final out = Platform.environment['OUT'] ?? 'build/render/recap';

const _fonts = {
  'Georgia': ['Georgia.ttf', 'Georgia Bold.ttf', 'Georgia Italic.ttf'],
  'serif': ['Georgia.ttf', 'Georgia Bold.ttf'],
  'Courier': ['Courier New.ttf', 'Courier New Bold.ttf'],
};

Future<void> _loadFonts() async {
  const dir = '/System/Library/Fonts/Supplemental';
  for (final MapEntry(key: family, value: files) in _fonts.entries) {
    final loader = FontLoader(family);
    for (final file in files) {
      final f = File('$dir/$file');
      if (f.existsSync()) loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
    await loader.load();
  }
  final material = '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/homebrew/share/flutter'}'
      '/bin/cache/artifacts/material_fonts';
  for (final (family, files) in [
    ('MaterialIcons', ['MaterialIcons-Regular.otf']),
    ('Roboto', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Italic.ttf']),
  ]) {
    final loader = FontLoader(family);
    for (final file in files) {
      final f = File('$material/$file');
      if (f.existsSync()) loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
    await loader.load();
  }
}

final _key = GlobalKey();

Future<void> _shot(WidgetTester tester, String name, double ratio) async {
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pump(const Duration(milliseconds: 400));
  await tester.runAsync(() async {
    final boundary = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: ratio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Widget _app(Widget home, AppLanguage language, {bool desk = false}) => RepaintBoundary(
      key: _key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        locale: language.locale,
        supportedLocales: AppLanguage.locales,
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        builder: desk ? (context, child) => DesktopFrame(orientation: DesktopOrientation.landscape, child: child!) : null,
        home: home,
      ),
    );


GameRecap _recap() {
  const names = ['Bruno', 'Carla', 'Dario', 'Elena', 'Fausto', 'Gina', 'Ivo', 'Lia', 'Marco', 'Nadia'];
  for (var seed = 1;; seed++) {
    final random = Random(seed);
    final lobby = [for (final (i, n) in names.indexed) Player(id: 's${i + 1}', name: n)];
    final engine = GameEngine(GameSetup.deal(lobby: lobby, random: random), seed: random.nextInt(1 << 32));
    for (var step = 0; step < 3000 && engine.phase != GamePhase.ended; step++) {
      final command = randomCommand(engine, random);
      if (command == null) break;
      engine.run(command);
    }
    final recap = engine.recap;
    if (recap != null && recap.nights.length >= 3 && recap.days.any((d) => d.votes.length > 4)) return recap;
  }
}

Widget _table(AppLanguage language) => Builder(
      builder: (context) => Scaffold(
        backgroundColor: const Color(0xFF15100C),
        body: Center(
          child: TextButton(
            onPressed: () {
              final r = RecapStrings.of(context);
              showNotice(context, r.wentAway('Bruno'), kind: NoticeKind.away);
              showNotice(context, r.cameBack('Carla'), kind: NoticeKind.arrive);
            },
            child: const Text('go'),
          ),
        ),
      ),
    );

void _phone(WidgetTester tester) {
  addTearDown(tester.view.reset);
  tester.view.physicalSize = const Size(393, 852) * 3;
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
}

void _desk(WidgetTester tester) {
  DesktopPlatform.debugOverride = true;
  addTearDown(() => DesktopPlatform.debugOverride = null);
  addTearDown(tester.view.reset);
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
}

void main() {
  setUpAll(_loadFonts);
  final recap = _recap();

  for (final language in [AppLanguage.it, AppLanguage.en]) {
    testWidgets('resoconto telefono ${language.name}', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(RecapScreen(recap: recap, me: recap.roles.keys.first), language));
      await tester.pumpAndSettle();
      await _shot(tester, 'phone_${language.name}_1_recap', 2);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
      await tester.pumpAndSettle();
      await _shot(tester, 'phone_${language.name}_2_timeline', 2);
    });

    testWidgets('resoconto desktop ${language.name}', (tester) async {
      _desk(tester);
      await tester.pumpWidget(_app(RecapScreen(recap: recap, me: recap.roles.keys.first), language, desk: true));
      await tester.pumpAndSettle();
      await _shot(tester, 'desk_${language.name}_1_recap', 1);
    });

    testWidgets('biglietti telefono ${language.name}', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(_table(language), language));
      await tester.tap(find.text('go'));
      await tester.pump(const Duration(milliseconds: 400));
      await _shot(tester, 'phone_${language.name}_3_notices', 2);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('biglietti desktop ${language.name}', (tester) async {
      _desk(tester);
      await tester.pumpWidget(_app(_table(language), language, desk: true));
      await tester.tap(find.text('go'));
      await tester.pump(const Duration(milliseconds: 400));
      await _shot(tester, 'desk_${language.name}_2_notices', 1);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  }
}
