import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Quanta corrente arriva a ogni lettera dell'insegna, da 0 (spenta) a 1.
/// Avvisa solo quando qualcosa cambia davvero: l'insegna resta ferma quasi
/// sempre, e non c'è motivo di ridisegnarla a ogni fotogramma.
class HomeNeonState extends ChangeNotifier {
  List<double> _power = List.filled(HomeNeonSign.letters, 0);

  List<double> get power => _power;

  /// La M fantasma dietro la B: si accende solo quando la B muore.
  double _ghost = 0;
  double get ghost => _ghost;

  /// La luce che manda la lettera [index], contando anche la M fantasma.
  double light(int index) => index == HomeNeonSign.ghostLetter ? max(_power[index], _ghost) : _power[index];

  /// La luce che l'insegna butta intorno, in media.
  double get glow => [for (var i = 0; i < _power.length; i++) light(i)].reduce((a, b) => a + b) / _power.length;

  void set(List<double> next, {double ghost = 0}) {
    if (listEquals(next, _power) && ghost == _ghost) return;
    _power = next;
    _ghost = ghost;
    notifyListeners();
  }
}

/// Le lettere dell'insegna, piegate a mano come tubi di vetro: non dipendono
/// da nessun font, quindi sono identiche su ogni telefono.
class HomeNeonSign {
  static const letters = 6;

  /// Spazio sopra le maiuscole, per l'accento della À.
  static const headroom = 0.30;

  static const _gap = 0.17;
  static const _widths = [0.62, 0.58, 0.50, 0.58, 0.60, 0.72];

  /// Larghezza e altezza dell'insegna, in altezze di lettera.
  static const width = 3.60 + _gap * (letters - 1);
  static const height = 1 + headroom;

  static double widthOf(int index) => _widths[index];

  /// La lettera che ha un errore sotto: la B di OBERTÀ nasconde la M di
  /// OMERTÀ. Quando la B si fulmina, per un attimo l'insegna prova a
  /// correggersi in OMERTÀ, ma non ce la fa mai: torna sempre OBERTÀ.
  static const ghostLetter = 1;

  /// I tubi della M fantasma, nello stesso spazio della B.
  static Path ghostTubes(double cap) {
    final w = _widths[ghostLetter];
    return Path()
      ..moveTo(0, cap)
      ..lineTo(0, 0)
      ..lineTo(w / 2 * cap, 0.58 * cap)
      ..lineTo(w * cap, 0)
      ..lineTo(w * cap, cap);
  }

  // La M che prova ad accendersi: scatti, buchi, mai ferma.
  static const _ghostBuzz = [0.9, 1.0, 0.0, 0.8, 1.0, 1.0, 0.15, 0.0, 1.0, 0.6, 1.0, 0.0, 0.0, 0.7];

  /// Quanto è accesa la M fantasma: solo mentre la B è spenta (nei suoi
  /// guasti, o quando qualcuno tocca l'insegna e salta la corrente).
  static double ghostAt(double seconds, double intro, {double jolt = 1}) {
    if (intro < 0.9 + ghostLetter * 0.15 + _strike.length / _rate) return 0;
    if (jolt < 0.3) return 0.85;
    for (final (letter, start, dark) in _faults) {
      if (letter != ghostLetter) continue;
      final local = seconds - start;
      final buzz = _pattern(_buzz, local);
      if (!buzz.isNaN) return buzz < 0.3 ? 0.9 : 0;
      final after = local - _buzz.length / _rate;
      if (after >= 0 && after < dark) return _ghostBuzz[(after * _rate).floor() % _ghostBuzz.length];
    }
    return 0;
  }

  /// Dove comincia la lettera [index], in altezze di lettera.
  static double leftOf(int index) {
    var x = 0.0;
    for (var i = 0; i < index; i++) {
      x += _widths[i] + _gap;
    }
    return x;
  }

