// Le immagini della pagina Steam, alle misure esatte che Steam chiede,
// dipinte con gli stessi pittori del vicolo della schermata iniziale:
// i mattoni, l'insegna al neon OBERTÀ, il lampione, l'uomo che fuma, il gatto.
// `flutter test tool/render/steam_art_render_test.dart` scrive i PNG in
// build/steam/art/; `steam/store/make.sh` li copia (e comprime) in steam/store.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/ui/widgets/home_alley.dart';
import 'package:oberta/ui/widgets/home_neon_sign.dart';

import 'steam_support.dart';

/// Il vicolo messo in scena per un formato: dove stanno l'insegna, il
/// marciapiede, il lampione e l'uomo. Il resto lo calcola [HomeAlleyLayout].
class _Stage extends HomeAlleyLayout {
  final Rect _sign;
  final double _cap;
  final double groundY;
  final double figure;
  final double lampX;

  _Stage(Size size, {required Rect sign, required this.groundY, required this.figure, required this.lampX, double? bricks})
      : _sign = sign,
        _cap = bricks ?? sign.height / HomeNeonSign.height,
        super(size, EdgeInsets.zero);

  /// L'insegna larga [width] con l'angolo in alto a sinistra in [topLeft].
  static Rect signAt(Offset topLeft, double width) =>
      topLeft & Size(width, width / HomeNeonSign.width * HomeNeonSign.height);

  @override
  Rect get sign => _sign;
  @override
  double get cap => _cap;
  @override
  double get ground => groundY;
  @override
  double get curb => groundY + (size.height - groundY) * 0.34;
  @override
  double get smoker => figure;
  @override
  Offset get lampFoot => Offset(lampX, ground + (size.height - ground) * 0.20);
  @override
  Offset get lampHead => Offset(lampFoot.dx + smoker * 0.27, ground - smoker * 1.02);
  @override
  Offset get smokerFeet => Offset(lampFoot.dx + smoker * 0.31, ground + (size.height - ground) * 0.25);

  // I colpi di pistola sul muro si fanno accanto alla targa: qui la targa
  // non c'è, e i colpi finiscono fuori dal quadro.
  static const _away = Rect.fromLTWH(-4000, -4000, 10, 10);
  @override
  Rect get plaque => _away;
  @override
  Rect get badge => _away;
  @override
  Rect get slot => _away;
  @override
  Rect get signIn => _away;
}

/// Le icone dei ruoli, lette dagli asset.
final _roles = <String, ui.Image>{};

Future<void> _loadRoles() async {
  for (final name in ['padrino', 'detective', 'medico', 'sicario', 'fesso', 'mafioso', 'sindaco', 'piromane']) {
    final codec = await ui.instantiateImageCodec(File('assets/roles/$name.png').readAsBytesSync());
    _roles[name] = (await codec.getNextFrame()).image;
  }
}

Future<ui.Image> _decode(String path, {int? size}) async {
  final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync(), targetWidth: size, targetHeight: size);
  return (await codec.getNextFrame()).image;
}

/// Il secondo del giro d'ambiente: l'uomo fuma, il gatto è fermo a guardare.
const _moment = 42.0 / HomeStreetPainter.loop;

void _alley(Canvas canvas, Size size, _Stage stage, {bool neon = true, double moment = _moment}) {
  final state = HomeNeonState()..set(List.filled(HomeNeonSign.letters, 1.0));
  HomeWallPainter(stage, plaque: null).paint(canvas, size);
  if (neon) HomeNeonPainter(sign: stage.sign, cap: stage.cap, state: state).paint(canvas, size);
  HomeStreetPainter(
    layout: stage,
    ambient: AlwaysStoppedAnimation(moment),
    intro: const AlwaysStoppedAnimation(1),
    neon: state,
  ).paint(canvas, size);
}

/// Una fila di medaglioni dei ruoli, col filo d'oro e l'ombra.
void _medallions(Canvas canvas, List<String> names, Offset center, double radius, {double gap = 0.35, double arc = 0}) {
  final step = radius * 2 * (1 + gap);
  final first = center.dx - step * (names.length - 1) / 2;
  for (final (i, name) in names.indexed) {
    final t = names.length == 1 ? 0.0 : i / (names.length - 1) * 2 - 1;
    final c = Offset(first + step * i, center.dy + arc * t * t);
    canvas.drawCircle(
      c.translate(0, radius * 0.12),
      radius * 1.04,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.65)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.18),
    );
    final image = _roles[name]!;
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: radius)));
    // L'icona ha un filo dell'icona accanto sul bordo: si prende il centro.
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()).deflate(image.width * 0.035);
    canvas.drawImageRect(image, src, Rect.fromCircle(center: c, radius: radius), Paint()..filterQuality = FilterQuality.high);
    canvas.restore();
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.5, radius * 0.07)
        ..color = const Color(0xFFD4A63A),
    );
  }
}

