import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/roster/roster_store.dart';
import 'package:oberta/rules/role.dart';
import 'package:oberta/sound/sound_stage.dart';
import 'package:oberta/sound/verdict_stage.dart';
import 'package:oberta/ui/theme/role_style.dart';
import 'package:oberta/ui/widgets/face_close_up.dart';
import 'package:oberta/ui/widgets/noir_avatar.dart';
import 'package:oberta/ui/widgets/verdict_scene.dart';

import '../support/languages.dart';
import '../support/test_photo.dart';

/// Le foto vere sullo schermo, dovunque siano.
Finder photos() => find.byType(RawImage);

Widget sceneOf(VerdictTake take, {String name = 'Marco', VoidCallback? onFinished}) => MaterialApp(
      home: Scaffold(
        body: take.condemns
            ? VerdictScene(condemnedName: name, variant: take.name, town: 'Palermo', onFinished: onFinished ?? () {})
            : VerdictScene.acquittal(onFinished: onFinished ?? () {}),
      ),
    );

void usePhone(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

Future<void> loadPhotos(WidgetTester tester) async {
  final context = tester.element(find.byType(Scaffold));
  await tester.runAsync(() async {
    for (final member in RosterStore.instance.roster.members) {
      final photo = RosterStore.instance.photoOf(member);
      if (photo != null) await precacheImage(photo.image, context);
    }
  });
  await tester.pump();
}

/// Un palco che sa suonare i verdetti, e si segna cosa gli chiedono.
class _ListeningStage extends SoundStage implements VerdictStage {
  final played = <VerdictTake>[];
  final prepared = <VerdictTake>[];

  @override
  void prepareVerdicts(Iterable<VerdictTake> takes) => prepared.addAll(takes);

  @override
  FutureOr<void> playVerdict(VerdictTake take) {
    played.add(take);
  }
}

void main() {
  test('ogni variante ha il suo nome, e chi non ne sceglie una ne ha una a caso', () {
    expect(VerdictScene.variants, ['molo', 'cartello', 'treno', 'cannone']);
    expect(VerdictTake.pick('treno', Random(1)), VerdictTake.treno);
    final drawn = {for (var seed = 0; seed < 40; seed++) VerdictTake.pick(null, Random(seed))};
    expect(drawn, VerdictTake.condemnations.toSet(), reason: 'tutte possono uscire');
    expect(VerdictTake.pick('assoluzione', Random(2)).condemns, isTrue, reason: 'l\'assoluzione non è una condanna');
    for (final take in VerdictTake.values) {
      expect(take.payoff, inExclusiveRange(0, VerdictBeats.card), reason: take.name);
    }
  });

  testWidgets('ogni variante si disegna dal primo all\'ultimo fotogramma, in tutte e due le lingue', (tester) async {
    for (final language in AppLanguage.values) {
      for (final take in VerdictTake.values) {
        for (final hat in AvatarHead.values) {
          for (var frame = 0; frame <= 40; frame++) {
            await tester.pumpWidget(CustomPaint(
              size: const Size(393, 852),
              painter: VerdictScenePainter(t: frame / 40, take: take, hat: hat, town: 'Las Vegas', strings: language.strings),
            ));
            expect(tester.takeException(), isNull, reason: '${language.name} ${take.name} $hat fotogramma $frame');
          }
        }
      }
    }
  });

  for (final withPhoto in [false, true]) {
    testWidgets('ogni film va in onda per intero ${withPhoto ? 'con' : 'senza'} foto, dal telefono piccolo al grande', (tester) async {
      if (withPhoto) {
        final photo = (await tester.runAsync(fakePhoto))!;
        await RosterStore.instance.add('Marco', photo: photo);
      }
      for (final size in const [Size(375, 667), Size(430, 932)]) {
        usePhone(tester, size);
        for (final take in VerdictTake.values) {
          await tester.pumpWidget(sceneOf(take));
          await loadPhotos(tester);
          for (var i = 0; i < 24; i++) {
            await tester.pump(take.length ~/ 20);
            expect(tester.takeException(), isNull, reason: '$size ${take.name} passo $i');
          }
          await tester.pumpWidget(const SizedBox());
        }
      }
    });
  }

  for (final take in [VerdictTake.molo, VerdictTake.assoluzione]) {
    testWidgets('${take.name}: il film si ferma sulla carta e aspetta il tavolo', (tester) async {
      usePhone(tester, const Size(393, 852));
      var finished = 0;
      await tester.pumpWidget(sceneOf(take, onFinished: () => finished++));
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('SALTA'), findsOneWidget);
      expect(find.text('AVANTI'), findsNothing);

      await tester.pump(take.length);
      await tester.pump();
      expect(finished, 0, reason: 'finito il film nessuno viene portato via dalla carta');
      expect(find.text('SALTA'), findsNothing);
      if (take.condemns) {
        expect(find.text('MARCO'), findsOneWidget);
        expect(find.text('LA PIAZZA HA DECISO'), findsOneWidget);
        expect(find.text('DORME COI PESCI'), findsOneWidget);
      } else {
        expect(find.text('NESSUNA CONDANNA'), findsOneWidget);
      }
      await tester.pump(const Duration(seconds: 20));
      expect(finished, 0);

      await tester.tap(find.text('AVANTI'));
      await tester.tap(find.text('AVANTI'));
      expect(finished, 1);
    });
  }

  testWidgets('chi salta il film arriva alla carta, non oltre', (tester) async {
    usePhone(tester, const Size(393, 852));
    var finished = 0;
    await tester.pumpWidget(sceneOf(VerdictTake.cannone, name: 'Giulia', onFinished: () => finished++));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('SALTA'));
    await tester.pump();
    expect(finished, 0);
    expect(find.text('GIULIA'), findsOneWidget);
    expect(find.text('IN ORBITA'), findsOneWidget);
    await tester.tap(find.text('AVANTI'));
    expect(finished, 1);
  });

  testWidgets('a metà film niente primi piani: al massimo la foto del condannato, e di nessun altro', (tester) async {
    usePhone(tester, const Size(393, 852));
    await RosterStore.instance.add('Marco', photo: (await tester.runAsync(() => fakePhoto(variant: 0)))!);
    await RosterStore.instance.add('Giulia', photo: (await tester.runAsync(() => fakePhoto(variant: 1)))!);
    for (final take in VerdictTake.condemnations) {
      await tester.pumpWidget(sceneOf(take));
      await loadPhotos(tester);
      for (var step = 0; step < 40; step++) {
        await tester.pump(take.length ~/ 40);
        final shown = photos().evaluate();
        expect(shown.length, lessThanOrEqualTo(1), reason: '${take.name} passo $step');
        expect(find.byType(FaceCloseUp), findsNothing, reason: '${take.name} passo $step');
      }
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('la scena non sa niente dei ruoli: nessun nome, colore o simbolo di parte', (tester) async {
    usePhone(tester, const Size(393, 852));
    final roleWords = <String>{
      for (final language in AppLanguage.values)
        for (final role in Role.values) language.strings.role(role).label.toUpperCase(),
      for (final language in AppLanguage.values) ...[
        language.strings.familyBadge.toUpperCase(),
        language.strings.townBadge.toUpperCase(),
        language.strings.innocentBadge.toUpperCase(),
        language.strings.isFamily.toUpperCase(),
        language.strings.isInnocent.toUpperCase(),
      ],
    };
    final roleColors = {for (final role in Role.values) role.color};
    final roleIcons = {for (final role in Role.values) role.icon};
    for (final language in AppLanguage.values) {
      for (final take in VerdictTake.values) {
        await tester.pumpWidget(appIn(
          language,
          Scaffold(
            body: take.condemns
                ? VerdictScene(condemnedName: 'Marco', variant: take.name, onFinished: () {})
                : VerdictScene.acquittal(onFinished: () {}),
          ),
        ));
        for (var step = 0; step <= 24; step++) {
          for (final text in tester.widgetList<Text>(find.byType(Text))) {
            final shown = (text.data ?? '').toUpperCase();
            for (final word in roleWords) {
              final whole = RegExp('(?<![A-ZÀ-Ý])${RegExp.escape(word)}(?![A-ZÀ-Ý])');
              expect(whole.hasMatch(shown), isFalse, reason: '${language.name} ${take.name}: "$shown"');
            }
            expect(roleColors.contains(text.style?.color), isFalse, reason: '${take.name}: "$shown"');
          }
          for (final icon in tester.widgetList<Icon>(find.byType(Icon))) {
            expect(roleIcons.contains(icon.icon), isFalse, reason: take.name);
          }
          await tester.pump(take.length ~/ 20);
        }
        await tester.pumpWidget(const SizedBox());
      }
    }
  });

  testWidgets('in inglese il verdetto parla inglese', (tester) async {
    usePhone(tester, const Size(393, 852));
    await tester.pumpWidget(appIn(
      AppLanguage.en,
      Scaffold(body: VerdictScene(condemnedName: 'Sara', variant: 'treno', onFinished: () {})),
    ));
    expect(find.text('SKIP'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(VerdictTake.treno.length);
    await tester.pump();
    expect(find.text('ONE WAY TICKET'), findsOneWidget);
    expect(find.text('THE PEOPLE HAVE SPOKEN'), findsOneWidget);
    expect(find.text('NEXT'), findsOneWidget);
  });

  testWidgets('la scena chiede al palco la sua musica, e col palco muto va in onda lo stesso', (tester) async {
    usePhone(tester, const Size(393, 852));
    final previous = SoundStage.instance;
    addTearDown(() => SoundStage.instance = previous);

    expect(SoundStage().playVerdict(VerdictTake.molo), isNull, reason: 'il palco muto non fa aspettare nessuno');
    SoundStage().prepareVerdicts();

    final stage = _ListeningStage();
    SoundStage.instance = stage;
    SoundStage.instance.prepareVerdicts();
    expect(stage.prepared, VerdictTake.values);
    await tester.pumpWidget(sceneOf(VerdictTake.cartello));
    expect(stage.played, [VerdictTake.cartello]);
    // Ogni verdetto è un film nuovo: chi lo mette in scena gli dà una chiave.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(sceneOf(VerdictTake.assoluzione));
    expect(stage.played, [VerdictTake.cartello, VerdictTake.assoluzione]);
    await tester.pumpWidget(const SizedBox());
  });
}
