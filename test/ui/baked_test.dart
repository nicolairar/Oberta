// A baked drawing is kept at the real pixels of the screen: on a phone with
// three pixels per point the image is three times the logical size, so it
// is not stretched (and blurred) when it is put back on screen.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/ui/screens/online/game/seat_card.dart';
import 'package:oberta/ui/widgets/baked.dart';
import 'package:oberta/ui/widgets/player_avatar.dart';

class _Dot extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) => canvas.drawCircle(size.center(Offset.zero), size.shortestSide / 2, Paint()..color = Colors.amber);

  @override
  bool shouldRepaint(_Dot old) => false;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('bakes at the device pixel ratio, and again when it changes', (tester) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Center(child: Baked(child: CustomPaint(size: const Size(100, 60), painter: _Dot()))),
    );
    await _settle(tester);
    var baked = tester.renderObject<RenderBaked>(find.byType(Baked));
    expect(baked.debugImage, isNotNull);
    expect(baked.debugImage!.width, 300);
    expect(baked.debugImage!.height, 180);

    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(780, 1688);
    await tester.pump();
    await _settle(tester);
    baked = tester.renderObject<RenderBaked>(find.byType(Baked));
    expect(baked.debugImage!.width, 200);
    expect(baked.debugImage!.height, 120);
  });

  testWidgets('a portrait on a phone is baked at three pixels per point', (tester) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: Center(child: PlayerAvatar(seed: 'anna', size: 80))));
    await _settle(tester);
    final baked = tester.renderObject<RenderBaked>(find.byType(Baked));
    final logical = 80 + 2 * (80 * 0.02 + 1);
    expect(baked.debugImage!.width, (logical * 3).ceil());
  });

  testWidgets('an exact bake sits on its fraction of a pixel, like the live drawing', (tester) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(600, 600);
    addTearDown(tester.view.reset);
    final screen = GlobalKey();
    Future<Uint8List> shot({required bool baked}) async {
      // A sharp edge, a soft shadow and a portrait baked on its own inside.
      Widget card = SizedBox(
        width: 80,
        height: 100,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.brown,
            border: Border.all(color: Colors.amber, width: 1.4),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
            boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 10, offset: Offset(0, 5))],
          ),
          child: const Center(child: PlayerAvatar(seed: 'anna', size: 60, bare: true)),
        ),
      );
      if (baked) card = Baked(exact: true, overflow: const EdgeInsets.all(30), child: card);
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: screen,
            child: ColoredBox(
              color: Colors.teal,
              child: Stack(children: [Positioned(left: 40.37, top: 30.71, child: card)]),
            ),
          ),
        ),
      );
      await _settle(tester);
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(screen));
      late final Uint8List bytes;
      await tester.runAsync(() async {
        final image = boundary.toImageSync(pixelRatio: 3);
        bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
        image.dispose();
      });
      return bytes;
    }

    final live = await shot(baked: false);
    final baked = await shot(baked: true);
    final outer = tester.renderObjectList<RenderBaked>(find.byType(Baked)).first;
    expect(outer.debugImage, isNotNull);
    var worst = 0;
    for (var i = 0; i < live.length; i++) {
      final d = (live[i] - baked[i]).abs();
      if (d > worst) worst = d;
    }
    // Only the rounding of the image's own pixels: nothing moved, nothing
    // blurred (a portrait off its pixels would differ by far more).
    expect(worst, lessThanOrEqualTo(4));
  });

  testWidgets('a seat is baked again when something on it changes, portrait included', (tester) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(600, 600);
    addTearDown(tester.view.reset);
    Future<void> show(int votes) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Stack(children: [Positioned(left: 20.5, top: 20.25, child: SeatCard(name: 'anna', width: 80, votes: votes))]),
        ),
      );
      await _settle(tester);
    }

    await show(0);
    final seat = tester.renderObjectList<RenderBaked>(find.byType(Baked)).first;
    final first = seat.debugImage;
    expect(first, isNotNull);
    await show(1);
    // The vote's stamp pops (drawn live), then the seat is one image again.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(seat.debugImage, isNotNull);
    expect(seat.debugImage, isNot(same(first)));

    // A portrait inside the seat changes: the seat's image goes with it.
    final portrait = tester.renderObjectList<RenderBaked>(find.byType(Baked)).firstWhere((b) => b != seat);
    final before = seat.debugImage;
    portrait.markNeedsPaint();
    await _settle(tester);
    expect(seat.debugImage, isNot(same(before)));
  });
}

