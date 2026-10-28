// Le regole del gioco sul telefono e sul desktop, e il cartello sul palo del
// vicolo che le apre. `flutter test tool/render/rules_render_test.dart`
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
import 'package:oberta/settings/display_settings.dart';
import 'package:oberta/sound/narrator_voice.dart';
import 'package:oberta/ui/desktop/desktop_frame.dart';
import 'package:oberta/ui/desktop/desktop_platform.dart';
import 'package:oberta/ui/screens/home_screen.dart';
import 'package:oberta/ui/screens/rules_screen.dart';
import 'package:oberta/ui/theme/app_theme.dart';

final out = Platform.environment['OUT'] ?? 'build/render/rules';

const _fonts = {
  'Georgia': ['Georgia.ttf', 'Georgia Bold.ttf', 'Georgia Italic.ttf', 'Georgia Bold Italic.ttf'],
  'serif': ['Georgia.ttf', 'Georgia Bold.ttf', 'Georgia Italic.ttf'],
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
  final material =
      '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/homebrew/share/flutter'}'
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

ThemeData _theme() {
  final theme = buildAppTheme();
  const label = WidgetStatePropertyAll(
    TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700, letterSpacing: 1.6, fontSize: 14),
  );
  return theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
    elevatedButtonTheme: ElevatedButtonThemeData(style: theme.elevatedButtonTheme.style!.copyWith(textStyle: label)),
    outlinedButtonTheme: OutlinedButtonThemeData(style: theme.outlinedButtonTheme.style!.copyWith(textStyle: label)),
    textButtonTheme: const TextButtonThemeData(style: ButtonStyle(textStyle: label)),
  );
}

Future<void> _shot(WidgetTester tester, String name, {double ratio = 1}) async {
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

Future<void> _flush(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
  await tester.pump(const Duration(milliseconds: 600));
}

Widget _material(Widget home, AppLanguage language, {TransitionBuilder? builder}) => RepaintBoundary(
  key: _key,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _theme(),
    locale: language.locale,
    supportedLocales: AppLanguage.locales,
    localizationsDelegates: const [
      AppStrings.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    builder: builder,
    home: home,
  ),
);

Future<void> _desk(WidgetTester tester, Size window, Widget home) async {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding.zero;
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  await tester.pumpWidget(
    _material(
      home,
      AppLanguage.it,
      builder: (context, child) => DesktopFrame(orientation: DesktopOrientation.landscape, child: child!),
    ),
  );
  await _flush(tester);
}

Future<void> _phone(
  WidgetTester tester,
  Size size,
  double top,
  double bottom,
  Widget home, {
  AppLanguage language = AppLanguage.it,
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  tester.view.padding = FakeViewPadding(top: top * 3, bottom: bottom * 3);
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  await tester.pumpWidget(_material(home, language));
  await _flush(tester);
}

Future<void> _scroll(WidgetTester tester, double by) async {
  await tester.drag(find.byType(SingleChildScrollView), Offset(0, -by));
  await _flush(tester);
}

Future<void> _clear(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  setUp(() => NarratorVoice.instance = NarratorVoice.fromJson(File('assets/voice/index.json').readAsStringSync()));

  testWidgets('telefono', (tester) async {
    await tester.runAsync(_loadFonts);
    addTearDown(tester.view.reset);
    for (final (name, size, top, bottom) in [
      ('m', const Size(393, 852), 59.0, 34.0),
      ('s', const Size(375, 667), 20.0, 0.0),
    ]) {
      await _phone(tester, size, top, bottom, HomeScreen(onSettings: () {}));
      await tester.pump(const Duration(seconds: 4));
      await _shot(tester, 'phone_${name}_0_home', ratio: 2);
      await _clear(tester);
    }

    for (final language in AppLanguage.values) {
      final l = language.name;
      await _phone(tester, const Size(393, 852), 59, 34, RulesScreen(onPlayLocal: () {}), language: language);
      await _shot(tester, 'phone_${l}_1_quick', ratio: 2);
      // La voce legge: il capoverso detto si accende e il foglio lo segue.
      await tester.tap(find.byKey(const Key('rules.read')));
      for (var i = 0; i < 90; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await _shot(tester, 'phone_${l}_1b_reading', ratio: 2);
      await tester.tap(find.byKey(const Key('rules.read')));
      await _flush(tester);
      await _scroll(tester, -4000);
      await _scroll(tester, 640);
      await _shot(tester, 'phone_${l}_2_quick_more', ratio: 2);
      await _scroll(tester, 700);
      await _shot(tester, 'phone_${l}_3_quick_end', ratio: 2);
      await tester.ensureVisible(find.byKey(const Key('rules.roles')));
      await _flush(tester);
      await tester.tap(find.byKey(const Key('rules.roles')));
      await _flush(tester);
      await _scroll(tester, 600);
      await _shot(tester, 'phone_${l}_4_roles', ratio: 2);
      await _scroll(tester, -6000);
      await tester.tap(find.byKey(const Key('rules.style.stage')));
      await _flush(tester);
      await _shot(tester, 'phone_${l}_5_stage', ratio: 2);
      await _scroll(tester, 640);
      await _shot(tester, 'phone_${l}_6_stage_more', ratio: 2);
      await _scroll(tester, 700);
      await _shot(tester, 'phone_${l}_7_stage_more', ratio: 2);
      await _scroll(tester, 700);
      await _shot(tester, 'phone_${l}_8_stage_end', ratio: 2);
      await _clear(tester);
    }
  });

  testWidgets('desktop', (tester) async {
    DesktopPlatform.debugOverride = true;
    addTearDown(() => DesktopPlatform.debugOverride = null);
    addTearDown(tester.view.reset);
    await tester.runAsync(_loadFonts);
    await _desk(tester, const Size(1600, 900), HomeScreen(onSettings: () {}));
    await tester.pump(const Duration(seconds: 4));
    await _shot(tester, 'desk_0_home');
    await _clear(tester);
    await _desk(tester, const Size(1600, 900), RulesScreen(onPlayFriends: () {}));
    await _shot(tester, 'desk_1_rules');
    await _scroll(tester, 700);
    await _shot(tester, 'desk_2_rules_more');
    await _scroll(tester, 3000);
    await _shot(tester, 'desk_3_rules_end');
    await _clear(tester);
  });
}
