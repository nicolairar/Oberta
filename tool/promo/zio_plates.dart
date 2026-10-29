// The real screens of the storytime short (zio_render_test.dart): a family
// game on the fake backend, with the family's own names and looks at the
// table. Uncle Vito is the Picciotto; the narrator ("io") is the Doctor.
// Shot once at 1080×1920 (×1.5), like promo_plates.dart.
import 'dart:io';
import 'dart:math' show Random;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/l10n/app_strings.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/rules/role.dart';
import 'package:oberta/ui/avatar/avatar_look.dart';
import 'package:oberta/ui/screens/online/game/noir_role_card.dart';
import 'package:oberta/ui/screens/online/online_game_screen.dart';
import 'package:oberta/ui/theme/app_theme.dart';
import 'package:oberta/ui/widgets/city_backdrop.dart';
import 'package:oberta/ui/widgets/flip_role_card.dart';
import 'package:oberta/ui/widgets/noir_avatar.dart' show AvatarHead;

import '../../test/support/manual_clock.dart';
import 'promo_plates.dart' show flipFrames, grab, logical;

/// The family at the table, in seat order. Seed 26 deals: io the Doctor,
/// vito and zia the family.
const family = ['io', 'vito', 'nonna', 'mamma', 'papà', 'zia', 'cugino', 'nipote'];
const _seed = 26;

/// Uncle Vito: fedora, pinstripe, cigar, a smirk.
final vito = AvatarLook.fallback('vito').copyWith(
  base: AvatarBase.of(SkinTone.olive, FaceMark.scar),
  hat: AvatarHead.fedora,
  outfit: AvatarOutfit.byId('charcoal_pinstripe'),
  accessory: AvatarAccessory.cigar,
  features: const FaceFeatures(hair: HairStyle.slicked, hairColor: HairColor.saltPepper, presentation: Presentation.man, shape: FaceShape.square, brows: BrowShape.angled, mouth: MouthShape.smirk, age: FaceAge.lines),
);

final nonna = AvatarLook.fallback('nonna').copyWith(
  hat: AvatarHead.bun,
  outfit: AvatarOutfit.byId('black_dress'),
  glasses: AvatarGlasses.round,
  accessory: AvatarAccessory.pearls,
  features: const FaceFeatures(hair: HairStyle.bun, hairColor: HairColor.white, presentation: Presentation.woman, age: FaceAge.deep, mouth: MouthShape.smile),
);

AvatarLook _woman(String name, AvatarHead hat, String outfit, HairStyle hair) {
  final f = AvatarLook.fallback(name);
  return f.copyWith(
    hat: hat,
    outfit: AvatarOutfit.byId(outfit),
    accessory: AvatarAccessory.none,
    features: FaceFeatures(hair: hair, hairColor: f.features.hairColor, presentation: Presentation.woman, eyes: f.features.eyes, nose: f.features.nose, lips: LipColor.red),
  );
}

AvatarLook _man(String name, AvatarHead hat, String outfit) {
  final f = AvatarLook.fallback(name);
  return f.copyWith(
    hat: hat,
    outfit: AvatarOutfit.byId(outfit),
    features: FaceFeatures(hair: HairStyle.sidePart, hairColor: f.features.hairColor, presentation: Presentation.man, eyes: f.features.eyes, nose: f.features.nose, shape: f.features.shape),
  );
}

final looks = <String, AvatarLook>{
  'io': _man('io', AvatarHead.slicked, 'navy_double'),
  'vito': vito,
  'nonna': nonna,
  'mamma': _woman('mamma', AvatarHead.bob, 'rose_dress', HairStyle.wavy),
  'papà': _man('papà', AvatarHead.bowler, 'grey_flannel'),
  'zia': _woman('zia', AvatarHead.cloche, 'emerald_dress', HairStyle.bob),
  'cugino': _man('cugino', AvatarHead.coppola, 'camel_check'),
  'nipote': _man('nipote', AvatarHead.slicked, 'cream_linen'),
};

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