  /// I tubi della lettera [index], alta [cap], con l'angolo in alto a
  /// sinistra delle maiuscole nell'origine.
  static Path tubes(int index, double cap) {
    final path = Path();
    void line(List<(double, double)> points) {
      path.moveTo(points.first.$1 * cap, points.first.$2 * cap);
      for (final (x, y) in points.skip(1)) {
        path.lineTo(x * cap, y * cap);
      }
    }

    switch (index) {
      case 0: // O
        path.addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, 0.62 * cap, cap),
          Radius.circular(0.31 * cap),
        ));
      case 1: // B: due pance, quella sotto un filo più larga.
        path
          ..moveTo(0, cap)
          ..lineTo(0, 0)
          ..lineTo(0.30 * cap, 0)
          ..arcToPoint(Offset(0.30 * cap, 0.48 * cap), radius: Radius.circular(0.24 * cap))
          ..lineTo(0, 0.48 * cap)
          ..moveTo(0.30 * cap, 0.48 * cap)
          ..lineTo(0.32 * cap, 0.48 * cap)
          ..arcToPoint(Offset(0.32 * cap, cap), radius: Radius.circular(0.26 * cap))
          ..lineTo(0, cap);
      case 2: // E
        line([(0.50, 0), (0, 0), (0, 1), (0.50, 1)]);
        line([(0, 0.5), (0.40, 0.5)]);
      case 3: // R
        path
          ..moveTo(0, cap)
          ..lineTo(0, 0)
          ..lineTo(0.32 * cap, 0)
          ..arcToPoint(Offset(0.32 * cap, 0.52 * cap), radius: Radius.circular(0.26 * cap))
          ..lineTo(0, 0.52 * cap);
        line([(0.27, 0.52), (0.58, 1)]);
      case 4: // T
        line([(0, 0), (0.60, 0)]);
        line([(0.30, 0), (0.30, 1)]);
      case 5: // À
        line([(0, 1), (0.36, 0), (0.72, 1)]);
        line([(0.15, 0.66), (0.57, 0.66)]);
        line([(0.17, -0.30), (0.36, -0.13)]);
    }
    return path;
  }

  // Un tubo che fa i capricci: acceso, spento, a metà. Sedici passi al secondo.
  static const _buzz = [1.0, 0.15, 1.0, 0.5, 0.0, 0.0, 1.0, 0.2, 1.0, 1.0, 0.4, 1.0];
  static const _strike = [0.5, 0.0, 1.0, 0.25, 1.0];
  static const _rate = 16.0;

  /// I guasti del giro: lettera, secondo in cui comincia a sfarfallare, e
  /// per quanti secondi poi resta al buio prima di riaccendersi.
  ///
  /// Il tubo difettoso è la B: quando muore l'insegna dice «O ERTÀ», e il
  /// buco è proprio la lettera che nessuno vuole pronunciare.
  static const _faults = [
    (1, 3.0, 0.9),
    (1, 7.0, 0.0),
    (1, 11.5, 1.2),
    (1, 16.4, 1.6),
    (1, 21.0, 0.8),
    (5, 24.5, 0.0),
    (1, 29.0, 1.0),
    (1, 35.5, 0.0),
    (1, 38.5, 1.1),
    (1, 41.2, 2.2),
    (3, 46.0, 0.0),
    (1, 49.5, 0.9),
    (1, 55.5, 1.3),
  ];

  /// Il calo di tensione che una volta a giro prende tutta l'insegna.
  static const _dipAt = 34.0;
  static const _dip = [0.55, 1.0, 0.3, 1.0, 0.7];

  static double _pattern(List<double> steps, double local) =>
      local < 0 ? double.nan : (local * _rate < steps.length ? steps[(local * _rate).floor()] : double.nan);

  /// La corrente di ogni lettera: [seconds] è il tempo del giro d'ambiente
  /// (60 secondi), [intro] i secondi passati dall'apertura della schermata,
  /// quando le lettere si accendono una dopo l'altra.
  static List<double> powerAt(double seconds, double intro) {
    final dip = _pattern(_dip, seconds - _dipAt);
    return [
      for (var i = 0; i < letters; i++) _letter(i, seconds, intro) * (dip.isNaN ? 1 : dip),
    ];
  }

  /// Il corto circuito di quando qualcuno tocca l'insegna: [progress] va da
  /// 0 a 1, e tutte le lettere saltano insieme.
  static double shortAt(double progress) {
    const jolt = [0.2, 1.0, 0.0, 0.0, 0.7, 0.0, 0.35, 1.0, 0.5, 1.0];
    return jolt[(progress * jolt.length).floor().clamp(0, jolt.length - 1)];
  }

  static double _letter(int index, double seconds, double intro) {
    final sinceStrike = intro - (0.9 + index * 0.15);
    if (sinceStrike < 0) return 0;
    final strike = _pattern(_strike, sinceStrike);
    if (!strike.isNaN) return strike;

    for (final (letter, start, dark) in _faults) {
      if (letter != index) continue;
      final local = seconds - start;
      final buzz = _pattern(_buzz, local);
      if (!buzz.isNaN) return buzz;
      final after = local - _buzz.length / _rate;
      if (after >= 0 && after < dark) return 0;
      final again = _pattern(_strike, after - dark);
      if (dark > 0 && !again.isNaN) return again;
    }
    return 1;
  }
}

/// L'insegna al neon sul muro: il telaio, i tubi, l'alone rosso sui mattoni.
/// Quando una lettera va in corto si spegne anche la sua parte di muro.
class HomeNeonPainter extends CustomPainter {
  /// Il riquadro delle lettere, accento compreso, e l'altezza delle maiuscole.
  final Rect sign;
  final double cap;
  final HomeNeonState state;

  HomeNeonPainter({required this.sign, required this.cap, required this.state}) : super(repaint: state);

  static const _glass = Color(0xFF331719);
  static const _red = Color(0xFFFF2E24);
  static const _hot = Color(0xFFFF5A44);
  static const _core = Color(0xFFFFE9D2);
  static const _iron = Color(0xFF08080B);

