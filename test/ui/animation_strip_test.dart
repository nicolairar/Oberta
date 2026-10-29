import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/l10n/lobby_language.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/rules/role.dart';
import 'package:oberta/ui/screens/online/game/noir_role_card.dart';
import 'package:oberta/ui/screens/online/online_game_screen.dart';
import 'package:oberta/ui/widgets/flip_role_card.dart';
import 'package:oberta/ui/widgets/lynch_mark.dart';

import '../support/languages.dart';
import '../support/manual_clock.dart';
import 'online_game_screen_test.dart' show flush, settled;

/// Strisce di fotogrammi delle animazioni principali, in build/strips: per
/// guardarle a occhio (scatti, salti, cose che compaiono senza dissolvenza).
/// I controlli veri sono pochi: il movimento ridotto e le misure fisse.

const _shot = Key('strip.shot');

Future<void> _fonts() async {
  const file = '/System/Library/Fonts/Supplemental/Georgia.ttf';
  if (!File(file).existsSync()) return;
  final bytes = File(file).readAsBytesSync();
  for (final family in ['Georgia', 'Roboto', 'serif', 'Courier']) {
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852) * 3;
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
  tester.view.viewPadding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
  addTearDown(tester.view.reset);
}

class _Strip {
  final List<ui.Image> frames = [];

  Future<void> grab(WidgetTester tester, {double ratio = 0.5}) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_shot),
    );
    await tester.runAsync(
      () async => frames.add(await boundary.toImage(pixelRatio: ratio)),
    );
  }

  Future<void> save(WidgetTester tester, String name) async {
    if (frames.isEmpty) return;
    await tester.runAsync(() async {
      final w = frames.first.width;
      final h = frames.first.height;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, (w + 4) * frames.length.toDouble(), h.toDouble()),
        Paint()..color = Colors.white,
      );
      for (var i = 0; i < frames.length; i++) {
        canvas.drawImage(frames[i], Offset((w + 4) * i.toDouble(), 0), Paint());
      }
      final image = await recorder.endRecording().toImage(
        (w + 4) * frames.length,
        h,
      );
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final tag = Platform.environment['STRIP_TAG'] ?? 'after';
      Directory('build/strips').createSync(recursive: true);
      File('build/strips/${name}_$tag.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    });
  }
}

Widget _stage(Widget child, {bool still = false}) => RepaintBoundary(
  key: _shot,
  child: appIn(
    AppLanguage.it,
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: still),
        child: Scaffold(backgroundColor: const Color(0xFF14100C), body: child),
      ),
    ),
  ),
);

