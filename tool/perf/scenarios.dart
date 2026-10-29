// Gli scenari delle prove delle prestazioni, gli stessi per il motore dei
// test (frame_cost_test.dart) e per l'app vera in profile
// (integration_test/perf_test.dart): cambia solo come si misura.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/l10n/app_strings.dart';
import 'package:oberta/l10n/lobby_language.dart';
import 'package:oberta/main.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/online/voice/voice_controller.dart';
import 'package:oberta/online/voice/voice_engine.dart';
import 'package:oberta/settings/app_settings.dart';
import 'package:oberta/settings/display_settings.dart';
import 'package:oberta/ui/desktop/desktop_frame.dart';
import 'package:oberta/ui/desktop/desktop_platform.dart';
import 'package:oberta/ui/screens/online/game/noir_role_card.dart';
import 'package:oberta/ui/screens/online/online_game_screen.dart';
import 'package:oberta/ui/screens/rules_screen.dart';
import 'package:oberta/ui/theme/app_theme.dart';
import 'package:oberta/ui/widgets/verdict_scene.dart';

import '../../test/support/manual_clock.dart';
import 'perf_harness.dart' show Screen, frame;


/// Come si misura: il motore dei test o l'app vera.
abstract class Rig {
  /// The real app (profile, real time) rather than the test engine.
  bool get live => false;

  Future<void> screen(WidgetTester tester, Screen s);
  Future<void> measure(WidgetTester tester, String name, {int frames = 48, Future<void> Function(int i)? step});
  Future<void> snapshot(WidgetTester tester, String name);
}

late Rig rig;

String _n(Screen s, String what) => '${s.name} $what';

void _desk(Screen s) {
  DesktopPlatform.debugOverride = s.name == 'desktop';
  addTearDown(() => DesktopPlatform.debugOverride = null);
}

Widget _app(Screen s, Widget home) => MaterialApp(
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
  builder: s.name == 'desktop'
      ? (context, child) => DesktopFrame(orientation: DesktopOrientation.landscape, child: child!)
      : null,
  home: home,
);

Future<void> _frames(WidgetTester tester, int n, [Duration step = const Duration(milliseconds: 100)]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(step);
  }
}

Future<void> streetScenario(WidgetTester tester, Screen s) async {
  await rig.screen(tester, s);
  _desk(s);
  final online = FakeOnline()..signInReady(handle: 'anna', coins: 4000);
  OnlineServices.instance = online.services;
  addTearDown(() => OnlineServices.instance = null);
  WornLooks.clear();
  await tester.pumpWidget(const ObertaApp());
  await _frames(tester, 40);
  await rig.measure(tester, _n(s, 'home steady'));
  await rig.snapshot(tester, _n(s, 'home'));

  await tester.tap(find.byKey(Key(s.name == 'desktop' ? 'desk.shop' : 'home.shopSign')));
  await tester.pump();
  await rig.measure(tester, _n(s, 'street walk'), frames: 96);
  await _frames(tester, 60);
  expect(find.byKey(const Key('shop.dept.window')), findsOneWidget);

  await rig.measure(tester, _n(s, 'shop steady'));
  await rig.snapshot(tester, _n(s, 'shop'));

  final hats = find.byKey(const Key('shop.dept.hats'));
  await tester.ensureVisible(hats);
  await _frames(tester, 10);
  await tester.tap(hats);
  await rig.measure(tester, _n(s, 'shop medallion switch'));
  await _frames(tester, 20);

  final dial = find.byKey(const Key('shop.dial'));
  if (dial.evaluate().isNotEmpty) {
    final gesture = await tester.startGesture(tester.getCenter(dial));
    await rig.measure(tester, _n(s, 'shop dial turn'), step: (i) => gesture.moveBy(const Offset(-6, 0)));
    await gesture.up();
    await rig.measure(tester, _n(s, 'shop dial fling settle'));
    await _frames(tester, 20);
  }

  final bust = find.byKey(const Key('shop.view.bust'));
  final card = find.byKey(const Key('shop.view.card'));
  if (card.evaluate().isNotEmpty) {
    await tester.tap(card);
    await rig.measure(tester, _n(s, 'shop preview toggle'));
    await _frames(tester, 20);
    if (bust.evaluate().isNotEmpty) await tester.tap(bust);
    await _frames(tester, 20);
  }
  await tester.pumpWidget(const SizedBox());
}

