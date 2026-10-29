// Le foto della pagina Steam: dieci schermate del desktop a 1920×1080, in
// inglese e in italiano, con dati di prova verosimili.
// `flutter test tool/render/steam_screenshots_render_test.dart` scrive i PNG in
// build/steam/screenshots/{en,it}/; `steam/store/make.sh` li comprime in
// steam/store/screenshots. LANG_ONLY=it per una lingua sola, SEED=n per
// un'altra partita.
import 'dart:io';
import 'dart:math' show Random;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/l10n/lobby_language.dart';
import 'package:oberta/l10n/app_strings.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/game/bot_brain.dart';
import 'package:oberta/online/game/game_client.dart';
import 'package:oberta/online/online_account.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/rules/role.dart';
import 'package:oberta/settings/display_settings.dart';
import 'package:oberta/ui/desktop/desktop_frame.dart';
import 'package:oberta/ui/desktop/desktop_platform.dart';
import 'package:oberta/ui/screens/avatar/barber_mirror_screen.dart';
import 'package:oberta/ui/screens/home_screen.dart';
import 'package:oberta/ui/screens/online/match_results_screen.dart';
import 'package:oberta/ui/screens/online/online_game_screen.dart';
import 'package:oberta/ui/screens/online/online_room_screen.dart';
import 'package:oberta/ui/screens/online/ranked_queue_screen.dart';
import 'package:oberta/ui/screens/shop/shop_screen.dart';

import '../../test/support/manual_clock.dart';
import 'steam_support.dart';

const _window = Size(1920, 1080);
final _key = GlobalKey();

/// Gli altri undici al tavolo: nomi da persone, non da bot.
const _others = ['anna', 'vito', 'carla', 'sal', 'elena', 'tommy', 'gina', 'frank', 'lucia', 'nico', 'rosa'];

