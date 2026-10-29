// La prova delle armi nuove dentro i filmati veri, senza toccare i filmati.
//
//   dart run tool/render/armi_demo.dart            (in docs/demo/armi/)
//   OUT=/tmp/armi dart run tool/render/armi_demo.dart
//
// Copia lib/ui/widgets/death_scene.dart e le sue parti in build/armi_demo/,
// ci aggancia lib/ui/widgets/weapons/noir_weapons.dart al posto delle armi
// disegnate lì dentro, e fa girare tool/render/armi_demo_sheet.dart su quella
// copia: il tavolo delle armi accanto alla figura, e qualche fotogramma dei
// filmati, per ognuno dei tre stili. Le enum pubbliche restano quelle vere,
// così il resto del gioco (i suoni, le storie) parla con la copia senza
// accorgersene.
import 'dart:io';

const _lib = 'lib/ui/widgets';
const _dir = 'build/armi_demo';

Future<void> main() async {
  final out = Platform.environment['OUT'] ?? 'docs/demo/armi';
  Directory(_dir).createSync(recursive: true);

  final main = File('$_lib/death_scene.dart').readAsStringSync();
  final parts = [
    for (final m in RegExp(r"^part '([a-z_]+\.dart)';", multiLine: true).allMatches(main)) m.group(1)!,
  ];
  final sources = {
    'death_scene.dart': main,
    for (final part in parts) part: File('$_lib/$part').readAsStringSync(),
  };

  // Le enum pubbliche si prendono dalla libreria vera.
  final shared = <String>[];
  for (final name in sources.keys.toList()) {
    var text = sources[name]!;
    for (final m in RegExp(r'^enum ([A-Z]\w*)\b', multiLine: true).allMatches(text).toList().reversed) {
      shared.add(m.group(1)!);
      text = text.replaceRange(m.start, _blockEnd(text, m.start), '');
    }
    sources[name] = text;
  }

  var copy = sources['death_scene.dart']!
      .replaceAllMapped(RegExp(r"^import '\.\./\.\./", multiLine: true), (_) => "import 'package:oberta/")
      .replaceAllMapped(RegExp(r"^import '\.\./", multiLine: true), (_) => "import 'package:oberta/ui/")
      .replaceAllMapped(
        RegExp(r"^import '([a-z_]+\.dart)';", multiLine: true),
        (m) => "import 'package:oberta/ui/widgets/${m.group(1)}';",
      );
  copy = copy.replaceFirst(
    "import 'package:flutter/material.dart';",
    "import 'package:flutter/material.dart';\n"
        "import 'package:oberta/ui/widgets/death_scene.dart' show ${shared.join(', ')};\n"
        "import 'package:oberta/ui/widgets/weapons/noir_weapons.dart';",
  );
  copy = copy.replaceFirst("part '${parts.last}';", "part '${parts.last}';\npart 'armi_demo_patch.dart';");
  sources['death_scene.dart'] = copy;

  // Le armi vecchie restano, col nome cambiato: le nuove (in
  // armi_demo_patch.dart) le chiamano quando la prova vuole il confronto.
  for (final name in ['_drawPistol', '_drawTommyGun', '_drawLupara', '_drawSniperRifle', '_casings']) {
    _replaceOnce(sources, '  void $name(', '  void ${name}Old(');
  }
  _replaceOnce(
    sources,
    '  void _held(Canvas canvas, Offset hand, Offset along, double h, _Prop prop) {',
    '  void _held(Canvas canvas, Offset hand, Offset along, double h, _Prop prop) {\n'
        '    if (_armiHeld(canvas, hand, along, h, prop)) return;',
  );
  _replaceOnce(
    sources,
    '    return hand + along * (h * reach);',
    '    return _armiMuzzle(hand, along, h, weapon, reach);',
  );

  for (final MapEntry(key: name, value: text) in sources.entries) {
    File('$_dir/$name').writeAsStringSync(text);
  }
  File('$_dir/armi_demo_patch.dart').writeAsStringSync(_patch);
  File('$_dir/armi_demo_test.dart').writeAsStringSync(_test);

  final run = await Process.start(
    'flutter',
    ['test', '$_dir/armi_demo_test.dart'],
    environment: {'OUT': out},
    mode: ProcessStartMode.inheritStdio,
  );
  exit(await run.exitCode);
}

/// Dove finisce il blocco `{ ... }` che comincia dopo [from].
int _blockEnd(String text, int from) {
  var depth = 0;
  var i = text.indexOf('{', from);
  while (i < text.length) {
    final c = text[i];
    if (c == '/' && i + 1 < text.length && text[i + 1] == '/') {
      i = text.indexOf('\n', i);
      continue;
    }
    if (c == "'" || c == '"') {
      i = text.indexOf(c, i + 1) + 1;
      continue;
    }
    if (c == '{') depth++;
    if (c == '}' && --depth == 0) return i + 1;
    i++;
  }
  throw StateError('blocco senza fine');
}

void _replaceOnce(Map<String, String> sources, String from, String to) {
  final hits = [for (final e in sources.entries) if (e.value.contains(from)) e.key];
  final count = hits.fold(0, (n, name) => n + from.allMatches(sources[name]!).length);
  if (count != 1) {
    throw StateError('"$from" compare $count volte: i filmati sono cambiati, va rivista la prova');
  }
  sources[hits.single] = sources[hits.single]!.replaceFirst(from, to);
}

