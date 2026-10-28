// A baked drawing is kept at the real pixels of the screen: on a phone with
// three pixels per point the image is three times the logical size, so it
// is not stretched (and blurred) when it is put back on screen.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