  @override
  void paint(Canvas canvas, Size size) {
    final top = sign.top + HomeNeonSign.headroom * cap;
    final power = state.power;

    Offset origin(int i) => Offset(sign.left + HomeNeonSign.leftOf(i) * cap, top);
    Offset middle(int i) => origin(i) + Offset(HomeNeonSign.widthOf(i) * cap / 2, cap / 2);

    // I mattoni sono dipinti già illuminati: dove un tubo è spento ci va
    // sopra il buio.
    for (var i = 0; i < HomeNeonSign.letters; i++) {
      final dark = 1 - state.light(i);
      if (dark < 0.02) continue;
      final bounds = Rect.fromCircle(center: middle(i), radius: cap * 2.5);
      canvas.drawRect(
        bounds,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFF05060B).withValues(alpha: 0.84 * dark),
              const Color(0xFF05060B).withValues(alpha: 0.62 * dark),
              const Color(0x0005060B),
            ],
            stops: const [0, 0.5, 1],
          ).createShader(bounds),
      );
    }

    _frame(canvas, sign, top, cap);

    // L'alone: una nebbia rossa larga, più forte dietro le lettere accese.
    for (var i = 0; i < HomeNeonSign.letters; i++) {
      final light = state.light(i);
      if (light < 0.02) continue;
      final bounds = Rect.fromCircle(center: middle(i), radius: cap * 1.25);
      canvas.drawRect(
        bounds,
        Paint()
          ..shader = RadialGradient(
            colors: [_red.withValues(alpha: 0.20 * light), _red.withValues(alpha: 0)],
          ).createShader(bounds),
      );
    }

    final tube = cap * 0.095;
    Paint stroke(double width, Color color) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    // Le lettere con la stessa corrente si disegnano insieme: di solito è
    // un'unica sfumatura per tutta l'insegna.
    final groups = <double, Path>{};
    for (var i = 0; i < HomeNeonSign.letters; i++) {
      final path = HomeNeonSign.tubes(i, cap).shift(origin(i));
      canvas.drawPath(path, stroke(tube * 1.5, Colors.black.withValues(alpha: 0.55)));
      canvas.drawPath(path, stroke(tube, _glass));
      if (power[i] > 0.02) (groups[power[i]] ??= Path()).addPath(path, Offset.zero);
    }
    // La M fantasma: il suo vetro si vede solo quando prende corrente.
    final ghost = state.ghost;
    if (ghost > 0.02) {
      final path = HomeNeonSign.ghostTubes(cap).shift(origin(HomeNeonSign.ghostLetter));
      (groups[ghost] ??= Path()).addPath(path, Offset.zero);
    }
    for (final MapEntry(key: p, value: path) in groups.entries) {
      canvas.drawPath(
        path,
        stroke(tube * 3.2, _red.withValues(alpha: 0.62 * p))..maskFilter = MaskFilter.blur(BlurStyle.normal, cap * 0.11),
      );
      canvas.drawPath(path, stroke(tube, Color.lerp(_glass, _hot, p)!));
      canvas.drawPath(path, stroke(tube * 0.42, _core.withValues(alpha: min(1, p * 1.1))));
    }
  }

  /// Il telaio di ferro che regge i tubi, le staffe nel muro e il cavo che
  /// scende dal trasformatore.
  void _frame(Canvas canvas, Rect sign, double top, double cap) {
    final iron = Paint()..color = _iron;
    final edge = Paint()..color = Colors.white.withValues(alpha: 0.07);
    final left = sign.left - cap * 0.16;
    final right = sign.right + cap * 0.16;
    for (final y in [top + cap * 0.20, top + cap * 0.82]) {
      final rail = Rect.fromLTRB(left, y - cap * 0.022, right, y + cap * 0.022);
      canvas.drawRect(rail.shift(Offset(0, cap * 0.05)), Paint()..color = Colors.black.withValues(alpha: 0.35));
      canvas.drawRect(rail, iron);
      canvas.drawRect(Rect.fromLTWH(rail.left, rail.top, rail.width, 1), edge);
    }
    for (final x in [left, right]) {
      final post = Rect.fromLTRB(x - cap * 0.03, top + cap * 0.10, x + cap * 0.03, top + cap * 0.92);
      canvas.drawRect(post, iron);
      for (final y in [post.top, post.bottom]) {
        canvas.drawCircle(Offset(x, y), cap * 0.045, iron);
        canvas.drawCircle(Offset(x - cap * 0.01, y - cap * 0.01), cap * 0.014, edge);
      }
    }
    final box = Rect.fromLTWH(left - cap * 0.10, top + cap * 0.92, cap * 0.20, cap * 0.16);
    canvas.drawRRect(RRect.fromRectAndRadius(box, Radius.circular(cap * 0.02)), iron);
    canvas.drawPath(
      Path()
        ..moveTo(box.center.dx, box.bottom)
        ..quadraticBezierTo(box.center.dx - cap * 0.06, box.bottom + cap * 0.55, -cap * 0.1, box.bottom + cap * 0.42),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.2, cap * 0.022)
        ..color = _iron,
    );
  }

  @override
  bool shouldRepaint(HomeNeonPainter old) => old.sign != sign || old.cap != cap || old.state != state;
}
