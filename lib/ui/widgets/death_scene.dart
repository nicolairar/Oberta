import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_strings.dart';
import '../../narration/death_story.dart';
import '../../sound/scene_cues.dart';
import '../../sound/sound_stage.dart';
import '../theme/app_theme.dart';
import 'city_backdrop.dart';
import 'face_close_up.dart';
import 'noir_avatar.dart';
import 'victim_card.dart';
import '../press.dart';

/// Le coreografie disponibili per quello che succede di notte.
enum DeathAct {
  knife,
  gun,
  burst,
  car,
  piano,
  safe,
  chandelier,
  blast,
  poison,
  noose,
  grab,
  bat,
  lupara,
  driveBy,
  garrote,
  pot,
  manhole,
  blackout,
  kiss,

  /// Il colpo del Cecchino: da lontano, senza nessuno dietro l'angolo.
  sniper,

  /// Un agguato andato a vuoto: il Dottore arriva in tempo.
  rescue,

  /// Un agguato andato a vuoto: il colpo si ferma su qualcosa.
  lucky;

  /// Le scene da cui chi era stato preso di mira esce sulle sue gambe.
  bool get survives => this == rescue || this == lucky;
}

/// La coreografia che mette in scena un'azione del copione. Un'azione senza
/// coreografia sua ripiega sul classico: il pugnale da dietro l'angolo.
DeathAct deathActFor(String methodId) => switch (methodId) {
      'pugnale' => DeathAct.knife,
      'silenziatore' => DeathAct.gun,
      'violino' => DeathAct.burst,
      'auto' => DeathAct.car,
      'pianoforte' => DeathAct.piano,
      'cassaforte' => DeathAct.safe,
      'lampadario' => DeathAct.chandelier,
      'pacco' || 'sigaro' => DeathAct.blast,
      'veleno' => DeathAct.poison,
      'cappio' => DeathAct.noose,
      'cemento' => DeathAct.grab,
      'mazza' => DeathAct.bat,
      'lupara' => DeathAct.lupara,
      'raffica' => DeathAct.driveBy,
      'garrota' => DeathAct.garrote,
      'vaso' => DeathAct.pot,
      'tombino' => DeathAct.manhole,
      'buio' => DeathAct.blackout,
      'bacio' => DeathAct.kiss,
      DeathStory.sniperId => DeathAct.sniper,
      DeathStory.rescueId => DeathAct.rescue,
      DeathStory.luckyId => DeathAct.lucky,
      _ => DeathAct.knife,
    };

const _knots = [(0.0, 0.0), (0.23, 0.34), (0.465, 0.50), (0.70, 0.66), (0.90, 0.86), (1.0, 1.0)];

double _warp(double value, {required bool toFilm}) {
  for (var i = 1; i < _knots.length; i++) {
    final (x0, t0) = _knots[i - 1];
    final (x1, t1) = _knots[i];
    final (a0, a1, b0, b1) = toFilm ? (x0, x1, t0, t1) : (t0, t1, x0, x1);
    if (value <= a1) return b0 + (b1 - b0) * (value - a0) / (a1 - a0);
  }
  return 1;
}

/// Il tempo del film non scorre uniforme: l'ingresso corre, l'attesa e il
/// colpo vanno al rallentatore, il finale si prende il suo tempo. Dato il
/// tempo vero [x], da 0 a 1, dice a che punto è la scena.
double filmTime(double x) => _warp(x, toFilm: true);

/// L'inverso di [filmTime]: in che momento, nel tempo vero, la scena arriva
/// a [t]. Serve a chi deve far cadere un suono esattamente su un fotogramma.
double filmClock(double t) => _warp(t, toFilm: false);

/// Dove deve saltare il film per tornare a tempo col nastro, o `null` se va
/// bene così. Uno scarto di qualche centesimo non si nota e non vale un
/// salto; uno scarto grande non è un ritardo del nastro ma il lettore che
/// parla ancora del nastro di prima, e lì è meglio restare dove si è.
Duration? resyncTarget({required Duration heard, required Duration film}) {
  final drift = (heard - film).abs();
  if (drift <= const Duration(milliseconds: 40) || drift >= const Duration(milliseconds: 800)) return null;
  if (heard >= DeathScene.length) return null;
  return heard;
}

/// Quello che è successo di notte, da guardare tutti insieme col telefono sul
/// tavolo: una strada, qualcuno che arriva, e qualcuno dietro l'angolo. Si
/// chiude sul ritratto di chi non vedrà l'alba (o di chi, stavolta, la vedrà)
/// e lì resta, finché il tavolo non decide di andare avanti.
class DeathScene extends StatefulWidget {
  /// Quanto dura il film, dal buio in sala al ritratto finale.
  static const length = Duration(seconds: 14);

  final DeathAct act;
  final String victimName;

  /// La didascalia sotto la scena, come il cartello di un film muto.
  final String caption;

  /// Il dettaglio finale del copione (`gatto`, `sirene`, `sipario`...): le
  /// scene che sanno mostrarlo lo mostrano.
  final String epilogue;
  final SkylineStyle style;
  final VoidCallback onFinished;

  const DeathScene({
    super.key,
    required this.act,
    required this.victimName,
    required this.caption,
    required this.onFinished,
    this.epilogue = '',
    this.style = SkylineStyle.metropolis,
  });

  @override
  State<DeathScene> createState() => _DeathSceneState();
}

