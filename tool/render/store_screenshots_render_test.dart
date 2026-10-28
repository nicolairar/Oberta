// Le foto per l'App Store, con la didascalia in alto:
// `flutter test tool/render/store_screenshots_render_test.dart` scrive i PNG
// in fastlane/screenshots/{it,en-US}/, alle misure che Apple chiede
// (iPhone 6,9" e 6,5", iPad 13"). DEVICE=iphone69 e LANG_ONLY=it per farne meno,
// RAW=1 per le sole schermate senza didascalia.
import 'dart:io';
import 'dart:math' show Random;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/l10n/app_strings.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/online_account.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/ui/screens/avatar/barber_mirror_screen.dart';
import 'package:oberta/ui/screens/home_screen.dart';
import 'package:oberta/ui/screens/online/game/noir_role_card.dart';
import 'package:oberta/ui/screens/online/match_results_screen.dart';
import 'package:oberta/ui/screens/online/online_game_screen.dart';
import 'package:oberta/ui/screens/shop/shop_screen.dart';
import 'package:oberta/ui/theme/app_theme.dart';

import '../../test/support/manual_clock.dart';

final out = Platform.environment['OUT'] ?? 'fastlane/screenshots';

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

/// Un telefono (o tablet) di Apple: misura logica, densità, margini sicuri.
typedef _Device = ({Size size, double ratio, double top, double bottom});

const _devices = <String, _Device>{
  'iphone69': (size: Size(440, 956), ratio: 3, top: 62, bottom: 34), // 1320×2868
  'iphone65': (size: Size(428, 926), ratio: 3, top: 47, bottom: 34), // 1284×2778
  'ipad13': (size: Size(1032, 1376), ratio: 2, top: 24, bottom: 20), // 2064×2752
};

const _folders = {AppLanguage.it: 'it', AppLanguage.en: 'en-US'};

/// Le didascalie: titolo e riga sotto, per scena e lingua.
const _captions = <String, Map<AppLanguage, (String, String)>>{
  'home': {
    AppLanguage.it: ('Un vicolo. Una città.\nNessun innocente.', 'Un telefono con il narratore, o online con gli amici.'),
    AppLanguage.en: ('One alley. One city.\nNo innocents.', 'One phone with a narrator, or online with friends.'),
  },
  'role': {
    AppLanguage.it: ('Guarda la tua carta.\nNon farti vedere.', 'Ventuno ruoli, dal Padrino al Becchino.'),
    AppLanguage.en: ('Check your card.\nDon\'t get caught.', 'Twenty-one roles, from the Godfather to the Gravedigger.'),
  },
  'night': {
    AppLanguage.it: ('Di notte,\ndecide la famiglia.', 'Il tavolo, i sussurri, una chat che nessun altro legge.'),
    AppLanguage.en: ('At night,\nthe Family decides.', 'The table, the whispers, a chat no one else can read.'),
  },
  'dawn': {
    AppLanguage.it: ('All\'alba,\nil giornale sa tutto.', 'Ogni delitto finisce in prima pagina.'),
    AppLanguage.en: ('At dawn,\nthe paper knows.', 'Every crime makes the front page.'),
  },
  'vote': {
    AppLanguage.it: ('Accusa. Difenditi.\nVota.', 'La città sceglie chi condannare.'),
    AppLanguage.en: ('Accuse. Defend.\nVote.', 'The town decides who takes the fall.'),
  },
  'shop': {
    AppLanguage.it: ('La bottega\ndel quartiere.', 'Cappelli, abiti, cornici. Le monete si vincono solo giocando.'),
    AppLanguage.en: ('The corner\nshop.', 'Hats, suits, frames. Coins are only earned by playing.'),
  },
  'barber': {
    AppLanguage.it: ('Dal barbiere,\nti fai la faccia.', 'Baffi, tagli e cicatrici: il tuo personaggio.'),
    AppLanguage.en: ('At the barber,\npick your face.', 'Moustaches, cuts and scars: your character.'),
  },
  'results': {
    AppLanguage.it: ('A fine partita,\nsi fanno i conti.', 'Esperienza e monete. La classificata arriva presto.'),
    AppLanguage.en: ('After the game,\nyou settle up.', 'Experience and coins. Ranked is coming soon.'),
  },
};