void main() {
  testWidgets('la carta del ruolo online: arriva, si gira, torna coperta', (
    tester,
  ) async {
    await tester.runAsync(_fonts);
    _phone(tester);
    final strip = _Strip();
    await tester.pumpWidget(
      _stage(
        const Center(
          child: SizedBox(width: 260, child: NoirRoleCard(role: Role.mafioso)),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await strip.grab(tester);
      await tester.pump(const Duration(milliseconds: 200));
    }
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(NoirRoleCard)),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await strip.grab(tester);
    }
    await gesture.up();
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 180));
      await strip.grab(tester);
    }
    await strip.save(tester, 'noir_role_card');
  });

  testWidgets(
    'la carta del ruolo al telefono: si gira finché si tiene premuto',
    (tester) async {
      await tester.runAsync(_fonts);
      _phone(tester);
      final strip = _Strip();
      await tester.pumpWidget(
        _stage(
          const Center(
            child: SizedBox(width: 260, child: FlipRoleCard(role: Role.medico)),
          ),
        ),
      );
      await strip.grab(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(FlipRoleCard)),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 90));
        await strip.grab(tester);
      }
      await gesture.up();
      await tester.pumpAndSettle();
      await strip.save(tester, 'flip_role_card');
    },
  );

  testWidgets('con il movimento ridotto le carte non volano e non girano', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      _stage(
        const Row(
          children: [
            Expanded(child: NoirRoleCard(role: Role.mafioso)),
            Expanded(child: FlipRoleCard(role: Role.medico)),
          ],
        ),
        still: true,
      ),
    );
    await tester.pump();
    // La carta è già al suo posto, senza aspettare il volo.
    final transforms = find.descendant(
      of: find.byType(NoirRoleCard),
      matching: find.byType(Transform),
    );
    final slide = tester.widget<Transform>(transforms.first);
    expect(slide.transform.getTranslation().y, 0);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(FlipRoleCard)),
    );
    await tester.pump();
    await tester.pump();
    // Il ruolo è già scoperto al primo fotogramma, senza giro.
    expect(tester.binding.hasScheduledFrame, isFalse);
    await gesture.up();
    await tester.pump();
  });

  testWidgets('il linciaggio sul posto, fotogramma per fotogramma', (
    tester,
  ) async {
    await tester.runAsync(_fonts);
    _phone(tester);
    final strip = _Strip();
    await tester.pumpWidget(
      _stage(
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 120),
            child: SizedBox(
              width: 110,
              height: 140,
              child: LynchMark(
                label: 'Linciato',
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A211A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text('Bea', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await strip.grab(tester, ratio: 0.6);
      await tester.pump(LynchMark.length ~/ 11);
    }
    await strip.save(tester, 'lynch_mark');
  });

  testWidgets('online: le fasi si passano la mano senza salti', (tester) async {
    await tester.runAsync(_fonts);
    _phone(tester);
    final clock = ManualClock();
    final online = FakeOnline(accountId: 'bruno', clock: clock)
      ..signInReady(handle: 'bruno');
    for (final who in ['anna', 'carla', 'dario']) {
      online.addPlayer(who, handle: who);
    }
    final room = online.openRoomAs('anna', LobbyLanguage.it);
    for (final who in ['bruno', 'carla', 'dario']) {
      online.joinAs(who, room.code);
    }
    await settled(tester, online.gameAs('anna').setBots(room.id, 4));
    await settled(tester, online.gameAs('anna').startGame(room.id));
    final me = await settled(tester, online.services.profiles.me());
    await tester.pumpWidget(
      RepaintBoundary(
        key: _shot,
        child: appIn(
          AppLanguage.it,
          OnlineGameScreen(
            services: online.services,
            room: room,
            me: me,
            clock: clock,
          ),
        ),
      ),
    );
    await flush(tester);

    const phases = [
      'online.night',
      'online.dawn',
      'online.discussion',
      'online.vote',
      'online.verdict',
    ];
    String? current() {
      for (final key in phases) {
        if (find.byKey(Key(key)).evaluate().isNotEmpty) return key;
      }
      return null;
    }

    Rect? chat() {
      final slot = find.byKey(const Key('game.chatSlot'));
      return slot.evaluate().isEmpty ? null : tester.getRect(slot.first);
    }

    final seen = <String>{};
    var last = current();
    final chatAt = <Rect>{};
    for (
      var i = 0;
      i < 600 &&
          online.roomOf(room.id)!.status == RoomStatus.playing &&
          seen.length < 4;
      i++
    ) {
      clock.fireNext();
      for (var k = 0; k < 20; k++) {
        await tester.pump(const Duration(milliseconds: 1));
      }
      final now = current();
      if (now != last &&
          now != null &&
          last != null &&
          !seen.contains('$last>$now')) {
        final name = '${last.split('.').last}_to_${now.split('.').last}';
        seen.add('$last>$now');
        final strip = _Strip();
        for (var f = 0; f < 6; f++) {
          await strip.grab(tester, ratio: 0.4);
          final rect = chat();
          if (rect != null) chatAt.add(rect);
          await tester.pump(const Duration(milliseconds: 70));
        }
        await strip.save(tester, 'phase_$name');
      }
      if (now != null) last = now;
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(seen, isNotEmpty);
    // La chat non si muove mai: il tavolo e la striscia hanno misure fisse.
    expect(chatAt.length, 1, reason: '$chatAt');
    await tester.pumpWidget(const SizedBox());
  });
}