const _patch = r'''
part of 'death_scene.dart';

/// Come si colorano le armi nella prova, e se ci sono (false: le vecchie).
WeaponLook armiLook = WeaponLook.inked;
bool armiOn = true;

/// La pistola del killer, al posto di quella col silenziatore.
NoirWeapon armiHandgun = NoirWeapon.revolver;

NoirWeapon? _armiFor(_Prop prop) => !armiOn
    ? null
    : switch (prop) {
        _Prop.knife => NoirWeapon.stiletto,
        _Prop.pistol || _Prop.silenced => armiHandgun,
        _Prop.tommy => NoirWeapon.tommy,
        _Prop.lupara => NoirWeapon.lupara,
        _Prop.bat => NoirWeapon.bat,
        _ => null,
      };

/// Una figura dei filmati, in piedi in [feet] e alta [u], con [prop] (il nome
/// di una delle armi dei filmati) in mano. Torna dove sta la mano e verso
/// dove punta l'avambraccio, per metterci quello che il filmato non sa
/// tenere in mano.
(Offset, Offset) armiFigure(
  Canvas canvas,
  Size size, {
  required Offset feet,
  required double u,
  String prop = 'none',
  int facing = 1,
  double lean = 0,
  double arm = 0.08,
  double elbow = 0.2,
  double backArm = -0.1,
  double backElbow = 0.2,
  bool killer = true,
}) {
  final painter = DeathScenePainter(t: 0.2, act: DeathAct.gun);
  painter._frame(size);
  painter._u = u;
  painter._person(
    canvas,
    feet: feet,
    facing: facing,
    lean: lean,
    arm: arm,
    elbow: elbow,
    backArm: backArm,
    backElbow: backElbow,
    prop: _Prop.values.byName(prop),
    killer: killer,
  );
  return painter._handOf(
    feet: feet,
    facing: facing,
    lean: lean,
    arm: arm,
    elbow: elbow,
    killer: killer,
  );
}

extension _Armi on DeathScenePainter {
  NoirWeapons get _art => NoirWeapons(armiLook);

  bool _armiHeld(Canvas canvas, Offset hand, Offset along, double h, _Prop prop) {
    final weapon = _armiFor(prop);
    if (weapon == null) return false;
    _art.held(canvas, weapon, hand, along, NoirWeapons.perMetre(h));
    return true;
  }

  Offset _armiMuzzle(Offset hand, Offset along, double h, _Prop prop, double reach) {
    final weapon = _armiFor(prop);
    if (weapon == null) return hand + along * (h * reach);
    return NoirWeapons.muzzleOf(weapon, hand, along, NoirWeapons.perMetre(h));
  }

  void _drawPistol(Canvas canvas, Offset hand, Offset along, Offset across, double h, {bool suppressed = false}) {
    if (!armiOn) return _drawPistolOld(canvas, hand, along, across, h, suppressed: suppressed);
    _art.held(canvas, armiHandgun, hand, along, NoirWeapons.perMetre(h));
  }

  void _drawTommyGun(Canvas canvas, Offset hand, Offset along, Offset across, double h) {
    if (!armiOn) return _drawTommyGunOld(canvas, hand, along, across, h);
    _art.held(canvas, NoirWeapon.tommy, hand, along, NoirWeapons.perMetre(h));
  }

  void _drawLupara(Canvas canvas, Offset hand, Offset along, Offset across, double h) {
    if (!armiOn) return _drawLuparaOld(canvas, hand, along, across, h);
    _art.held(canvas, NoirWeapon.lupara, hand, along, NoirWeapons.perMetre(h));
  }

  /// Il fucile alla finestra: il castello sul davanzale ([muzzle]) e la canna
  /// verso la strada, in scala vera al primo piano (lì il vecchio valeva
  /// h = 0,72 u, e più lontano meno).
  void _drawSniperRifle(Canvas canvas, Offset muzzle, double h) {
    if (!armiOn) return _drawSniperRifleOld(canvas, muzzle, h);
    final perMetre = NoirWeapons.perMetre(_u) * h / (_u * 0.72);
    canvas.save();
    canvas.translate(muzzle.dx, muzzle.dy);
    canvas.scale(-1, 1);
    _art.held(canvas, NoirWeapon.sniper, Offset(-0.20 * perMetre, 0), const Offset(1, 0), perMetre, fist: false);
    canvas.restore();
  }

  /// Il revolver i bossoli se li tiene nel tamburo.
  void _casings(Canvas canvas, Offset from, List<double> shots, {double side = 1, double floor = 0}) {
    final revolver = armiHandgun == NoirWeapon.revolver || armiHandgun == NoirWeapon.snubNose;
    if (armiOn && revolver && act != DeathAct.burst && act != DeathAct.driveBy) return;
    _casingsOld(canvas, from, shots, side: side, floor: floor);
  }
}
''';

const _test = r'''
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/ui/widgets/death_scene.dart' show DeathAct;

import '../../tool/render/armi_demo_sheet.dart';
import 'death_scene.dart';

void main() {
  testWidgets('armi nuove: tavole e fotogrammi', (tester) async {
    await armiDemo(
      tester,
      figure: (canvas, size, {required feet, required u, prop = 'none', facing = 1, lean = 0, arm = 0.08, elbow = 0.2, backArm = -0.1, backElbow = 0.2}) => armiFigure(
        canvas,
        size,
        feet: feet,
        u: u,
        prop: prop,
        facing: facing,
        lean: lean,
        arm: arm,
        elbow: elbow,
        backArm: backArm,
        backElbow: backElbow,
      ),
      film: (t, act, sprites) => DeathScenePainter(t: t, act: DeathAct.values.byName(act), sprites: sprites),
      setup: ({required look, required on, required handgun}) {
        armiLook = look;
        armiOn = on;
        armiHandgun = handgun;
      },
    );
  });
}
''';
