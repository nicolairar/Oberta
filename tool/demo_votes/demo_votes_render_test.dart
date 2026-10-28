// Vote visuals for the online table, before anything changes in the game:
// `flutter test tool/demo_votes/demo_votes_render_test.dart` writes
// build/demo_votes/v{1,2,3}_*_phone.png (393x852 at 2x) and a desk crop.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/l10n/app_strings.dart';
import 'package:oberta/ui/theme/app_theme.dart';

import 'demo_votes.dart';

final out = Platform.environment['OUT'] ?? 'build/demo_votes';

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

final _key = GlobalKey();

ThemeData _theme() {
  final theme = buildAppTheme();
  return theme.copyWith(textTheme: theme.textTheme.apply(fontFamily: 'Roboto'));
}

Future<void> _render(WidgetTester tester, Widget screen, Size size, double ratio, String name) async {
  tester.view.physicalSize = size * ratio;
  tester.view.devicePixelRatio = ratio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _theme(),
        locale: AppLanguage.it.locale,
        supportedLocales: AppLanguage.locales,
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: DefaultTextStyle(
          style: const TextStyle(fontFamily: 'Roboto'),
          child: Material(type: MaterialType.transparency, child: screen),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pump(const Duration(milliseconds: 600));
  await tester.runAsync(() async {
    final boundary = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: ratio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  const phone = Size(393, 852);
  const looks = {
    VoteLook.ballot: ('1 · Scheda e gettoni', 'v1_ballot_tokens'),
    VoteLook.seals: ('2 · Ceralacca', 'v2_wax_seals'),
    VoteLook.chalk: ('3 · Gesso', 'v3_chalk'),
  };
  for (final MapEntry(key: look, value: (label, file)) in looks.entries) {
    testWidgets('phone $file', (tester) async {
      await tester.runAsync(_loadFonts);
      await _render(tester, PhoneVotes(look, label), phone, 2, '${file}_phone');
    });
  }
  testWidgets('desk crop', (tester) async {
    await tester.runAsync(_loadFonts);
    await _render(tester, const DeskVotes(VoteLook.ballot), const Size(1400, 860), 1, 'v1_ballot_tokens_desk');
  });
}