const _order = ['home', 'role', 'night', 'dawn', 'vote', 'shop', 'barber', 'results'];

final _key = GlobalKey();

Widget _app(Widget home, AppLanguage language) => RepaintBoundary(
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
    home: home,
  ),
);

Future<void> _flush(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
  await tester.pump(const Duration(milliseconds: 300));
}

Future<T?> _settled<T>(WidgetTester tester, Future<T> future) async {
  T? value;
  var done = false;
  future.then<void>((v) {
    value = v;
    done = true;
  }, onError: (Object _) {
    done = true;
  });
  for (var i = 0; i < 200 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
  return value;
}

/// La schermata, a piena risoluzione, poi la cartolina con la didascalia.
Future<void> _shot(WidgetTester tester, String device, AppLanguage language, String scene, {bool settle = true}) async {
  if (settle) await tester.pump(const Duration(milliseconds: 400));
  final ratio = _devices[device]!.ratio;
  await tester.runAsync(() async {
    final boundary = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final screen = await boundary.toImage(pixelRatio: ratio);
    // RAW=1: solo la schermata, senza didascalia (per la landing).
    final card = Platform.environment['RAW'] != null
        ? screen
        : await _postcard(screen, _captions[scene]![language]!, ipad: device == 'ipad13');
    final bytes = await card.toByteData(format: ui.ImageByteFormat.png);
    final index = _order.indexOf(scene) + 1;
    File('$out/${_folders[language]}/${index.toString().padLeft(2, '0')}_${device}_$scene.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

/// Il fondo scuro, la fascia della didascalia e il telefono incorniciato.
Future<ui.Image> _postcard(ui.Image screen, (String, String) caption, {required bool ipad}) async {
  final w = screen.width.toDouble(), h = screen.height.toDouble();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));
  final all = Rect.fromLTWH(0, 0, w, h);
  canvas.drawRect(
    all,
    Paint()
      ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), const [
        Color(0xFF1E1714),
        Color(0xFF14110F),
        Color(0xFF0A0807),
      ], const [0, 0.35, 1]),
  );
  // Un alone rosso, come un'insegna al neon dietro l'angolo.
  canvas.drawRect(
    all,
    Paint()
      ..shader = ui.Gradient.radial(Offset(w * 0.5, h * 0.06), w * 0.8, [
        AppColors.accent.withValues(alpha: 0.22),
        AppColors.accent.withValues(alpha: 0),
      ]),
  );

  final band = h * (ipad ? 0.2 : 0.215);
  final unit = ipad ? w / 1032 * 1.25 : w / 440;
  double y = band * 0.2;

  // La firma: OBERTÀ, spaziato, fra due filetti d'oro.
  final mark = _paragraph('OBERTÀ', w, fontSize: 11 * unit, color: AppColors.gold, spacing: 6 * unit, weight: FontWeight.w700);
  canvas.drawParagraph(mark, Offset(0, y));
  final ruleY = y + mark.height / 2;
  final ruleW = 34 * unit, gap = 62 * unit;
  final rule = Paint()
    ..color = AppColors.gold.withValues(alpha: 0.7)
    ..strokeWidth = 1.2 * unit;
  canvas.drawLine(Offset(w / 2 - gap - ruleW, ruleY), Offset(w / 2 - gap, ruleY), rule);
  canvas.drawLine(Offset(w / 2 + gap, ruleY), Offset(w / 2 + gap + ruleW, ruleY), rule);
  y += mark.height + 10 * unit;

  final title = _paragraph(caption.$1, w * 0.88, fontSize: 30 * unit, color: AppColors.textPrimary, weight: FontWeight.w700, height: 1.12);
  canvas.drawParagraph(title, Offset(w * 0.06, y));
  y += title.height + 9 * unit;
  final line = _paragraph(caption.$2, w * 0.82, fontSize: 14.5 * unit, color: AppColors.textSecondary, italic: true, height: 1.3);
  canvas.drawParagraph(line, Offset(w * 0.09, y));
  y += line.height;

  // Il telefono, rimpicciolito sotto la fascia.
  final top = (y + 22 * unit).clamp(band, h * 0.32);
  final scale = (h - top - h * 0.035) / h;
  final sw = w * scale, sh = h * scale;
  final frame = Rect.fromLTWH((w - sw) / 2, top, sw, sh);
  final radius = Radius.circular((ipad ? 26 : 46) * unit * scale);
  final rrect = RRect.fromRectAndRadius(frame, radius);
  canvas.drawRRect(
    rrect.shift(Offset(0, 10 * unit)),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 24 * unit),
  );
  canvas.save();
  canvas.clipRRect(rrect);
  canvas.drawImageRect(screen, Rect.fromLTWH(0, 0, w, h), frame, Paint()..filterQuality = FilterQuality.high);
  canvas.restore();
  canvas.drawRRect(
    rrect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * unit
      ..color = AppColors.gold.withValues(alpha: 0.55),
  );
  final picture = recorder.endRecording();
  return picture.toImage(screen.width, screen.height);
}

