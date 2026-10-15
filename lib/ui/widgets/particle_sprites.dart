import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;

/// Sprite riutilizzati nei filmati: si decodificano una volta e restano
/// condivisi fra le scene della notte e i verdetti.
class ParticleSprites {
  final ui.Image muzzle;
  final ui.Image spark;
  final ui.Image smoke;
  final List<ui.Image> explosions;

  const ParticleSprites({
    required this.muzzle,
    required this.spark,
    required this.smoke,
    required this.explosions,
  });

  static final Future<ParticleSprites> shared = _load();

  static Future<ParticleSprites> _load() async => ParticleSprites(
        muzzle: await _decode('assets/particles/muzzle_01.png'),
        spark: await _decode('assets/particles/star_01.png'),
        smoke: await _decode('assets/particles/smoke_01.png'),
        explosions: [
          for (var i = 0; i <= 8; i++)
            await _decode('assets/particles/explosion_${i.toString().padLeft(2, '0')}.png'),
        ],
      );

  static Future<ui.Image> _decode(String path) async {
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }

  ui.Image explosionAt(double progress) => explosions[(progress * explosions.length).floor().clamp(0, explosions.length - 1)];

  static void draw(
    ui.Canvas canvas,
    ui.Image image,
    ui.Offset center, {
    required double width,
    required double height,
    double opacity = 1,
    double rotation = 0,
    ui.Color tint = const ui.Color(0xFFFFFFFF),
  }) {
    if (opacity <= 0 || width <= 0 || height <= 0) return;
    final source = ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final destination = ui.Rect.fromCenter(center: ui.Offset.zero, width: width, height: height);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.drawImageRect(
      image,
      source,
      destination,
      ui.Paint()
        ..filterQuality = ui.FilterQuality.medium
        ..color = tint.withValues(alpha: opacity.clamp(0.0, 1.0)),
    );
    canvas.restore();
  }
}
