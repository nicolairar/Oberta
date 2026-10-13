import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// L'icona dell'app: un volto col cappello davanti a una luna d'oro.
///
/// Come tutto il resto è disegnata in codice. Per rigenerare i file che
/// vanno negli store: `tool/make_app_icons.sh`.
class IconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.25),
          radius: 0.95,
          colors: [Color(0xFF2A1B2E), Color(0xFF120D18), Color(0xFF050407)],
          stops: [0, 0.55, 1],
        ).createShader(rect),
    );
    // La luna d'oro, con il suo alone.
    final moon = Offset(s * 0.5, s * 0.44);
    canvas.drawCircle(
      moon,
      s * 0.44,
      Paint()
        ..color = const Color(0xFFE2B33C).withValues(alpha: 0.22)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.06),
    );
    canvas.drawCircle(
      moon,
      s * 0.36,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.35),
          colors: [Color(0xFFFFE9A6), Color(0xFFE8B93E), Color(0xFFB8811C)],
          stops: [0, 0.6, 1],
        ).createShader(Rect.fromCircle(center: moon, radius: s * 0.36)),
    );

    final ink = Paint()..color = const Color(0xFF07060A);
    // Le spalle e il bavero.
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.02, s * 1.02)
        ..quadraticBezierTo(s * 0.06, s * 0.74, s * 0.34, s * 0.69)
        ..lineTo(s * 0.66, s * 0.69)
        ..quadraticBezierTo(s * 0.94, s * 0.74, s * 0.98, s * 1.02)
        ..close(),
      ink,
    );
    // La camicia e la cravatta rossa.
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.40, s * 0.70)
        ..lineTo(s * 0.60, s * 0.70)
        ..lineTo(s * 0.50, s * 0.92)
        ..close(),
      Paint()..color = const Color(0xFFEDE6D6),
    );
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.47, s * 0.715)
        ..lineTo(s * 0.53, s * 0.715)
        ..lineTo(s * 0.555, s * 0.86)
        ..lineTo(s * 0.50, s * 0.93)
        ..lineTo(s * 0.445, s * 0.86)
        ..close(),
      Paint()..color = const Color(0xFFC2222D),
    );
    // I risvolti del bavero, sopra la camicia.
    for (final side in [-1.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(s * (0.5 + side * 0.15), s * 0.695)
          ..lineTo(s * (0.5 + side * 0.035), s * 0.90)
          ..lineTo(s * (0.5 + side * 0.20), s * 0.80)
          ..close(),
        ink,
      );
    }
    // Il collo e il viso.
    canvas.drawRect(Rect.fromLTRB(s * 0.445, s * 0.58, s * 0.555, s * 0.72), ink);
    canvas.drawOval(Rect.fromCenter(center: Offset(s * 0.5, s * 0.50), width: s * 0.29, height: s * 0.35), ink);
    // Il cappello: la tesa larga, la cupola con la piega, il nastro rosso.
    canvas.save();
    canvas.translate(s * 0.5, s * 0.405);
    canvas.rotate(-0.06);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: s * 0.66, height: s * 0.105), ink);
    canvas.drawPath(
      Path()
        ..moveTo(-s * 0.185, -s * 0.01)
        ..quadraticBezierTo(-s * 0.20, -s * 0.24, -s * 0.09, -s * 0.245)
        ..quadraticBezierTo(0, -s * 0.195, s * 0.09, -s * 0.25)
        ..quadraticBezierTo(s * 0.205, -s * 0.24, s * 0.185, -s * 0.01)
        ..close(),
      ink,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-s * 0.187, -s * 0.085)
        ..quadraticBezierTo(0, -s * 0.045, s * 0.187, -s * 0.085)
        ..lineTo(s * 0.186, -s * 0.025)
        ..quadraticBezierTo(0, s * 0.015, -s * 0.186, -s * 0.025)
        ..close(),
      Paint()..color = const Color(0xFFC2222D),
    );
    canvas.restore();
    // Due occhi nell'ombra della tesa: ti ha visto.
    for (final side in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(s * (0.5 + side * 0.065), s * 0.487), width: s * 0.055, height: s * 0.02),
        Paint()..color = const Color(0xFFFFF3C4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void main() {
  testWidgets('disegna l\'icona a 1024 punti', (tester) async {
    tester.view.physicalSize = const Size(1024, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: CustomPaint(size: const Size(1024, 1024), painter: IconPainter()),
    ));
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(Platform.environment['ICON_OUT'] ?? 'build/app_icon.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
