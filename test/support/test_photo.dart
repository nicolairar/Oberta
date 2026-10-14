import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/roster/roster_store.dart';

/// Una foto finta, come uscirebbe dalla fotocamera: verticale 3:4, con una
/// faccia disegnata nel mezzo. [variant] cambia colori e pettinatura.
///
/// Codificare un'immagine è lavoro vero, non finto: dentro un test di widget
/// va chiamata sotto `tester.runAsync`.
Future<Uint8List> fakePhoto({int variant = 0, int width = 300, int height = 400}) async {
  const walls = [Color(0xFF7FA6C9), Color(0xFFD9C7A3), Color(0xFF9CC29A), Color(0xFFC79BB4)];
  const skins = [Color(0xFFE8B896), Color(0xFFC68E6A), Color(0xFFF2CDB4), Color(0xFF8E5D43)];
  const hairs = [Color(0xFF2B1B12), Color(0xFFB98A3E), Color(0xFF5A2E1C), Color(0xFF111111)];
  const shirts = [Color(0xFF2F6FB3), Color(0xFFC0392B), Color(0xFF2E8B57), Color(0xFFEFEFEF)];

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final w = width.toDouble();
  final h = height.toDouble();
  Paint fill(Color color) => Paint()..color = color;

  canvas.drawRect(Rect.fromLTWH(0, 0, w, h), fill(walls[variant % walls.length]));
  // Spalle, collo, testa.
  canvas.drawRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.08, h * 0.72, w * 0.84, h * 0.4), Radius.circular(w * 0.2)),
    fill(shirts[variant % shirts.length]),
  );
  final skin = fill(skins[variant % skins.length]);
  canvas.drawRect(Rect.fromLTWH(w * 0.42, h * 0.58, w * 0.16, h * 0.18), skin);
  canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.42), width: w * 0.46, height: h * 0.44), skin);
  // Capelli: corti o lunghi, a varianti alterne.
  final hair = fill(hairs[variant % hairs.length]);
  canvas.drawArc(
    Rect.fromCenter(center: Offset(w * 0.5, h * 0.36), width: w * 0.50, height: h * 0.34),
    3.1416,
    3.1416,
    true,
    hair,
  );
  if (variant.isOdd) {
    canvas.drawRect(Rect.fromLTWH(w * 0.25, h * 0.36, w * 0.07, h * 0.28), hair);
    canvas.drawRect(Rect.fromLTWH(w * 0.68, h * 0.36, w * 0.07, h * 0.28), hair);
  }
  // Occhi e bocca.
  for (final x in [0.41, 0.59]) {
    canvas.drawOval(Rect.fromCenter(center: Offset(w * x, h * 0.42), width: w * 0.07, height: h * 0.028), fill(Colors.white));
    canvas.drawCircle(Offset(w * x, h * 0.42), w * 0.016, fill(const Color(0xFF1B1B1B)));
  }
  canvas.drawArc(
    Rect.fromCenter(center: Offset(w * 0.5, h * 0.50), width: w * 0.18, height: h * 0.08),
    0.3,
    2.5,
    false,
    Paint()
      ..color = const Color(0xFF8A2B2B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.018,
  );

  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// Aspetta che le foto dell'elenco siano decodificate, come lo sarebbero su
/// un telefono un attimo dopo l'avvio, poi ridisegna.
Future<void> loadPhotos(WidgetTester tester, RosterStore store) async {
  final context = tester.element(find.byType(Directionality).first);
  await tester.runAsync(() async {
    for (final member in store.roster.members) {
      final photo = store.photoOf(member);
      if (photo != null) await precacheImage(photo.image, context);
    }
  });
  await tester.pump();
}
