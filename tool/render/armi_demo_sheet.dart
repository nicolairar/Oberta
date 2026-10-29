// Le tavole della prova delle armi (vedi tool/render/armi_demo.dart, che la
// fa girare sulla copia dei filmati con le armi nuove agganciate).
//
// Per ognuno dei tre stili: la tavola con tutte le armi in mano alla figura
// dei filmati e da sole, in scala vera, e quattro fotogrammi dei filmati.
// Più il confronto fra le armi di adesso e i tre stili, sul colpo di pistola.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/ui/widgets/city_backdrop.dart';
import 'package:oberta/ui/widgets/particle_sprites.dart';
import 'package:oberta/ui/widgets/weapons/noir_weapons.dart';

/// Una figura dei filmati con un'arma dei filmati in mano; torna la mano e
/// la direzione dell'avambraccio.
typedef ArmiFigure =
    (Offset, Offset) Function(
      Canvas canvas,
      Size size, {
      required Offset feet,
      required double u,
      String prop,
      int facing,
      double lean,
      double arm,
      double elbow,
      double backArm,
      double backElbow,
    });

/// Il pittore di un fotogramma del filmato [act] al tempo [t].
typedef ArmiFilm = CustomPainter Function(double t, String act, ParticleSprites? sprites);

/// Sceglie lo stile delle armi nella copia dei filmati ([on] false: le
/// armi di adesso).
typedef ArmiSetup = void Function({required WeaponLook look, required bool on, required NoirWeapon handgun});

final _out = Platform.environment['OUT'] ?? 'docs/demo/armi';

const _phone = Size(390, 844);

/// I fotogrammi: il colpo di pistola, la raffica, la lupara, lo stiletto.
const _shots = [('gun', 'gun', 0.53), ('burst', 'burst', 0.56), ('lupara', 'lupara', 0.56), ('knife', 'knife', 0.555)];

const _looks = {
  WeaponLook.inked: ('A', 'Inchiostro', 'Nere come le figure, col filo di luce del lampione'),
  WeaponLook.detailed: ('B', 'Dettaglio', 'La sagoma nera, più acciaio brunito, ottone e venature del legno'),
  WeaponLook.graphic: ('C', 'Fumetto', 'Contorno spesso, ombre nette, un solo colore: il rosso del killer'),
};

const _cream = Color(0xFFF3E9D2);
const _muted = Color(0xFFB9B0A0);
const _gold = Color(0xFFD9B46A);

Future<void> armiDemo(
  WidgetTester tester, {
  required ArmiFigure figure,
  required ArmiFilm film,
  required ArmiSetup setup,
}) async {
  await tester.runAsync(_fonts);
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final sprites = await tester.runAsync(() => ParticleSprites.shared);

  // Per il confronto, il colpo di pistola anche a 3x, come sui telefoni veri:
  // da lì si ritaglia la mano del killer.
  setup(look: WeaponLook.inked, on: false, handgun: NoirWeapon.revolver);
  final before = (await _film(tester, film(0.53, 'gun', sprites)), await _film(tester, film(0.53, 'gun', sprites), ratio: 3));
  final guns = <WeaponLook, (ui.Image, ui.Image)>{};
  for (final MapEntry(key: look, value: (letter, _, _)) in _looks.entries) {
    setup(look: look, on: true, handgun: NoirWeapon.revolver);
    for (final (name, act, t) in _shots) {
      final image = await _film(tester, film(t, act, sprites));
      if (name == 'gun') guns[look] = (image, await _film(tester, film(t, act, sprites), ratio: 3));
      await _save(tester, image, '${letter}_$name');
    }
    await _save(tester, _sheet(look, figure), '${letter}_sheet');
  }
  await _save(tester, _compare(before, guns), 'armi_confronto');
}

Future<void> _fonts() async {
  const dir = '/System/Library/Fonts/Supplemental';
  final loader = FontLoader('Georgia');
  for (final file in ['Georgia.ttf', 'Georgia Bold.ttf', 'Georgia Italic.ttf']) {
    final f = File('$dir/$file');
    if (f.existsSync()) loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
  }
  await loader.load();
}

final _key = GlobalKey();

