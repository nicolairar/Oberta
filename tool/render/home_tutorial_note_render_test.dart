// Il vicolo al primo avvio, col biglietto del tutorial: sui telefoni piccolo,
// medio e grande (375×667, 393×852, 430×932) e sul PC a 1080p, per vedere che
// il biglietto si legge intero e niente gli finisce sopra.
// `flutter test tool/render/home_tutorial_note_render_test.dart` scrive i PNG in OUT.
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
import 'package:oberta/online/online_services.dart';
import 'package:oberta/settings/app_settings.dart';
import 'package:oberta/settings/display_settings.dart';
import 'package:oberta/settings/settings_store.dart';
import 'package:oberta/ui/desktop/desktop_frame.dart';
import 'package:oberta/ui/desktop/desktop_platform.dart';
import 'package:oberta/ui/screens/home_screen.dart';
import 'package:oberta/ui/theme/app_theme.dart';

final out = Platform.environment['OUT'] ?? 'build/render/home_tutorial_note';

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

final _key = GlobalKey();

void main() {
  for (final (name, size, ratio, top, bottom, desk) in const [
    ('phone_s_375x667', Size(375, 667), 2.0, 20.0, 0.0, false),
    ('phone_m_393x852', Size(393, 852), 3.0, 59.0, 34.0, false),
    ('phone_l_430x932', Size(430, 932), 3.0, 59.0, 34.0, false),
    ('desktop_1920x1080', Size(1920, 1080), 1.0, 0.0, 0.0, true),
  ]) {
    for (final language in [AppLanguage.it, AppLanguage.en]) {
      testWidgets('il biglietto del tutorial, $name ${language.name}', (tester) async {
        await tester.runAsync(_loadFonts);
        tester.view.physicalSize = size * ratio;
        tester.view.devicePixelRatio = ratio;
        tester.view.padding = FakeViewPadding(top: top * ratio, bottom: bottom * ratio);
        addTearDown(tester.view.reset);
        if (desk) {
          DesktopPlatform.debugOverride = true;
          addTearDown(() => DesktopPlatform.debugOverride = null);
        }
        AppSettings.instance = AppSettings(MemorySettingsStore());
        // Al primo avvio non si è ancora entrati.
        OnlineServices.instance = FakeOnline(accountId: 'nuovo').services;
        addTearDown(() => OnlineServices.instance = null);
        tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
        await tester.pumpWidget(RepaintBoundary(
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
            builder: desk ? (context, child) => DesktopFrame(orientation: DesktopOrientation.landscape, child: child!) : null,
            home: HomeScreen(onSettings: () {}, offerTutorial: true),
          ),
        ));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('tutorial.note')), findsOneWidget);
        await tester.runAsync(() async {
          final boundary = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: ratio);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File('$out/${name}_${language.name}.png')
            ..createSync(recursive: true)
            ..writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      });
    }
  }
}