Widget _app(Widget home) => RepaintBoundary(
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

/// The seats on a plate, by name: the centre of each name tag, as a
/// fraction of the plate.
typedef Seats = Map<String, Offset>;

Finder _tag(String name) => find.byWidgetPredicate((w) => w is Text && (w.data ?? w.textSpan?.toPlainText() ?? '').toUpperCase() == name.toUpperCase());

Seats _seats(WidgetTester tester, Finder within) => {
  for (final name in family)
    if (find.descendant(of: within, matching: _tag(name)).evaluate().isNotEmpty)
      name: tester.getCenter(find.descendant(of: within, matching: _tag(name)).first).scale(1 / logical.width, 1 / logical.height),
};

/// Plates: `night` (Vito's family screen, Nonna not yet picked), `nightPick`
/// (Nonna picked), `day` (the table at dawn, "Nessun morto stanotte"),
/// `verdictSky`, `flip_00…` (the Picciotto's card turning over) and
/// `card_prostituta`, `card_medico`, `card_carceriere` (face up).
/// Seats: the name tags on `night` and on `day`.
Future<(Map<String, ui.Image>, Map<String, Seats>)> shootZioPlates(WidgetTester tester) async {
  final plates = <String, ui.Image>{};
  final seats = <String, Seats>{};
  final clock = ManualClock();
  final online = FakeOnline(accountId: 'io', clock: clock, random: Random(_seed))..signInReady(handle: 'io');
  for (final p in family.skip(1)) {
    online.addPlayer(p, handle: p);
  }
  for (final p in family) {
    WornLooks.remember(Profile(id: p, handle: p, avatar: looks[p]!.toJson()));
  }
  OnlineServices.instance = online.services;
  final room = online.openRoomAs('io', AppLanguage.it);
  for (final p in family.skip(1)) {
    online.joinAs(p, room.code);
  }
  await _settled(tester, online.gameAs('io').startGame(room.id));

  Future<void> screenAs(String id) async {
    online.auth.debugSignIn(id);
    final me = (await _settled(tester, online.services.profiles.me()))!;
    await tester.pumpWidget(
      _app(OnlineGameScreen(key: UniqueKey(), services: online.services, room: room, me: me, clock: clock)),
    );
    await _flush(tester);
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump(const Duration(seconds: 2));
    final card = find.byType(NoirRoleCard);
    if (card.evaluate().isNotEmpty) {
      final hold = await tester.startGesture(tester.getCenter(card));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      await hold.up();
      await tester.pump(const Duration(milliseconds: 700));
    }
  }

  Future<bool> until(String key, {int tries = 200}) async {
    for (var i = 0; i < tries; i++) {
      if (find.byKey(Key(key)).evaluate().isNotEmpty) return true;
      clock.elapse(const Duration(seconds: 2));
      await _flush(tester);
      if (find.byKey(Key(key)).evaluate().isNotEmpty) return true;
      clock.fireNext();
      await _flush(tester);
    }
    return false;
  }

  Future<void> tapSeat(String name) async {
    final night = find.byKey(const Key('online.night'));
    final f = find.descendant(of: night, matching: _tag(name));
    if (f.evaluate().isEmpty) return;
    final r = tester.getRect(f.first);
    await tester.tapAt(Offset(r.center.dx, r.top - 28));
    await _flush(tester);
  }

  // Vito's night: the family chat, then his finger on Nonna.
  await screenAs('vito');
  clock.elapse(const Duration(seconds: 2));
  await _flush(tester);
  if (!await until('online.night')) throw StateError('no night for vito');
  clock.elapse(const Duration(seconds: 3));
  await _flush(tester);
  for (final (who, text) in [('vito', 'Stanotte la nonna.'), ('zia', 'La nonna?! Sei sicuro?'), ('vito', 'Fidati.')]) {
    online.auth.debugSignIn(who);
    await _settled(tester, online.services.game.sendChat(room.id, ChatChannel.family, text));
  }
  online.auth.debugSignIn('vito');
  await _flush(tester);
  plates['night'] = await grab(tester, key: _key);
  seats['night'] = _seats(tester, find.byKey(const Key('online.night')));
  await tapSeat('nonna');
  plates['nightPick'] = await grab(tester, key: _key);

  // The Doctor (io) saves her; then the morning.
  await screenAs('io');
  if (await until('online.night', tries: 3)) {
    clock.elapse(const Duration(seconds: 1));
    await _flush(tester);
    await tapSeat('nonna');
  }
  if (!await until('online.vote')) throw StateError('no day');
  clock.elapse(const Duration(seconds: 2));
  await _flush(tester);
  plates['day'] = await grab(tester, key: _key);
  seats['day'] = _seats(tester, find.byKey(const Key('online.vote')));
  OnlineServices.instance = null;

  // The dusk city behind the pier film.
  await tester.pumpWidget(
    _app(CityBackdrop(mood: SceneMood.dusk, style: SkylineStyle.metropolis, child: const SizedBox.expand())),
  );
  await tester.pump(const Duration(milliseconds: 100));
  plates['verdictSky'] = await grab(tester, key: _key);

  // The Picciotto's card turning over, and the Prostituta face up.
  final card = GlobalKey();
  Future<void> cardOf(Role role) => tester.pumpWidget(
    _app(
      Center(
        child: RepaintBoundary(
          key: card,
          child: SizedBox(
            width: 380,
            height: 520,
            child: Center(
              child: Material(
                type: MaterialType.transparency,
                child: SizedBox(width: 300, child: FlipRoleCard(key: ValueKey(role), role: role)),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await cardOf(Role.mafioso);
  await tester.pump(const Duration(milliseconds: 100));
  plates['flip_00'] = await grab(tester, key: card);
  var finger = await tester.startGesture(tester.getCenter(find.byType(FlipRoleCard)));
  for (var i = 1; i <= flipFrames; i++) {
    await tester.pump(const Duration(milliseconds: 40));
    plates['flip_${i.toString().padLeft(2, '0')}'] = await grab(tester, key: card);
  }
  await finger.up();
  await tester.pump(const Duration(seconds: 1));
  // The three role moments: their cards face up.
  for (final role in [Role.prostituta, Role.medico, Role.carceriere]) {
    await cardOf(role);
    await tester.pump(const Duration(milliseconds: 100));
    finger = await tester.startGesture(tester.getCenter(find.byType(FlipRoleCard)));
    for (var i = 0; i < 18; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    plates['card_${role.name}'] = await grab(tester, key: card);
    await finger.up();
    await tester.pump(const Duration(seconds: 1));
  }
  return (plates, seats);
}

/// Saves the plates (PLATES=1), for a look.
Future<void> savePlates(WidgetTester tester, Map<String, ui.Image> plates, String dir) async {
  await tester.runAsync(() async {
    for (final e in plates.entries) {
      final bytes = await e.value.toByteData(format: ui.ImageByteFormat.png);
      File('$dir/${e.key}.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes!.buffer.asUint8List());
    }
  });
}