/// Uno scuro morbido verso i bordi, per staccare l'insegna.
void _vignette(Canvas canvas, Size size, {double strength = 0.55}) {
  final rect = Offset.zero & size;
  canvas.drawRect(
    rect,
    Paint()
      ..shader = RadialGradient(
        radius: 0.95,
        colors: [Colors.transparent, Colors.black.withValues(alpha: strength)],
        stops: const [0.55, 1],
      ).createShader(rect),
  );
}

Future<ui.Image> _paint(Size size, void Function(Canvas canvas) draw) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & size);
  draw(canvas);
  return recorder.endRecording().toImage(size.width.round(), size.height.round());
}

/// La capsula orizzontale (920×430, 1232×706): l'insegna in alto a destra
/// del lampione, l'uomo che fuma sotto la luce, i ruoli sul muro.
Future<ui.Image> _wide(Size size, {bool roles = true}) => _paint(size, (canvas) {
      final w = size.width, h = size.height;
      final signW = w * 0.60;
      final stage = _Stage(
        size,
        sign: _Stage.signAt(Offset(w * 0.30, h * 0.08), signW),
        groundY: h * 0.86,
        figure: h * 0.56,
        lampX: w * 0.09,
      );
      _alley(canvas, size, stage);
      if (roles) {
        _medallions(
          canvas,
          ['padrino', 'detective', 'medico', 'sicario', 'fesso'],
          Offset(stage.sign.center.dx, h * 0.665),
          h * 0.085,
          gap: 0.42,
        );
      }
      _vignette(canvas, size, strength: 0.35);
    });

/// La capsula piccola (462×174): solo l'insegna, grande, sul muro.
Future<ui.Image> _small(Size size) => _paint(size, (canvas) {
      final w = size.width, h = size.height;
      final signW = w * 0.80;
      final sign = _Stage.signAt(Offset((w - signW) / 2, 0), signW);
      final stage = _Stage(
        size,
        sign: sign.shift(Offset(0, (h - sign.height) / 2 - h * 0.05)),
        groundY: h * 1.2,
        figure: h,
        lampX: -w,
      );
      // Un secondo in cui il gatto non passa: qui non ci starebbe.
      _alley(canvas, size, stage, moment: 12 / HomeStreetPainter.loop);
    });

/// Le capsule verticali (748×896, 600×900): l'insegna in cima, sotto il
/// lampione, l'uomo e i ruoli.
Future<ui.Image> _tall(Size size) => _paint(size, (canvas) {
      final w = size.width, h = size.height;
      final signW = w * 0.88;
      final stage = _Stage(
        size,
        sign: _Stage.signAt(Offset((w - signW) / 2, h * 0.06), signW),
        groundY: h * 0.88,
        figure: h * 0.40,
        lampX: w * 0.12,
      );
      _alley(canvas, size, stage);
      final r = w * 0.07;
      _medallions(canvas, ['padrino', 'detective', 'medico'], Offset(w * 0.70, h * 0.45), r, gap: 0.30);
      _medallions(canvas, ['sicario', 'fesso'], Offset(w * 0.70, h * 0.45 + r * 2.7), r, gap: 0.30);
      _vignette(canvas, size, strength: 0.35);
    });

/// L'eroe della libreria (3840×1240): il vicolo senza scritte. L'insegna
/// sta appena sopra il quadro, se ne vede solo la luce rossa.
Future<ui.Image> _hero(Size size) => _paint(size, (canvas) {
      final w = size.width, h = size.height;
      final signW = w * 0.34;
      final sign = _Stage.signAt(Offset(w * 0.50, 0), signW);
      final stage = _Stage(
        size,
        sign: sign.shift(Offset(0, -sign.height * 0.93)),
        groundY: h * 0.84,
        figure: h * 0.56,
        lampX: w * 0.40,
        bricks: h * 0.16,
      );
      // L'uomo a metà, il gatto più in là che cammina: a sinistra resta il
      // posto per il logo che Steam ci mette sopra.
      _alley(canvas, size, stage, neon: false, moment: 40 / HomeStreetPainter.loop);
      _vignette(canvas, size, strength: 0.3);
    });

/// Lo sfondo della pagina (1438×810): il vicolo quasi al buio, sfocato.
Future<ui.Image> _background(Size size) => _paint(size, (canvas) {
      final w = size.width, h = size.height;
      final signW = w * 0.6;
      final sign = _Stage.signAt(Offset(w * 0.2, 0), signW);
      final stage = _Stage(
        size,
        sign: sign.shift(Offset(0, -sign.height * 0.9)),
        groundY: h * 0.9,
        figure: h * 0.5,
        lampX: w * 0.08,
        bricks: h * 0.11,
      );
      canvas.saveLayer(Offset.zero & size, Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6));
      _alley(canvas, size, stage, neon: false);
      canvas.restore();
      final rect = Offset.zero & size;
      canvas.drawRect(rect, Paint()..color = const Color(0xFF07070B).withValues(alpha: 0.62));
      canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x00000000), Color(0xFF07070B)],
            stops: [0.35, 1],
          ).createShader(rect),
      );
    });