Future<void> rulesScenario(WidgetTester tester, Screen s) async {
  await rig.screen(tester, s);
  _desk(s);
  await tester.pumpWidget(_app(s, const RulesScreen()));
  await _frames(tester, 30);
  await rig.measure(tester, _n(s, 'rules steady'));
  await rig.snapshot(tester, _n(s, 'rules'));
  final scroll = find.byType(Scrollable).first;
  final gesture = await tester.startGesture(tester.getCenter(scroll));
  await rig.measure(tester, _n(s, 'rules scroll'), step: (i) => gesture.moveBy(const Offset(0, -9)));
  await gesture.up();
  await tester.pumpWidget(const SizedBox());
}

Future<void> filmScenario(WidgetTester tester, Screen s) async {
  await rig.screen(tester, s);
  _desk(s);
  await tester.pumpWidget(
    _app(
      s,
      Scaffold(
        body: VerdictScene(condemnedName: 'Marco', variant: VerdictTake.molo.name, town: 'Palermo', onFinished: () {}),
      ),
    ),
  );
  await _frames(tester, 4);
  await rig.measure(tester, _n(s, 'verdict film'), frames: 120, step: (i) => tester.pump(const Duration(milliseconds: 40)));
  await tester.pumpWidget(const SizedBox());
}

/// A LiveKit that is always there: the seats talk in turn, and the own
/// voice rises and falls.
class _Engine extends VoiceEngine {
  bool _connected = false;
  bool _mic = false;
  Set<String> talking = {};
  double loud = 0;

  @override
  bool get connected => _connected;
  @override
  Set<String> get participants => _connected ? talking : const {};
  @override
  Set<String> get speaking => talking;
  @override
  String? get selfIdentity => 'me';
  @override
  bool get microphoneOn => _mic;
  @override
  bool get microphoneReady => true;
  @override
  double get level => loud;
  @override
  Future<void> connect(String url, String token) async => _connected = true;
  @override
  Future<void> disconnect() async => _connected = false;
  @override
  Future<bool> prepareMicrophone() async => true;
  @override
  Future<void> releaseMicrophone() async {}
  @override
  Future<bool> setMicrophone(bool on) async => _mic = on;
  @override
  Future<void> setPrivacy({required Set<String> unheard, required Set<String> deafTo}) async {}
  @override
  Future<void> dispose() async {}

  void talk(Set<String> who) {
    talking = who;
    onChanged?.call();
  }
}

class _Tokens implements VoiceTokenSource {
  @override
  Future<VoiceGrant> grant(String roomId) async =>
      VoiceGrant(room: roomId, url: 'wss://voice.test', token: 't', canPublish: true, canSubscribe: true);
}

