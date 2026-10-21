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
import 'package:oberta/ui/desktop/desktop_frame.dart';
import 'package:oberta/ui/desktop/desktop_platform.dart';
import 'package:oberta/ui/theme/app_theme.dart';

/// Le due finestre desktop che si fotografano: la più piccola e il 1080p.
const desktopSizes = {'1080p': Size(1920, 1080), '720p': Size(1280, 720)};

const _shot = Key('desktop.shot');

Future<void> _fonts() async {
  const file = '/System/Library/Fonts/Supplemental/Georgia.ttf';
  if (!File(file).existsSync()) return;
  final bytes = File(file).readAsBytesSync();
  for (final family in ['Georgia', 'Roboto', 'serif', 'Courier']) {
    final loader = FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}

/// Finge il desktop, con una finestra di [size] pixel.
Future<void> useDesktop(WidgetTester tester, Size size) async {
  await tester.runAsync(_fonts);
  DesktopPlatform.debugOverride = true;
  addTearDown(() => DesktopPlatform.debugOverride = null);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

/// L'app come su desktop: il riquadro 16:9 con la tela a 1080p.
Widget desktopApp(Widget home, {AppLanguage language = AppLanguage.it}) => RepaintBoundary(
      key: _shot,
      child: MaterialApp(
        theme: buildAppTheme(),
        locale: language.locale,
        supportedLocales: AppLanguage.locales,
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        builder: (context, child) => DesktopFrame(orientation: DesktopOrientation.landscape, child: child!),
        home: home,
      ),
    );

/// Qualche fotogramma, senza errori.
Future<void> desktopFrames(WidgetTester tester, [int count = 20]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull, reason: 'fotogramma $i');
  }
}

/// Salva la foto in build/screens/desktop/[name].png.
Future<void> saveDesktopShot(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_shot));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory('build/screens/desktop').createSync(recursive: true);
    File('build/screens/desktop/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

/// Apre [page] sopra una pagina vuota (così c'è da tornare indietro),
/// aspetta e fotografa.
Future<void> shootDesktopPage(WidgetTester tester, String name, Widget Function(BuildContext) page,
    {int frames = 20}) async {
  await tester.pumpWidget(desktopApp(Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: page)),
        child: const Text('go'),
      ),
    ),
  )));
  await tester.tap(find.text('go'));
  await desktopFrames(tester, frames);
  await saveDesktopShot(tester, name);
}
