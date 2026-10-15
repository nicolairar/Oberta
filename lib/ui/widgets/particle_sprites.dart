import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;

/// Sprite riutilizzati nei filmati: si decodificano una volta e restano
/// condivisi fra le scene della notte e i verdetti.
class ParticleSprites {
  final ui.Image muzzle;
  final ui.Image spark;
  final ui.Image smoke;
  final List<ui.Image> explosions;

  // Polvere, detriti e fumo per i tonfi e le esplosioni.
  final List<ui.Image> puffs;
  final List<ui.Image> dirt;
  final List<ui.Image> blackSmoke;
  final List<ui.Image> flashes;
  final ui.Image? slash;
  final ui.Image? glint;
  final ui.Image? scorch;

  const ParticleSprites({
    required this.muzzle,
    required this.spark,
    required this.smoke,
    required this.explosions,
    this.puffs = const [],
    this.dirt = const [],
    this.blackSmoke = const [],
    this.flashes = const [],
    this.slash,
    this.glint,
    this.scorch,
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
        puffs: [for (final i in const ['00', '03', '06', '09', '12']) await _decode('assets/particles/puff_$i.png')],
        dirt: [for (final i in const ['01', '02']) await _decode('assets/particles/dirt_$i.png')],
        blackSmoke: [for (final i in const ['00', '03', '06', '09', '12']) await _decode('assets/particles/black_smoke_$i.png')],
        flashes: [for (var i = 0; i <= 8; i++) await _decode('assets/particles/flash_0$i.png')],
        slash: await _decode('assets/particles/slash_02.png'),
        glint: await _decode('assets/particles/star_06.png'),
        scorch: await _decode('assets/particles/scorch_01.png'),
      );

  static Future<ui.Image> _decode(String path) async {
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }

  ui.Image explosionAt(double progress) => explosions[(progress * explosions.length).floor().clamp(0, explosions.length - 1)];

  /// Come [draw], ma il colore tinge davvero lo sprite (con [draw] conta
  /// solo l'opacità): polvere grigia, fumi verdi, bruciature scure.
  static void drawTinted(
    ui.Canvas canvas,
    ui.Image image,
    ui.Offset center, {
    required double width,
    required double height,
    required ui.Color tint,
    double opacity = 1,
    double rotation = 0,
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
        ..colorFilter = ui.ColorFilter.mode(tint, ui.BlendMode.modulate)
        ..color = ui.Color.fromARGB((opacity.clamp(0.0, 1.0) * 255).round(), 255, 255, 255),
    );
    canvas.restore();
  }

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
        // Gli sprite sono bianchi: il colore li moltiplica, l'alfa li sfuma.
        ..color = ui.Color.fromRGBO(255, 255, 255, opacity.clamp(0.0, 1.0))
        ..colorFilter = ui.ColorFilter.mode(tint, ui.BlendMode.modulate),
    );
    canvas.restore();
  }
}