Future<T?> _settled<T>(WidgetTester tester, Future<T> future) async {
  T? value;
  var done = false;
  future.then<void>((v) {
    value = v;
    done = true;
  }, onError: (Object _) => done = true);
  for (var i = 0; i < 200 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
  return value;
}

Future<void> _flush(WidgetTester tester) async {
  // In the real app each pump waits for a real frame: a few are enough.
  for (var i = 0; i < (rig.live ? 3 : 20); i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> gameScenario(WidgetTester tester, Screen s) async {
  await rig.screen(tester, s);
  _desk(s);
  final engine = _Engine();
  VoiceController.engineFactory = () => engine;
  addTearDown(() => VoiceController.engineFactory = () => throw StateError('no voice'));
  AppSettings.instance.voiceMode = VoiceMode.mic;
  final clock = ManualClock();
  final online = FakeOnline(accountId: 'bruno', clock: clock, random: Random(16))
    ..signInReady(handle: 'bruno')
    ..addPlayer('anna', handle: 'anna');
  final room = online.openRoomAs('anna', LobbyLanguage.it);
  online.joinAs('bruno', room.code);
  await _settled(tester, online.gameAs('anna').setBots(room.id, 10));
  await _settled(tester, online.gameAs('anna').startGame(room.id));
  final me = (await _settled(tester, online.services.profiles.me()))!;
  final base = online.services;
  final services = OnlineServices(
    auth: base.auth,
    profiles: base.profiles,
    friends: base.friends,
    rooms: base.rooms,
    game: base.game,
    shop: base.shop,
    account: base.account,
    ranked: base.ranked,
    safety: base.safety,
    sessions: base.sessions,
    links: base.links,
    progress: base.progress,
    reactions: base.reactions,
    voice: _Tokens(),
  );
  // Di notte i posti si rimescolano: sempre allo stesso modo, così i
  // fotogrammi fermi di due prove si confrontano pixel per pixel.
  await tester.pumpWidget(_app(s, OnlineGameScreen(services: services, room: room, me: me, clock: clock, seating: Random(16))));
  await _flush(tester);
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pump(const Duration(milliseconds: 1800));
  await tester.pump(const Duration(seconds: 2));
  clock.elapse(const Duration(seconds: 2));
  await _flush(tester);
  if (find.byType(NoirRoleCard).evaluate().isNotEmpty) {
    final hold = await tester.startGesture(tester.getCenter(find.byType(NoirRoleCard)));
    await _frames(tester, 7);
    await hold.up();
    await _frames(tester, 7);
  }

  List<String> seats() => [
    for (final e in find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('seat-')).evaluate())
      (e.widget.key! as ValueKey<String>).value.substring(5),
  ];
  final done = <String>{};
  for (var i = 0; i < 400 && online.roomOf(room.id)!.status == RoomStatus.playing; i++) {
    for (final key in ['online.night', 'online.discussion', 'online.vote', 'online.verdict']) {
      final name = key.substring(7);
      if (done.contains(name) || find.byKey(Key(key)).evaluate().isEmpty) continue;
      clock.elapse(const Duration(seconds: 2));
      await _flush(tester);
      if (find.byKey(Key(key)).evaluate().isEmpty) continue;
      done.add(name);
      switch (name) {
        case 'night':
          // The phase's arrival settles first: the steady table, then.
          await _frames(tester, 20);
          await rig.measure(tester, _n(s, 'night steady'));
          await rig.snapshot(tester, _n(s, 'night'));
        case 'discussion':
          // The phase's arrival settles first: the steady table, then.
          await _frames(tester, 20);
          await rig.measure(tester, _n(s, 'day steady'));
          await rig.snapshot(tester, _n(s, 'day'));
          for (var m = 0; m < 24; m++) {
            final who = m.isEven ? online.gameAs('anna') : online.services.game;
            await _settled(tester, who.sendChat(room.id, ChatChannel.day, 'Messaggio $m: chi era fuori stanotte vicino al porto?'));
          }
          await _flush(tester);
          await rig.measure(tester, _n(s, 'day chat arriving'), step: (i) async {
            if (i % 12 == 0) {
              await _settled(tester, online.gameAs('anna').sendChat(room.id, ChatChannel.day, 'Ancora uno, il numero $i.'));
            }
          });
          final list = find.byKey(const Key('chat.messages'));
          if (list.evaluate().isNotEmpty) {
            final drag = await tester.startGesture(tester.getCenter(list));
            await rig.measure(tester, _n(s, 'day chat scroll'), step: (i) => drag.moveBy(Offset(0, i < 24 ? 8 : -8)));
            await drag.up();
            await _frames(tester, 10);
          }
          // Voices: the seats talk two at a time, LiveKit says so every 100 ms.
          await rig.measure(tester, _n(s, 'day voice rings'), step: (i) async {
            final ids = seats();
            if (i % 12 == 0 && ids.isNotEmpty) engine.talk({ids[(i ~/ 12) % ids.length], ids[(i ~/ 12 + 3) % ids.length]});
          });
          final talk = find.byKey(const Key('voice.talk'));
          // In the real app holding the button never lets go of the test:
          // the ring is measured on the test engine only.
          if (talk.evaluate().isNotEmpty && !rig.live) {
            final press = await tester.startGesture(tester.getCenter(talk));
            await _frames(tester, 3, frame);
            await rig.measure(tester, _n(s, 'day talking ring'), step: (i) async => engine.loud = 0.5 + 0.5 * sin(i / 3));
            await press.up();
          }
          engine.talk({});
          await _frames(tester, 5);
        case 'vote':
          clock.elapse(const Duration(seconds: 10));
          await _flush(tester);
          await _frames(tester, 20);
          await rig.measure(tester, _n(s, 'vote steady'));
          await rig.snapshot(tester, _n(s, 'vote'));
          // Bots vote: the numbers on the seats change.
          await rig.measure(tester, _n(s, 'vote numbers changing'), step: (i) async {
            if (i % 8 == 0) clock.fireNext();
          });
        case 'verdict':
          await rig.measure(tester, _n(s, 'verdict on the table'), frames: 72);
          await rig.snapshot(tester, _n(s, 'verdict'));
      }
    }
    if (done.length == 4) break;
    clock.fireNext();
    await _flush(tester);
  }
  await tester.pumpWidget(const SizedBox());
  await _frames(tester, 5);
}

/// The end of a short game (eight seats, the narrator plays fast): the
/// results on the table.
Future<void> endScenario(WidgetTester tester, Screen s) async {
  await rig.screen(tester, s);
  _desk(s);
  final clock = ManualClock();
  final online = FakeOnline(accountId: 'bruno', clock: clock)
    ..signInReady(handle: 'bruno')
    ..addPlayer('anna', handle: 'anna');
  final room = online.openRoomAs('anna', LobbyLanguage.it);
  online.joinAs('bruno', room.code);
  await _settled(tester, online.gameAs('anna').setBots(room.id, 6));
  await _settled(tester, online.gameAs('anna').startGame(room.id));
  final me = (await _settled(tester, online.services.profiles.me()))!;
  await tester.pumpWidget(_app(s, OnlineGameScreen(services: online.services, room: room, me: me, clock: clock, seating: Random(16))));
  await _flush(tester);
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pump(const Duration(milliseconds: 1800));
  await tester.pump(const Duration(seconds: 2));
  clock.elapse(const Duration(seconds: 2));
  await _flush(tester);
  if (find.byType(NoirRoleCard).evaluate().isNotEmpty) {
    final hold = await tester.startGesture(tester.getCenter(find.byType(NoirRoleCard)));
    await _frames(tester, 7);
    await hold.up();
    await _frames(tester, 7);
  }
  // As the narrator would: each phase gets its seconds, then the next step.
  for (var i = 0; i < 300 && online.roomOf(room.id)!.status == RoomStatus.playing; i++) {
    for (final key in ['online.night', 'online.dawn', 'online.discussion', 'online.vote', 'online.verdict']) {
      if (find.byKey(Key(key)).evaluate().isEmpty) continue;
      clock.elapse(const Duration(seconds: 2));
      await _flush(tester);
    }
    // He plays his turns (passing), or the table counts him as gone.
    for (final key in ['online.pass', 'online.abstain']) {
      final button = find.byKey(Key(key)).hitTestable();
      if (button.evaluate().isEmpty) continue;
      await tester.tap(button.first, warnIfMissed: false);
      await _flush(tester);
    }
    clock.fireNext();
    await _flush(tester);
    if (find.byKey(const Key('online.end')).evaluate().isNotEmpty) break;
  }
  for (var i = 0; i < 40 && find.byKey(const Key('online.end')).evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(find.byKey(const Key('online.end')), findsOneWidget);
  await rig.measure(tester, _n(s, 'end screen'), frames: 72);
  await rig.snapshot(tester, _n(s, 'end'));
  await tester.pumpWidget(const SizedBox());
  await _frames(tester, 5);
}