class _DeathSceneState extends State<DeathScene> with SingleTickerProviderStateMixin {
  late final AnimationController _film;
  late final List<SceneCue> _cues = sceneCuesFor(widget.act, memes: SoundStage.instance.memeMode);
  int _nextCue = 0;
  final List<Timer> _tuning = [];
  bool _struck = false;
  bool _ended = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    // Chi riduce le animazioni vede fermo il fondale, ma non questa scena: è
    // il racconto della notte, e accorciarla la renderebbe illeggibile.
    _film = AnimationController(
      vsync: this,
      duration: DeathScene.length,
      animationBehavior: AnimationBehavior.preserve,
    )
      ..addListener(() {
        final t = filmTime(_film.value);
        if (!_struck && t >= DeathScenePainter.strike) {
          _struck = true;
          HapticFeedback.heavyImpact();
        }
        while (_nextCue < _cues.length && t >= _cues[_nextCue].t) {
          SoundStage.instance.sceneCue(_cues[_nextCue++]);
        }
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) setState(() => _ended = true);
      });

    // Il film parte quando parte la musica. Il palco muto risponde subito;
    // quello vero ci mette un attimo, e la scena lo aspetta (ma non per
    // sempre: senza audio si va in onda lo stesso).
    SoundStage.instance.duckMusic(true);
    final music = SoundStage.instance.playScene(widget.act);
    if (music is Future<void>) {
      music.timeout(const Duration(seconds: 4), onTimeout: () {}).whenComplete(() {
        if (!mounted || _ended) return;
        _film.forward();
        for (final after in const [300, 1000, 2400]) {
          _tuning.add(Timer(Duration(milliseconds: after), _tune));
        }
      });
    } else {
      _film.forward();
    }
  }

  /// Il momento in cui la vittima si accorge di qualcosa, e la cinepresa le
  /// va addosso: chi guarda in alto lo fa più tardi, gli altri quando si
  /// girano sotto il lampione.
  double get _closeUpAt => switch (widget.act) {
        DeathAct.car || DeathAct.piano || DeathAct.safe || DeathAct.chandelier => 0.465,
        DeathAct.pot || DeathAct.manhole || DeathAct.sniper || DeathAct.driveBy => 0.465,
        _ => 0.39,
      };

  /// Rimette il film a tempo col nastro. Lo fa presto, mentre la vittima sta
  /// ancora camminando: lì un fotogramma saltato non lo nota nessuno, mentre
  /// uno sparo fuori tempo lo notano tutti.
  Future<void> _tune() async {
    final heard = await SoundStage.instance.position();
    if (heard == null || !mounted || !_film.isAnimating) return;
    final target = resyncTarget(heard: heard, film: DeathScene.length * _film.value);
    if (target != null) _film.forward(from: target.inMicroseconds / DeathScene.length.inMicroseconds);
  }

  /// Chi salta la scena arriva comunque al ritratto finale: il nome si legge
  /// sempre, e avanti si va solo col pulsante.
  void _skip() {
    _struck = true;
    _nextCue = _cues.length;
    _film.value = 1;
    SoundStage.instance.stop();
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onFinished();
  }

  @override
  void dispose() {
    for (final timer in _tuning) {
      timer.cancel();
    }
    SoundStage.instance.duckMusic(false);
    SoundStage.instance.stop();
    _film.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hat = avatarHeadFor(widget.victimName);
    final survives = widget.act.survives;
    return Stack(
      fit: StackFit.expand,
      children: [
        CityBackdrop(style: widget.style, rain: true, child: const SizedBox.expand()),
        AnimatedBuilder(
          animation: _film,
          builder: (context, _) => CustomPaint(
            painter: DeathScenePainter(
              t: filmTime(_film.value),
              act: widget.act,
              victimHat: hat,
              epilogue: widget.epilogue,
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _film,
          builder: (context, _) {
            final t = filmTime(_film.value);
            final typed = (widget.caption.length * _span(_film.value, 0.02, 0.20)).round();
            final card = _span(t, 0.86, 0.93);
            // Chi si salva resta anonimo: niente primo piano.
            final closeUp = survives ? 0.0 : _span(t, _closeUpAt, _closeUpAt + 0.09);
            return Stack(
              fit: StackFit.expand,
              children: [
                Align(
                  alignment: const Alignment(-0.55, -0.48),
                  child: FaceCloseUp(name: widget.victimName, life: closeUp),
                ),
                Align(
                  alignment: const Alignment(0, 0.93),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Opacity(
                      opacity: 1 - _span(t, 0.80, 0.86),
                      child: Text(
                        widget.caption.substring(0, typed),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Courier',
                          fontFamilyFallback: ['monospace'],
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                ),
                if (card > 0)
                  Opacity(
                    opacity: card,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        VictimCard(name: widget.victimName, survives: survives, reveal: card),
                        const SizedBox(height: 22),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              widget.victimName.toUpperCase(),
                              style: AppText.display(44, color: AppColors.textPrimary),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          survives ? AppStrings.of(context).willSeeDawn : AppStrings.of(context).wontSeeDawn,
                          style: survives ? AppText.overline.copyWith(color: AppColors.gold) : AppText.overline,
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        SafeArea(
          child: _ended
              ? Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(onPressed: pressed(_finish, Press.confirm), child: Text(AppStrings.of(context).next)),
                    ),
                  ),
                )
              : Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: pressed(_skip, Press.back),
                    child: Text(AppStrings.of(context).skip, style: const TextStyle(color: AppColors.textSecondary)),
                  ),
                ),
        ),
      ],
    );
  }
}

double _span(double t, double from, double to) => ((t - from) / (to - from)).clamp(0.0, 1.0);

double _mix(double a, double b, double t) => a + (b - a) * t;

double _smooth(double t) => Curves.easeInOut.transform(t);

/// Direzione di un arto: 0 punta in basso, pi/2 in avanti, pi in alto.
Offset _aim(double angle) => Offset(sin(angle), cos(angle));

enum _Prop { none, knife, pistol, tommy, cup, box, bat, lupara, bag, flask }

/// Disegna un fotogramma della scena. [t] va da 0 a 1 lungo tutto il film.
///
/// Il canovaccio è lo stesso per ogni coreografia: la vittima entra da
/// sinistra e si ferma sotto il lampione, la cinepresa stringe, qualcosa
/// succede a [strike], poi restano gli oggetti di scena e lo schermo vira al
/// rosso.
class DeathScenePainter extends CustomPainter {
  final double t;
  final DeathAct act;
  final AvatarHead victimHat;

  /// Il dettaglio finale del copione, per le scene che sanno mostrarlo.
  final String epilogue;

  DeathScenePainter({
    required this.t,
    required this.act,
    this.victimHat = AvatarHead.fedora,
    this.epilogue = '',
  });

  /// Il momento del colpo, uguale per tutte le coreografie.
  static const strike = 0.56;

  static const _ink = Color(0xFF050506);
  static const _rim = Color(0xFF6A5632);
  static const _blood = Color(0xFFB3202A);
  static const _steel = Color(0xFFD5DAE0);
  static const _gunmetal = Color(0xFF3B4048);
  static const _warm = Color(0xFFFFD27A);

  late double _w;
  late double _h;
  late double _ground;
  late double _u;
  late double _victimX;
  late double _cornerX;

  double get _hiddenX => _cornerX + _u * 0.75;
  double get _peekX => _cornerX + _u * 0.17;

  bool get _hasWall => act != DeathAct.car;

  bool get _shakes => switch (act) {
        DeathAct.car || DeathAct.piano || DeathAct.safe || DeathAct.chandelier || DeathAct.blast => true,
        DeathAct.bat || DeathAct.lupara || DeathAct.pot => true,
        _ => false,
      };

  /// Le coreografie in cui la vittima finisce stesa verso sinistra: la
  /// cinepresa, dopo il colpo, si sposta per tenerla tutta in campo.
  bool get _fallsLeft => switch (act) {
        DeathAct.knife || DeathAct.gun || DeathAct.burst || DeathAct.poison => true,
        DeathAct.bat || DeathAct.lupara || DeathAct.driveBy || DeathAct.garrote => true,
        DeathAct.pot || DeathAct.blackout || DeathAct.kiss => true,
        DeathAct.sniper || DeathAct.rescue => true,
        _ => false,
      };

  /// Le coreografie in cui il pericolo arriva da dietro l'angolo: la
  /// cinepresa, stringendo, lo tiene d'occhio.
  bool get _fromCorner => switch (act) {
        DeathAct.car || DeathAct.driveBy || DeathAct.noose || DeathAct.pot || DeathAct.manhole => false,
        _ => true,
      };

  /// Quanta luce fa il lampione: nel buio improvviso salta, e la raffica
  /// dall'auto in corsa se lo porta via.
  double get _lampPower {
    if (act == DeathAct.driveBy) return t < 0.63 ? 1 : 0;
    if (act != DeathAct.blackout) return 1;
    const dying = [1.0, 0.35, 1.0, 0.25, 0.7, 0.0];
    const waking = [0.0, 0.5, 0.2, 1.0];
    if (t < 0.44) return 1;
    if (t < 0.50) return dying[min(5, (_span(t, 0.44, 0.50) * 6).floor())];
    if (t < 0.655) return 0;
    if (t < 0.70) return waking[min(3, (_span(t, 0.655, 0.70) * 4).floor())];
    return 1;
  }

  @override
  void paint(Canvas canvas, Size size) {
    _w = size.width;
    _h = size.height;
    _ground = _h * 0.76;
    // Lo schermo è stretto: le figure si misurano sulla larghezza, così chi
    // cade a terra resta dentro l'inquadratura.
    _u = min(_h * 0.30, _w * 0.50);
    _victimX = _w * 0.50;
    _cornerX = _w * 0.84;

    canvas.save();
    _camera(canvas);
    final quake = _span(t, strike, strike + 0.10);
    if (_shakes && quake > 0 && quake < 1) {
      final force = (1 - quake) * _u * 0.06;
      canvas.translate(sin(t * 900) * force, cos(t * 760) * force);
    }
    _street(canvas);
    switch (act) {
      case DeathAct.knife:
        _knife(canvas);
      case DeathAct.gun:
        _shooting(canvas, const [strike], _Prop.pistol);
      case DeathAct.burst:
        _shooting(canvas, const [0.55, 0.575, 0.60, 0.625, 0.65], _Prop.tommy);
      case DeathAct.car:
        _car(canvas);
      case DeathAct.piano || DeathAct.safe || DeathAct.chandelier:
        _fallingObject(canvas);
      case DeathAct.blast:
        _blast(canvas);
      case DeathAct.poison:
        _poison(canvas);
      case DeathAct.noose:
        _noose(canvas);
      case DeathAct.grab:
        _grab(canvas);
      case DeathAct.bat:
        _bat(canvas);
      case DeathAct.lupara:
        _lupara(canvas);
      case DeathAct.driveBy:
        _driveBy(canvas);
      case DeathAct.garrote:
        _garrote(canvas);
      case DeathAct.pot:
        _pot(canvas);
      case DeathAct.manhole:
        _manhole(canvas);
      case DeathAct.blackout:
        _blackout(canvas);
      case DeathAct.kiss:
        _kiss(canvas);
      case DeathAct.sniper:
        _sniper(canvas);
      case DeathAct.rescue:
        _rescue(canvas);
      case DeathAct.lucky:
        _lucky(canvas);
    }
    if (!act.survives) _aftermath(canvas);
    _sfx(canvas);
    canvas.restore();

    // Il finale: chi muore chiude sul rosso (o sul sipario, se il copione lo
    // chiama), chi si salva su un nero che lascia leggere il nome.
    final rect = Offset.zero & size;
    final close = _span(t, 0.82, 0.92);
    if (close > 0) {
      if (act.survives) {
        canvas.drawRect(rect, Paint()..color = Colors.black.withValues(alpha: close * 0.80));
      } else if (epilogue == 'sipario') {
        _curtain(canvas, close);
      } else {
        canvas.drawRect(
          rect,
          Paint()..color = Color.lerp(_blood, Colors.black, 0.55)!.withValues(alpha: close * 0.86),
        );
      }
    }
    // Le bande nere del cinema.
    final bar = _h * 0.105 * Curves.easeOut.transform(_span(t, 0, 0.05));
    final black = Paint()..color = Colors.black;
    canvas.drawRect(Rect.fromLTWH(0, 0, _w, bar), black);
    canvas.drawRect(Rect.fromLTWH(0, _h - bar * 1.5, _w, bar * 1.5), black);
  }

  /// La cinepresa: parte larga, stringe piano mentre cresce la tensione, e
  /// dopo il colpo si sistema su quello che resta.
  void _camera(Canvas canvas) {
    if (act == DeathAct.car || act == DeathAct.driveBy) return;
    final push = _smooth(_span(t, 0.30, 0.54));
    // Quando arriva il Dottore la cinepresa si allarga prima, e di più: deve
    // starci anche lui.
    final rescue = act == DeathAct.rescue;
    final settle = _smooth(_span(t, strike + (rescue ? 0.04 : 0.10), strike + (rescue ? 0.14 : 0.28)));
    final zoom = 1 + 0.22 * push - (rescue ? 0.17 : 0.08) * settle;
    var focus = _mix(_w / 2, _mix(_victimX, _cornerX, _fromCorner ? 0.28 : 0.0), push);
    focus = _mix(focus, _victimX - (_fallsLeft ? _u * (rescue ? 0.50 : 0.34) : 0), settle);
    final horizon = _ground - _u * 0.45;
    canvas.translate(_w / 2, horizon);
    canvas.scale(zoom);
    canvas.translate(-focus, -horizon);
  }

  // ---------------------------------------------------------------- scenografia

  void _street(Canvas canvas) {
    final lampX = _w * 0.26;
    final lampTop = _ground - _u * 1.42;
    final head = Offset(lampX + _u * 0.24, lampTop + _u * 0.04);

    canvas.drawRect(
      Rect.fromLTRB(-_w, _ground, _w * 2, _h * 1.3),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF101117), Color(0xFF030304)],
        ).createShader(Rect.fromLTRB(0, _ground, _w, _h)),
    );
    // Il bordo del marciapiede.
    canvas.drawRect(
      Rect.fromLTRB(-_w, _ground, _w * 2, _ground + _u * 0.022),
      Paint()..color = const Color(0xFF23242C),
    );

    // Il cono di luce del lampione, e la pozza di luce sull'asfalto bagnato.
    final flicker = (0.92 + 0.08 * sin(t * 140)) * _lampPower;
    canvas.drawPath(
      Path()
        ..moveTo(head.dx - _u * 0.05, head.dy)
        ..lineTo(head.dx + _u * 0.05, head.dy)
        ..lineTo(head.dx + _u * 1.25, _ground)
        ..lineTo(head.dx - _u * 0.80, _ground)
        ..close(),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_warm.withValues(alpha: 0.30 * flicker), _warm.withValues(alpha: 0.03)],
        ).createShader(Rect.fromLTRB(0, head.dy, _w, _ground)),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(head.dx + _u * 0.22, _ground + _u * 0.06), width: _u * 2.3, height: _u * 0.20),
      Paint()
        ..color = _warm.withValues(alpha: 0.16 * flicker)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, _u * 0.06),
    );

    final iron = Paint()
      ..color = _ink
      ..strokeWidth = _u * 0.04
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(lampX, _ground), Offset(lampX, lampTop), iron);
    canvas.drawPath(
      Path()
        ..moveTo(lampX, lampTop)
        ..quadraticBezierTo(lampX + _u * 0.02, lampTop - _u * 0.11, head.dx, head.dy - _u * 0.045),
      iron,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(lampX, _ground - _u * 0.05), width: _u * 0.11, height: _u * 0.10),
        Radius.circular(_u * 0.02),
      ),
      Paint()..color = _ink,
    );
    canvas.drawCircle(head, _u * 0.05, Paint()..color = _warm.withValues(alpha: flicker));
    canvas.drawCircle(
      head,
      _u * 0.18,
      Paint()
        ..color = _warm.withValues(alpha: 0.35 * flicker)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, _u * 0.09),
    );
  }

  /// Il muro dietro cui aspetta il killer. Va disegnato dopo di lui: è così
  /// che lo si vede spuntare dall'angolo.
  void _wall(Canvas canvas) {
    if (!_hasWall) return;
    final wall = Rect.fromLTRB(_cornerX, -_h, _w * 2, _ground);
    canvas.drawRect(wall, Paint()..color = const Color(0xFF0A0A0D));
    final mortar = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1;
    for (var y = _ground - _u * 0.14; y > -_u; y -= _u * 0.14) {
      canvas.drawLine(Offset(_cornerX, y), Offset(_w * 2, y), mortar);
    }
    canvas.drawLine(
      Offset(_cornerX, -_h),
      Offset(_cornerX, _ground),
      Paint()
        ..color = const Color(0xFF2E2F38)
        ..strokeWidth = 2,
    );
    // Un manifesto strappato, e più su una finestra accesa: qualcuno, lassù,
    // non ha visto niente.
    final poster = Rect.fromLTWH(_cornerX + _u * 0.07, _ground - _u * 1.00, _u * 0.20, _u * 0.27);
    canvas.drawRect(poster, Paint()..color = const Color(0xFF3A3326));
    canvas.drawCircle(poster.center.translate(0, -_u * 0.03), _u * 0.045, Paint()..color = const Color(0xFF15120D));
    canvas.drawRect(
      Rect.fromLTWH(poster.left + _u * 0.03, poster.bottom - _u * 0.07, _u * 0.14, _u * 0.025),
      Paint()..color = const Color(0xFF15120D),
    );
    final window = Rect.fromLTWH(_cornerX + _u * 0.09, _ground - _u * 1.80, _u * 0.20, _u * 0.28);
    // Si spegne appena succede qualcosa. Se il copione dice che una finestra
    // si riaccende, eccola: con qualcuno dietro il vetro.
    final lit = act == DeathAct.sniper ? 0.0 : 0.5 - 0.5 * _span(t, 0.60, 0.66);
    final watching = epilogue == 'finestra' ? _span(t, 0.70, 0.715) - _span(t, 0.80, 0.815) : 0.0;
    canvas.drawRect(window, Paint()..color = const Color(0xFF040405));
    canvas.drawRect(window, Paint()..color = _warm.withValues(alpha: lit + 0.5 * watching));
    if (watching > 0) {
      final shadow = Paint()..color = _ink.withValues(alpha: watching);
      canvas.drawCircle(window.center.translate(0, _u * 0.02), _u * 0.045, shadow);
      canvas.drawRect(Rect.fromLTRB(window.left + _u * 0.04, window.center.dy + _u * 0.06, window.right - _u * 0.04, window.bottom), shadow);
    }
    final frame = Paint()
      ..color = _ink
      ..strokeWidth = 2;
    canvas.drawLine(window.topCenter, window.bottomCenter, frame);
    canvas.drawLine(window.centerLeft, window.centerRight, frame);
  }

  // ------------------------------------------------------------------- sagome

  /// Un arto: più largo all'attaccatura, più stretto in fondo.
  void _limb(Canvas canvas, Offset from, Offset to, double fromRadius, double toRadius, Paint paint) {
    final delta = to - from;
    final length = delta.distance;
    canvas.drawCircle(from, fromRadius, paint);
    canvas.drawCircle(to, toRadius, paint);
    if (length < 0.01) return;
    final side = Offset(-delta.dy, delta.dx) / length;
    canvas.drawPath(
      Path()
        ..moveTo(from.dx + side.dx * fromRadius, from.dy + side.dy * fromRadius)
        ..lineTo(to.dx + side.dx * toRadius, to.dy + side.dy * toRadius)
        ..lineTo(to.dx - side.dx * toRadius, to.dy - side.dy * toRadius)
        ..lineTo(from.dx - side.dx * fromRadius, from.dy - side.dy * fromRadius)
        ..close(),
      paint,
    );
  }

  /// Dove si piega il ginocchio, dati anca e piede: sempre in avanti.
  Offset _knee(Offset hip, Offset foot, double thigh, double shin) {
    final delta = foot - hip;
    final length = max(delta.distance, 0.001);
    final reach = min(length, thigh + shin - 0.001);
    final along = delta / length;
    final base = (thigh * thigh - shin * shin + reach * reach) / (2 * reach);
    final rise = sqrt(max(0.0, thigh * thigh - base * base));
    final middle = hip + along * base;
    final side = Offset(along.dy, -along.dx);
    final a = middle + side * rise;
    final b = middle - side * rise;
    return a.dx > b.dx ? a : b;
  }

  /// Una persona in soprabito, vista di profilo.
  ///
  /// [stride] da 0 (ferma) a 1 (passo pieno), con [walk] che fa avanzare il
  /// passo; [lean] piega il busto in avanti; [crouch] piega le ginocchia;
  /// [tilt] ruota tutta la figura intorno ai piedi. [arm] e [elbow] muovono
  /// il braccio davanti: 0 lungo il fianco, pi/2 teso in avanti, pi in alto.
  void _person(
    Canvas canvas, {
    required Offset feet,
    int facing = 1,
    double walk = 0,
    double stride = 0,
    double lean = 0,
    double crouch = 0,
    double tilt = 0,
    double arm = 0.08,
    double elbow = 0.20,
    double backArm = -0.10,
    double backElbow = 0.20,
    double dangle = double.nan,
    AvatarHead hat = AvatarHead.fedora,
    bool hatOn = true,
    _Prop prop = _Prop.none,
    bool killer = false,
    bool dame = false,
    bool smoking = false,
    Color? cloth,
  }) {
    final h = killer ? _u * 1.08 : _u;
    canvas.save();
    canvas.translate(feet.dx, feet.dy);
    canvas.rotate(tilt);
    canvas.scale(facing.toDouble(), 1);

    void body(Paint paint, {required bool details}) {
      final bob = stride * sin(walk * 2).abs() * h * 0.012;
      final hip = Offset(-h * 0.03 * crouch, -h * (0.50 - 0.13 * crouch) + bob);
      const thigh = 0.265;
      const shin = 0.265;

      Offset footAt(double phase, double rest) {
        if (!dangle.isNaN) return hip + _aim(dangle * (rest > 0 ? 1 : -0.7)) * (h * 0.50);
        if (stride <= 0) return Offset(rest * h, 0);
        final cycle = (phase / (2 * pi)) % 1;
        final reach = stride * h * 0.21;
        if (cycle < 0.5) return Offset(_mix(reach, -reach, cycle * 2), 0);
        final swing = (cycle - 0.5) * 2;
        return Offset(_mix(-reach, reach, _smooth(swing)), -sin(pi * swing) * h * 0.075 * stride);
      }

      void leg(Offset foot) {
        final knee = _knee(hip, foot, h * thigh, h * shin);
        _limb(canvas, hip, knee, h * 0.058, h * 0.046, paint);
        _limb(canvas, knee, foot.translate(0, -h * 0.03), h * 0.046, h * 0.034, paint);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTRB(foot.dx - h * 0.04, foot.dy - h * 0.048, foot.dx + h * 0.115, foot.dy),
            topLeft: Radius.circular(h * 0.02),
            topRight: Radius.circular(h * 0.045),
            bottomRight: Radius.circular(h * 0.012),
          ),
          paint,
        );
      }

      leg(footAt(walk + pi, -0.055));
      leg(footAt(walk, 0.06));

      canvas.save();
      canvas.translate(hip.dx, hip.dy);
      canvas.rotate(lean);

      final swing = stride * sin(walk) * 0.45;
      final broad = killer ? 1.16 : (dame ? 0.84 : 1.0);
      // Il nero è per le sagome qualunque. La dama veste di rosso e il
      // Dottore di bianco: si devono riconoscere da lontano.
      final tint = cloth ?? (dame ? const Color(0xFF8A1622) : null);
      final coat = details && tint != null ? (Paint()..color = tint) : paint;

      (Offset, Offset) armAt(Offset shoulder, double angle, double bend) {
        final joint = shoulder + _aim(angle) * (h * 0.185);
        final hand = joint + _aim(angle + bend) * (h * 0.175);
        _limb(canvas, shoulder, joint, h * 0.046, h * 0.038, coat);
        _limb(canvas, joint, hand, h * 0.038, h * 0.030, coat);
        canvas.drawCircle(hand, h * 0.034, paint);
        return (hand, _aim(angle + bend));
      }

      armAt(Offset(-h * 0.03 * broad, -h * 0.325), backArm - swing, backElbow);

      // Il soprabito: spalle larghe, vita segnata, la falda che si apre dietro.
      final flare = h * (0.04 + 0.05 * stride * (0.5 + 0.5 * sin(walk * 2)));
      canvas.drawPath(
        Path()
          ..moveTo(-h * 0.145 * broad, -h * 0.335)
          ..quadraticBezierTo(-h * 0.10 * broad, -h * 0.385, 0, -h * 0.385)
          ..quadraticBezierTo(h * 0.11 * broad, -h * 0.385, h * 0.135 * broad, -h * 0.325)
          ..quadraticBezierTo(h * 0.16 * broad, -h * 0.20, h * 0.11, -h * 0.085)
          ..quadraticBezierTo(h * 0.13, h * 0.08, h * 0.165, h * 0.215)
          ..lineTo(-h * 0.17 - flare, h * 0.215)
          ..quadraticBezierTo(-h * 0.15, h * 0.04, -h * 0.115, -h * 0.085)
          ..quadraticBezierTo(-h * 0.17 * broad, -h * 0.22, -h * 0.145 * broad, -h * 0.335)
          ..close(),
        coat,
      );

      // Il bavero alzato, il collo, la testa di profilo.
      canvas.drawPath(
        Path()
          ..moveTo(-h * 0.07, -h * 0.375)
          ..lineTo(-h * 0.055, -h * 0.435)
          ..lineTo(h * 0.01, -h * 0.385)
          ..lineTo(h * 0.085, -h * 0.425)
          ..lineTo(h * 0.075, -h * 0.365)
          ..close(),
        paint,
      );
      final head = Offset(h * 0.03, -h * 0.485);
      if (dame) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(head.dx - h * 0.105, head.dy - h * 0.095, head.dx + h * 0.040, head.dy + h * 0.125),
            Radius.circular(h * 0.07),
          ),
          paint,
        );
      }
      canvas.drawOval(Rect.fromCenter(center: head, width: h * 0.150, height: h * 0.172), paint);
      canvas.drawPath(
        Path()
          ..moveTo(head.dx + h * 0.060, head.dy - h * 0.030)
          ..lineTo(head.dx + h * 0.102, head.dy + h * 0.022)
          ..lineTo(head.dx + h * 0.074, head.dy + h * 0.032)
          ..lineTo(head.dx + h * 0.080, head.dy + h * 0.062)
          ..quadraticBezierTo(head.dx + h * 0.065, head.dy + h * 0.105, head.dx + h * 0.010, head.dy + h * 0.095)
          ..lineTo(head.dx, head.dy)
          ..close(),
        paint,
      );
      if (hatOn) _hat(canvas, head, h, dame ? AvatarHead.wideBrim : hat, paint, details: details, killer: killer);

      if (details && dame) {
        canvas.drawCircle(head.translate(h * 0.078, h * 0.052), h * 0.013, Paint()..color = const Color(0xFFE23A4A));
      }
      if (details && smoking) {
        final lips = head.translate(h * 0.080, h * 0.050);
        final tip = lips.translate(h * 0.075, h * 0.012);
        canvas.drawLine(
          lips,
          tip,
          Paint()
            ..color = const Color(0xFFE9E4D8)
            ..strokeWidth = h * 0.014,
        );
        canvas.drawCircle(tip, h * (0.011 + 0.006 * sin(t * 160).abs()), Paint()..color = const Color(0xFFFF7A3B));
        _wisp(canvas, tip);
      }
      if (details && killer) {
        // Un riflesso sotto la tesa: da lì ti sta guardando.
        canvas.drawCircle(head.translate(h * 0.048, -h * 0.012), h * 0.010, Paint()..color = const Color(0xFFFFF3C4));
        // La cravatta rossa: è lui.
        canvas.drawPath(
          Path()
            ..moveTo(h * 0.035, -h * 0.365)
            ..lineTo(h * 0.085, -h * 0.365)
            ..lineTo(h * 0.075, -h * 0.20)
            ..lineTo(h * 0.045, -h * 0.25)
            ..close(),
          Paint()..color = _blood,
        );
      }

      final (hand, along) = armAt(Offset(h * 0.035 * broad, -h * 0.325), arm + swing, elbow);
      if (details) _held(canvas, hand, along, h, prop);
      canvas.restore();
    }

    // Due passate: prima un filo di luce calda dal lato del lampione, poi il
    // nero sopra. È quel bordo che dà spessore alla sagoma.
    canvas.save();
    canvas.translate(-h * 0.016 * facing, -h * 0.010);
    body(Paint()..color = _rim, details: false);
    canvas.restore();
    body(Paint()..color = _ink, details: true);
    canvas.restore();
  }

  void _hat(Canvas canvas, Offset head, double h, AvatarHead hat, Paint paint, {required bool details, required bool killer}) {
    void band(double left, double right, double y) {
      if (!details) return;
      canvas.drawRect(
        Rect.fromLTRB(head.dx + h * left, head.dy + h * y, head.dx + h * right, head.dy + h * (y + 0.024)),
        Paint()..color = killer ? _blood : _rim,
      );
    }

    switch (hat) {
      case AvatarHead.fedora || AvatarHead.wideBrim:
        final wide = hat == AvatarHead.wideBrim;
        canvas.save();
        canvas.translate(head.dx + h * 0.02, head.dy - h * 0.050);
        canvas.rotate(0.10);
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: h * (wide ? 0.44 : 0.33), height: h * 0.048),
          paint,
        );
        canvas.restore();
        canvas.drawPath(
          Path()
            ..moveTo(head.dx - h * 0.082, head.dy - h * 0.050)
            ..quadraticBezierTo(head.dx - h * 0.090, head.dy - h * 0.160, head.dx - h * 0.040, head.dy - h * 0.160)
            ..quadraticBezierTo(head.dx + h * 0.010, head.dy - h * 0.130, head.dx + h * 0.055, head.dy - h * 0.165)
            ..quadraticBezierTo(head.dx + h * 0.105, head.dy - h * 0.150, head.dx + h * 0.100, head.dy - h * 0.040)
            ..close(),
          paint,
        );
        band(-0.084, 0.102, -0.082);
      case AvatarHead.bowler:
        canvas.drawOval(
          Rect.fromCenter(center: head.translate(h * 0.01, -h * 0.052), width: h * 0.27, height: h * 0.04),
          paint,
        );
        canvas.drawArc(
          Rect.fromCenter(center: head.translate(h * 0.005, -h * 0.052), width: h * 0.18, height: h * 0.22),
          pi,
          pi,
          true,
          paint,
        );
        band(-0.085, 0.095, -0.080);
      case AvatarHead.coppola:
        canvas.drawPath(
          Path()
            ..moveTo(head.dx - h * 0.090, head.dy - h * 0.045)
            ..quadraticBezierTo(head.dx - h * 0.080, head.dy - h * 0.125, head.dx + h * 0.020, head.dy - h * 0.115)
            ..quadraticBezierTo(head.dx + h * 0.100, head.dy - h * 0.100, head.dx + h * 0.165, head.dy - h * 0.040)
            ..lineTo(head.dx + h * 0.160, head.dy - h * 0.022)
            ..close(),
          paint,
        );
      case AvatarHead.slicked:
        canvas.drawArc(
          Rect.fromCenter(center: head.translate(-h * 0.008, -h * 0.012), width: h * 0.165, height: h * 0.180),
          pi * 0.95,
          pi * 1.05,
          true,
          paint,
        );
      case AvatarHead.bob:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(head.dx - h * 0.105, head.dy - h * 0.100, head.dx + h * 0.045, head.dy + h * 0.105),
            Radius.circular(h * 0.07),
          ),
          paint,
        );
      case AvatarHead.bun:
        canvas.drawCircle(head.translate(-h * 0.075, -h * 0.075), h * 0.048, paint);
        canvas.drawArc(
          Rect.fromCenter(center: head.translate(-h * 0.008, -h * 0.010), width: h * 0.165, height: h * 0.185),
          pi * 0.9,
          pi * 1.0,
          true,
          paint,
        );
    }
  }

  void _held(Canvas canvas, Offset hand, Offset along, double h, _Prop prop) {
    final across = Offset(-along.dy, along.dx);
    switch (prop) {
      case _Prop.none:
        break;
      case _Prop.knife:
        final tip = hand + along * (h * 0.24);
        canvas.drawPath(
          Path()
            ..moveTo(hand.dx + across.dx * h * 0.022, hand.dy + across.dy * h * 0.022)
            ..lineTo(tip.dx, tip.dy)
            ..lineTo(hand.dx - across.dx * h * 0.012, hand.dy - across.dy * h * 0.012)
            ..close(),
          Paint()..color = _steel,
        );
        canvas.drawLine(
          hand - across * (h * 0.035),
          hand + across * (h * 0.035),
          Paint()
            ..color = _gunmetal
            ..strokeWidth = h * 0.018
            ..strokeCap = StrokeCap.round,
        );
      case _Prop.pistol:
        final metal = Paint()
          ..color = _gunmetal
          ..strokeWidth = h * 0.045
          ..strokeCap = StrokeCap.square;
        canvas.drawLine(hand, hand + along * (h * 0.13), metal);
        canvas.drawLine(hand, hand - across * (h * 0.05), metal..strokeWidth = h * 0.035);
        canvas.drawLine(
          hand + across * (h * 0.012),
          hand + along * (h * 0.13) + across * (h * 0.012),
          Paint()
            ..color = _steel.withValues(alpha: 0.7)
            ..strokeWidth = h * 0.008,
        );
      case _Prop.tommy:
        final metal = Paint()
          ..color = _gunmetal
          ..strokeCap = StrokeCap.square;
        canvas.drawLine(hand - along * (h * 0.16), hand + along * (h * 0.30), metal..strokeWidth = h * 0.045);
        canvas.drawLine(hand + along * (h * 0.30), hand + along * (h * 0.40), metal..strokeWidth = h * 0.022);
        canvas.drawCircle(hand + along * (h * 0.13) - across * (h * 0.055), h * 0.052, Paint()..color = _gunmetal);
        canvas.drawCircle(
          hand + along * (h * 0.13) - across * (h * 0.055),
          h * 0.052,
          Paint()
            ..color = _steel.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = h * 0.008,
        );
      case _Prop.cup:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: hand.translate(h * 0.035, -h * 0.02), width: h * 0.065, height: h * 0.055),
            Radius.circular(h * 0.012),
          ),
          Paint()..color = AppColors.textPrimary,
        );
      case _Prop.bat:
        _limb(
          canvas,
          hand - along * (h * 0.06),
          hand + along * (h * 0.46),
          h * 0.015,
          h * 0.036,
          Paint()..color = const Color(0xFFC9A26B),
        );
      case _Prop.lupara:
        canvas.drawLine(
          hand - along * (h * 0.17) + across * (h * 0.03),
          hand,
          Paint()
            ..color = const Color(0xFF6B4423)
            ..strokeWidth = h * 0.055
            ..strokeCap = StrokeCap.round,
        );
        final barrel = Paint()
          ..color = _gunmetal
          ..strokeWidth = h * 0.024
          ..strokeCap = StrokeCap.square;
        for (final side in [-0.014, 0.014]) {
          canvas.drawLine(hand + across * (h * side), hand + along * (h * 0.22) + across * (h * side), barrel);
        }
        canvas.drawLine(
          hand - across * (h * 0.024),
          hand + along * (h * 0.22) - across * (h * 0.024),
          Paint()
            ..color = _steel.withValues(alpha: 0.6)
            ..strokeWidth = h * 0.007,
        );
      case _Prop.bag:
        _bag(canvas, hand.translate(0, h * 0.09), h);
      case _Prop.flask:
        final flask = Rect.fromCenter(center: hand.translate(h * 0.01, -h * 0.045), width: h * 0.075, height: h * 0.11);
        canvas.drawRect(
          Rect.fromCenter(center: flask.topCenter, width: h * 0.03, height: h * 0.03),
          Paint()..color = _gunmetal,
        );
        canvas.drawRRect(RRect.fromRectAndRadius(flask, Radius.circular(h * 0.018)), Paint()..color = _steel);
        canvas.drawCircle(flask.center, h * 0.017, Paint()..color = _ink);
      case _Prop.box:
        final box = Rect.fromCenter(center: hand.translate(h * 0.06, -h * 0.02), width: h * 0.19, height: h * 0.15);
        canvas.drawRect(box, Paint()..color = const Color(0xFF7A1B22));
        final ribbon = Paint()
          ..color = AppColors.gold
          ..strokeWidth = h * 0.02;
        canvas.drawLine(box.topCenter, box.bottomCenter, ribbon);
        canvas.drawLine(box.centerLeft, box.centerRight, ribbon);
        canvas.drawCircle(box.topCenter.translate(-h * 0.02, -h * 0.015), h * 0.02, Paint()..color = AppColors.gold);
        canvas.drawCircle(box.topCenter.translate(h * 0.02, -h * 0.015), h * 0.02, Paint()..color = AppColors.gold);
    }
  }

  /// La vittima, in piedi o mentre crolla. [fall] va da 0 a 1: le ginocchia
  /// cedono, il corpo gira, e alla fine resta a terra, stesa verso [fallTo].
  void _victim(
    Canvas canvas, {
    required double x,
    int facing = 1,
    double walk = 0,
    double stride = 0,
    double fall = 0,
    int fallTo = -1,
    double lean = 0,
    double arm = 0.08,
    double elbow = 0.20,
    _Prop prop = _Prop.none,
    bool smoking = false,
  }) {
    if (fall >= 1) return _corpse(canvas, x, fallTo);
    if (fall <= 0) {
      // Il tempo di accendersela: la mano sale al viso, il fiammifero fa luce.
      final lighting = smoking ? sin(pi * _span(t, 0.37, 0.42)) : 0.0;
      if (lighting > 0) {
        canvas.drawCircle(
          Offset(x + facing * _u * 0.14, _ground - _u * 0.93),
          _u * 0.24 * lighting,
          Paint()
            ..color = _warm.withValues(alpha: 0.55 * lighting)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, _u * 0.08),
        );
      }
      return _person(
        canvas,
        feet: Offset(x, _ground),
        facing: facing,
        walk: walk,
        stride: stride,
        lean: lean,
        arm: _mix(arm, 1.0, lighting),
        elbow: _mix(elbow, 2.45, lighting),
        hat: victimHat,
        prop: prop,
        smoking: smoking && t > 0.395,
      );
    }
    final buckle = Curves.easeOut.transform(min(1, fall * 1.6));
    final topple = Curves.easeIn.transform(fall);
    _person(
      canvas,
      feet: Offset(x, _ground),
      facing: facing,
      crouch: buckle * 0.95,
      tilt: fallTo * (0.10 * buckle + 1.20 * topple),
      lean: -facing * fallTo * 0.25 * buckle,
      arm: _mix(arm, 2.3, buckle),
      elbow: 0.7,
      backArm: -1.3 * buckle,
      hat: victimHat,
      hatOn: false,
    );
  }

  /// Il corpo a terra, con i piedi in [feetX] e la testa verso [toward].
  void _corpse(Canvas canvas, double feetX, int toward) {
    canvas.save();
    canvas.translate(feetX, _ground);
    canvas.scale(toward.toDouble(), 1);
    final u = _u;

    void body(Paint paint) {
      // Il soprabito aperto sull'asfalto, poi gambe, busto, braccia, testa.
      canvas.drawOval(Rect.fromLTRB(u * 0.20, -u * 0.07, u * 0.80, u * 0.01), paint);
      _limb(canvas, Offset(u * 0.06, -u * 0.05), Offset(u * 0.36, -u * 0.07), u * 0.036, u * 0.056, paint);
      _limb(canvas, Offset(u * 0.02, -u * 0.04), Offset(u * 0.20, -u * 0.17), u * 0.034, u * 0.046, paint);
      _limb(canvas, Offset(u * 0.20, -u * 0.17), Offset(u * 0.36, -u * 0.07), u * 0.046, u * 0.056, paint);
      for (final x in [0.0, 0.055]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(u * (x - 0.025), -u * 0.135, u * (x + 0.03), -u * 0.01),
            Radius.circular(u * 0.025),
          ),
          paint,
        );
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTRB(u * 0.32, -u * 0.165, u * 0.70, -u * 0.012), Radius.circular(u * 0.075)),
        paint,
      );
      _limb(canvas, Offset(u * 0.62, -u * 0.09), Offset(u * 0.48, -u * 0.02), u * 0.044, u * 0.032, paint);
      _limb(canvas, Offset(u * 0.64, -u * 0.07), Offset(u * 0.90, -u * 0.025), u * 0.044, u * 0.030, paint);
      final head = Offset(u * 0.77, -u * 0.085);
      canvas.drawCircle(head, u * 0.078, paint);
      canvas.drawPath(
        Path()
          ..moveTo(head.dx - u * 0.02, head.dy - u * 0.07)
          ..lineTo(head.dx + u * 0.02, head.dy - u * 0.115)
          ..lineTo(head.dx + u * 0.04, head.dy - u * 0.06)
          ..close(),
        paint,
      );
    }

    canvas.save();
    canvas.translate(-u * 0.012 * toward, -u * 0.014);
    body(Paint()..color = _rim);
    canvas.restore();
    body(Paint()..color = _ink);
    canvas.restore();
  }

  /// Un cappello caduto, che rotola o resta lì.
  void _looseHat(Canvas canvas, Offset center, double spin) {
    final ink = Paint()..color = _ink;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(spin);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: _u * 0.33, height: _u * 0.055), ink);
    canvas.drawPath(
      Path()
        ..moveTo(-_u * 0.09, 0)
        ..quadraticBezierTo(-_u * 0.10, -_u * 0.12, -_u * 0.04, -_u * 0.12)
        ..quadraticBezierTo(_u * 0.005, -_u * 0.09, _u * 0.05, -_u * 0.125)
        ..quadraticBezierTo(_u * 0.10, -_u * 0.11, _u * 0.095, 0)
        ..close(),
      ink,
    );
    canvas.drawRect(Rect.fromLTRB(-_u * 0.09, -_u * 0.04, _u * 0.095, -_u * 0.014), Paint()..color = _rim);
    canvas.restore();
  }

  void _shoes(Canvas canvas, double x) {
    final ink = Paint()..color = _ink;
    for (final dx in [-0.12, 0.05]) {
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(x + _u * dx, _ground - _u * 0.05, x + _u * (dx + 0.15), _ground),
          topLeft: Radius.circular(_u * 0.02),
          topRight: Radius.circular(_u * 0.045),
        ),
        ink,
      );
    }
  }

  // -------------------------------------------------------------------- effetti

  /// Schizzi che partono da [origin], volano secondo [bias] e ricadono.
  void _spray(
    Canvas canvas,
    Offset origin,
    double life, {
    required int seed,
    Color color = _blood,
    int count = 16,
    Offset bias = const Offset(-0.5, -0.9),
    double reach = 1,
  }) {
    if (life <= 0 || life >= 1) return;
    final rng = Random(seed);
    final paint = Paint();
    for (var i = 0; i < count; i++) {
      final angle = rng.nextDouble() * 2 * pi;
      final speed = (0.35 + rng.nextDouble() * 0.65) * _u * 0.9 * reach;
      final direction = Offset(cos(angle), sin(angle)) * 0.55 + bias;
      final position = origin + direction * (speed * life) + Offset(0, _u * 1.3 * life * life);
      paint.color = color.withValues(alpha: (1 - life * life).clamp(0.0, 1.0));
      canvas.drawCircle(position, _u * (0.012 + rng.nextDouble() * 0.022) * (1 - life * 0.4), paint);
    }
  }

  void _pool(Canvas canvas, Offset center, double grown) {
    if (grown <= 0) return;
    canvas.drawOval(
      Rect.fromCenter(center: center, width: _u * 0.95 * grown, height: _u * 0.11 * grown),
      Paint()..color = _blood.withValues(alpha: 0.9),
    );
  }

  void _puff(Canvas canvas, Offset center, double life, {double size = 1, Color color = const Color(0xFF8E8A86)}) {
    if (life <= 0 || life >= 1) return;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.5 * (1 - life))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, _u * 0.05);
    for (final (dx, dy, r) in [(-0.22, 0.0, 0.16), (0.0, -0.08, 0.22), (0.24, 0.02, 0.15)]) {
      canvas.drawCircle(
        center + Offset(dx * (1 + life), dy - life * 0.25) * (_u * size),
        _u * r * size * (0.6 + life),
        paint,
      );
    }
  }

  void _flash(Canvas canvas, double life, {double strength = 0.8}) {
    if (life <= 0 || life >= 1) return;
    canvas.drawRect(
      Rect.fromLTWH(-_w, -_h, _w * 3, _h * 3),
      Paint()..color = Colors.white.withValues(alpha: strength * (1 - life) * (1 - life)),
    );
  }

  void _star(Canvas canvas, Offset center, double radius, Color color) {
    final path = Path();
    for (var i = 0; i < 16; i++) {
      final r = i.isEven ? radius : radius * 0.42;
      final point = center + Offset(cos(i * pi / 8), sin(i * pi / 8)) * r;
      i == 0 ? path.moveTo(point.dx, point.dy) : path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  // ---------------------------------------------------------------- canovaccio

  /// La vittima entra e si ferma sotto il lampione: posizione, fase del
  /// passo e ampiezza (zero quando è ferma).
  (double, double, double) _entrance() {
    final walk = _span(t, 0.04, 0.34);
    final slowing = 1 - Curves.easeIn.transform(_span(t, 0.30, 0.34));
    return (_mix(-_w * 0.25, _victimX, walk), walk * 9 * pi, walk < 1 ? slowing.clamp(0.25, 1.0) : 0.0);
  }

  /// Il killer che, a cose fatte, si affaccia dall'angolo e si tocca il cappello.
  void _killerSalute(Canvas canvas) {
    final out = _smooth(_span(t, 0.69, 0.75)) - _smooth(_span(t, 0.82, 0.86));
    if (out <= 0) return;
    _person(
      canvas,
      feet: Offset(_mix(_hiddenX, _cornerX - _u * 0.16, out), _ground),
      facing: -1,
      arm: _mix(0.1, 2.35, out),
      elbow: _mix(0.2, 1.25, out),
      killer: true,
    );
  }

  /// Un passo felpato, per chi si avvicina o se ne va.
  double get _prowl => t * 230;

  // ---------------------------------------------------------------- coreografie

  void _knife(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    final peek = _smooth(_span(t, 0.38, 0.46));
    final dash = Curves.easeIn.transform(_span(t, 0.49, strike));
    final leave = _smooth(_span(t, 0.70, 0.84));
    final killerX = _mix(_mix(_mix(_hiddenX, _peekX, peek), _victimX + _u * 0.42, dash), _hiddenX, leave);
    final running = (dash > 0 && dash < 1) || (leave > 0 && leave < 1);
    final raise = _span(t, 0.46, 0.53);
    final blow = _span(t, strike, strike + 0.03);

    _person(
      canvas,
      feet: Offset(killerX, _ground),
      facing: leave > 0.08 ? 1 : -1,
      walk: _prowl,
      stride: running ? 1 : 0,
      lean: leave > 0 ? 0.08 : 0.16 * dash + 0.25 * sin(pi * blow),
      crouch: 0.18 * dash * (1 - leave),
      arm: leave > 0 ? 0.1 : _mix(_mix(0.3, 2.85, raise), 1.35, blow),
      elbow: leave > 0 ? 0.2 : _mix(0.9, 0.1, blow),
      prop: _Prop.knife,
      killer: true,
    );
    _wall(canvas);

    final fall = _span(t, strike + 0.02, strike + 0.13);
    _pool(canvas, Offset(_victimX - _u * 0.50, _ground + _u * 0.04), _smooth(_span(t, 0.67, 0.84)));
    _victim(
      canvas,
      x: walkX,
      facing: t < 0.37 ? 1 : -1,
      walk: walk,
      stride: stride,
      fall: fall,
      smoking: t > 0.37 && t < strike,
    );
    if (fall > 0.12) {
      final flight = _span(t, strike + 0.03, 0.78);
      _looseHat(
        canvas,
        Offset(_victimX - _u * (0.30 + 0.95 * flight), _ground - _u * 0.03 - _u * 0.9 * sin(pi * min(1, flight * 1.6)) * (1 - flight)),
        flight < 1 ? -flight * 9 : -0.2,
      );
    }

    // Il lampo della lama, e quello che ne segue.
    if (blow > 0 && blow < 1) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(_victimX + _u * 0.22, _ground - _u * 0.72), radius: _u * 0.46),
        pi * 0.92,
        pi * 0.62 * blow,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _u * 0.035
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: 1 - blow),
      );
    }
    _spray(canvas, Offset(_victimX, _ground - _u * 0.74), _span(t, strike, strike + 0.20), seed: 3, count: 20);
    _flash(canvas, _span(t, strike, strike + 0.04), strength: 0.35);
  }

  void _shooting(Canvas canvas, List<double> shots, _Prop weapon) {
    final (walkX, walk, stride) = _entrance();
    final last = shots.last;
    final peek = _smooth(_span(t, 0.38, 0.46));
    final out = _smooth(_span(t, 0.46, 0.53));
    final leave = _smooth(_span(t, last + 0.12, last + 0.25));
    final killerX = _mix(_mix(_mix(_hiddenX, _peekX, peek), _cornerX - _u * 0.10, out), _hiddenX, leave);

    var kick = 0.0;
    var jolt = 0.0;
    for (final shot in shots) {
      final bang = _span(t, shot, shot + 0.025);
      if (bang > 0 && bang < 1) {
        kick = sin(pi * bang);
        jolt = sin(pi * bang);
      }
    }

    final twoHands = weapon == _Prop.tommy;
    _person(
      canvas,
      feet: Offset(killerX, _ground),
      facing: leave > 0.08 ? 1 : -1,
      walk: _prowl,
      stride: (out > 0 && out < 1) || (leave > 0 && leave < 1) ? 0.8 : 0,
      lean: leave > 0 ? 0.05 : 0.10 * out - 0.05 * kick,
      arm: leave > 0 ? 0.1 : _mix(0.2, twoHands ? 1.25 : pi / 2, out) + 0.16 * kick,
      elbow: leave > 0 ? 0.2 : (twoHands ? 0.42 : 0.03),
      backArm: leave > 0 ? -0.1 : (twoHands ? _mix(-0.1, 1.45, out) : -0.1),
      backElbow: twoHands ? 0.25 : 0.2,
      prop: weapon,
      killer: true,
    );
    _wall(canvas);

    final fall = _span(t, last + 0.02, last + 0.13);
    _pool(canvas, Offset(_victimX - _u * 0.50, _ground + _u * 0.04), _smooth(_span(t, last + 0.11, last + 0.28)));
    _victim(
      canvas,
      x: walkX,
      facing: t < 0.37 ? 1 : -1,
      walk: walk,
      stride: stride,
      fall: fall,
      lean: 0.20 * jolt,
      smoking: t > 0.37 && t < shots.first,
    );
    if (fall > 0.12) {
      final flight = _span(t, last + 0.03, last + 0.24);
      _looseHat(
        canvas,
        Offset(_victimX - _u * (0.30 + 0.90 * flight), _ground - _u * 0.03 - _u * 0.8 * sin(pi * min(1, flight * 1.6)) * (1 - flight)),
        flight < 1 ? -flight * 8 : -0.2,
      );
    }

    final killerHeight = _u * 1.08;
    final muzzle = Offset(
      killerX - killerHeight * (twoHands ? 0.74 : 0.56),
      _ground - killerHeight * (twoHands ? 0.74 : 0.83),
    );
    for (var i = 0; i < shots.length; i++) {
      final bang = _span(t, shots[i], shots[i] + 0.025);
      if (bang > 0 && bang < 1) {
        _star(canvas, muzzle, _u * 0.24 * (1 - bang * 0.5), const Color(0xFFFFF3C4).withValues(alpha: 1 - bang));
        canvas.drawLine(
          muzzle,
          Offset(_victimX + _u * 0.08, _ground - _u * 0.72),
          Paint()
            ..color = _warm.withValues(alpha: 0.85 * (1 - bang))
            ..strokeWidth = _u * 0.014,
        );
      }
      _flash(canvas, bang, strength: 0.4);
      _spray(
        canvas,
        Offset(_victimX, _ground - _u * 0.74),
        _span(t, shots[i], shots[i] + 0.16),
        seed: 20 + i,
        count: 9,
      );
    }
    // Il filo di fumo dalla canna.
    final smoke = _span(t, last + 0.02, last + 0.12);
    if (smoke > 0 && smoke < 1) {
      _puff(canvas, muzzle.translate(0, -_u * 0.25 * smoke), smoke, size: 0.4);
    }
  }

  void _car(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    final drive = _span(t, 0.47, 0.66);
    final frontX = _mix(-_w * 0.35, _w * 2.4, Curves.easeIn.transform(drive));
    final hit = frontX >= _victimX;

    // Prima i fari, in fondo alla strada, da dove la vittima è arrivata.
    final glare = _span(t, 0.38, 0.50) * (1 - _span(t, 0.50, 0.56));
    if (glare > 0) {
      canvas.drawCircle(
        Offset(-_u * 0.1, _ground - _u * 0.30),
        _u * (0.3 + 0.9 * glare),
        Paint()
          ..color = _warm.withValues(alpha: 0.55 * glare)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, _u * 0.25),
      );
    }

    if (!hit) {
      final alarm = _span(t, 0.47, 0.52);
      _victim(
        canvas,
        x: walkX,
        facing: t < 0.43 ? 1 : -1,
        walk: walk,
        stride: stride,
        lean: -0.14 * alarm,
        arm: _mix(0.08, 2.1, alarm),
        elbow: _mix(0.2, 0.9, alarm),
      );
    } else {
      // La vittima vola via, e restano le scarpe.
      final flight = _span(t, strike - 0.02, 0.72);
      if (flight < 1) {
        final arc = sin(pi * flight);
        _person(
          canvas,
          feet: Offset(_victimX + _u * 2.6 * flight, _ground - _u * (0.2 + 2.2 * arc)),
          facing: -1,
          tilt: flight * 11,
          arm: 2.6,
          elbow: 0.3,
          backArm: -2.2,
          crouch: 0.5,
          hat: victimHat,
          hatOn: false,
        );
      }
      _shoes(canvas, _victimX);
      final hatFlight = _span(t, strike - 0.02, 0.86);
      _looseHat(
        canvas,
        Offset(_victimX + _u * 0.9 * hatFlight, _ground - _u * 0.04 - _u * 2.0 * sin(pi * min(1, hatFlight * 1.15)) * (1 - hatFlight * 0.3)),
        hatFlight < 1 ? hatFlight * 14 : 0,
      );
      _puff(canvas, Offset(_victimX + _u * 0.3, _ground - _u * 0.05), _span(t, strike, 0.74), size: 1.2);
    }

    if (drive > 0 && drive < 1) _sedan(canvas, frontX);
    // I segni della frenata che non c'è stata.
    if (hit) {
      final marks = Paint()
        ..color = Colors.black.withValues(alpha: 0.6)
        ..strokeWidth = _u * 0.02;
      for (final dy in [0.04, 0.10]) {
        canvas.drawLine(
          Offset(_victimX - _u * 0.4, _ground + _u * dy),
          Offset(min(frontX, _w + 40), _ground + _u * dy),
          marks,
        );
      }
    }
    _flash(canvas, _span(t, strike - 0.03, strike + 0.07), strength: 0.95);
  }

  void _sedan(Canvas canvas, double front) {
    final ink = Paint()..color = _ink;
    final length = _u * 2.1;
    final back = front - length;
    final base = _ground - _u * 0.08;

    final lamp = Offset(front - _u * 0.03, _ground - _u * 0.34);
    canvas.drawPath(
      Path()
        ..moveTo(lamp.dx, lamp.dy)
        ..lineTo(lamp.dx + _u * 2.6, lamp.dy - _u * 0.40)
        ..lineTo(lamp.dx + _u * 2.6, _ground + _u * 0.04)
        ..close(),
      Paint()
        ..shader = LinearGradient(
          colors: [_warm.withValues(alpha: 0.55), _warm.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(lamp.dx, lamp.dy - _u * 0.4, _u * 2.6, _u * 0.5)),
    );

    // La carrozzeria: cofano lungo, tetto tondo, parafanghi gonfi.
    canvas.drawPath(
      Path()
        ..moveTo(back + _u * 0.05, base)
        ..quadraticBezierTo(back - _u * 0.03, _ground - _u * 0.42, back + _u * 0.22, _ground - _u * 0.46)
        ..quadraticBezierTo(back + _u * 0.42, _ground - _u * 0.86, back + _u * 0.82, _ground - _u * 0.86)
        ..quadraticBezierTo(back + _u * 1.15, _ground - _u * 0.86, back + _u * 1.32, _ground - _u * 0.52)
        ..quadraticBezierTo(back + _u * 1.80, _ground - _u * 0.52, front - _u * 0.04, _ground - _u * 0.40)
        ..quadraticBezierTo(front + _u * 0.03, _ground - _u * 0.30, front, base)
        ..close(),
      ink,
    );
    canvas.drawPath(
      Path()
        ..moveTo(back + _u * 0.50, _ground - _u * 0.52)
        ..quadraticBezierTo(back + _u * 0.58, _ground - _u * 0.78, back + _u * 0.84, _ground - _u * 0.78)
        ..quadraticBezierTo(back + _u * 1.06, _ground - _u * 0.78, back + _u * 1.20, _ground - _u * 0.52)
        ..close(),
      Paint()..color = const Color(0xFF3B4658),
    );
    canvas.drawLine(
      Offset(back + _u * 0.86, _ground - _u * 0.78),
      Offset(back + _u * 0.86, _ground - _u * 0.52),
      Paint()
        ..color = _ink
        ..strokeWidth = _u * 0.03,
    );
    for (final x in [back + _u * 0.38, front - _u * 0.36]) {
      canvas.drawCircle(Offset(x, _ground - _u * 0.15), _u * 0.21, ink);
      canvas.drawCircle(Offset(x, _ground - _u * 0.13), _u * 0.13, Paint()..color = const Color(0xFF17181C));
      canvas.drawCircle(Offset(x, _ground - _u * 0.13), _u * 0.055, Paint()..color = _steel.withValues(alpha: 0.7));
    }
    canvas.drawCircle(lamp, _u * 0.06, Paint()..color = const Color(0xFFFFF3C4));
    // Le righe della velocità.
    final streak = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = _u * 0.012;
    for (final (dy, len) in [(0.70, 1.0), (0.48, 1.5), (0.24, 0.8)]) {
      canvas.drawLine(
        Offset(back - _u * 0.15, _ground - _u * dy),
        Offset(back - _u * (0.15 + len), _ground - _u * dy),
        streak,
      );
    }
  }

  void _fallingObject(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    final drop = Curves.easeIn.transform(_span(t, 0.46, strike));
    final landed = t >= strike;
    final bottom = _mix(-_u * 2.2, _ground, drop);

    _killerSalute(canvas);
    _wall(canvas);

    // L'ombra che si allarga: la vittima se ne accorge un attimo troppo tardi.
    final shadow = _span(t, 0.40, strike);
    if (shadow > 0 && !landed) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(_victimX, _ground + _u * 0.04),
          width: _u * (0.3 + 1.1 * shadow),
          height: _u * 0.12 * (0.4 + shadow),
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.6 * shadow),
      );
    }

    if (!landed) {
      final alarm = _span(t, 0.49, 0.53);
      _victim(
        canvas,
        x: walkX,
        walk: walk,
        stride: stride,
        lean: -0.16 * alarm,
        arm: _mix(0.08, 2.75, alarm),
        elbow: _mix(0.2, 0.5, alarm),
      );
      if (alarm > 0) {
        final mark = TextPainter(
          text: TextSpan(
            text: '!',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: _u * 0.34,
              fontWeight: FontWeight.w900,
              color: AppColors.gold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        mark.paint(canvas, Offset(_victimX + _u * 0.20, _ground - _u * 1.52));
      }
    } else {
      // Sotto resta poco: due gambe che spuntano, e un cappello che rotola via.
      final ink = Paint()..color = _ink;
      for (final dy in [0.04, 0.12]) {
        _limb(
          canvas,
          Offset(_victimX - _u * 0.36, _ground - _u * dy),
          Offset(_victimX - _u * 0.80, _ground - _u * dy),
          _u * 0.05,
          _u * 0.038,
          ink,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(_victimX - _u * 0.87, _ground - _u * (dy + 0.10), _u * 0.07, _u * 0.14),
            Radius.circular(_u * 0.03),
          ),
          ink,
        );
      }
      final roll = _span(t, strike, 0.80);
      _looseHat(canvas, Offset(_victimX - _u * (0.95 + 0.6 * roll), _ground - _u * 0.03), -roll * 9);
    }

    switch (act) {
      case DeathAct.safe:
        _safeShape(canvas, bottom);
      case DeathAct.chandelier:
        _chandelierShape(canvas, bottom, landed);
      default:
        _pianoShape(canvas, bottom);
    }
    if (!landed && drop > 0) {
      final rush = Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..strokeWidth = _u * 0.012;
      for (final dx in [-0.42, -0.1, 0.25, 0.45]) {
        canvas.drawLine(
          Offset(_victimX + _u * dx, bottom - _u * 1.05),
          Offset(_victimX + _u * dx, bottom - _u * 1.55),
          rush,
        );
      }
    }

    final dust = _span(t, strike, strike + 0.22);
    _puff(canvas, Offset(_victimX - _u * 0.6, _ground - _u * 0.05), dust, size: 1.3);
    _puff(canvas, Offset(_victimX + _u * 0.6, _ground - _u * 0.05), dust, size: 1.3);
    if (act == DeathAct.chandelier) {
      _spray(
        canvas,
        Offset(_victimX, _ground - _u * 0.2),
        _span(t, strike, strike + 0.22),
        seed: 8,
        color: const Color(0xFFFFF3C4),
        count: 26,
        bias: const Offset(0, -1.0),
        reach: 1.3,
      );
    }
    _flash(canvas, _span(t, strike, strike + 0.05), strength: 0.5);
  }

  void _pianoShape(Canvas canvas, double bottom) {
    final ink = Paint()..color = _ink;
    final x = _victimX;
    for (final dx in [-0.50, 0.06, 0.52]) {
      _limb(canvas, Offset(x + _u * dx, bottom - _u * 0.34), Offset(x + _u * dx, bottom - _u * 0.02), _u * 0.035, _u * 0.02, ink);
    }
    // La cassa a coda, il coperchio alzato, la tastiera.
    canvas.drawPath(
      Path()
        ..moveTo(x - _u * 0.64, bottom - _u * 0.30)
        ..lineTo(x - _u * 0.64, bottom - _u * 0.56)
        ..quadraticBezierTo(x - _u * 0.20, bottom - _u * 0.66, x + _u * 0.20, bottom - _u * 0.64)
        ..quadraticBezierTo(x + _u * 0.66, bottom - _u * 0.62, x + _u * 0.64, bottom - _u * 0.40)
        ..quadraticBezierTo(x + _u * 0.62, bottom - _u * 0.30, x + _u * 0.50, bottom - _u * 0.30)
        ..close(),
      ink,
    );
    canvas.drawPath(
      Path()
        ..moveTo(x - _u * 0.42, bottom - _u * 0.62)
        ..lineTo(x + _u * 0.58, bottom - _u * 1.10)
        ..lineTo(x + _u * 0.62, bottom - _u * 0.60)
        ..close(),
      ink,
    );
    canvas.drawLine(
      Offset(x + _u * 0.30, bottom - _u * 0.62),
      Offset(x + _u * 0.44, bottom - _u * 1.02),
      Paint()
        ..color = _ink
        ..strokeWidth = _u * 0.018,
    );
    canvas.drawRect(
      Rect.fromLTRB(x - _u * 0.64, bottom - _u * 0.44, x - _u * 0.40, bottom - _u * 0.385),
      Paint()..color = AppColors.textPrimary,
    );
    for (var i = 1; i < 6; i++) {
      canvas.drawRect(
        Rect.fromLTWH(x - _u * 0.64 + i * _u * 0.04 - _u * 0.008, bottom - _u * 0.44, _u * 0.016, _u * 0.032),
        ink,
      );
    }
  }

  void _safeShape(Canvas canvas, double bottom) {
    final box = Rect.fromLTRB(_victimX - _u * 0.44, bottom - _u * 0.88, _victimX + _u * 0.44, bottom);
    canvas.drawRRect(RRect.fromRectAndRadius(box, Radius.circular(_u * 0.04)), Paint()..color = const Color(0xFF0C0D10));
    final brass = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _u * 0.022;
    canvas.drawRRect(RRect.fromRectAndRadius(box.deflate(_u * 0.07), Radius.circular(_u * 0.03)), brass);
    final dial = box.center.translate(-_u * 0.08, 0);
    canvas.drawCircle(dial, _u * 0.12, brass);
    for (var i = 0; i < 8; i++) {
      final spoke = Offset(cos(i * pi / 4), sin(i * pi / 4));
      canvas.drawLine(dial + spoke * (_u * 0.09), dial + spoke * (_u * 0.12), brass);
    }
    canvas.drawLine(dial, dial.translate(0, -_u * 0.08), brass);
    canvas.drawLine(box.center.translate(_u * 0.18, -_u * 0.10), box.center.translate(_u * 0.18, _u * 0.10), brass);
    for (final corner in [box.topLeft, box.topRight, box.bottomLeft, box.bottomRight]) {
      canvas.drawCircle(Offset.lerp(corner, box.center, 0.10)!, _u * 0.014, Paint()..color = AppColors.gold);
    }
  }

  void _chandelierShape(Canvas canvas, double bottom, bool landed) {
    final x = _victimX;
    final ink = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = _u * 0.04
      ..strokeCap = StrokeCap.round;
    if (!landed) canvas.drawLine(Offset(x, bottom - _u * 0.85), Offset(x, bottom - _u * 2.6), ink);
    final squash = landed ? 0.55 : 1.0;
    for (final (width, lift) in [(1.30, 0.20), (0.94, 0.44), (0.56, 0.66)]) {
      final y = bottom - _u * lift * squash;
      canvas.drawArc(
        Rect.fromCenter(center: Offset(x, y - _u * 0.10), width: _u * width, height: _u * 0.36 * squash),
        0,
        pi,
        false,
        ink,
      );
      for (var i = 0; i < 6; i++) {
        final cx = x - _u * width / 2 + _u * width * i / 5;
        final candle = Offset(cx, y - _u * 0.12);
        canvas.drawCircle(candle, _u * 0.03, Paint()..color = _warm.withValues(alpha: landed ? 0.25 : 0.95));
        if (!landed) {
          canvas.drawCircle(
            candle,
            _u * 0.07,
            Paint()
              ..color = _warm.withValues(alpha: 0.25)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, _u * 0.03),
          );
        }
      }
    }
  }

  void _blast(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    final boom = _span(t, strike, strike + 0.12);
    final gone = t >= strike;
    final centre = Offset(_victimX + _u * 0.15, _ground - _u * 0.55);

    _killerSalute(canvas);
    _wall(canvas);

    // La bruciatura resta sull'asfalto.
    if (gone) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(_victimX, _ground + _u * 0.04), width: _u * 1.6, height: _u * 0.18),
        Paint()..color = Colors.black.withValues(alpha: 0.8),
      );
    }

    if (!gone) {
      final curious = _smooth(_span(t, 0.36, 0.44));
      _victim(
        canvas,
        x: walkX,
        walk: walk,
        stride: stride,
        lean: 0.10 * curious,
        arm: _mix(0.5, 1.15, curious),
        elbow: _mix(0.6, 0.9, curious),
        prop: _Prop.box,
      );
      // La miccia sfrigola: chi guarda capisce prima della vittima.
      final fuse = _span(t, 0.40, strike);
      if (fuse > 0) {
        _star(
          canvas,
          Offset(_victimX + _u * 0.40, _ground - _u * 0.60),
          _u * (0.05 + 0.04 * sin(t * 500).abs()),
          const Color(0xFFFFF3C4).withValues(alpha: 0.6 + 0.4 * sin(t * 380).abs()),
        );
      }
    }

    if (boom > 0 && boom < 1) {
      final grow = Curves.easeOut.transform(boom);
      for (final (scale, color) in [
        (1.0, Color(0xFFFF6A2B)),
        (0.72, Color(0xFFFFB13B)),
        (0.42, Color(0xFFFFF3C4)),
      ]) {
        canvas.drawCircle(
          centre,
          _u * 1.5 * grow * scale,
          Paint()
            ..color = color.withValues(alpha: (1 - boom) * 0.95)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, _u * 0.05),
        );
      }
      _spray(canvas, centre, boom, seed: 5, color: const Color(0xFFFFB13B), count: 28, bias: Offset.zero, reach: 2.2);
    }
    // Il fumo sale, e alla fine dal cielo torna giù il cappello.
    for (var i = 0; i < 5; i++) {
      final life = _span(t, strike + 0.04 + i * 0.025, 0.86 + i * 0.02);
      _puff(
        canvas,
        centre + Offset((i - 2) * _u * 0.22, -_u * (0.2 + 1.3 * life) - i * _u * 0.05),
        life,
        size: 1.5,
        color: const Color(0xFF3A3836),
      );
    }
    final fallBack = _span(t, 0.68, 0.80);
    if (fallBack > 0) {
      _looseHat(
        canvas,
        Offset(_victimX - _u * 0.2, _mix(-_u * 1.4, _ground - _u * 0.03, Curves.easeIn.transform(fallBack))),
        fallBack < 1 ? fallBack * 9 : 0.2,
      );
      _shoes(canvas, _victimX + _u * 0.15);
    }
    _flash(canvas, _span(t, strike, strike + 0.08), strength: 1);
  }

  void _poison(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    final sip = _smooth(_span(t, 0.37, 0.44)) - _smooth(_span(t, 0.48, 0.52));
    final queasy = _span(t, 0.50, strike + 0.04);
    final fall = _span(t, strike + 0.04, strike + 0.16);
    final dropped = t >= strike;

    _killerSalute(canvas);
    _wall(canvas);

    _victim(
      canvas,
      x: walkX,
      walk: walk,
      stride: stride,
      fall: fall,
      lean: queasy > 0 ? sin(t * 110) * 0.16 * queasy : 0,
      arm: dropped ? 2.5 : _mix(0.9, 2.0, sip),
      elbow: dropped ? 1.1 : _mix(0.5, 1.2, sip),
      prop: dropped || t < 0.34 ? _Prop.none : _Prop.cup,
    );
    if (fall > 0.12) {
      final flight = _span(t, strike + 0.07, 0.82);
      _looseHat(canvas, Offset(_victimX - _u * (0.30 + 0.90 * flight), _ground - _u * 0.03), flight < 1 ? -flight * 7 : -0.2);
    }

    // La tazzina cade, va in pezzi, e quello che c'era dentro non era caffè.
    if (dropped) {
      final tumble = Curves.easeIn.transform(_span(t, strike, strike + 0.04));
      final spot = Offset(_victimX + _u * 0.36, _ground - _u * 0.02);
      if (tumble < 1) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(spot.dx, _mix(_ground - _u * 0.98, spot.dy, tumble)), width: _u * 0.065, height: _u * 0.055),
            Radius.circular(_u * 0.012),
          ),
          Paint()..color = AppColors.textPrimary,
        );
      } else {
        _spray(canvas, spot, _span(t, strike + 0.04, strike + 0.16), seed: 4, color: AppColors.textPrimary, count: 8, bias: const Offset(0, -0.6), reach: 0.5);
        canvas.drawOval(
          Rect.fromCenter(center: spot.translate(0, _u * 0.06), width: _u * 0.46 * _span(t, strike + 0.04, 0.80), height: _u * 0.055),
          Paint()..color = const Color(0xFF6FBF4A).withValues(alpha: 0.85),
        );
      }
    }
  }

  void _noose(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    final lower = Curves.easeOut.transform(_span(t, 0.37, 0.52));
    final hoist = _smooth(_span(t, strike, strike + 0.12));
    final lift = hoist * _u * 0.60;
    final calm = _span(t, 0.66, 0.86);
    final sway = sin(t * 26) * 0.12 * hoist * (1 - calm * 0.6);
    final caught = t >= strike - 0.02;

    _killerSalute(canvas);
    _wall(canvas);

    final neck = Offset(_victimX + sin(sway) * _u * 0.85, _ground - lift - _u * 0.88);
    final rope = Paint()
      ..color = const Color(0xFFC9B48A)
      ..strokeWidth = _u * 0.024
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final end = caught ? neck : Offset(_victimX, _mix(-_u * 1.2, _ground - _u * 1.20, lower));
    canvas.drawLine(Offset(_victimX, -_h), end, rope);
    canvas.drawOval(
      Rect.fromCenter(
        center: end.translate(0, caught ? 0 : _u * 0.11),
        width: _u * (caught ? 0.17 : 0.24),
        height: _u * (caught ? 0.07 : 0.26),
      ),
      rope,
    );

    if (hoist > 0) {
      _person(
        canvas,
        feet: Offset(walkX + sin(sway) * _u * 0.2, _ground - lift),
        tilt: sway,
        dangle: sin(t * 95) * 0.75 * (1 - calm) + 0.12,
        arm: 2.55,
        elbow: 1.5,
        backArm: 2.3,
        backElbow: 1.6,
        hat: victimHat,
        hatOn: hoist < 0.2,
      );
      if (hoist >= 0.2) {
        final dropHat = Curves.easeIn.transform(_span(t, strike + 0.03, strike + 0.10));
        _looseHat(
          canvas,
          Offset(_victimX - _u * 0.40 * dropHat, _mix(_ground - lift - _u, _ground - _u * 0.03, dropHat)),
          dropHat < 1 ? dropHat * 5 : 0.15,
        );
      }
    } else {
      final alarm = _span(t, 0.52, strike);
      _victim(
        canvas,
        x: walkX,
        walk: walk,
        stride: stride,
        arm: _mix(0.08, 2.3, alarm),
        elbow: _mix(0.2, 1.4, alarm),
      );
    }
  }

  void _grab(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    final drag = _smooth(_span(t, strike + 0.03, strike + 0.20));
    final held = t >= strike;

    for (final (gap, delay) in [(0.40, 0.0), (0.82, 0.035)]) {
      final come = _smooth(_span(t, 0.43 + delay, strike));
      final x = _mix(_mix(_hiddenX + _u * gap, _victimX + _u * gap, come), _hiddenX + _u * gap, drag);
      final moving = (come > 0 && come < 1) || (drag > 0 && drag < 1);
      _person(
        canvas,
        feet: Offset(x, _ground),
        facing: drag > 0.05 ? 1 : -1,
        walk: _prowl + gap * 5,
        stride: moving ? 0.9 : 0,
        lean: 0.10 * come * (1 - drag),
        arm: held && drag < 1 ? 1.45 : 0.1,
        elbow: held && drag < 1 ? 0.15 : 0.2,
        killer: true,
      );
    }

    // La vittima viene trascinata dietro il muro: per questo va disegnata prima.
    final victimX = _mix(walkX, _hiddenX, drag);
    if (!held) {
      _victim(canvas, x: walkX, facing: t < 0.37 ? 1 : -1, walk: walk, stride: stride);
    } else {
      _person(
        canvas,
        feet: Offset(victimX, _ground),
        facing: -1,
        tilt: 0.45,
        crouch: 0.35,
        arm: 2.2 + 0.4 * sin(t * 120),
        elbow: 0.5,
        backArm: -1.6 + 0.4 * cos(t * 130),
        hat: victimHat,
        hatOn: false,
      );
    }
    _wall(canvas);

    if (held) {
      _looseHat(canvas, Offset(_victimX - _u * 0.25, _ground - _u * 0.03), 0.2);
      // I tacchi che strisciano sull'asfalto.
      final heels = Paint()
        ..color = Colors.black.withValues(alpha: 0.6)
        ..strokeWidth = _u * 0.02;
      for (final dy in [0.03, 0.07]) {
        canvas.drawLine(
          Offset(_victimX, _ground + _u * dy),
          Offset(min(victimX, _cornerX), _ground + _u * dy),
          heels,
        );
      }
    }
    // Da dietro l'angolo: un tonfo, e la polvere del cemento.
    _puff(canvas, Offset(_cornerX + _u * 0.05, _ground - _u * 0.25), _span(t, strike + 0.22, strike + 0.36), size: 1.6, color: const Color(0xFFB9B4AC));
    _puff(canvas, Offset(_cornerX + _u * 0.20, _ground - _u * 0.8), _span(t, strike + 0.25, strike + 0.40), size: 1.4, color: const Color(0xFFB9B4AC));
  }

  // ------------------------------------------------------------- nuove coreografie

  /// Le stelline che girano intorno alla testa di chi ha preso una botta.
  void _dizzy(Canvas canvas, Offset head, double life) {
    if (life <= 0 || life >= 1) return;
    for (var i = 0; i < 3; i++) {
      final angle = life * 16 + i * 2 * pi / 3;
      _star(
        canvas,
        head + Offset(cos(angle) * _u * 0.24, sin(angle) * _u * 0.07),
        _u * 0.055,
        AppColors.gold.withValues(alpha: (1 - life * life).clamp(0.0, 1.0)),
      );
    }
  }

  /// Il cappello che salta via quando la vittima va giù.
  void _hatOff(Canvas canvas, double from, double to, {double height = 0.9}) {
    final flight = _span(t, from, to);
    if (flight <= 0) return;
    _looseHat(
      canvas,
      Offset(
        _victimX - _u * (0.30 + 0.92 * flight),
        _ground - _u * 0.03 - _u * height * sin(pi * min(1, flight * 1.6)) * (1 - flight),
      ),
      flight < 1 ? -flight * 9 : -0.2,
    );
  }

  void _bat(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    final peek = _smooth(_span(t, 0.38, 0.46));
    final dash = Curves.easeIn.transform(_span(t, 0.47, 0.54));
    final leave = _smooth(_span(t, 0.72, 0.86));
    final killerX = _mix(_mix(_mix(_hiddenX, _peekX, peek), _victimX + _u * 0.50, dash), _hiddenX, leave);
    final running = (dash > 0 && dash < 1) || (leave > 0 && leave < 1);
    final windUp = _span(t, 0.46, 0.54);
    final swing = Curves.easeOut.transform(_span(t, 0.54, strike + 0.015));
    final follow = _span(t, strike + 0.015, strike + 0.10);

    _person(
      canvas,
      feet: Offset(killerX, _ground),
      facing: leave > 0.08 ? 1 : -1,
      walk: _prowl,
      stride: running ? 1 : 0,
      lean: leave > 0 ? 0.04 : 0.10 * dash + 0.32 * swing * (1 - follow),
      crouch: 0.15 * swing * (1 - follow),
      arm: leave > 0 ? 2.5 : _mix(_mix(0.5, 2.6, windUp), 1.20, swing),
      elbow: leave > 0 ? 1.1 : _mix(_mix(2.3, 0.9, windUp), 0.05, swing),
      prop: _Prop.bat,
      killer: true,
    );
    _wall(canvas);

    final dazed = _span(t, strike, strike + 0.09);
    final fall = _span(t, strike + 0.08, strike + 0.19);
    _victim(
      canvas,
      x: walkX,
      facing: t < 0.37 ? 1 : -1,
      walk: walk,
      stride: stride,
      fall: fall,
      lean: dazed > 0 && fall == 0 ? sin(t * 100) * 0.16 : 0,
      smoking: t > 0.37 && t < strike,
    );
    _hatOff(canvas, strike, strike + 0.26, height: 1.5);
    _dizzy(canvas, Offset(_victimX, _ground - _u * 1.10), _span(t, strike, strike + 0.14));
    _spray(canvas, Offset(_victimX, _ground - _u * 0.95), _span(t, strike, strike + 0.10), seed: 31, color: _warm, count: 10, reach: 0.8);
    _flash(canvas, _span(t, strike, strike + 0.03), strength: 0.45);
  }

  void _lupara(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    final peek = _smooth(_span(t, 0.38, 0.46));
    final out = _smooth(_span(t, 0.46, 0.53));
    final leave = _smooth(_span(t, 0.74, 0.88));
    final killerX = _mix(_mix(_mix(_hiddenX, _peekX, peek), _cornerX + _u * 0.16, out), _hiddenX, leave);
    final bang = _span(t, strike, strike + 0.045);
    final recoil = bang > 0 && bang < 1 ? sin(pi * bang) : 0.0;

    _person(
      canvas,
      feet: Offset(killerX, _ground),
      facing: leave > 0.08 ? 1 : -1,
      walk: _prowl,
      stride: (out > 0 && out < 1) || (leave > 0 && leave < 1) ? 0.8 : 0,
      lean: leave > 0 ? 0.04 : 0.10 * out - 0.22 * recoil,
      arm: leave > 0 ? 0.3 : _mix(0.3, 1.38, out) + 0.55 * recoil,
      elbow: leave > 0 ? 0.2 : 0.18,
      backArm: leave > 0 ? -0.1 : _mix(-0.1, 1.50, out) + 0.4 * recoil,
      backElbow: 0.25,
      prop: _Prop.lupara,
      killer: true,
    );
    _wall(canvas);

    // La vittima non cade: decolla.
    final blown = _span(t, strike, strike + 0.14);
    _pool(canvas, Offset(_victimX - _u * 0.50, _ground + _u * 0.04), _smooth(_span(t, strike + 0.16, strike + 0.32)));
    if (blown <= 0 || blown >= 1) {
      _victim(
        canvas,
        x: walkX,
        facing: t < 0.37 ? 1 : -1,
        walk: walk,
        stride: stride,
        fall: blown,
        smoking: t > 0.37 && t < strike,
      );
    } else {
      _person(
        canvas,
        feet: Offset(_victimX, _ground - _u * 0.40 * sin(pi * blown)),
        facing: -1,
        tilt: -blown * pi / 2,
        crouch: 0.4,
        arm: 2.6,
        elbow: 0.2,
        backArm: -2.0,
        hat: victimHat,
        hatOn: false,
      );
    }
    _hatOff(canvas, strike, strike + 0.30, height: 1.9);

    final killerHeight = _u * 1.08;
    final muzzle = Offset(killerX - killerHeight * 0.64, _ground - killerHeight * 0.73);
    if (bang > 0 && bang < 1) {
      _star(canvas, muzzle, _u * 0.42 * (1 - bang * 0.4), const Color(0xFFFFF3C4).withValues(alpha: 1 - bang));
      _star(canvas, muzzle, _u * 0.26, const Color(0xFFFFB13B).withValues(alpha: 1 - bang));
      final pellets = Paint()
        ..color = _warm.withValues(alpha: 0.9 * (1 - bang))
        ..strokeWidth = _u * 0.012;
      for (var i = -3; i <= 3; i++) {
        final target = Offset(_victimX + _u * 0.05, _ground - _u * (0.70 + i * 0.09));
        canvas.drawLine(Offset.lerp(muzzle, target, bang * 0.5)!, Offset.lerp(muzzle, target, min(1, bang * 0.5 + 0.5))!, pellets);
      }
    }
    _puff(canvas, muzzle.translate(-_u * 0.1, -_u * 0.1), _span(t, strike + 0.02, strike + 0.20), size: 0.9);
    _spray(canvas, Offset(_victimX, _ground - _u * 0.74), _span(t, strike, strike + 0.22), seed: 41, count: 26, reach: 1.3);
    _flash(canvas, bang, strength: 0.75);
  }

  void _driveBy(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    const shots = [0.535, 0.552, 0.569, 0.586, 0.603, 0.620];
    final drive = _span(t, 0.40, 0.74);
    final frontX = _mix(-_w * 0.25, _w * 2.35, drive);
    final fall = _span(t, shots.last, shots.last + 0.09);

    _wall(canvas);
    var jolt = 0.0;
    for (final shot in shots) {
      final bang = _span(t, shot, shot + 0.016);
      if (bang > 0 && bang < 1) jolt = sin(pi * bang);
    }
    _pool(canvas, Offset(_victimX - _u * 0.50, _ground + _u * 0.04), _smooth(_span(t, 0.68, 0.80)));
    _victim(
      canvas,
      x: walkX,
      facing: t < 0.46 ? 1 : -1,
      walk: walk,
      stride: stride,
      fall: fall,
      lean: 0.18 * jolt,
      arm: t > 0.50 && fall == 0 ? 2.3 : 0.08,
      elbow: t > 0.50 && fall == 0 ? 0.6 : 0.2,
      smoking: t > 0.37 && t < 0.50,
    );
    _hatOff(canvas, shots.last, shots.last + 0.22);
    for (var i = 0; i < shots.length; i++) {
      _spray(canvas, Offset(_victimX, _ground - _u * 0.74), _span(t, shots[i], shots[i] + 0.12), seed: 50 + i, count: 7);
    }
    // L'ultimo colpo si porta via il lampione.
    _spray(
      canvas,
      Offset(_w * 0.26 + _u * 0.24, _ground - _u * 1.38),
      _span(t, 0.63, 0.74),
      seed: 60,
      color: _warm,
      count: 18,
      bias: const Offset(0, -0.3),
      reach: 0.9,
    );

    // L'auto passa davanti a tutto, e dal finestrino spunta la canna.
    if (drive > 0 && drive < 1) {
      canvas.save();
      canvas.translate(0, _u * 0.15);
      _sedan(canvas, frontX);
      final window = Offset(frontX - _u * 1.22, _ground - _u * 0.66);
      canvas.drawLine(
        window,
        window.translate(-_u * 0.03, -_u * 0.20),
        Paint()
          ..color = _gunmetal
          ..strokeWidth = _u * 0.04
          ..strokeCap = StrokeCap.round,
      );
      for (final shot in shots) {
        final bang = _span(t, shot, shot + 0.016);
        if (bang > 0 && bang < 1) {
          _star(canvas, window.translate(-_u * 0.03, -_u * 0.26), _u * 0.22, const Color(0xFFFFF3C4).withValues(alpha: 1 - bang));
          _flash(canvas, bang, strength: 0.35);
        }
      }
      canvas.restore();
    }
  }

  void _garrote(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    final peek = _smooth(_span(t, 0.38, 0.45));
    final creep = _smooth(_span(t, 0.46, 0.55));
    final choke = _span(t, strike, 0.70);
    final limp = _smooth(_span(t, 0.66, 0.72));
    final leave = _smooth(_span(t, 0.76, 0.88));
    final killerX = _mix(_mix(_mix(_hiddenX, _peekX, peek), _victimX + _u * 0.38, creep), _hiddenX, leave);
    final gripping = choke > 0 && limp < 1;

    _person(
      canvas,
      feet: Offset(killerX, _ground),
      facing: leave > 0.08 ? 1 : -1,
      walk: _prowl * 0.7,
      stride: (creep > 0 && creep < 1) ? 0.55 : (leave > 0 && leave < 1 ? 0.9 : 0),
      crouch: 0.28 * creep * (1 - _span(t, 0.55, strike)),
      lean: gripping ? -0.16 : 0.08 * creep * (1 - leave),
      arm: gripping ? 0.9 : (leave > 0 ? 0.1 : _mix(0.2, 2.2, _span(t, 0.53, strike))),
      elbow: gripping ? 1.9 : 0.5,
      backArm: gripping ? 1.05 : (leave > 0 ? -0.1 : _mix(-0.1, 2.3, _span(t, 0.53, strike))),
      backElbow: gripping ? 1.8 : 0.5,
      killer: true,
    );
    _wall(canvas);

    if (!gripping) {
      _victim(
        canvas,
        x: walkX,
        facing: t < 0.37 ? 1 : -1,
        walk: walk,
        stride: stride,
        fall: _span(t, 0.72, 0.82),
        smoking: t > 0.37 && t < strike,
      );
    } else {
      // Sollevata quasi da terra, scalcia finché ha fiato.
      final fight = 1 - limp;
      _person(
        canvas,
        feet: Offset(_victimX, _ground - _u * 0.05 * fight),
        facing: -1,
        tilt: 0.10,
        walk: t * 420,
        stride: 0.55 * fight * (1 - choke * 0.5),
        crouch: 0.25 * limp,
        arm: _mix(2.55, 0.4, limp),
        elbow: _mix(1.5, 0.3, limp),
        backArm: _mix(2.3, -0.2, limp),
        backElbow: 1.5 * fight,
        hat: victimHat,
        hatOn: false,
      );
      canvas.drawLine(
        Offset(killerX - _u * 0.20, _ground - _u * 0.97),
        Offset(_victimX - _u * 0.03, _ground - _u * 0.91),
        Paint()
          ..color = _steel
          ..strokeWidth = _u * 0.014
          ..strokeCap = StrokeCap.round,
      );
    }
    _hatOff(canvas, strike, strike + 0.20, height: 0.5);
  }

  void _flowerPot(Canvas canvas, Offset center, double spin) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(spin);
    for (final (dx, dy) in [(-0.10, -0.20), (0.0, -0.26), (0.10, -0.20)]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(_u * dx, _u * (dy + 0.08)), width: _u * 0.10, height: _u * 0.17),
        Paint()..color = const Color(0xFF3E7B3A),
      );
      canvas.drawCircle(Offset(_u * dx, _u * dy), _u * 0.05, Paint()..color = const Color(0xFFD9303C));
    }
    canvas.drawPath(
      Path()
        ..moveTo(-_u * 0.13, -_u * 0.09)
        ..lineTo(_u * 0.13, -_u * 0.09)
        ..lineTo(_u * 0.09, _u * 0.12)
        ..lineTo(-_u * 0.09, _u * 0.12)
        ..close(),
      Paint()..color = const Color(0xFFB5552E),
    );
    canvas.drawRect(
      Rect.fromLTRB(-_u * 0.15, -_u * 0.11, _u * 0.15, -_u * 0.06),
      Paint()..color = const Color(0xFFCB6A3F),
    );
    canvas.restore();
  }

  void _pot(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    final drop = Curves.easeIn.transform(_span(t, 0.46, strike));
    final landed = t >= strike;

    _killerSalute(canvas);
    _wall(canvas);

    final dazed = _span(t, strike, strike + 0.10);
    final fall = _span(t, strike + 0.09, strike + 0.20);
    _victim(
      canvas,
      x: walkX,
      walk: walk,
      stride: stride,
      fall: fall,
      lean: dazed > 0 && fall == 0 ? sin(t * 95) * 0.15 : 0,
      smoking: t > 0.37 && !landed,
    );
    if (!landed) {
      if (drop > 0) _flowerPot(canvas, Offset(_victimX + _u * 0.03, _mix(-_u * 2.0, _ground - _u * 1.22, drop)), drop * 5);
    } else {
      final head = Offset(_victimX, _ground - _u * 1.05);
      _spray(canvas, head, _span(t, strike, strike + 0.18), seed: 71, color: const Color(0xFFB5552E), count: 14, bias: const Offset(0, -0.7), reach: 0.9);
      _spray(canvas, head, _span(t, strike, strike + 0.22), seed: 72, color: const Color(0xFFD9303C), count: 10, bias: const Offset(0.2, -0.9), reach: 1.1);
      _spray(canvas, head, _span(t, strike, strike + 0.16), seed: 73, color: const Color(0xFF3A2A1C), count: 12, bias: const Offset(-0.1, -0.5), reach: 0.7);
      _dizzy(canvas, head, _span(t, strike + 0.01, strike + 0.14));
    }
    _hatOff(canvas, strike + 0.09, strike + 0.30, height: 0.6);
    _flash(canvas, _span(t, strike, strike + 0.03), strength: 0.3);
  }

  void _manhole(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    final open = _smooth(_span(t, 0.50, 0.555));
    final drop = Curves.easeIn.transform(_span(t, strike, strike + 0.07));
    final close = _smooth(_span(t, strike + 0.13, strike + 0.19));
    final slide = (open - close) * _u * 0.62;
    final hole = Rect.fromCenter(center: Offset(_victimX, _ground + _u * 0.045), width: _u * 0.66, height: _u * 0.11);

    _killerSalute(canvas);
    _wall(canvas);

    if (open > 0) canvas.drawOval(hole, Paint()..color = Colors.black);
    // Il chiusino: scivola via, e poi torna al suo posto.
    final lid = hole.shift(Offset(slide, -_u * 0.012));
    canvas.drawOval(lid, Paint()..color = const Color(0xFF2B2D34));
    canvas.drawOval(
      lid.deflate(_u * 0.02),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _u * 0.012
        ..color = const Color(0xFF4A4D57),
    );
    for (final dx in [-0.16, 0.0, 0.16]) {
      canvas.drawLine(
        lid.center.translate(_u * dx, -_u * 0.025),
        lid.center.translate(_u * dx, _u * 0.025),
        Paint()
          ..color = const Color(0xFF4A4D57)
          ..strokeWidth = _u * 0.012,
      );
    }

    if (drop < 1) {
      // Un attimo sospesa nel vuoto, come nei cartoni, poi giù.
      final aware = _span(t, 0.535, strike);
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(-_w, -_h * 2, _w * 3, _ground + _u * 0.05));
      _person(
        canvas,
        feet: Offset(walkX, _ground + drop * _u * 1.25),
        walk: walk,
        stride: stride,
        lean: 0.14 * aware * (1 - drop),
        arm: _mix(0.08, 2.9, max(aware * 0.4, drop)),
        elbow: 0.3,
        backArm: _mix(-0.1, -2.6, drop),
        hat: victimHat,
        hatOn: drop <= 0,
        smoking: t > 0.37 && t < 0.52,
      );
      canvas.restore();
      if (aware > 0 && drop <= 0) _mark(canvas, '?', Offset(_victimX + _u * 0.28, _ground - _u * 1.36));
    }
    // Il cappello resta in aria, poi si posa sul chiusino.
    if (drop > 0) {
      final settle = Curves.easeIn.transform(_span(t, strike + 0.05, strike + 0.20));
      _looseHat(
        canvas,
        Offset(_victimX + _u * 0.02, _mix(_ground - _u * 1.02, _ground - _u * 0.045, settle)),
        sin(settle * pi) * 0.35,
      );
    }
    _spray(
      canvas,
      hole.center,
      _span(t, strike + 0.07, strike + 0.20),
      seed: 81,
      color: const Color(0xFF7FA8C9),
      count: 16,
      bias: const Offset(0, -1.1),
      reach: 0.9,
    );
  }

  void _blackout(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    final creep = _smooth(_span(t, 0.50, strike));
    final leave = _smooth(_span(t, 0.585, 0.655));
    final killerX = _mix(_mix(_hiddenX, _victimX + _u * 0.42, creep), _hiddenX, leave);
    final night = 1 - _lampPower;

    _person(
      canvas,
      feet: Offset(killerX, _ground),
      facing: leave > 0.05 ? 1 : -1,
      walk: _prowl,
      stride: (creep > 0 && creep < 1) || (leave > 0 && leave < 1) ? 1 : 0,
      arm: leave > 0 ? 0.1 : 2.4,
      elbow: 0.6,
      prop: _Prop.knife,
      killer: true,
    );
    _wall(canvas);
    _pool(canvas, Offset(_victimX - _u * 0.50, _ground + _u * 0.04), _smooth(_span(t, 0.70, 0.84)));
    _victim(
      canvas,
      x: walkX,
      facing: t < 0.37 ? 1 : -1,
      walk: walk,
      stride: stride,
      fall: _span(t, strike, strike + 0.07),
      lean: t > 0.44 && t < 0.50 ? -0.08 : 0,
      smoking: t > 0.37 && t < strike,
    );
    if (t > strike + 0.07) _looseHat(canvas, Offset(_victimX - _u * 1.15, _ground - _u * 0.03), -0.2);

    // Il buio: nel nero restano solo due occhi, una brace e un lampo d'acciaio.
    if (night > 0) {
      canvas.drawRect(
        Rect.fromLTWH(-_w * 2, -_h * 2, _w * 5, _h * 5),
        Paint()..color = Colors.black.withValues(alpha: 0.90 * night),
      );
    }
    if (night > 0.5) {
      final killerHeight = _u * 1.08;
      final facing = leave > 0.05 ? 1 : -1;
      final eyes = Offset(killerX + facing * killerHeight * 0.075, _ground - killerHeight * 0.995);
      final glint = Paint()..color = const Color(0xFFFFF3C4);
      canvas.drawCircle(eyes, _u * 0.014, glint);
      canvas.drawCircle(eyes.translate(-facing * _u * 0.045, 0), _u * 0.014, glint);
      if (t < strike) {
        canvas.drawCircle(Offset(_victimX - _u * 0.185, _ground - _u * 0.923), _u * 0.016, Paint()..color = const Color(0xFFFF7A3B));
      }
      final blow = _span(t, strike, strike + 0.03);
      if (blow > 0 && blow < 1) {
        canvas.drawArc(
          Rect.fromCircle(center: Offset(_victimX + _u * 0.22, _ground - _u * 0.72), radius: _u * 0.46),
          pi * 0.92,
          pi * 0.62 * blow,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = _u * 0.035
            ..strokeCap = StrokeCap.round
            ..color = Colors.white.withValues(alpha: 1 - blow),
        );
      }
    }
  }

  void _heart(Canvas canvas, Offset center, double size, Color color) {
    canvas.drawPath(
      Path()
        ..moveTo(center.dx, center.dy + size * 0.55)
        ..cubicTo(center.dx - size * 1.1, center.dy - size * 0.1, center.dx - size * 0.55, center.dy - size * 0.85, center.dx, center.dy - size * 0.30)
        ..cubicTo(center.dx + size * 0.55, center.dy - size * 0.85, center.dx + size * 1.1, center.dy - size * 0.1, center.dx, center.dy + size * 0.55)
        ..close(),
      Paint()..color = color,
    );
  }

  void _kiss(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    final come = _smooth(_span(t, 0.37, 0.51));
    final leanIn = _smooth(_span(t, 0.51, strike)) - _smooth(_span(t, strike + 0.03, strike + 0.07));
    final leave = _smooth(_span(t, 0.66, 0.84));
    final dameX = _mix(_mix(_hiddenX, _victimX + _u * 0.36, come), _hiddenX, leave);
    final strolling = (come > 0 && come < 1) || (leave > 0 && leave < 1);
    final blowsKiss = _span(t, 0.62, 0.66) * (1 - leave);

    _person(
      canvas,
      feet: Offset(dameX, _ground),
      facing: leave > 0.08 ? 1 : -1,
      walk: t * 150,
      stride: strolling ? 0.55 : 0,
      lean: 0.20 * leanIn,
      arm: _mix(0.1, 1.85, max(leanIn, blowsKiss)),
      elbow: _mix(0.2, 0.9, max(leanIn, blowsKiss)),
      dame: true,
    );
    _wall(canvas);

    final tipsHat = _span(t, 0.43, 0.47) - _span(t, 0.49, 0.52);
    final queasy = _span(t, 0.60, 0.66);
    final fall = _span(t, 0.66, 0.77);
    _victim(
      canvas,
      x: walkX,
      walk: walk,
      stride: stride,
      fall: fall,
      lean: 0.18 * leanIn + (queasy > 0 && fall == 0 ? sin(t * 110) * 0.14 * queasy : 0),
      arm: _mix(0.08, 2.35, tipsHat),
      elbow: _mix(0.2, 1.3, tipsHat),
    );
    _hatOff(canvas, 0.68, 0.84, height: 0.5);

    // Il cuore sale rosso, e mentre sale cambia colore.
    final love = _span(t, strike, 0.68);
    if (love > 0 && love < 1) {
      _heart(
        canvas,
        Offset(_victimX + _u * 0.18 + sin(love * 9) * _u * 0.04, _ground - _u * (1.15 + 0.55 * love)),
        _u * (0.10 + 0.05 * sin(love * 30).abs()),
        Color.lerp(const Color(0xFFE23A4A), const Color(0xFF6FBF4A), _span(love, 0.35, 0.8))!.withValues(alpha: 1 - love * love),
      );
    }
  }

  // ------------------------------------------------------------------ dopo

  /// Il dettaglio finale del copione, messo in scena: il gatto che passa, le
  /// sirene che arrivano tardi, una carta lasciata lì, la musica dal bar.
  void _aftermath(Canvas canvas) {
    switch (epilogue) {
      case 'gatto':
        final stroll = _span(t, 0.66, 0.86);
        if (stroll > 0) _cat(canvas, _mix(_w * 1.15, -_w * 0.25, stroll), t * 260);
      case 'sirene':
        final arriving = _span(t, 0.68, 0.84);
        if (arriving > 0) {
          final red = (t * 70).floor().isEven;
          canvas.drawCircle(
            Offset(-_u * 0.3, _ground - _u * 0.5),
            _u * (1.2 + 1.6 * arriving),
            Paint()
              ..color = (red ? const Color(0xFFE23A4A) : const Color(0xFF3B6BFF)).withValues(alpha: 0.30 * arriving)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, _u * 0.5),
          );
        }
      case 'carta':
        final flutter = _span(t, 0.66, 0.76);
        if (flutter > 0) {
          final landed = flutter >= 1;
          canvas.save();
          canvas.translate(
            _victimX + _u * (0.55 - 0.15 * flutter) + sin(flutter * 12) * _u * 0.10 * (1 - flutter),
            _mix(_ground - _u * 1.1, _ground - _u * 0.02, Curves.easeIn.transform(flutter)),
          );
          canvas.rotate(landed ? 0.25 : flutter * 7);
          canvas.scale(1, landed ? 0.35 : 1);
          final card = RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: _u * 0.12, height: _u * 0.17),
            Radius.circular(_u * 0.015),
          );
          canvas.drawRRect(card, Paint()..color = const Color(0xFF6E161E));
          canvas.drawRRect(
            card.deflate(_u * 0.012),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = _u * 0.008
              ..color = AppColors.gold,
          );
          canvas.restore();
        }
      case 'mambo':
        for (var i = 0; i < 3; i++) {
          final rise = _span(t, 0.62 + i * 0.05, 0.80 + i * 0.03);
          if (rise <= 0 || rise >= 1) continue;
          final note = Offset(
            _cornerX + _u * (0.10 - 0.55 * rise) + sin(rise * 10 + i) * _u * 0.05,
            _ground - _u * (1.70 + 0.55 * rise),
          );
          final paint = Paint()..color = _warm.withValues(alpha: 1 - rise);
          canvas.drawOval(Rect.fromCenter(center: note, width: _u * 0.07, height: _u * 0.05), paint);
          canvas.drawLine(
            note.translate(_u * 0.03, 0),
            note.translate(_u * 0.03, -_u * 0.14),
            paint..strokeWidth = _u * 0.012,
          );
          canvas.drawLine(note.translate(_u * 0.03, -_u * 0.14), note.translate(_u * 0.08, -_u * 0.10), paint);
        }
    }
  }

  void _cat(Canvas canvas, double x, double step) {
    final ink = Paint()..color = _ink;
    final legs = Paint()
      ..color = _ink
      ..strokeWidth = _u * 0.022
      ..strokeCap = StrokeCap.round;
    final y = _ground - _u * 0.13;
    for (final (dx, phase) in [(-0.10, 0.0), (-0.06, pi), (0.08, pi), (0.12, 0.0)]) {
      canvas.drawLine(
        Offset(x + _u * dx, y + _u * 0.02),
        Offset(x + _u * dx + sin(step + phase) * _u * 0.04, _ground),
        legs,
      );
    }
    canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: _u * 0.32, height: _u * 0.11), ink);
    final head = Offset(x - _u * 0.19, y - _u * 0.06);
    canvas.drawCircle(head, _u * 0.058, ink);
    for (final dx in [-0.04, 0.03]) {
      canvas.drawPath(
        Path()
          ..moveTo(head.dx + _u * (dx - 0.022), head.dy - _u * 0.035)
          ..lineTo(head.dx + _u * dx, head.dy - _u * 0.105)
          ..lineTo(head.dx + _u * (dx + 0.022), head.dy - _u * 0.035)
          ..close(),
        ink,
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(x + _u * 0.15, y)
        ..quadraticBezierTo(x + _u * 0.30, y - _u * 0.02, x + _u * 0.27, y - _u * (0.24 + 0.03 * sin(step * 0.3))),
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = _u * 0.028
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(head.translate(-_u * 0.025, -_u * 0.005), _u * 0.011, Paint()..color = const Color(0xFFE8D24A));
  }

  /// Il sipario di velluto che cala sulla scena.
  void _curtain(Canvas canvas, double drop) {
    if (drop <= 0) return;
    final bottom = _h * 1.08 * Curves.easeIn.transform(drop);
    final folds = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF6A0F17), Color(0xFF9C1B26), Color(0xFF5A0C13), Color(0xFF9C1B26), Color(0xFF6A0F17)],
        tileMode: TileMode.repeated,
      ).createShader(Rect.fromLTWH(0, 0, _w / 3, _h));
    final path = Path()
      ..moveTo(0, -10)
      ..lineTo(_w, -10)
      ..lineTo(_w, bottom);
    const scallops = 6;
    for (var i = scallops; i > 0; i--) {
      final right = _w * i / scallops;
      final left = _w * (i - 1) / scallops;
      path.quadraticBezierTo((left + right) / 2, bottom + _h * 0.035, left, bottom);
    }
    path.close();
    canvas.drawPath(path, folds);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.gold.withValues(alpha: 0.8),
    );
  }

  /// La parola da fumetto che scoppia sul colpo.
  void _sfx(Canvas canvas) {
    final (word, from, length) = switch (act) {
      DeathAct.knife => ('ZAC!', strike, 0.12),
      DeathAct.gun => ('BANG!', strike, 0.12),
      DeathAct.burst => ('RATATATA!', 0.55, 0.16),
      DeathAct.car => ('SBAM!', strike, 0.14),
      DeathAct.piano => ('KLONG!', strike, 0.14),
      DeathAct.safe => ('THUD!', strike, 0.14),
      DeathAct.chandelier => ('CRASH!', strike, 0.14),
      DeathAct.blast => ('BOOM!', strike, 0.16),
      DeathAct.poison => ('COFF!', 0.52, 0.10),
      DeathAct.noose => ('GACK!', strike, 0.12),
      DeathAct.grab => ('MMPH!', strike, 0.12),
      DeathAct.bat => ('CRACK!', strike, 0.12),
      DeathAct.lupara => ('BOOM!', strike, 0.14),
      DeathAct.driveBy => ('RATATATA!', 0.535, 0.14),
      DeathAct.garrote => ('GHHK!', strike, 0.12),
      DeathAct.pot => ('BONK!', strike, 0.12),
      DeathAct.manhole => ('CLANG!', strike + 0.17, 0.12),
      DeathAct.blackout => ('ZAC!', strike, 0.10),
      DeathAct.kiss => ('SMACK!', strike, 0.12),
      DeathAct.sniper => ('PAM!', strike, 0.12),
      DeathAct.rescue => ('BANG!', strike, 0.10),
      DeathAct.lucky => ('DING!', strike, 0.12),
    };
    _word(canvas, word, from, length, act == DeathAct.kiss ? const Color(0xFFFF7AA8) : const Color(0xFFFFE27A));
    // Il cuore che riparte.
    if (act == DeathAct.rescue) _word(canvas, 'TU-TUM!', 0.765, 0.09, const Color(0xFF8BE0A4));
  }

  void _word(Canvas canvas, String word, double from, double length, Color fill) {
    final life = _span(t, from, from + length);
    if (life <= 0 || life >= 1) return;

    final pop = Curves.easeOutBack.transform(min(1, life / 0.2));
    final fade = 1 - Curves.easeIn.transform(_span(life, 0.6, 1));
    final size = _u * (word.length > 6 ? 0.21 : 0.38);

    TextPainter letters({Paint? outline, Color? color}) => TextPainter(
          text: TextSpan(
            text: word,
            style: TextStyle(
              fontSize: size,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              letterSpacing: size * 0.02,
              foreground: outline,
              color: color,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

    canvas.save();
    canvas.translate(_victimX + _u * 0.05, _ground - _u * 1.62);
    canvas.rotate(-0.13);
    canvas.scale(0.45 + 0.55 * pop + 0.10 * life);
    final edge = letters(
      outline: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.20
        ..strokeJoin = StrokeJoin.round
        ..color = _ink.withValues(alpha: fade),
    );
    final origin = Offset(-edge.width / 2, -edge.height / 2);
    edge.paint(canvas, origin);
    letters(color: _blood.withValues(alpha: fade)).paint(canvas, origin.translate(size * 0.05, size * 0.05));
    letters(color: fill.withValues(alpha: fade)).paint(canvas, origin);
    canvas.restore();
  }

  /// Il filo di fumo di una sigaretta accesa.
  void _wisp(Canvas canvas, Offset from) {
    final path = Path()..moveTo(from.dx, from.dy);
    for (var i = 1; i <= 6; i++) {
      path.lineTo(from.dx + sin(t * 70 + i * 0.9) * _u * 0.012 * i, from.dy - i * _u * 0.07);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _u * 0.018
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  // ------------------------------------------------------- scene legate ai fatti

  /// Un segno da fumetto sopra una testa: stupore, o un dubbio.
  void _mark(Canvas canvas, String text, Offset at) {
    final mark = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Georgia',
          fontSize: _u * 0.34,
          fontWeight: FontWeight.w900,
          color: AppColors.gold,
          shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    mark.paint(canvas, at.translate(-mark.width / 2, -mark.height / 2));
  }

  /// La borsa del Dottore, con la croce verde che la fa riconoscere.
  void _bag(Canvas canvas, Offset center, double h) {
    canvas.drawArc(
      Rect.fromCenter(center: center.translate(0, -h * 0.07), width: h * 0.10, height: h * 0.08),
      pi,
      pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.016
        ..color = const Color(0xFF3A2414),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: h * 0.22, height: h * 0.14),
        Radius.circular(h * 0.03),
      ),
      Paint()..color = const Color(0xFF6B4423),
    );
    canvas.drawCircle(center, h * 0.046, Paint()..color = const Color(0xFFE9E4D8));
    _cross(canvas, center, h * 0.030);
  }

  void _cross(Canvas canvas, Offset center, double arm) {
    final green = Paint()
      ..color = const Color(0xFF2E9E5B)
      ..strokeWidth = arm * 0.62;
    canvas.drawLine(center.translate(-arm, 0), center.translate(arm, 0), green);
    canvas.drawLine(center.translate(0, -arm), center.translate(0, arm), green);
  }

  /// Chi spara da dietro l'angolo con la pistola, e poi sparisce a [leaveAt].
  /// Restituisce dove si trova, per chi deve disegnargli qualcosa addosso.
  double _gunman(Canvas canvas, {required double leaveAt, double puzzled = 0}) {
    final peek = _smooth(_span(t, 0.38, 0.46));
    final out = _smooth(_span(t, 0.46, 0.53));
    final leave = _smooth(_span(t, leaveAt, leaveAt + 0.08));
    final killerX = _mix(_mix(_mix(_hiddenX, _peekX, peek), _cornerX - _u * 0.10, out), _hiddenX, leave);
    final bang = _span(t, strike, strike + 0.025);
    final kick = bang > 0 && bang < 1 ? sin(pi * bang) : 0.0;

    _person(
      canvas,
      feet: Offset(killerX, _ground),
      facing: leave > 0.08 ? 1 : -1,
      walk: _prowl,
      stride: (out > 0 && out < 1) || (leave > 0 && leave < 1) ? 0.9 : 0,
      lean: leave > 0 ? 0.05 : 0.10 * out - 0.05 * kick + 0.14 * puzzled,
      arm: leave > 0 ? 0.1 : _mix(_mix(0.2, pi / 2, out) + 0.16 * kick, 0.9, puzzled),
      elbow: leave > 0 ? 0.2 : _mix(0.03, 0.9, puzzled),
      prop: _Prop.pistol,
      killer: true,
    );

    final killerHeight = _u * 1.08;
    final muzzle = Offset(killerX - killerHeight * 0.56, _ground - killerHeight * 0.83);
    if (bang > 0 && bang < 1) {
      _star(canvas, muzzle, _u * 0.24 * (1 - bang * 0.5), const Color(0xFFFFF3C4).withValues(alpha: 1 - bang));
      canvas.drawLine(
        muzzle,
        Offset(_victimX + _u * 0.08, _ground - _u * 0.72),
        Paint()
          ..color = _warm.withValues(alpha: 0.85 * (1 - bang))
          ..strokeWidth = _u * 0.014,
      );
    }
    final smoke = _span(t, strike + 0.02, strike + 0.12);
    if (smoke > 0 && smoke < 1) _puff(canvas, muzzle.translate(0, -_u * 0.25 * smoke), smoke, size: 0.4);
    return killerX;
  }

  /// Il colpo del Cecchino: nessuno dietro l'angolo, solo una finestra buia,
  /// il riflesso di una lente e un mirino che trova il bersaglio.
  void _sniper(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    _wall(canvas);

    final fall = _span(t, strike + 0.01, strike + 0.11);
    _pool(canvas, Offset(_victimX - _u * 0.50, _ground + _u * 0.04), _smooth(_span(t, 0.67, 0.84)));
    _victim(
      canvas,
      x: walkX,
      facing: t < 0.37 ? 1 : -1,
      walk: walk,
      stride: stride,
      fall: fall,
      smoking: t > 0.37 && t < strike,
    );
    _hatOff(canvas, strike + 0.01, strike + 0.24, height: 1.2);

    final nest = Offset(_cornerX + _u * 0.19, _ground - _u * 1.66);
    final chest = Offset(_victimX + _u * 0.02, _ground - _u * 0.76);
    final glint = sin(pi * _span(t, 0.36, 0.43));
    if (glint > 0) _star(canvas, nest, _u * 0.10 * glint, Colors.white.withValues(alpha: glint));

    final aim = _smooth(_span(t, 0.39, 0.535));
    if (aim > 0 && t < strike + 0.02) {
      final wander = (1 - aim) * _u;
      final sight = chest + Offset(sin(t * 55) * 0.5 + 0.55, cos(t * 41) * 0.28 - 0.40) * wander;
      final radius = _u * _mix(0.36, 0.15, aim);
      final red = Paint()
        ..color = const Color(0xFFFF3B30).withValues(alpha: 0.9 * min(1, aim * 4))
        ..style = PaintingStyle.stroke
        ..strokeWidth = _u * 0.014;
      canvas.drawCircle(sight, radius, red);
      for (final side in const [Offset(1, 0), Offset(-1, 0), Offset(0, 1), Offset(0, -1)]) {
        canvas.drawLine(sight + side * (radius * 0.45), sight + side * (radius * 1.35), red);
      }
      canvas.drawCircle(sight, _u * 0.012, Paint()..color = red.color);
    }

    final bang = _span(t, strike, strike + 0.03);
    if (bang > 0 && bang < 1) {
      _star(canvas, nest, _u * 0.20 * (1 - bang * 0.5), const Color(0xFFFFF3C4).withValues(alpha: 1 - bang));
      canvas.drawLine(
        nest,
        chest,
        Paint()
          ..color = _warm.withValues(alpha: 0.9 * (1 - bang))
          ..strokeWidth = _u * 0.012,
      );
    }
    _puff(canvas, nest.translate(-_u * 0.05, -_u * 0.1), _span(t, strike + 0.02, strike + 0.16), size: 0.4);
    _spray(canvas, chest, _span(t, strike, strike + 0.20), seed: 91, count: 18);
    _flash(canvas, bang, strength: 0.4);
  }

  /// Un agguato andato a vuoto: il colpo parte, ma il Dottore arriva di corsa
  /// e chi era a terra si rialza.
  void _rescue(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    _gunman(canvas, leaveAt: 0.60);
    _wall(canvas);

    final bang = _span(t, strike, strike + 0.025);
    final fall = _span(t, strike + 0.01, strike + 0.07);
    final rise = _smooth(_span(t, 0.775, 0.845));
    final thanks = _smooth(_span(t, 0.845, 0.875));
    if (rise < 1) _hatOff(canvas, strike + 0.01, strike + 0.20, height: 0.9);

    final come = _span(t, 0.62, 0.71);
    final doctorX = _mix(-_w * 0.45, _victimX - _u * 1.02, Curves.easeOut.transform(come));
    final kneel = _smooth(_span(t, 0.71, 0.735)) - _smooth(_span(t, 0.80, 0.84));
    if (come > 0) {
      _person(
        canvas,
        feet: Offset(doctorX, _ground),
        walk: t * 300,
        stride: come < 1 ? 1 : 0,
        lean: come < 1 ? 0.22 : 0.45 * kneel,
        crouch: 0.9 * kneel,
        arm: come < 1 ? 0.3 : _mix(0.3, 1.25, kneel),
        elbow: 0.3,
        hat: AvatarHead.bowler,
        cloth: const Color(0xFFE9E4D8),
        prop: come < 1 ? _Prop.bag : _Prop.none,
      );
      if (come >= 1) _bag(canvas, Offset(doctorX - _u * 0.26, _ground - _u * 0.07), _u);
    }

    _victim(
      canvas,
      x: walkX,
      facing: t < 0.37 ? 1 : -1,
      walk: walk,
      stride: stride,
      fall: fall - rise,
      lean: bang > 0 && bang < 1 ? 0.20 * sin(pi * bang) : 0,
      arm: _mix(0.08, 2.35, thanks),
      elbow: _mix(0.2, 1.3, thanks),
      smoking: t > 0.37 && t < strike,
    );
    _spray(canvas, Offset(_victimX, _ground - _u * 0.74), _span(t, strike, strike + 0.16), seed: 95, count: 9);
    _flash(canvas, bang, strength: 0.4);

    // La cura: una croce che pulsa sopra il petto, e le scintille intorno.
    final cure = _span(t, 0.725, 0.80);
    if (cure > 0 && cure < 1) {
      final heart = Offset(_victimX - _u * 0.50, _ground - _u * (0.42 + 0.14 * cure));
      final pulse = 1 + 0.25 * sin(cure * pi * 6).abs();
      final fade = 1 - cure * cure;
      canvas.drawCircle(
        heart,
        _u * 0.30 * pulse,
        Paint()
          ..color = const Color(0xFF8BE0A4).withValues(alpha: 0.35 * fade)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, _u * 0.10),
      );
      canvas.drawCircle(heart, _u * 0.10 * pulse, Paint()..color = const Color(0xFFE9E4D8).withValues(alpha: fade));
      _cross(canvas, heart, _u * 0.065 * pulse);
      for (var i = 0; i < 5; i++) {
        final angle = cure * 5 + i * 2 * pi / 5;
        _star(
          canvas,
          heart + Offset(cos(angle), sin(angle) * 0.6) * (_u * (0.24 + 0.22 * cure)),
          _u * 0.04,
          AppColors.gold.withValues(alpha: fade),
        );
      }
    }
  }

  /// Un agguato andato a vuoto: il colpo si ferma sulla fiaschetta nel
  /// taschino, e chi doveva morire resta in piedi a guardarla.
  void _lucky(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    final puzzled = _smooth(_span(t, strike + 0.035, strike + 0.07)) - _smooth(_span(t, 0.655, 0.67));
    final killerX = _gunman(canvas, leaveAt: 0.67, puzzled: puzzled);
    _wall(canvas);
    if (puzzled > 0.5) _mark(canvas, '?!', Offset(killerX - _u * 0.05, _ground - _u * 1.52));

    final stagger = sin(pi * _span(t, strike, strike + 0.08));
    final show = _smooth(_span(t, 0.69, 0.75));
    _victim(
      canvas,
      x: walkX - _u * 0.10 * _smooth(_span(t, strike, strike + 0.05)),
      facing: t < 0.37 ? 1 : -1,
      walk: walk,
      stride: stride,
      lean: 0.34 * stagger,
      arm: _mix(0.08, 1.95, show),
      elbow: _mix(0.2, 0.85, show),
      prop: show > 0.1 ? _Prop.flask : _Prop.none,
      smoking: t > 0.37 && t < strike,
    );

    // La scintilla sul metallo, al posto del sangue.
    final chest = Offset(_victimX, _ground - _u * 0.74);
    final ding = _span(t, strike, strike + 0.05);
    if (ding > 0 && ding < 1) {
      _star(canvas, chest, _u * 0.30 * (1 - ding * 0.4), AppColors.gold.withValues(alpha: 1 - ding));
      _star(canvas, chest, _u * 0.16, Colors.white.withValues(alpha: 1 - ding));
    }
    _spray(canvas, chest, _span(t, strike, strike + 0.14), seed: 97, color: _warm, count: 12, reach: 0.8);
    _flash(canvas, _span(t, strike, strike + 0.03), strength: 0.4);
    if (show > 0.6) {
      final shine = sin(t * 60).abs();
      _star(
        canvas,
        Offset(_victimX - _u * 0.36, _ground - _u * 1.02),
        _u * 0.07 * shine,
        Colors.white.withValues(alpha: 0.9 * shine),
      );
    }
  }

  @override
  bool shouldRepaint(DeathScenePainter old) =>
      old.t != t || old.act != act || old.victimHat != victimHat || old.epilogue != epilogue;
}