ui.Paragraph _paragraph(
  String text,
  double width, {
  required double fontSize,
  required Color color,
  FontWeight weight = FontWeight.w400,
  bool italic = false,
  double spacing = 0,
  double? height,
}) {
  final builder =
      ui.ParagraphBuilder(
          ui.ParagraphStyle(textAlign: TextAlign.center, fontFamily: 'Georgia', fontSize: fontSize, height: height),
        )
        ..pushStyle(
          ui.TextStyle(
            color: color,
            fontFamily: 'Georgia',
            fontSize: fontSize,
            fontWeight: weight,
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            letterSpacing: spacing,
            height: height,
          ),
        )
        ..addText(text);
  return builder.build()..layout(ui.ParagraphConstraints(width: width));
}

void _view(WidgetTester tester, _Device d) {
  tester.view.physicalSize = d.size * d.ratio;
  tester.view.devicePixelRatio = d.ratio;
  tester.view.padding = FakeViewPadding(top: d.top * d.ratio, bottom: d.bottom * d.ratio);
}

void main() {
  setUpAll(_loadFonts);
  final onlyDevice = Platform.environment['DEVICE'];
  final onlyLang = Platform.environment['LANG_ONLY'];
  for (final MapEntry(key: device, value: d) in _devices.entries) {
    if (onlyDevice != null && onlyDevice != device) continue;
    for (final language in [AppLanguage.it, AppLanguage.en]) {
      if (onlyLang != null && onlyLang != language.name) continue;
      testWidgets('vetrina $device ${language.name}', (tester) async {
        addTearDown(tester.view.reset);
        addTearDown(() => OnlineServices.instance = null);
        _view(tester, d);
        await _still(tester, device, language);
        await _game(tester, device, language);
      });
    }
  }
}