Widget _app(Widget home, AppLanguage language) => RepaintBoundary(
      key: _key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: steamTheme(),
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

Future<void> _flush(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _frames(WidgetTester tester, int count) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
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

Future<void> _shot(WidgetTester tester, AppLanguage language, String name) async {
  // Le icone dei ruoli si decodificano fuori dal tempo finto: si aspettano.
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump(const Duration(milliseconds: 400));
  await tester.runAsync(() async {
    final boundary = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await writeSteamPng(await boundary.toImage(pixelRatio: 1), 'screenshots/${language.name}/$name');
  });
}

Future<void> _clear(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}

/// Una persona al suo computer, che gioca come un bot ma dalla sua app.
class _Player {
  final GameClient client;
  final BotBrain brain;
  String? _turn;

  _Player(this.client, Random random) : brain = BotBrain(random);

  Future<void> act() async {
    final seat = client.seat;
    final window = client.schedule;
    if (!client.ready || client.busy || seat == null || window == null) return;
    if (_turn == window.key || client.elapsed.isNegative) return;
    if (window.stage.acceptsActions) {
      if (seat.view.action == null) return;
      _turn = window.key;
      final intent = brain.decide(seat.view);
      if (intent != null) await client.send(intent);
    } else if (window.stage.acknowledged && seat.view.alive && !seat.acked) {
      _turn = window.key;
      await client.ack();
    }
  }
}

void main() {
  setUpAll(loadSteamFonts);
  setUp(() => DesktopPlatform.debugOverride = true);
  tearDown(() {
    DesktopPlatform.debugOverride = null;
    OnlineServices.instance = null;
  });
  final only = Platform.environment['LANG_ONLY'];
  for (final language in [AppLanguage.en, AppLanguage.it]) {
    if (only != null && only != language.name) continue;
    testWidgets('steam ${language.name}', (tester) async {
      tester.view.physicalSize = _window;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = FakeViewPadding.zero;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await _menus(tester, language);
      await _game(tester, language);
    });
  }
}

/// Il conto di chi gioca: un cappello, i baffi e qualche moneta.
Future<FakeOnline> _me(WidgetTester tester, {ManualClock? clock, Random? random}) async {
  final online = FakeOnline(accountId: 'bruno', clock: clock, random: random)
    ..signInReady(handle: 'bruno', level: 12, xp: 420, coins: 2400)
    ..slow = false;
  await tester.runAsync(() async {
    await online.shop.buy('hat.borsalino');
    await online.shop.equip('hat.borsalino');
    await online.shop.buy('face.handlebar');
    await online.shop.equip('face.handlebar', tone: 'olive');
  });
  for (final name in _others) {
    online.addPlayer(name, handle: name);
  }
  return online;
}

Future<void> _menus(WidgetTester tester, AppLanguage language) async {
  final en = language == AppLanguage.en;

  // 01 Il vicolo: il menu principale.
  var online = await _me(tester);
  OnlineServices.instance = online.services;
  await tester.pumpWidget(_app(HomeScreen(onSettings: () {}), language));
  await tester.pump(const Duration(seconds: 4));
  await _flush(tester);
  await _shot(tester, language, '01_home');
  await _clear(tester);

  // 02 La stanza degli amici, col codice e la chat.
  online = await _me(tester);
  OnlineServices.instance = online.services;
  final room = online.openRoomAs('bruno', LobbyLanguage.of(language));
  for (final name in _others.take(7)) {
    online.joinAs(name, room.code);
  }
  final me = (await _settled(tester, online.services.profiles.me()))!;
  await tester.runAsync(() async {
    for (final (who, it, english) in [
      ('anna', 'Chi dà le carte stasera?', 'Who\'s dealing tonight?'),
      ('vito', 'Io no, l\'ultima volta ero il Padrino e mi avete beccato subito.', 'Not me, last time I was the Godfather and you got me on day one.'),
      ('carla', 'Aspettiamo Elena e Tommy, arrivano tra un minuto.', 'Waiting on Elena and Tommy, they\'re a minute away.'),
      ('bruno', 'Le carte le do io. Appena arrivano, si parte.', 'I\'ll deal. We start as soon as they\'re in.'),
    ]) {
      await online.gameAs(who).sendChat(room.id, ChatChannel.lobby, en ? english : it);
    }
  });
  await tester.pumpWidget(_app(OnlineRoomScreen(services: online.services, room: room, me: me), language));
  await _frames(tester, 20);
  await _shot(tester, language, '02_friends_room');
  await _clear(tester);

  // 03 La classificata: il retrobottega, con la gente in coda.
  final clock = ManualClock();
  online = await _me(tester, clock: clock);
  OnlineServices.instance = online.services;
  for (final lang in AppLanguage.values) {
    online.ratings[('bruno', LobbyLanguage.of(lang))] = const Rating(25, 3);
  }
  for (var i = 0; i < 37; i++) {
    online.rankedQueue['q$i'] = (LobbyLanguage.of(language), clock.now());
  }
  await tester.pumpWidget(_app(RankedQueueScreen(services: online.services), language));
  await _frames(tester, 20);
  await tester.tap(find.byKey(Key('ranked.lang.${language.name}')).first);
  await _frames(tester, 10);
  await _shot(tester, language, '03_ranked');
  online.rankedQueue.clear();
  await _clear(tester);

  // 08 I conti di fine partita, in classificata.
  online = await _me(tester);
  OnlineServices.instance = online.services;
  tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
  await tester.pumpWidget(_app(
    const MatchResultsScreen(
      result: MatchResult(
        gameId: 'steam',
        ranked: true,
        won: true,
        role: 'detective',
        team: 'citizens',
        survived: true,
        xpGained: 140,
        levelBefore: 12,
        levelAfter: 13,
        coinsGained: 60,
        ratingDelta: 1.4,
        ordinalAfter: 25.4,
        durationSeconds: 1260,
      ),
      xpNow: 80,
    ),
    language,
  ));
  await _frames(tester, 60);
  await _shot(tester, language, '08_results');
  await _clear(tester);
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);

  // 09 La bottega: il reparto cappelli, il borsalino sul bancone.
  WornLooks.clear();
  online = await _me(tester);
  OnlineServices.instance = online.services;
  final account = OnlineAccount(online.services);
  await tester.pumpWidget(_app(ShopScreen(account: account, shop: online.shop), language));
  await _frames(tester, 20);
  final sets = find.byKey(const Key('shop.section.sets'));
  if (sets.evaluate().isNotEmpty) await tester.tap(sets);
  await _frames(tester, 6);
  final bundle = find.byKey(const Key('shop.bundle.padrino'));
  if (bundle.evaluate().isNotEmpty) {
    await tester.tap(bundle);
    await _frames(tester, 8);
  }
  await _shot(tester, language, '09_shop');
  await _clear(tester);

  // 10 Lo specchio del barbiere.
  WornLooks.clear();
  online = await _me(tester);
  OnlineServices.instance = online.services;
  final profile = (await _settled(tester, online.services.profiles.me()))!;
  await tester.pumpWidget(_app(BarberMirrorScreen(services: online.services, profile: profile), language));
  await _frames(tester, 20);
  final man = find.byKey(const Key('mirror.present.man'));
  if (man.evaluate().isNotEmpty) {
    await tester.tap(man);
    await _frames(tester, 20);
  }
  await _shot(tester, language, '10_barber');
  await _clear(tester);
}

/// Una partita a dodici: la discussione, la notte, l'alba e il voto.
Future<void> _game(WidgetTester tester, AppLanguage language) async {
  final en = language == AppLanguage.en;
  // Si cerca una partita in cui chi gioca sta con la famiglia: di notte si
  // vede la chat dei mafiosi.
  final first = int.tryParse(Platform.environment['SEED'] ?? '') ?? 1;
  for (var seed = first; seed < first + 40; seed++) {
    final clock = ManualClock();
    final online = await _me(tester, clock: clock, random: Random(seed));
    OnlineServices.instance = online.services;
    final room = online.openRoomAs('anna', LobbyLanguage.of(language));
    online.joinAs('bruno', room.code);
    for (final name in _others.skip(1)) {
      online.joinAs(name, room.code);
    }
    await _settled(tester, online.gameAs('anna').startGame(room.id));
    final mine = GameClient(backend: online.services.game, roomId: room.id, clock: clock);
    await _flush(tester);
    final role = mine.seat?.view.role;
    mine.dispose();
    if (role != Role.mafioso && role != Role.padrino) {
      await _clear(tester);
      continue;
    }
    await _play(tester, language, online, room, clock, en, Random(seed));
    return;
  }
  fail('nessuna partita con bruno nella famiglia');
}

Future<void> _play(
  WidgetTester tester,
  AppLanguage language,
  FakeOnline online,
  Room room,
  ManualClock clock,
  bool en,
  Random random,
) async {
  final players = [
    for (final name in _others)
      _Player(GameClient(backend: online.gameAs(name), roomId: room.id, clock: clock), random),
  ];
  final me = (await _settled(tester, online.services.profiles.me()))!;
  await tester.pumpWidget(
    _app(OnlineGameScreen(services: online.services, room: room, me: me, clock: clock), language),
  );
  await _flush(tester);
  await tester.pump(const Duration(seconds: 4));
  clock.elapse(const Duration(seconds: 2));
  await _flush(tester);

  Future<void> say(String who, ChatChannel channel, String it, String english) =>
      _settled(tester, online.gameAs(who).sendChat(room.id, channel, en ? english : it));

  final shot = <String>{};
  const scenes = {
    'online.night': '04_night',
    'online.dawn': '05_dawn',
    'online.discussion': '06_discussion',
    'online.vote': '07_vote',
  };
  for (var i = 0; i < 600 && shot.length < scenes.length; i++) {
    if (online.roomOf(room.id)!.status != RoomStatus.playing) break;
    for (final MapEntry(key: key, value: name) in scenes.entries) {
      if (shot.contains(key) || find.byKey(Key(key)).evaluate().isEmpty) continue;
      clock.elapse(const Duration(seconds: 2));
      await _flush(tester);
      if (find.byKey(Key(key)).evaluate().isEmpty) continue;
      switch (key) {
        case 'online.night':
          await say('bruno', ChatChannel.family, 'Il dottore è quello col cappello.', 'The doctor is the one in the hat.');
          await say('bruno', ChatChannel.family, 'Stanotte tocca a lui.', 'Tonight it\'s his turn.');
          await say('bruno', ChatChannel.family, 'Domani in piazza, faccia da santi.', 'Tomorrow in the square, act like saints.');
        case 'online.discussion':
          await say('anna', ChatChannel.day, 'Stanotte ho sentito dei passi vicino al porto.', 'I heard footsteps down by the docks last night.');
          await say('carla', ChatChannel.day, 'Il 4 era troppo tranquillo ieri sera...', 'Number 4 was way too calm last night...');
          await say('sal', ChatChannel.day, 'Io? Ero al bar fino a mezzanotte, chiedete al barista.', 'Me? I was at the bar till midnight, ask the barman.');
          await say('bruno', ChatChannel.day, 'Calma. Prima sentiamo il Commissario.', 'Easy. Let\'s hear from the Detective first.');
          await say('elena', ChatChannel.day, 'Votiamo con la testa, non con la pancia.', 'Vote with your head, not your gut.');
        case 'online.vote':
          // Metà degli altri vota: le mani puntate sul tavolo.
          for (var k = 0; k < 2; k++) {
            clock.elapse(const Duration(seconds: 3));
            for (final p in players.take(6)) {
              await _settled(tester, p.act());
            }
            await _flush(tester);
          }
          final seats = find.descendant(of: find.byKey(Key(key)), matching: find.byType(InkWell));
          final target = [for (final e in seats.evaluate()) if ((e.widget as InkWell).onTap != null) e].firstOrNull;
          if (target != null) {
            await tester.tap(find.byWidget(target.widget));
            await _flush(tester);
          }
      }
      await _flush(tester);
      shot.add(key);
      await _shot(tester, language, name);
    }
    // Il voto si fotografa a metà: prima della foto votano solo in sei.
    final voting = find.byKey(const Key('online.vote')).evaluate().isNotEmpty && !shot.contains('online.vote');
    for (final p in voting ? players.take(6) : players) {
      await _settled(tester, p.act());
    }
    await _flush(tester);
    clock.fireNext();
    await _flush(tester);
  }
  for (final p in players) {
    p.client.dispose();
  }
  expect(shot, hasLength(scenes.length), reason: 'mancano delle scene: $shot');
  await _clear(tester);
}