Future<ui.Image> _film(WidgetTester tester, CustomPainter painter, {double ratio = 1}) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
        key: _key,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CityBackdrop(style: SkylineStyle.metropolis, rain: true, child: const SizedBox.expand()),
            // Una chiave nuova a ogni fotogramma: lo stesso istante con le
            // armi cambiate non deve riusare il disegno di prima.
            CustomPaint(key: UniqueKey(), painter: painter),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
  return (await tester.runAsync(() {
    final boundary = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    return boundary.toImage(pixelRatio: ratio);
  }))!;
}

Future<void> _save(WidgetTester tester, ui.Image image, String name) => tester.runAsync(() async {
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File('$_out/$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
});

void _text(
  Canvas canvas,
  String text,
  Offset at, {
  double size = 18,
  Color color = _muted,
  FontWeight weight = FontWeight.normal,
  bool italic = false,
  bool centre = false,
  double width = 600,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'Georgia',
        fontSize: size,
        color: color,
        fontWeight: weight,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        height: 1.2,
      ),
    ),
    textAlign: centre ? TextAlign.center : TextAlign.left,
    textDirection: TextDirection.ltr,
  )..layout(minWidth: centre ? width : 0, maxWidth: width);
  painter.paint(canvas, centre ? at - Offset(width / 2, 0) : at);
}

String _cm(NoirWeapon weapon) => '${(NoirWeapons.lengthOf(weapon) * 100).round()} cm';

/// Il fondo delle tavole: la notte della strada, il lampione in alto a
/// sinistra (da lì viene il filo di luce), il marciapiede.
void _night(Canvas canvas, Size size, List<double> grounds) {
  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF151B29), Color(0xFF283044), Color(0xFF1D2231)],
      ).createShader(Offset.zero & size),
  );
  canvas.drawCircle(
    const Offset(-60, -80),
    900,
    Paint()
      ..shader = ui.Gradient.radial(const Offset(-60, -80), 900, [
        const Color(0x40FFD27A),
        const Color(0x00FFD27A),
      ]),
  );
  for (final y in grounds) {
    canvas.drawRect(Rect.fromLTRB(0, y, size.width, y + 14), Paint()..color = const Color(0xFF23242C));
    canvas.drawRect(Rect.fromLTRB(0, y, size.width, y + 2), Paint()..color = const Color(0xFF3A3A44));
  }
}

