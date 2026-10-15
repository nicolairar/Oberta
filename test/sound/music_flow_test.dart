import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/main.dart';
import 'package:oberta/settings/app_settings.dart';
import 'package:oberta/settings/settings_store.dart';
import 'package:oberta/sound/sound_stage.dart';

/// Un palco che si segna cosa gli chiedono, invece di suonare.
class _Ear extends SoundStage {
  final moods = <MusicMood?>[];
  final presses = <Press>[];

  @override
  void music(MusicMood? mood) => moods.add(mood);

  @override
  void press(Press press) => presses.add(press);
}

void main() {
  late _Ear ear;
  setUp(() => SoundStage.instance = ear = _Ear());
  tearDown(() => SoundStage.instance = SoundStage());

  testWidgets('il menu ha la sua musica, il tavolo un\'altra, e i tasti si sentono', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    tester.platformDispatcher.localesTestValue = const [Locale('it', 'IT')];

    await tester.pumpWidget(ObertaApp(settings: AppSettings(MemorySettingsStore())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CREA STANZA'));
    await tester.pumpAndSettle();
    expect(ear.moods.last, MusicMood.table, reason: 'al tavolo non suona più il menu');

    await tester.tap(find.text('+ TEST'));
    await tester.pump();
    expect(ear.presses, isNotEmpty, reason: 'un tasto premuto fa il suo suono');

    Navigator.of(tester.element(find.text('+ TEST'))).pop();
    await tester.pumpAndSettle();
    expect(ear.moods.last, MusicMood.menu, reason: 'tornati nel vicolo, torna la sua musica');
  });
}