/// Il logo della libreria (1280×720): solo l'insegna, su trasparente.
/// L'alone rosso, che sul muro si posa sui mattoni, qui andrebbe sopra
/// l'eroe come una macchia: si dimezza, i tubi restano pieni.
Future<ui.Image> _logo(Size size) async {
  final neon = await _neonOnly(size);
  final bytes = (await neon.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!.buffer.asUint8List();
  for (var i = 0; i < bytes.length; i += 4) {
    final (r, g, a) = (bytes[i], bytes[i + 1], bytes[i + 3]);
    // Solo il rosso puro e poco coprente: niente crema dei tubi, niente ferro.
    if (r > 180 && g < 80 && a < 200) bytes[i + 3] = (a * 0.5).round();
  }
  for (var i = 0; i < bytes.length; i += 4) {
    final a = bytes[i + 3];
    for (var c = 0; c < 3; c++) {
      bytes[i + c] = (bytes[i + c] * a / 255).round();
    }
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: neon.width,
    height: neon.height,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await descriptor.instantiateCodec();
  return (await codec.getNextFrame()).image;
}

Future<ui.Image> _neonOnly(Size size) => _paint(size, (canvas) {
      final w = size.width, h = size.height;
      final signW = w * 0.86;
      final sign = _Stage.signAt(Offset.zero, signW);
      final rect = sign.shift(Offset((w - signW) / 2, (h - sign.height) / 2));
      final state = HomeNeonState()..set(List.filled(HomeNeonSign.letters, 1.0));
      HomeNeonPainter(sign: rect, cap: rect.height / HomeNeonSign.height, state: state).paint(canvas, size);
    });

/// L'icona dell'app, ridotta a [px].
Future<ui.Image> _icon(int px) async {
  final image = await _decode('site/oberta/img/icon.png');
  return _paint(Size.square(px.toDouble()), (canvas) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, px.toDouble(), px.toDouble()),
      Paint()..filterQuality = FilterQuality.high,
    );
  });
}

Future<Uint8List> _png(ui.Image image) async =>
    (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();

/// Un .ico con dentro i PNG così come sono (Windows Vista e seguenti).
Uint8List _ico(List<(int, Uint8List)> pngs) {
  final header = BytesBuilder()
    ..add(_u16(0))
    ..add(_u16(1))
    ..add(_u16(pngs.length));
  var offset = 6 + 16 * pngs.length;
  final body = BytesBuilder();
  for (final (px, png) in pngs) {
    header
      ..addByte(px >= 256 ? 0 : px)
      ..addByte(px >= 256 ? 0 : px)
      ..addByte(0)
      ..addByte(0)
      ..add(_u16(1))
      ..add(_u16(32))
      ..add(_u32(png.length))
      ..add(_u32(offset));
    offset += png.length;
    body.add(png);
  }
  return Uint8List.fromList([...header.takeBytes(), ...body.takeBytes()]);
}

List<int> _u16(int v) => [v & 0xFF, (v >> 8) & 0xFF];
List<int> _u32(int v) => [v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF];

void main() {
  testWidgets('la pagina Steam: capsule, sfondi, logo, icone', (tester) async {
    await tester.runAsync(() async {
      await _loadRoles();
      final jobs = <String, Future<ui.Image> Function()>{
        'header_capsule_920x430': () => _wide(const Size(920, 430)),
        'small_capsule_462x174': () => _small(const Size(462, 174)),
        'main_capsule_1232x706': () => _wide(const Size(1232, 706)),
        'vertical_capsule_748x896': () => _tall(const Size(748, 896)),
        'library_capsule_600x900': () => _tall(const Size(600, 900)),
        'library_hero_3840x1240': () => _hero(const Size(3840, 1240)),
        'library_logo_1280x720': () => _logo(const Size(1280, 720)),
        'page_background_1438x810': () => _background(const Size(1438, 810)),
        'community_icon_184x184': () => _icon(184),
        'client_icon_256x256': () => _icon(256),
        'client_icon_32x32': () => _icon(32),
      };
      final only = Platform.environment['ONLY'];
      for (final MapEntry(key: name, value: job) in jobs.entries) {
        if (only != null && !name.contains(only)) continue;
        final image = await job();
        final [w, h] = name.split('_').last.split('x').map(int.parse).toList();
        expect((image.width, image.height), (w, h), reason: name);
        await writeSteamPng(image, 'art/$name');
      }
      if (only == null) {
        final ico = _ico([(32, await _png(await _icon(32))), (256, await _png(await _icon(256)))]);
        File('$steamOut/art/client_icon.ico').writeAsBytesSync(ico);
      }
    });
  });
}