ui.Image _sheet(WeaponLook look, ArmiFigure figure) {
  const size = Size(1800, 1620);
  final (letter, name, about) = _looks[look]!;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const ground = 620.0;
  _night(canvas, size, const [ground]);
  _text(canvas, '$letter · $name', const Offset(48, 30), size: 40, color: _cream, weight: FontWeight.bold);
  _text(canvas, about, const Offset(48, 84), size: 21, italic: true, width: 1200);
  _text(
    canvas,
    'Scala vera: la figura è alta 1,78 m. Il revolver prende il posto della pistola col silenziatore.',
    const Offset(48, 116),
    size: 17,
    width: 1400,
  );

  final art = NoirWeapons(look);

  // In mano alla figura dei filmati, girata come nei filmati (verso il
  // lampione), un po' più grande che sul telefono.
  const u = 300.0;
  final perMetre = NoirWeapons.perMetre(u * 1.08);
  final poses = <(String, NoirWeapon, String, double, double, double, double, double, double)>[
    ('Fucile del Cecchino', NoirWeapon.sniper, 'none', 330, 0.06, 1.48, 0.10, 1.62, 0.12),
    ('Thompson', NoirWeapon.tommy, 'tommy', 560, 0.10, 0.55, 1.05, 1.25, 0.55),
    ('Lupara', NoirWeapon.lupara, 'lupara', 800, 0.10, 1.38, 0.18, 1.50, 0.25),
    ('Revolver .38', NoirWeapon.revolver, 'pistol', 1020, 0.04, pi / 2, 0.03, -0.1, 0.2),
    ('Stiletto', NoirWeapon.stiletto, 'knife', 1230, 0.06, 1.0, 0.85, -0.1, 0.2),
    ('Mazza', NoirWeapon.bat, 'bat', 1450, 0.02, 2.5, 1.1, -0.1, 0.2),
    ('Custodia da violino', NoirWeapon.violinCase, 'none', 1690, 0.0, 0.03, 0.02, -0.1, 0.2),
  ];
  for (final (label, weapon, prop, x, lean, arm, elbow, backArm, backElbow) in poses) {
    final feet = Offset(x, ground);
    final (hand, along) = figure(
      canvas,
      size,
      feet: feet,
      u: u,
      prop: prop,
      facing: -1,
      lean: lean,
      arm: arm,
      elbow: elbow,
      backArm: backArm,
      backElbow: backElbow,
    );
    if (weapon == NoirWeapon.violinCase) {
      art.held(canvas, weapon, hand, const Offset(-1, 0), perMetre, mirror: true);
    } else if (weapon == NoirWeapon.sniper) {
      art.held(canvas, weapon, hand, along, perMetre, mirror: true);
    }
    final under = weapon == NoirWeapon.sniper ? feet.dx - 110 : feet.dx - 45;
    _text(canvas, label, Offset(under, ground + 24), size: 19, color: _cream, centre: true, width: 230);
    _text(canvas, _cm(weapon), Offset(under, ground + 50), size: 16, centre: true, width: 230);
  }

  // Da sole, tutte nella stessa scala, col metro.
  const scale = 360.0;
  _text(canvas, 'Da sole, alla stessa scala', const Offset(48, 712), size: 22, color: _gold, italic: true);
  void row(List<(String, NoirWeapon)> weapons, double centreY, double startX) {
    var x = startX;
    for (final (label, weapon) in weapons) {
      if (weapon == NoirWeapon.garroteToggle) {
        const span = 0.55;
        art.garrote(canvas, Offset(x + 10, centreY), Offset(x + 10 + span * scale, centreY), scale, sag: 0.04);
        final middle = x + 10 + span * scale / 2;
        _text(canvas, label, Offset(middle, centreY + 46), size: 16, color: _cream, centre: true, width: 200);
        _text(canvas, 'filo da ${(span * 100).round()} cm', Offset(middle, centreY + 68), size: 14, centre: true, width: 200);
        x += span * scale + 72;
        continue;
      }
      final b = NoirWeapons.boundsOf(weapon);
      art.held(canvas, weapon, Offset(x - b.left * scale, centreY - b.center.dy * scale), const Offset(1, 0), scale, fist: false);
      final w = b.width * scale;
      final below = centreY + b.height * scale / 2;
      _text(canvas, label, Offset(x + w / 2, below + 12), size: 16, color: _cream, centre: true, width: max(w, 130));
      _text(canvas, _cm(weapon), Offset(x + w / 2, below + 34), size: 14, centre: true, width: max(w, 130));
      x += w + 46;
    }
  }

  row(const [
    ('Revolver .38', NoirWeapon.revolver),
    ('Naso corto', NoirWeapon.snubNose),
    ('Beretta 1934', NoirWeapon.beretta),
    ('Stiletto', NoirWeapon.stiletto),
    ('Ananas', NoirWeapon.grenade),
    ('Lupara', NoirWeapon.lupara),
    ('Thompson', NoirWeapon.tommy),
    ('Mazza', NoirWeapon.bat),
  ], 820, 56);
  row(const [
    ('Fucile del Cecchino', NoirWeapon.sniper),
    ('Fucile subacqueo', NoirWeapon.speargun),
    ('Custodia da violino', NoirWeapon.violinCase),
    ('Garrota', NoirWeapon.garroteToggle),
  ], 1035, 56);
  row(const [('Forcone (verdetto)', NoirWeapon.pitchfork)], 1215, 56);

  // Il metro.
  final ruler = Paint()
    ..color = _muted
    ..strokeWidth = 2;
  const rx = 1300.0, ry = 1222.0;
  canvas.drawLine(const Offset(rx, ry), const Offset(rx + scale, ry), ruler);
  for (var i = 0; i <= 10; i++) {
    final h = i % 5 == 0 ? 14.0 : 7.0;
    canvas.drawLine(Offset(rx + i * scale / 10, ry), Offset(rx + i * scale / 10, ry - h), ruler);
  }
  _text(canvas, '1 metro', const Offset(rx + scale / 2, ry + 10), size: 15, centre: true, width: 200);

  // Sul telefono: alla grandezza dei filmati, e piccole (40 px di altezza).
  _text(canvas, 'Come si vedono sul telefono', const Offset(48, 1318), size: 22, color: _gold, italic: true);
  const film = 157.0; // pixel per metro nei fotogrammi, quando la cinepresa stringe sul colpo
  var x = 60.0;
  for (final weapon in const [
    NoirWeapon.revolver,
    NoirWeapon.stiletto,
    NoirWeapon.lupara,
    NoirWeapon.tommy,
    NoirWeapon.bat,
    NoirWeapon.sniper,
  ]) {
    final b = NoirWeapons.boundsOf(weapon);
    art.held(canvas, weapon, Offset(x - b.left * film, 1395 - b.center.dy * film), const Offset(1, 0), film, fist: false);
    x += b.width * film + 34;
  }
  _text(canvas, 'grandezza vera nei fotogrammi', Offset(x + 6, 1386), size: 14, width: 300);
  x = 60;
  for (final weapon in const [
    NoirWeapon.revolver,
    NoirWeapon.stiletto,
    NoirWeapon.lupara,
    NoirWeapon.tommy,
    NoirWeapon.bat,
    NoirWeapon.sniper,
    NoirWeapon.grenade,
    NoirWeapon.violinCase,
  ]) {
    final b = NoirWeapons.boundsOf(weapon);
    final w = min(170.0, b.width / b.height * 40);
    art.icon(canvas, weapon, Rect.fromLTWH(x, 1470, w, 40));
    x += w + 28;
  }
  _text(canvas, 'alte 40 px', Offset(x + 4, 1480), size: 14);

  // I gesti del tavolo, sul panno.
  for (final (i, (weapon, tilt)) in const [(NoirWeapon.revolver, -0.2), (NoirWeapon.tommy, -0.15)].indexed) {
    final tile = Rect.fromLTWH(1500 + i * 132.0, 1360, 112, 112);
    canvas.drawRRect(RRect.fromRectAndRadius(tile, const Radius.circular(18)), Paint()..color = const Color(0xFF2C4A3A));
    canvas.drawRRect(
      RRect.fromRectAndRadius(tile.deflate(3), const Radius.circular(16)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF8C6A3A),
    );
    art.icon(canvas, weapon, tile.deflate(16), tilt: tilt);
  }
  _text(canvas, 'gesti del tavolo', const Offset(1632, 1484), size: 14, centre: true, width: 260);

  return recorder.endRecording().toImageSync(size.width.toInt(), size.height.toInt());
}