/// Il vicolo, la bottega, il barbiere e i conti di fine partita.
Future<void> _still(WidgetTester tester, String device, AppLanguage language) async {
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  final online = FakeOnline()..signInReady(handle: language == AppLanguage.it ? 'nicolai' : 'nick', level: 7, xp: 420, coins: 2400);
  await tester.runAsync(() async {
    await online.shop.buy('hat.borsalino');
    await online.shop.equip('hat.borsalino');
    await online.shop.buy('face.handlebar');
    await online.shop.equip('face.handlebar', tone: 'olive');
  });
  OnlineServices.instance = online.services;
  await tester.pumpWidget(_app(HomeScreen(onSettings: () {}), language));
  await tester.pumpAndSettle();
  await _shot(tester, device, language, 'home');

  final account = OnlineAccount(online.services);
  await tester.pumpWidget(_app(ShopScreen(key: UniqueKey(), account: account, shop: online.shop), language));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  final hats = find.byKey(const Key('shop.dept.hats'));
  if (hats.evaluate().isNotEmpty) {
    await tester.tap(hats);
    await tester.pump(const Duration(milliseconds: 500));
  }
  await _shot(tester, device, language, 'shop');

  final me = (await _settled(tester, online.services.profiles.me()))!;
  await tester.pumpWidget(_app(BarberMirrorScreen(key: UniqueKey(), services: online.services, profile: me), language));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  final seat = find.text(language == AppLanguage.it ? 'Uomo' : 'Man');
  if (seat.evaluate().isNotEmpty) {
    await tester.tap(seat.first);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }
  await _shot(tester, device, language, 'barber');

  tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
  await tester.pumpWidget(
    _app(
      MatchResultsScreen(
        key: UniqueKey(),
        result: const MatchResult(
          gameId: 'vetrina',
          won: true,
          role: 'detective',
          xpGained: 140,
          levelBefore: 7,
          levelAfter: 8,
          coinsGained: 60,
        ),
        xpNow: 80,
      ),
      language,
    ),
  );
  for (var i = 0; i < 60; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await _shot(tester, device, language, 'results');
}

/// Una partita online con i bot: la carta, la notte, l'alba e il voto.
Future<void> _game(WidgetTester tester, String device, AppLanguage language) async {
  final seed = int.tryParse(Platform.environment['SEED'] ?? '') ?? 16;
  final clock = ManualClock();
  final online = FakeOnline(accountId: 'bruno', clock: clock, random: Random(seed))
    ..signInReady(handle: 'bruno')
    ..addPlayer('anna', handle: 'anna');
  final room = online.openRoomAs('anna', language);
  online.joinAs('bruno', room.code);
  await _settled(tester, online.gameAs('anna').setBots(room.id, 6));
  await _settled(tester, online.gameAs('anna').startGame(room.id));
  final me = (await _settled(tester, online.services.profiles.me()))!;
  await tester.pumpWidget(
    _app(OnlineGameScreen(key: UniqueKey(), services: online.services, room: room, me: me, clock: clock), language),
  );
  await _flush(tester);
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pump(const Duration(milliseconds: 1800));
  await tester.pump(const Duration(seconds: 2));
  clock.elapse(const Duration(seconds: 2));
  await _flush(tester);
  final hold = await tester.startGesture(tester.getCenter(find.byType(NoirRoleCard)));
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  await _shot(tester, device, language, 'role', settle: false);
  await hold.up();
  await tester.pump(const Duration(milliseconds: 700));

  final it = language == AppLanguage.it;
  final shot = <String>{};
  for (var i = 0; i < 300 && shot.length < 3 && online.roomOf(room.id)!.status == RoomStatus.playing; i++) {
    for (final name in ['night', 'dawn', 'vote']) {
      final key = Key('online.$name');
      if (shot.contains(name) || find.byKey(key).evaluate().isEmpty) continue;
      clock.elapse(const Duration(seconds: 2));
      await _flush(tester);
      if (find.byKey(key).evaluate().isEmpty) continue;
      shot.add(name);
      if (name == 'night') {
        for (final (game, text) in [
          (online.services.game, it ? 'Il dottore è quello col cappello.' : 'The doctor is the one in the hat.'),
          (online.services.game, it ? 'Stanotte tocca a lui.' : 'Tonight it\'s his turn.'),
          (online.services.game, it ? 'Silenzio al voto, mi raccomando.' : 'Keep quiet at the vote.'),
        ]) {
          await _settled(tester, game.sendChat(room.id, ChatChannel.family, text));
        }
        await _flush(tester);
      }
      if (name == 'vote') {
        clock.elapse(const Duration(seconds: 10));
        await _flush(tester);
        final seats = find.descendant(of: find.byKey(key), matching: find.byType(InkWell));
        final target = [for (final e in seats.evaluate()) if ((e.widget as InkWell).onTap != null) e].firstOrNull;
        if (target != null) {
          await tester.tap(find.byWidget(target.widget));
          await _flush(tester);
        }
      }
      await _shot(tester, device, language, name);
    }
    clock.fireNext();
    await _flush(tester);
  }
}
