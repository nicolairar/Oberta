import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/l10n/lobby_language.dart';
import 'package:oberta/main.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/settings/app_settings.dart';
import 'package:oberta/settings/settings_store.dart';
import 'package:oberta/sound/fx_groups.dart';
import 'package:oberta/sound/screen_music.dart';
import 'package:oberta/sound/sound_stage.dart';
import 'package:oberta/ui/screens/online/online_game_screen.dart';
import 'package:oberta/ui/screens/online/online_room_screen.dart';

import '../support/languages.dart';
import '../support/manual_clock.dart';

/// Un palco che si segna la musica che gli chiedono, invece di suonarla.
class _Ear extends SoundStage {
  final moods = <MusicMood?>[];
  final beds = <FxGroup?>[];

  @override
  void music(MusicMood? mood) => moods.add(mood);

  @override
  void ambience(FxGroup? group) => beds.add(group);
}

/// Una pagina qualunque che, davanti, mette la musica della vittoria.
class _Victory extends StatefulWidget {
  const _Victory();

  @override
  State<_Victory> createState() => _VictoryState();
}

class _VictoryState extends State<_Victory> {
  @override
  void initState() {
    super.initState();
    SoundStage.instance
      ..screenLoop = MusicMood.menu
      ..music(MusicMood.winTown);
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('VITTORIA'));
}

Future<void> _flush(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
  await tester.pump(const Duration(milliseconds: 300));
}

Future<T> _settled<T>(WidgetTester tester, Future<T> future) async {
  var done = false;
  late T value;
  unawaited(future.then((v) {
    value = v;
    done = true;
  }));
  for (var i = 0; i < 200 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
  expect(done, isTrue);
  return value;
}

void main() {
  late _Ear ear;
  setUp(() => SoundStage.instance = ear = _Ear());
  tearDown(() => SoundStage.instance = SoundStage());

  test('finita la vittoria, riparte il loop della schermata', () {
    ear.screenLoop = MusicMood.table;
    ear.musicEnded(MusicMood.winFamily);
    expect(ear.moods.last, MusicMood.table);

    ear.moods.clear();
    ear.musicEnded(MusicMood.day);
    expect(ear.moods, isEmpty, reason: 'un loop non finisce da solo');
  });

  testWidgets('tornati nel vicolo dalla vittoria, torna la musica del menu', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    tester.platformDispatcher.localesTestValue = const [Locale('it', 'IT')];

    await tester.pumpWidget(ObertaApp(settings: AppSettings(MemorySettingsStore())));
    await tester.pumpAndSettle();
    expect(ear.moods.last, MusicMood.menu, reason: 'il vicolo mette la sua musica entrando');

    final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
    unawaited(navigator.push(MaterialPageRoute<void>(builder: (_) => const _Victory())));
    await tester.pumpAndSettle();
    expect(ear.moods.last, MusicMood.winTown);

    navigator.pop();
    await tester.pumpAndSettle();
    expect(ear.moods.last, MusicMood.menu, reason: 'la vittoria non resta accesa nel menu');
    expect(ear.beds.last, isNull);
  });

  testWidgets('dalla partita online alla stanza: la vittoria si spegne, torna la musica della stanza', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final online = FakeOnline(accountId: 'bruno', clock: ManualClock())
      ..signInReady(handle: 'bruno')
      ..addPlayer('anna', handle: 'anna');
    final room = online.openRoomAs('anna', LobbyLanguage.it);
    online.joinAs('bruno', room.code);
    await _settled(tester, online.gameAs('anna').setBots(room.id, 3));
    await _settled(tester, online.gameAs('anna').startGame(room.id));
    final me = await _settled(tester, online.services.profiles.me());
    final playing = online.roomOf(room.id)!;

    await tester.pumpWidget(appIn(
      AppLanguage.it,
      OnlineRoomScreen(services: online.services, room: playing, me: me),
      observers: [screenMusicRoutes],
    ));
    await _flush(tester);
    await _flush(tester);
    expect(find.byType(OnlineGameScreen), findsOneWidget);

    // La partita finisce con una vittoria: suona il suo tema.
    SoundStage.instance.music(MusicMood.winFamily);
    await tester.tap(find.byTooltip('Abbandona la partita'));
    await _flush(tester);
    await tester.tap(find.text('ESCI'));
    await _flush(tester);
    await _flush(tester);
    expect(find.byType(OnlineGameScreen), findsNothing);
    expect(ear.moods.last, MusicMood.menu, reason: 'fuori dalla partita la vittoria non resta accesa');
    await tester.pumpWidget(const SizedBox());
  });
}