/// Le armi di adesso e i tre stili sullo stesso fotogramma, e sotto la mano
/// del killer da vicino.
ui.Image _compare((ui.Image, ui.Image) before, Map<WeaponLook, (ui.Image, ui.Image)> after) {
  const gap = 14.0;
  const top = 64.0;
  // La mano del killer col revolver, nel fotogramma a 3x.
  const zoom = Rect.fromLTWH(150, 392, 190, 112);
  const zoomScale = 2.0;
  final width = 4 * _phone.width + 5 * gap;
  final height = top + _phone.height + gap + zoom.height * zoomScale + 60;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(Rect.fromLTWH(0, 0, width, height), Paint()..color = const Color(0xFF101318));
  final panels = [
    ('Adesso', before),
    for (final MapEntry(key: look, value: images) in after.entries)
      ('${_looks[look]!.$1} · ${_looks[look]!.$2}', images),
  ];
  for (final (i, (label, (image, sharp))) in panels.indexed) {
    final x = gap + i * (_phone.width + gap);
    _text(canvas, label, Offset(x + _phone.width / 2, 18), size: 24, color: i == 0 ? _muted : _cream, weight: FontWeight.bold, centre: true, width: _phone.width);
    canvas.drawImage(image, Offset(x, top), Paint());
    final dst = Rect.fromLTWH(x + (_phone.width - zoom.width * zoomScale) / 2, top + _phone.height + gap, zoom.width * zoomScale, zoom.height * zoomScale);
    final src = Rect.fromLTWH(zoom.left * 3, zoom.top * 3, zoom.width * 3, zoom.height * 3);
    canvas.drawImageRect(sharp, src, dst, Paint()..filterQuality = FilterQuality.high);
    canvas.drawRect(
      dst,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFF3A3A44),
    );
  }
  _text(canvas, 'Colpo di pistola, t = 0,53 · sotto, la mano del killer come sul telefono a 3x, ingrandita', Offset(width / 2, height - 40), size: 17, centre: true, width: width);
  return recorder.endRecording().toImageSync(width.toInt(), height.toInt());
}
