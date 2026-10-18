import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_strings.dart';
import '../../narration/death_story.dart';
import '../../sound/scene_cues.dart';
import '../../sound/sound_stage.dart';
import '../theme/app_theme.dart';
import 'city_backdrop.dart';
import 'noir_avatar.dart';
import 'particle_sprites.dart';
import 'victim_card.dart';
import '../press.dart';

part 'death_scenes_saves.dart';
part 'death_scenes_family.dart';
part 'death_scenes_spliced.dart';

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
  bowling,
  swordfish,
  harpoon,
  pie,
  trombone,
  tango,
  bouquet,
  laundry,

  /// Il colpo del Cecchino: da lontano, senza nessuno dietro l'angolo.
  sniper,

  /// Un agguato andato a vuoto: il Dottore arriva in tempo.
  rescue,

  /// Un agguato andato a vuoto: il colpo si ferma su qualcosa.
  lucky,

  // Le altre varianti del Cecchino, del Dottore e del colpo a vuoto: i
  // filmati stanno in death_scenes_saves.dart.
  belfry,
  phoneBooth,
  carDoor,
  defibrillator,
  pliers,
  ambulance,
  stitches,
  bible,
  jam,
  banana,
  blackCat;

  /// Le scene in cui arriva il Dottore e rimette in piedi chi era a terra.
  bool get doctorSaves => switch (this) {
    rescue || defibrillator || pliers || ambulance || stitches => true,
    _ => false,
  };

  /// Le scene in cui chi era nel mirino se la cava da solo.
  bool get luckyEscape => switch (this) {
    lucky || bible || jam || banana || blackCat => true,
    _ => false,
  };

  /// Le scene da cui chi era stato preso di mira esce sulle sue gambe.
  bool get survives => doctorSaves || luckyEscape;
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
  'boccia' => DeathAct.bowling,
  'pescespada' => DeathAct.swordfish,
  'arpione' => DeathAct.harpoon,
  'torta' => DeathAct.pie,
  'trombone' => DeathAct.trombone,
  'tango' => DeathAct.tango,
  'rose' => DeathAct.bouquet,
  'lavanderia' => DeathAct.laundry,
  DeathStory.sniperId => DeathAct.sniper,
  DeathStory.rescueId => DeathAct.rescue,
  DeathStory.luckyId => DeathAct.lucky,
  DeathStory.belfryId => DeathAct.belfry,
  DeathStory.phoneBoothId => DeathAct.phoneBooth,
  DeathStory.carDoorId => DeathAct.carDoor,
  DeathStory.defibrillatorId => DeathAct.defibrillator,
  DeathStory.pliersId => DeathAct.pliers,
  DeathStory.ambulanceId => DeathAct.ambulance,
  DeathStory.stitchesId => DeathAct.stitches,
  DeathStory.bibleId => DeathAct.bible,
  DeathStory.jamId => DeathAct.jam,
  DeathStory.bananaId => DeathAct.banana,
  DeathStory.blackCatId => DeathAct.blackCat,
  _ => DeathAct.knife,
};

/// Il filmato di una storia della notte: la coreografia dell'agguato e,
/// se è andato a vuoto, chi l'ha mandato a vuoto. Le storie senza agguato
/// della famiglia (il Cecchino, i salvataggi di una volta) hanno un filmato
/// solo.
({DeathAct act, DeathAct? save}) filmFor(DeathStory story) {
  final attack = story.attack;
  final act = deathActFor(story.method.id);
  if (attack == null) return (act: act, save: null);
  return (act: deathActFor(attack.id), save: act);
}

const _knots = [
  (0.0, 0.0),
  (0.23, 0.34),
  (0.465, 0.50),
  (0.70, 0.66),
  (0.90, 0.86),
  (1.0, 1.0),
];

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
  if (drift <= const Duration(milliseconds: 40) ||
      drift >= const Duration(milliseconds: 800)) {
    return null;
  }
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

  /// Chi manda a vuoto l'agguato di [act]: il Dottore (in una delle sue
  /// varianti) o un colpo di fortuna. Senza, l'agguato va come va [act].
  final DeathAct? save;
  final String victimName;

  /// La didascalia sotto la scena, come il cartello di un film muto.
  final String caption;

  /// Il dettaglio finale del copione (`gatto`, `sirene`, `sipario`...): le
  /// scene che sanno mostrarlo lo mostrano.
  final String epilogue;
  final SkylineStyle style;
  final VoidCallback onFinished;

  /// Online: il film va in onda per tutti nello stesso momento, deciso dal
  /// server. [startAt] è quanto ne è già passato quando questa scena parte
  /// (chi arriva in ritardo entra a metà). Così non si salta, non c'è il
  /// pulsante per andare avanti, e [onFinished] scatta da solo alla fine.
  final Duration? startAt;

  const DeathScene({
    super.key,
    required this.act,
    this.save,
    required this.victimName,
    required this.caption,
    required this.onFinished,
    this.epilogue = '',
    this.style = SkylineStyle.metropolis,
    this.startAt,
  });

  @override
  State<DeathScene> createState() => _DeathSceneState();
}

class _DeathSceneState extends State<DeathScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _film;
  late final List<SceneCue> _cues = sceneCuesFor(
    widget.act,
    save: widget.save,
    memes: SoundStage.instance.memeMode,
  );
  int _nextCue = 0;
  final List<Timer> _tuning = [];
  late final Future<ParticleSprites> _particles = ParticleSprites.shared;
  bool _struck = false;
  bool _ended = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    // Chi riduce le animazioni vede fermo il fondale, ma non questa scena: è
    // il racconto della notte, e accorciarla la renderebbe illeggibile.
    _film =
        AnimationController(
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
            if (status == AnimationStatus.completed) {
              setState(() => _ended = true);
              if (_synced) _finish();
            }
          });

    final startAt = widget.startAt;
    if (startAt != null) {
      // Si entra al punto giusto; la musica solo per chi arriva in tempo.
      final from = (startAt.inMicroseconds / DeathScene.length.inMicroseconds).clamp(0.0, 1.0);
      final t = filmTime(from);
      while (_nextCue < _cues.length && _cues[_nextCue].t < t) {
        _nextCue++;
      }
      _struck = t >= DeathScenePainter.strike;
      SoundStage.instance.duckMusic(true);
      if (startAt < const Duration(milliseconds: 700)) SoundStage.instance.playScene(widget.act);
      _film.forward(from: from);
      return;
    }

    // Il film parte quando parte la musica. Il palco muto risponde subito;
    // quello vero ci mette un attimo, e la scena lo aspetta (ma non per
    // sempre: senza audio si va in onda lo stesso).
    SoundStage.instance.duckMusic(true);
    final music = SoundStage.instance.playScene(widget.act);
    if (music is Future<void>) {
      music.timeout(const Duration(seconds: 4), onTimeout: () {}).whenComplete(
        () {
          if (!mounted || _ended) return;
          _film.forward();
          for (final after in const [300, 1000, 2400]) {
            _tuning.add(Timer(Duration(milliseconds: after), _tune));
          }
        },
      );
    } else {
      _film.forward();
    }
  }

  /// Rimette il film a tempo col nastro. Lo fa presto, mentre la vittima sta
  /// ancora camminando: lì un fotogramma saltato non lo nota nessuno, mentre
  /// uno sparo fuori tempo lo notano tutti.
  Future<void> _tune() async {
    final heard = await SoundStage.instance.position();
    if (heard == null || !mounted || !_film.isAnimating) return;
    final target = resyncTarget(
      heard: heard,
      film: DeathScene.length * _film.value,
    );
    if (target != null) {
      _film.forward(
        from: target.inMicroseconds / DeathScene.length.inMicroseconds,
      );
    }
  }

  bool get _synced => widget.startAt != null;

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
    final survives = (widget.save ?? widget.act).survives;
    return Stack(
      fit: StackFit.expand,
      children: [
        CityBackdrop(
          style: widget.style,
          rain: true,
          child: const SizedBox.expand(),
        ),
        FutureBuilder<ParticleSprites>(
          future: _particles,
          builder: (context, snapshot) => AnimatedBuilder(
            animation: _film,
            builder: (context, _) => CustomPaint(
              painter: DeathScenePainter(
                t: filmTime(_film.value),
                act: widget.act,
                save: widget.save,
                victimHat: hat,
                epilogue: widget.epilogue,
                sprites: snapshot.data,
              ),
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _film,
          builder: (context, _) {
            final t = filmTime(_film.value);
            final typed =
                (widget.caption.length * _span(_film.value, 0.02, 0.20))
                    .round();
            final card = _span(t, 0.86, 0.93);
            // Niente primo piano a metà film: la faccia si vede solo alla
            // fine, sulla carta della vittima.
            return Stack(
              fit: StackFit.expand,
              children: [
                SafeArea(
                  minimum: const EdgeInsets.only(bottom: 18),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
                      child: Opacity(
                        opacity: 1 - _span(t, 0.80, 0.86),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: typed == 0 ? 0 : 0.55),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Text(
                              widget.caption.substring(0, typed),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Courier',
                                fontFamilyFallback: ['monospace'],
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                height: 1.35,
                              ),
                            ),
                          ),
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
                        VictimCard(
                          name: widget.victimName,
                          survives: survives,
                          reveal: card,
                        ),
                        const SizedBox(height: 22),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              widget.victimName.toUpperCase(),
                              style: AppText.display(
                                44,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          survives
                              ? AppStrings.of(context).willSeeDawn
                              : AppStrings.of(context).wontSeeDawn,
                          style: survives
                              ? AppText.overline.copyWith(color: AppColors.gold)
                              : AppText.overline,
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        if (!_synced)
        SafeArea(
          child: _ended
              ? Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: pressed(_finish, Press.confirm),
                        child: Text(AppStrings.of(context).next),
                      ),
                    ),
                  ),
                )
              : Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: pressed(_skip, Press.back),
                    child: Text(
                      AppStrings.of(context).skip,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

double _span(double t, double from, double to) =>
    ((t - from) / (to - from)).clamp(0.0, 1.0);

double _mix(double a, double b, double t) => a + (b - a) * t;

double _smooth(double t) => Curves.easeInOut.transform(t);

/// Direzione di un arto: 0 punta in basso, pi/2 in avanti, pi in alto.
Offset _aim(double angle) => Offset(sin(angle), cos(angle));

/// [p] ruotato di [angle] intorno all'origine, come fa `canvas.rotate`.
Offset _turn(Offset p, double angle) => Offset(
  p.dx * cos(angle) - p.dy * sin(angle),
  p.dx * sin(angle) + p.dy * cos(angle),
);

enum _Prop {
  none,
  knife,
  pistol,
  silenced,
  tommy,
  cup,
  box,
  bat,
  lupara,
  bag,
  flask,
}

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
  final ParticleSprites? sprites;

  /// Chi manda a vuoto l'agguato di [act]: una variante del Dottore o del
  /// colpo andato a vuoto. Senza, [act] si vede com'è.
  final DeathAct? save;

  /// Quale parte del filmato composto disegna questo pittore.
  final _Cut _cut;

  /// Quello che l'agguato fa sapere a chi lo manda a vuoto.
  final _Handover? _handover;

  /// Nelle varianti del colpo a vuoto girate con l'arma di un altro
  /// agguato: chi le porta.
  final DeathAct? _armedWith;

  DeathScenePainter({
    required this.t,
    required this.act,
    this.save,
    this.victimHat = AvatarHead.fedora,
    this.epilogue = '',
    this.sprites,
  }) : _cut = _Cut.whole,
       _handover = null,
       _armedWith = null;

  DeathScenePainter._part(
    this._cut, {
    required this.t,
    required this.act,
    this.save,
    this._handover,
    this._armedWith,
    this.victimHat = AvatarHead.fedora,
    this.sprites,
  }) : epilogue = '';

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

  bool get _hasWall => switch (act) {
    DeathAct.car || DeathAct.belfry || DeathAct.carDoor => false,
    DeathAct.banana => false,
    _ => true,
  };

  bool get _shakes => switch (act) {
    DeathAct.car ||
    DeathAct.piano ||
    DeathAct.safe ||
    DeathAct.chandelier ||
    DeathAct.blast => true,
    DeathAct.bat || DeathAct.lupara || DeathAct.pot => true,
    DeathAct.bowling || DeathAct.pie => true,
    _ => false,
  };

  /// Le coreografie in cui la vittima finisce stesa verso sinistra: la
  /// cinepresa, dopo il colpo, si sposta per tenerla tutta in campo.
  bool get _fallsLeft => switch (act) {
    DeathAct.knife || DeathAct.gun || DeathAct.burst || DeathAct.poison => true,
    DeathAct.bat ||
    DeathAct.lupara ||
    DeathAct.driveBy ||
    DeathAct.garrote => true,
    DeathAct.pot || DeathAct.blackout || DeathAct.kiss => true,
    DeathAct.sniper || DeathAct.rescue => true,
    DeathAct.belfry || DeathAct.carDoor => true,
    DeathAct.defibrillator ||
    DeathAct.pliers ||
    DeathAct.ambulance ||
    DeathAct.stitches => true,
    DeathAct.bowling || DeathAct.swordfish || DeathAct.trombone => true,
    DeathAct.tango || DeathAct.bouquet => true,
    _ => false,
  };

  /// Le coreografie in cui il pericolo arriva da dietro l'angolo: la
  /// cinepresa, stringendo, lo tiene d'occhio.
  bool get _fromCorner => switch (act) {
    DeathAct.car ||
    DeathAct.driveBy ||
    DeathAct.noose ||
    DeathAct.pot ||
    DeathAct.manhole => false,
    DeathAct.phoneBooth || DeathAct.carDoor => false,
    DeathAct.laundry => false,
    _ => true,
  };

  /// Dove si ferma la vittima, in frazioni di schermo. Chi spara da dietro
  /// l'angolo ha bisogno di un po' di strada fra la canna e il bersaglio; la
  /// raffica dall'auto ha bisogno di posto per l'auto intera.
  double get _standAt => switch (act) {
    DeathAct.gun || DeathAct.burst => 0.36,
    DeathAct.lupara => 0.42,
    DeathAct.rescue || DeathAct.lucky => 0.36,
    DeathAct.defibrillator ||
    DeathAct.pliers ||
    DeathAct.ambulance ||
    DeathAct.stitches => 0.36,
    DeathAct.bible || DeathAct.jam || DeathAct.blackCat => 0.36,
    DeathAct.banana => 0.20,
    DeathAct.carDoor => 0.40,
    DeathAct.driveBy => 0.43,
    DeathAct.bowling || DeathAct.pie => 0.40,
    DeathAct.swordfish || DeathAct.harpoon || DeathAct.trombone => 0.30,
    DeathAct.bouquet => 0.30,
    DeathAct.laundry => 0.40,
    _ => 0.50,
  };

  /// Quanta luce fa il lampione: nel buio improvviso salta, e la raffica
  /// dall'auto in corsa se lo porta via.
  double get _lampPower {
    if (act == DeathAct.driveBy) return t < 0.63 || _holdsFire ? 1 : 0;
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
    _frame(size);
    if (save != null) return _paintSpliced(canvas, size);
    canvas.save();
    _camera(canvas);
    _quake(canvas);
    _street(canvas);
    _stage(canvas);
    if (!act.survives) _aftermath(canvas);
    _sfx(canvas);
    canvas.restore();
    _closing(canvas, size, survives: act.survives);
  }

  /// Le misure della scena, prese sullo schermo.
  void _frame(Size size) {
    _w = size.width;
    _h = size.height;
    _ground = _h * 0.76;
    // Lo schermo è stretto: le figure si misurano sulla larghezza, così chi
    // cade a terra resta dentro l'inquadratura.
    _u = min(_h * 0.30, _w * 0.50);
    _victimX = _w * _standAt;
    _cornerX = _w * 0.84;
  }

  /// Il colpo che scuote la cinepresa, nelle scene che fanno tremare tutto.
  void _quake(Canvas canvas) {
    final quake = _span(t, strike, strike + 0.10);
    if (_shakes && quake > 0 && quake < 1) {
      final force = (1 - quake) * _u * 0.06;
      canvas.translate(sin(t * 900) * force, cos(t * 760) * force);
    }
  }

  /// La coreografia vera e propria.
  void _stage(Canvas canvas) {
    switch (act) {
      case DeathAct.knife:
        _knife(canvas);
      case DeathAct.gun:
        _shooting(canvas, const [strike], _Prop.silenced);
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
      case DeathAct.bowling:
        _bowling(canvas);
      case DeathAct.swordfish:
        _swordfish(canvas);
      case DeathAct.harpoon:
        _harpoon(canvas);
      case DeathAct.pie:
        _pie(canvas);
      case DeathAct.trombone:
        _trombone(canvas);
      case DeathAct.tango:
        _tango(canvas);
      case DeathAct.bouquet:
        _bouquet(canvas);
      case DeathAct.laundry:
        _laundry(canvas);
      case DeathAct.sniper:
        _sniper(canvas);
      case DeathAct.rescue:
        _rescue(canvas);
      case DeathAct.lucky:
        _lucky(canvas);
      case DeathAct.belfry:
        _belfry(canvas);
      case DeathAct.phoneBooth:
        _phoneBooth(canvas);
      case DeathAct.carDoor:
        _carDoor(canvas);
      case DeathAct.defibrillator:
        _defibrillator(canvas);
      case DeathAct.pliers:
        _pliers(canvas);
      case DeathAct.ambulance:
        _ambulance(canvas);
      case DeathAct.stitches:
        _stitches(canvas);
      case DeathAct.bible:
        _bible(canvas);
      case DeathAct.jam:
        _jam(canvas);
      case DeathAct.banana:
        _banana(canvas);
      case DeathAct.blackCat:
        _blackCat(canvas);
    }
  }

  /// Il finale: chi muore chiude sul rosso (o sul sipario, se il copione lo
  /// chiama), chi si salva su un nero che lascia leggere il nome. Poi le
  /// bande nere del cinema.
  void _closing(Canvas canvas, Size size, {required bool survives}) {
    final rect = Offset.zero & size;
    final close = _span(t, 0.82, 0.92);
    if (close > 0) {
      if (survives) {
        canvas.drawRect(
          rect,
          Paint()..color = Colors.black.withValues(alpha: close * 0.80),
        );
      } else if (epilogue == 'sipario') {
        _curtain(canvas, close);
      } else {
        canvas.drawRect(
          rect,
          Paint()
            ..color = Color.lerp(
              _blood,
              Colors.black,
              0.55,
            )!.withValues(alpha: close * 0.86),
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
  void _camera(Canvas canvas) => _shoot(canvas, _lens);

  /// Punta la cinepresa: [lens] è quanto stringe, e su che punto.
  void _shoot(Canvas canvas, (double, double) lens) {
    final (zoom, focus) = lens;
    final horizon = _ground - _u * 0.45;
    canvas.translate(_w / 2, horizon);
    canvas.scale(zoom);
    canvas.translate(-focus, -horizon);
  }

  /// Quanto stringe la cinepresa, e su che punto della strada.
  (double, double) get _lens {
    if (act == DeathAct.car || act == DeathAct.driveBy) return (1, _w / 2);
    final push = _smooth(_span(t, 0.30, 0.54));
    // Quando arriva il Dottore la cinepresa si allarga prima, e di più: deve
    // starci anche lui.
    final rescue = act.doctorSaves;
    // Nei filmati dove la vittima vola via (la boccia, il casquè del tango)
    // la cinepresa si allarga subito, prima della caduta, se no la taglia.
    final early = rescue || act == DeathAct.bowling || act == DeathAct.tango;
    final settle = _smooth(
      _span(
        t,
        strike + (early ? -0.03 : 0.10),
        strike + (early ? 0.08 : 0.28),
      ),
    );
    final zoom = 1 + 0.22 * push - (rescue ? _rescueWiden : early ? 0.24 : 0.08) * settle;
    var focus = _mix(
      _w / 2,
      _mix(_victimX, _cornerX, _fromCorner ? 0.28 : 0.0),
      push,
    );
    focus = _mix(
      focus,
      _victimX - (_fallsLeft ? _u * (rescue ? _rescueShift : early ? 0.9 : 0.34) : 0) + _u * _settleNudge,
      settle,
    );
    return (zoom, focus);
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
          colors: [
            _warm.withValues(alpha: 0.30 * flicker),
            _warm.withValues(alpha: 0.03),
          ],
        ).createShader(Rect.fromLTRB(0, head.dy, _w, _ground)),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(head.dx + _u * 0.22, _ground + _u * 0.06),
        width: _u * 2.3,
        height: _u * 0.20,
      ),
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
        ..quadraticBezierTo(
          lampX + _u * 0.02,
          lampTop - _u * 0.11,
          head.dx,
          head.dy - _u * 0.045,
        ),
      iron,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(lampX, _ground - _u * 0.05),
          width: _u * 0.11,
          height: _u * 0.10,
        ),
        Radius.circular(_u * 0.02),
      ),
      Paint()..color = _ink,
    );
    canvas.drawCircle(
      head,
      _u * 0.05,
      Paint()..color = _warm.withValues(alpha: flicker),
    );
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
    if (!_hasWall || _cut == _Cut.rescue) return;
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
    final poster = Rect.fromLTWH(
      _cornerX + _u * 0.07,
      _ground - _u * 1.00,
      _u * 0.20,
      _u * 0.27,
    );
    canvas.drawRect(poster, Paint()..color = const Color(0xFF3A3326));
    canvas.drawCircle(
      poster.center.translate(0, -_u * 0.03),
      _u * 0.045,
      Paint()..color = const Color(0xFF15120D),
    );
    canvas.drawRect(
      Rect.fromLTWH(
        poster.left + _u * 0.03,
        poster.bottom - _u * 0.07,
        _u * 0.14,
        _u * 0.025,
      ),
      Paint()..color = const Color(0xFF15120D),
    );
    final window = Rect.fromLTWH(
      _cornerX + _u * 0.09,
      _ground - _u * 1.80,
      _u * 0.20,
      _u * 0.28,
    );
    // Si spegne appena succede qualcosa. Se il copione dice che una finestra
    // si riaccende, eccola: con qualcuno dietro il vetro.
    final lit = act == DeathAct.sniper ? 0.0 : 0.5 - 0.5 * _span(t, 0.60, 0.66);
    final watching = epilogue == 'finestra'
        ? _span(t, 0.70, 0.715) - _span(t, 0.80, 0.815)
        : 0.0;
    canvas.drawRect(window, Paint()..color = const Color(0xFF040405));
    canvas.drawRect(
      window,
      Paint()..color = _warm.withValues(alpha: lit + 0.5 * watching),
    );
    if (watching > 0) {
      final shadow = Paint()..color = _ink.withValues(alpha: watching);
      canvas.drawCircle(
        window.center.translate(0, _u * 0.02),
        _u * 0.045,
        shadow,
      );
      canvas.drawRect(
        Rect.fromLTRB(
          window.left + _u * 0.04,
          window.center.dy + _u * 0.06,
          window.right - _u * 0.04,
          window.bottom,
        ),
        shadow,
      );
    }
    final frame = Paint()
      ..color = _ink
      ..strokeWidth = 2;
    canvas.drawLine(window.topCenter, window.bottomCenter, frame);
    canvas.drawLine(window.centerLeft, window.centerRight, frame);
  }

  // ------------------------------------------------------------------- sagome

  /// Un arto: più largo all'attaccatura, più stretto in fondo.
  void _limb(
    Canvas canvas,
    Offset from,
    Offset to,
    double fromRadius,
    double toRadius,
    Paint paint,
  ) {
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
    if (killer && _spared) _handover!.killer = feet;
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
        if (!dangle.isNaN) {
          return hip + _aim(dangle * (rest > 0 ? 1 : -0.7)) * (h * 0.50);
        }
        if (stride <= 0) return Offset(rest * h, 0);
        final cycle = (phase / (2 * pi)) % 1;
        final reach = stride * h * 0.21;
        if (cycle < 0.5) return Offset(_mix(reach, -reach, cycle * 2), 0);
        final swing = (cycle - 0.5) * 2;
        return Offset(
          _mix(-reach, reach, _smooth(swing)),
          -sin(pi * swing) * h * 0.075 * stride,
        );
      }

      void leg(Offset foot) {
        final knee = _knee(hip, foot, h * thigh, h * shin);
        _limb(canvas, hip, knee, h * 0.058, h * 0.046, paint);
        _limb(
          canvas,
          knee,
          foot.translate(0, -h * 0.03),
          h * 0.046,
          h * 0.034,
          paint,
        );
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTRB(
              foot.dx - h * 0.04,
              foot.dy - h * 0.048,
              foot.dx + h * 0.115,
              foot.dy,
            ),
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
          ..quadraticBezierTo(
            h * 0.11 * broad,
            -h * 0.385,
            h * 0.135 * broad,
            -h * 0.325,
          )
          ..quadraticBezierTo(h * 0.16 * broad, -h * 0.20, h * 0.11, -h * 0.085)
          ..quadraticBezierTo(h * 0.13, h * 0.08, h * 0.165, h * 0.215)
          ..lineTo(-h * 0.17 - flare, h * 0.215)
          ..quadraticBezierTo(-h * 0.15, h * 0.04, -h * 0.115, -h * 0.085)
          ..quadraticBezierTo(
            -h * 0.17 * broad,
            -h * 0.22,
            -h * 0.145 * broad,
            -h * 0.335,
          )
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
            Rect.fromLTRB(
              head.dx - h * 0.105,
              head.dy - h * 0.095,
              head.dx + h * 0.040,
              head.dy + h * 0.125,
            ),
            Radius.circular(h * 0.07),
          ),
          paint,
        );
      }
      canvas.drawOval(
        Rect.fromCenter(center: head, width: h * 0.150, height: h * 0.172),
        paint,
      );
      canvas.drawPath(
        Path()
          ..moveTo(head.dx + h * 0.060, head.dy - h * 0.030)
          ..lineTo(head.dx + h * 0.102, head.dy + h * 0.022)
          ..lineTo(head.dx + h * 0.074, head.dy + h * 0.032)
          ..lineTo(head.dx + h * 0.080, head.dy + h * 0.062)
          ..quadraticBezierTo(
            head.dx + h * 0.065,
            head.dy + h * 0.105,
            head.dx + h * 0.010,
            head.dy + h * 0.095,
          )
          ..lineTo(head.dx, head.dy)
          ..close(),
        paint,
      );
      if (hatOn) {
        _hat(
          canvas,
          head,
          h,
          dame ? AvatarHead.wideBrim : hat,
          paint,
          details: details,
          killer: killer,
        );
      }

      if (details && dame) {
        canvas.drawCircle(
          head.translate(h * 0.078, h * 0.052),
          h * 0.013,
          Paint()..color = const Color(0xFFE23A4A),
        );
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
        canvas.drawCircle(
          tip,
          h * (0.011 + 0.006 * sin(t * 160).abs()),
          Paint()..color = const Color(0xFFFF7A3B),
        );
        _wisp(canvas, tip);
      }
      if (details && killer) {
        // Un riflesso sotto la tesa: da lì ti sta guardando.
        canvas.drawCircle(
          head.translate(h * 0.048, -h * 0.012),
          h * 0.010,
          Paint()..color = const Color(0xFFFFF3C4),
        );
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

      final (hand, along) = armAt(
        Offset(h * 0.035 * broad, -h * 0.325),
        arm + swing,
        elbow,
      );
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

  void _hat(
    Canvas canvas,
    Offset head,
    double h,
    AvatarHead hat,
    Paint paint, {
    required bool details,
    required bool killer,
  }) {
    void band(double left, double right, double y) {
      if (!details) return;
      canvas.drawRect(
        Rect.fromLTRB(
          head.dx + h * left,
          head.dy + h * y,
          head.dx + h * right,
          head.dy + h * (y + 0.024),
        ),
        Paint()..color = killer ? _blood : _rim,
      );
    }

    switch (hat) {
      case AvatarHead.fedora || AvatarHead.wideBrim || AvatarHead.borsalino || AvatarHead.panama || AvatarHead.trilby || AvatarHead.homburg || AvatarHead.porkPie || AvatarHead.pearlFedora || AvatarHead.morettiFedora || AvatarHead.morettiPanama || AvatarHead.morettiHomburg:
        final wide = hat == AvatarHead.wideBrim;
        canvas.save();
        canvas.translate(head.dx + h * 0.02, head.dy - h * 0.050);
        canvas.rotate(0.10);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: h * (wide ? 0.44 : 0.33),
            height: h * 0.048,
          ),
          paint,
        );
        canvas.restore();
        canvas.drawPath(
          Path()
            ..moveTo(head.dx - h * 0.082, head.dy - h * 0.050)
            ..quadraticBezierTo(
              head.dx - h * 0.090,
              head.dy - h * 0.160,
              head.dx - h * 0.040,
              head.dy - h * 0.160,
            )
            ..quadraticBezierTo(
              head.dx + h * 0.010,
              head.dy - h * 0.130,
              head.dx + h * 0.055,
              head.dy - h * 0.165,
            )
            ..quadraticBezierTo(
              head.dx + h * 0.105,
              head.dy - h * 0.150,
              head.dx + h * 0.100,
              head.dy - h * 0.040,
            )
            ..close(),
          paint,
        );
        band(-0.084, 0.102, -0.082);
      case AvatarHead.bowler || AvatarHead.boater || AvatarHead.topHat || AvatarHead.beret || AvatarHead.cloche || AvatarHead.fulmineCap || AvatarHead.vaugirardCap || AvatarHead.adelphiCap || AvatarHead.clownWig || AvatarHead.magicianHat || AvatarHead.chefToque || AvatarHead.sombrero || AvatarHead.tricorn || AvatarHead.operaHelmet || AvatarHead.beekeeper || AvatarHead.roosterHead || AvatarHead.propellerBeanie || AvatarHead.angelHalo || AvatarHead.devilHorns || AvatarHead.fishHead || AvatarHead.dinoHood || AvatarHead.astronautHelmet || AvatarHead.unicornHorn || AvatarHead.spaghettiHat || AvatarHead.octopusHat || AvatarHead.ufoHat || AvatarHead.birthdayCake || AvatarHead.rainbowAfro || AvatarHead.flamingHair || AvatarHead.starHalo || AvatarHead.catOnHead:
        canvas.drawOval(
          Rect.fromCenter(
            center: head.translate(h * 0.01, -h * 0.052),
            width: h * 0.27,
            height: h * 0.04,
          ),
          paint,
        );
        canvas.drawArc(
          Rect.fromCenter(
            center: head.translate(h * 0.005, -h * 0.052),
            width: h * 0.18,
            height: h * 0.22,
          ),
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
            ..quadraticBezierTo(
              head.dx - h * 0.080,
              head.dy - h * 0.125,
              head.dx + h * 0.020,
              head.dy - h * 0.115,
            )
            ..quadraticBezierTo(
              head.dx + h * 0.100,
              head.dy - h * 0.100,
              head.dx + h * 0.165,
              head.dy - h * 0.040,
            )
            ..lineTo(head.dx + h * 0.160, head.dy - h * 0.022)
            ..close(),
          paint,
        );
      case AvatarHead.slicked:
        canvas.drawArc(
          Rect.fromCenter(
            center: head.translate(-h * 0.008, -h * 0.012),
            width: h * 0.165,
            height: h * 0.180,
          ),
          pi * 0.95,
          pi * 1.05,
          true,
          paint,
        );
      case AvatarHead.bob:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              head.dx - h * 0.105,
              head.dy - h * 0.100,
              head.dx + h * 0.045,
              head.dy + h * 0.105,
            ),
            Radius.circular(h * 0.07),
          ),
          paint,
        );
      case AvatarHead.bun:
        canvas.drawCircle(
          head.translate(-h * 0.075, -h * 0.075),
          h * 0.048,
          paint,
        );
        canvas.drawArc(
          Rect.fromCenter(
            center: head.translate(-h * 0.008, -h * 0.010),
            width: h * 0.165,
            height: h * 0.185,
          ),
          pi * 0.9,
          pi * 1.0,
          true,
          paint,
        );
    }
  }

  void _drawPistol(
    Canvas canvas,
    Offset hand,
    Offset along,
    Offset across,
    double h, {
    bool suppressed = false,
  }) {
    Offset p(double x, double y) => hand + along * (h * x) + across * (h * y);
    final frame = Paint()..color = const Color(0xFF282B31);
    final slide = Paint()..color = const Color(0xFF525862);
    final wood = Paint()..color = const Color(0xFF65432F);
    canvas.drawPath(
      Path()
        ..moveTo(p(-0.055, -0.025).dx, p(-0.055, -0.025).dy)
        ..lineTo(p(0.20, -0.025).dx, p(0.20, -0.025).dy)
        ..lineTo(p(0.23, -0.014).dx, p(0.23, -0.014).dy)
        ..lineTo(p(0.23, 0.018).dx, p(0.23, 0.018).dy)
        ..lineTo(p(0.10, 0.026).dx, p(0.10, 0.026).dy)
        ..lineTo(p(0.08, 0.075).dx, p(0.08, 0.075).dy)
        ..lineTo(p(0.02, 0.150).dx, p(0.02, 0.150).dy)
        ..lineTo(p(-0.045, 0.140).dx, p(-0.045, 0.140).dy)
        ..lineTo(p(-0.010, 0.050).dx, p(-0.010, 0.050).dy)
        ..lineTo(p(-0.060, 0.045).dx, p(-0.060, 0.045).dy)
        ..close(),
      frame,
    );
    canvas.drawPath(
      Path()
        ..moveTo(p(-0.04, -0.035).dx, p(-0.04, -0.035).dy)
        ..lineTo(p(0.22, -0.035).dx, p(0.22, -0.035).dy)
        ..lineTo(p(0.22, -0.010).dx, p(0.22, -0.010).dy)
        ..lineTo(p(-0.04, -0.010).dx, p(-0.04, -0.010).dy)
        ..close(),
      slide,
    );
    canvas.drawPath(
      Path()
        ..moveTo(p(0.00, 0.050).dx, p(0.00, 0.050).dy)
        ..lineTo(p(0.07, 0.061).dx, p(0.07, 0.061).dy)
        ..lineTo(p(0.015, 0.145).dx, p(0.015, 0.145).dy)
        ..lineTo(p(-0.035, 0.132).dx, p(-0.035, 0.132).dy)
        ..close(),
      wood,
    );
    if (suppressed) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromPoints(p(0.225, -0.027), p(0.405, 0.027)),
          Radius.circular(h * 0.018),
        ),
        Paint()..color = const Color(0xFF24272C),
      );
      canvas.drawLine(
        p(0.26, -0.018),
        p(0.37, -0.018),
        Paint()
          ..color = const Color(0xFF707780)
          ..strokeWidth = h * 0.006,
      );
      canvas.drawCircle(p(0.405, 0.0), h * 0.016, Paint()..color = _ink);
    } else {
      canvas.drawCircle(p(0.235, 0.0), h * 0.013, Paint()..color = _ink);
    }
    canvas.drawLine(
      p(0.13, -0.022),
      p(0.18, -0.022),
      Paint()
        ..color = const Color(0xFFBBC2CB)
        ..strokeWidth = h * 0.006,
    );
    final trigger = Path()
      ..moveTo(p(0.015, 0.055).dx, p(0.015, 0.055).dy)
      ..quadraticBezierTo(
        p(0.07, 0.095).dx,
        p(0.07, 0.095).dy,
        p(0.09, 0.050).dx,
        p(0.09, 0.050).dy,
      );
    canvas.drawPath(
      trigger,
      Paint()
        ..color = const Color(0xFFB7B9BC)
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.008,
    );
  }

  void _drawTommyGun(
    Canvas canvas,
    Offset hand,
    Offset along,
    Offset across,
    double h,
  ) {
    Offset p(double x, double y) => hand + along * (h * x) + across * (h * y);
    final metal = Paint()..color = const Color(0xFF30343B);
    final wood = Paint()..color = const Color(0xFF69482E);
    final edge = Paint()
      ..color = const Color(0xFF9AA0A7)
      ..strokeWidth = h * 0.006;
    canvas.drawPath(
      Path()
        ..moveTo(p(-0.25, -0.035).dx, p(-0.25, -0.035).dy)
        ..lineTo(p(-0.10, -0.045).dx, p(-0.10, -0.045).dy)
        ..lineTo(p(-0.04, -0.020).dx, p(-0.04, -0.020).dy)
        ..lineTo(p(0.23, -0.025).dx, p(0.23, -0.025).dy)
        ..lineTo(p(0.23, 0.026).dx, p(0.23, 0.026).dy)
        ..lineTo(p(-0.05, 0.025).dx, p(-0.05, 0.025).dy)
        ..lineTo(p(-0.11, 0.045).dx, p(-0.11, 0.045).dy)
        ..lineTo(p(-0.25, 0.030).dx, p(-0.25, 0.030).dy)
        ..close(),
      wood,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromPoints(p(-0.06, -0.035), p(0.24, 0.040)),
        Radius.circular(h * 0.018),
      ),
      metal,
    );
    canvas.drawLine(
      p(0.23, 0.0),
      p(0.42, 0.0),
      Paint()
        ..color = const Color(0xFF272A30)
        ..strokeWidth = h * 0.023
        ..strokeCap = StrokeCap.square,
    );
    canvas.drawLine(p(0.40, -0.012), p(0.42, -0.012), edge);
    canvas.drawCircle(
      p(0.08, 0.09),
      h * 0.070,
      Paint()..color = const Color(0xFF24272C),
    );
    canvas.drawCircle(
      p(0.08, 0.09),
      h * 0.049,
      Paint()..color = const Color(0xFF50555C),
    );
    canvas.drawCircle(
      p(0.08, 0.09),
      h * 0.018,
      Paint()..color = const Color(0xFF26292E),
    );
    canvas.drawPath(
      Path()
        ..moveTo(p(0.19, 0.035).dx, p(0.19, 0.035).dy)
        ..lineTo(p(0.22, 0.115).dx, p(0.22, 0.115).dy)
        ..lineTo(p(0.15, 0.115).dx, p(0.15, 0.115).dy)
        ..lineTo(p(0.12, 0.035).dx, p(0.12, 0.035).dy)
        ..close(),
      wood,
    );
    canvas.drawLine(p(-0.02, -0.042), p(0.18, -0.042), edge);
  }

  void _drawLupara(
    Canvas canvas,
    Offset hand,
    Offset along,
    Offset across,
    double h,
  ) {
    Offset p(double x, double y) => hand + along * (h * x) + across * (h * y);
    final wood = Paint()..color = const Color(0xFF704B2F);
    final metal = Paint()..color = const Color(0xFF30343B);
    final steel = Paint()
      ..color = const Color(0xFFA8ADB4)
      ..strokeWidth = h * 0.006;
    canvas.drawPath(
      Path()
        ..moveTo(p(-0.23, -0.035).dx, p(-0.23, -0.035).dy)
        ..lineTo(p(-0.08, -0.030).dx, p(-0.08, -0.030).dy)
        ..lineTo(p(0.00, -0.018).dx, p(0.00, -0.018).dy)
        ..lineTo(p(0.00, 0.028).dx, p(0.00, 0.028).dy)
        ..lineTo(p(-0.09, 0.045).dx, p(-0.09, 0.045).dy)
        ..lineTo(p(-0.23, 0.028).dx, p(-0.23, 0.028).dy)
        ..close(),
      wood,
    );
    canvas.drawLine(
      p(-0.02, -0.02),
      p(0.34, -0.02),
      Paint()
        ..color = metal.color
        ..strokeWidth = h * 0.023
        ..strokeCap = StrokeCap.square,
    );
    canvas.drawLine(
      p(-0.02, 0.02),
      p(0.34, 0.02),
      Paint()
        ..color = metal.color
        ..strokeWidth = h * 0.023
        ..strokeCap = StrokeCap.square,
    );
    canvas.drawLine(p(0.31, -0.035), p(0.35, -0.035), steel);
    canvas.drawLine(p(0.31, 0.005), p(0.35, 0.005), steel);
    canvas.drawPath(
      Path()
        ..moveTo(p(0.00, 0.035).dx, p(0.00, 0.035).dy)
        ..lineTo(p(0.08, 0.040).dx, p(0.08, 0.040).dy)
        ..lineTo(p(0.04, 0.11).dx, p(0.04, 0.11).dy)
        ..lineTo(p(-0.04, 0.10).dx, p(-0.04, 0.10).dy)
        ..close(),
      wood,
    );
    canvas.drawLine(p(0.24, -0.045), p(0.24, 0.045), steel);
  }

  void _drawSniperRifle(Canvas canvas, Offset muzzle, double h) {
    Offset p(double x, double y) => muzzle + Offset(-h * x, h * y);
    final wood = Paint()..color = const Color(0xFF65432F);
    final metal = Paint()..color = const Color(0xFF30343B);
    final steel = Paint()
      ..color = const Color(0xFF9AA0A7)
      ..strokeWidth = h * 0.014;
    canvas.drawPath(
      Path()
        ..moveTo(p(-0.22, -0.05).dx, p(-0.22, -0.05).dy)
        ..lineTo(p(-0.04, -0.045).dx, p(-0.04, -0.045).dy)
        ..lineTo(p(-0.015, 0.04).dx, p(-0.015, 0.04).dy)
        ..lineTo(p(-0.22, 0.055).dx, p(-0.22, 0.055).dy)
        ..close(),
      wood,
    );
    canvas.drawPath(
      Path()
        ..moveTo(p(-0.04, -0.04).dx, p(-0.04, -0.04).dy)
        ..lineTo(p(0.13, -0.04).dx, p(0.13, -0.04).dy)
        ..lineTo(p(0.13, 0.035).dx, p(0.13, 0.035).dy)
        ..lineTo(p(-0.04, 0.035).dx, p(-0.04, 0.035).dy)
        ..close(),
      metal,
    );
    canvas.drawLine(
      p(0, 0),
      p(0.48, 0),
      Paint()
        ..color = metal.color
        ..strokeWidth = h * 0.026
        ..strokeCap = StrokeCap.square,
    );
    canvas.drawLine(p(0.44, -0.02), p(0.48, -0.02), steel);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromPoints(p(-0.14, -0.09), p(0.025, -0.045)),
        Radius.circular(h * 0.018),
      ),
      metal,
    );
    canvas.drawLine(p(-0.13, 0.04), p(-0.09, 0.14), steel);
    canvas.drawLine(p(-0.09, 0.14), p(-0.01, 0.04), steel);
  }

  void _held(Canvas canvas, Offset hand, Offset along, double h, _Prop prop) {
    final across = Offset(-along.dy, along.dx);
    switch (prop) {
      case _Prop.none:
        break;
      case _Prop.knife:
        final tip = hand + along * (h * 0.25);
        final guard = hand - along * (h * 0.015);
        final handleEnd = hand - along * (h * 0.14);
        final blade = Path()
          ..moveTo(
            hand.dx + across.dx * h * 0.025,
            hand.dy + across.dy * h * 0.025,
          )
          ..lineTo(tip.dx, tip.dy)
          ..lineTo(
            hand.dx - across.dx * h * 0.020,
            hand.dy - across.dy * h * 0.020,
          )
          ..close();
        canvas.drawPath(blade, Paint()..color = const Color(0xFFB9C2CA));
        canvas.drawLine(
          hand + across * (h * 0.009),
          tip - along * (h * 0.03),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.82)
            ..strokeWidth = h * 0.006,
        );
        final handle = Path()
          ..moveTo(
            guard.dx + across.dx * h * 0.030,
            guard.dy + across.dy * h * 0.030,
          )
          ..lineTo(
            handleEnd.dx + across.dx * h * 0.024,
            handleEnd.dy + across.dy * h * 0.024,
          )
          ..lineTo(
            handleEnd.dx - across.dx * h * 0.024,
            handleEnd.dy - across.dy * h * 0.024,
          )
          ..lineTo(
            guard.dx - across.dx * h * 0.030,
            guard.dy - across.dy * h * 0.030,
          )
          ..close();
        canvas.drawPath(handle, Paint()..color = const Color(0xFF5B3828));
        canvas.drawLine(
          guard - across * (h * 0.045),
          guard + across * (h * 0.045),
          Paint()
            ..color = const Color(0xFFD5DAE0)
            ..strokeWidth = h * 0.022
            ..strokeCap = StrokeCap.round,
        );
        for (final fraction in [0.28, 0.53, 0.78]) {
          final wrap = _mix(hand.dx, handleEnd.dx, fraction);
          final wrapY = _mix(hand.dy, handleEnd.dy, fraction);
          canvas.drawLine(
            Offset(wrap, wrapY) - across * (h * 0.018),
            Offset(wrap, wrapY) + across * (h * 0.018),
            Paint()
              ..color = const Color(0xFF9A6A45)
              ..strokeWidth = h * 0.008,
          );
        }
      case _Prop.pistol:
        _drawPistol(canvas, hand, along, across, h);
      case _Prop.silenced:
        _drawPistol(canvas, hand, along, across, h, suppressed: true);
      case _Prop.tommy:
        _drawTommyGun(canvas, hand, along, across, h);
      case _Prop.cup:
        _teacup(canvas, hand.translate(h * 0.035, -h * 0.02), h);
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
        _drawLupara(canvas, hand, along, across, h);
      case _Prop.bag:
        _bag(canvas, hand.translate(0, h * 0.09), h);
      case _Prop.flask:
        final flask = Rect.fromCenter(
          center: hand.translate(h * 0.01, -h * 0.045),
          width: h * 0.075,
          height: h * 0.11,
        );
        canvas.drawRect(
          Rect.fromCenter(
            center: flask.topCenter,
            width: h * 0.03,
            height: h * 0.03,
          ),
          Paint()..color = _gunmetal,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(flask, Radius.circular(h * 0.018)),
          Paint()..color = _steel,
        );
        canvas.drawCircle(flask.center, h * 0.017, Paint()..color = _ink);
      case _Prop.box:
        final box = Rect.fromCenter(
          center: hand.translate(h * 0.06, -h * 0.02),
          width: h * 0.19,
          height: h * 0.15,
        );
        canvas.drawRect(box, Paint()..color = const Color(0xFF7A1B22));
        final ribbon = Paint()
          ..color = AppColors.gold
          ..strokeWidth = h * 0.02;
        canvas.drawLine(box.topCenter, box.bottomCenter, ribbon);
        canvas.drawLine(box.centerLeft, box.centerRight, ribbon);
        canvas.drawCircle(
          box.topCenter.translate(-h * 0.02, -h * 0.015),
          h * 0.02,
          Paint()..color = AppColors.gold,
        );
        canvas.drawCircle(
          box.topCenter.translate(h * 0.02, -h * 0.015),
          h * 0.02,
          Paint()..color = AppColors.gold,
        );
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
    if (_yields(x, facing) || _victimOffstage) return;
    if (_doctorLayer) {
      // Il Dottore lavora su chi l'agguato ha messo a terra, quando c'è.
      if (_handover!.downAt != null) _corpse(canvas, _victimX, -1);
      return;
    }
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
    if (_spared && _handover!.splice == Splice.doctor) {
      // Steso a terra: da qui lo disegna il Dottore.
      _handover.downAt = feetX;
      return;
    }
    canvas.save();
    canvas.translate(feetX, _ground);
    canvas.scale(toward.toDouble(), 1);
    final u = _u;

    void body(Paint paint) {
      // Il soprabito aperto sull'asfalto, poi gambe, busto, braccia, testa.
      canvas.drawOval(
        Rect.fromLTRB(u * 0.20, -u * 0.07, u * 0.80, u * 0.01),
        paint,
      );
      _limb(
        canvas,
        Offset(u * 0.06, -u * 0.05),
        Offset(u * 0.36, -u * 0.07),
        u * 0.036,
        u * 0.056,
        paint,
      );
      _limb(
        canvas,
        Offset(u * 0.02, -u * 0.04),
        Offset(u * 0.20, -u * 0.17),
        u * 0.034,
        u * 0.046,
        paint,
      );
      _limb(
        canvas,
        Offset(u * 0.20, -u * 0.17),
        Offset(u * 0.36, -u * 0.07),
        u * 0.046,
        u * 0.056,
        paint,
      );
      for (final x in [0.0, 0.055]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              u * (x - 0.025),
              -u * 0.135,
              u * (x + 0.03),
              -u * 0.01,
            ),
            Radius.circular(u * 0.025),
          ),
          paint,
        );
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(u * 0.32, -u * 0.165, u * 0.70, -u * 0.012),
          Radius.circular(u * 0.075),
        ),
        paint,
      );
      _limb(
        canvas,
        Offset(u * 0.62, -u * 0.09),
        Offset(u * 0.48, -u * 0.02),
        u * 0.044,
        u * 0.032,
        paint,
      );
      _limb(
        canvas,
        Offset(u * 0.64, -u * 0.07),
        Offset(u * 0.90, -u * 0.025),
        u * 0.044,
        u * 0.030,
        paint,
      );
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
    if (_missed) return;
    final ink = Paint()..color = _ink;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(spin);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: _u * 0.33,
        height: _u * 0.055,
      ),
      ink,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-_u * 0.09, 0)
        ..quadraticBezierTo(-_u * 0.10, -_u * 0.12, -_u * 0.04, -_u * 0.12)
        ..quadraticBezierTo(_u * 0.005, -_u * 0.09, _u * 0.05, -_u * 0.125)
        ..quadraticBezierTo(_u * 0.10, -_u * 0.11, _u * 0.095, 0)
        ..close(),
      ink,
    );
    canvas.drawRect(
      Rect.fromLTRB(-_u * 0.09, -_u * 0.04, _u * 0.095, -_u * 0.014),
      Paint()..color = _rim,
    );
    canvas.restore();
  }

  void _shoes(Canvas canvas, double x) {
    final ink = Paint()..color = _ink;
    for (final dx in [-0.12, 0.05]) {
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(
            x + _u * dx,
            _ground - _u * 0.05,
            x + _u * (dx + 0.15),
            _ground,
          ),
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
    if (life <= 0 || life >= 1 || _missed) return;
    final rng = Random(seed);
    final paint = Paint();
    for (var i = 0; i < count; i++) {
      final angle = rng.nextDouble() * 2 * pi;
      final speed = (0.35 + rng.nextDouble() * 0.65) * _u * 0.9 * reach;
      final direction = Offset(cos(angle), sin(angle)) * 0.55 + bias;
      final position =
          origin +
          direction * (speed * life) +
          Offset(0, _u * 1.3 * life * life);
      paint.color = color.withValues(alpha: (1 - life * life).clamp(0.0, 1.0));
      canvas.drawCircle(
        position,
        _u * (0.012 + rng.nextDouble() * 0.022) * (1 - life * 0.4),
        paint,
      );
    }
  }

  void _pool(Canvas canvas, Offset center, double grown) {
    if (grown <= 0 || _spared) return;
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: _u * 0.95 * grown,
        height: _u * 0.11 * grown,
      ),
      Paint()..color = _blood.withValues(alpha: 0.9),
    );
  }

  void _puff(
    Canvas canvas,
    Offset center,
    double life, {
    double size = 1,
    Color color = const Color(0xFF8E8A86),
  }) {
    if (life <= 0 || life >= 1 || _holdsFire) return;
    final textures = sprites;
    if (textures != null) {
      ParticleSprites.draw(
        canvas,
        textures.smoke,
        center,
        width: _u * size * 1.45,
        height: _u * size * 1.45,
        opacity: 0.68 * (1 - life),
        tint: color,
      );
      return;
    }
    final paint = Paint()
      ..color = color.withValues(alpha: 0.5 * (1 - life))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, _u * 0.05);
    for (final (dx, dy, r) in [
      (-0.22, 0.0, 0.16),
      (0.0, -0.08, 0.22),
      (0.24, 0.02, 0.15),
    ]) {
      canvas.drawCircle(
        center + Offset(dx * (1 + life), dy - life * 0.25) * (_u * size),
        _u * r * size * (0.6 + life),
        paint,
      );
    }
  }

  void _flash(Canvas canvas, double life, {double strength = 0.8}) {
    // Il lampo del colpo è uno solo: quello dell'agguato.
    if (life <= 0 || life >= 1 || _holdsFire || (_cut == _Cut.rescue && act.luckyEscape)) return;
    canvas.drawRect(
      Rect.fromLTWH(-_w, -_h, _w * 3, _h * 3),
      Paint()
        ..color = Colors.white.withValues(
          alpha: strength * (1 - life) * (1 - life),
        ),
    );
  }

  void _star(Canvas canvas, Offset center, double radius, Color color) {
    if (_holdsFire) return;
    final textures = sprites;
    if (textures != null) {
      ParticleSprites.draw(
        canvas,
        textures.spark,
        center,
        width: radius * 3.2,
        height: radius * 3.2,
        opacity: color.a,
        tint: color,
      );
      return;
    }
    final path = Path();
    for (var i = 0; i < 16; i++) {
      final r = i.isEven ? radius : radius * 0.42;
      final point = center + Offset(cos(i * pi / 8), sin(i * pi / 8)) * r;
      i == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  /// La vampata alla bocca della canna: parte da [muzzle] e va verso
  /// [toward], con l'alone caldo che illumina chi spara.
  void _muzzleFlash(
    Canvas canvas,
    Offset muzzle,
    double bang, {
    Offset toward = const Offset(-1, 0),
    double size = 1,
  }) {
    if (bang <= 0 || bang >= 1 || _holdsFire) return;
    final dir = toward / max(toward.distance, 0.001);
    final length = _u * 0.46 * size * (1 - 0.3 * bang);
    final fade = 1 - bang;
    canvas.drawCircle(
      muzzle + dir * (length * 0.15),
      _u * 0.17 * size,
      Paint()
        ..color = _warm.withValues(alpha: 0.55 * fade)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, _u * 0.07),
    );
    final texture = sprites?.muzzle;
    if (texture == null) {
      final side = Offset(-dir.dy, dir.dx) * (length * 0.22);
      final tip = muzzle + dir * length;
      canvas.drawPath(
        Path()
          ..moveTo(muzzle.dx + side.dx * 0.3, muzzle.dy + side.dy * 0.3)
          ..lineTo(tip.dx, tip.dy)
          ..lineTo(muzzle.dx - side.dx * 0.3, muzzle.dy - side.dy * 0.3)
          ..close(),
        Paint()..color = const Color(0xFFFFE6A8).withValues(alpha: fade),
      );
      return;
    }
    // Lo sprite punta in su, con la base vicino al bordo basso.
    _tinted(
      canvas,
      texture,
      muzzle + dir * (length * 0.36),
      width: length * 0.55,
      height: length,
      opacity: fade,
      rotation: atan2(dir.dx, -dir.dy),
      tint: const Color(0xFFFFD68A),
    );
  }

  /// Un punto del busto di un [_person], in coordinate di scena: [at] è
  /// misurato in altezze dall'anca, nel verso del busto piegato.
  Offset _onBody(
    Offset at, {
    required Offset feet,
    int facing = 1,
    double lean = 0,
    double crouch = 0,
    double tilt = 0,
    bool killer = false,
    double scale = 1,
  }) {
    final h = (killer ? _u * 1.08 : _u) * scale;
    final hip = Offset(-h * 0.03 * crouch, -h * (0.50 - 0.13 * crouch));
    final local = hip + _turn(at * h, lean);
    return feet + _turn(Offset(local.dx * facing, local.dy), tilt);
  }

  /// Dove arriva la mano di un [_person] messo in posa così, e verso dove
  /// punta l'avambraccio: è da lì che partono canne e lame.
  (Offset, Offset) _handOf({
    required Offset feet,
    int facing = 1,
    double lean = 0,
    double crouch = 0,
    double tilt = 0,
    double arm = 0.08,
    double elbow = 0.20,
    bool back = false,
    bool killer = false,
    double scale = 1,
  }) {
    final broad = killer ? 1.16 : 1.0;
    final shoulder = Offset((back ? -0.03 : 0.035) * broad, -0.325);
    final hand = shoulder + _aim(arm) * 0.185 + _aim(arm + elbow) * 0.175;
    final at = _onBody(
      hand,
      feet: feet,
      facing: facing,
      lean: lean,
      crouch: crouch,
      tilt: tilt,
      killer: killer,
      scale: scale,
    );
    final along = _turn(_aim(arm + elbow), lean);
    return (at, _turn(Offset(along.dx * facing, along.dy), tilt));
  }

  /// La bocca della canna di un'arma tenuta in [hand] lungo [along].
  Offset _muzzleOf(
    Offset hand,
    Offset along,
    _Prop weapon, {
    bool killer = true,
    double scale = 1,
  }) {
    final h = (killer ? _u * 1.08 : _u) * scale;
    final reach = switch (weapon) {
      _Prop.silenced => 0.405,
      _Prop.tommy => 0.42,
      _Prop.lupara => 0.35,
      _ => 0.235,
    };
    return hand + along * (h * reach);
  }

  /// I bossoli che saltano fuori dall'arma e rimbalzano sull'asfalto.
  void _casings(
    Canvas canvas,
    Offset from,
    List<double> shots, {
    double side = 1,
    double floor = 0,
  }) {
    final brass = Paint()..color = const Color(0xFFE0B65A);
    for (var i = 0; i < shots.length; i++) {
      final life = _span(t, shots[i] + 0.004, shots[i] + 0.07);
      if (life <= 0 || life >= 1) continue;
      final spread = 0.8 + 0.25 * sin(i * 2.7);
      var at =
          from +
          Offset(side * _u * 0.45 * spread * life, -_u * 0.55 * life) +
          Offset(0, _u * 1.6 * life * life);
      final ground = (floor == 0 ? _ground : floor) - _u * 0.01;
      if (at.dy > ground) at = Offset(at.dx, ground);
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(life * 22 + i);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: _u * 0.035,
          height: _u * 0.016,
        ),
        brass,
      );
      canvas.restore();
    }
  }

  /// Come [ParticleSprites.draw], ma il colore tinge davvero lo sprite
  /// (bianco su trasparente) invece di regolarne solo la trasparenza.
  void _tinted(
    Canvas canvas,
    ui.Image image,
    Offset center, {
    required double width,
    required double height,
    double opacity = 1,
    double rotation = 0,
    Color tint = Colors.white,
  }) {
    if (opacity <= 0 || width <= 0 || height <= 0) return;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromCenter(center: Offset.zero, width: width, height: height),
      Paint()
        ..filterQuality = FilterQuality.medium
        ..colorFilter = ColorFilter.mode(
          tint.withValues(alpha: opacity.clamp(0.0, 1.0)),
          BlendMode.modulate,
        ),
    );
    canvas.restore();
  }

  /// Uno sprite dei filmati, se c'è: senza sprite la scena va avanti lo stesso.
  void _sprite(
    Canvas canvas,
    ui.Image? image,
    Offset center,
    double size, {
    double opacity = 1,
    double rotation = 0,
    Color tint = Colors.white,
    double stretch = 1,
  }) {
    if (image == null) return;
    _tinted(
      canvas,
      image,
      center,
      width: size,
      height: size * stretch,
      opacity: opacity,
      rotation: rotation,
      tint: tint,
    );
  }

  // ---------------------------------------------------------------- canovaccio

  /// La vittima entra e si ferma sotto il lampione: posizione, fase del
  /// passo e ampiezza (zero quando è ferma).
  (double, double, double) _entrance() {
    final walk = _span(t, 0.04, 0.34);
    final slowing = 1 - Curves.easeIn.transform(_span(t, 0.30, 0.34));
    return (
      _mix(-_w * 0.25, _victimX, walk),
      walk * 9 * pi,
      walk < 1 ? slowing.clamp(0.25, 1.0) : 0.0,
    );
  }

  /// Il killer che, a cose fatte, si affaccia dall'angolo e si tocca il cappello.
  void _killerSalute(Canvas canvas) {
    if (_spared) return;
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
    final killerX = _mix(
      _mix(_mix(_hiddenX, _peekX, peek), _victimX + _u * 0.42, dash),
      _hiddenX,
      leave,
    );
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
    _pool(
      canvas,
      Offset(_victimX - _u * 0.50, _ground + _u * 0.04),
      _smooth(_span(t, 0.67, 0.84)),
    );
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
        Offset(
          _victimX - _u * (0.30 + 0.95 * flight),
          _ground -
              _u * 0.03 -
              _u * 0.9 * sin(pi * min(1, flight * 1.6)) * (1 - flight),
        ),
        flight < 1 ? -flight * 9 : -0.2,
      );
    }

    // Il lampo della lama, e quello che ne segue.
    if (blow > 0 && blow < 1) {
      canvas.drawArc(
        Rect.fromCircle(
          center: Offset(_victimX + _u * 0.22, _ground - _u * 0.72),
          radius: _u * 0.46,
        ),
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
    _spray(
      canvas,
      Offset(_victimX, _ground - _u * 0.74),
      _span(t, strike, strike + 0.20),
      seed: 3,
      count: 20,
    );
    _flash(canvas, _span(t, strike, strike + 0.04), strength: 0.35);
  }

  void _shooting(Canvas canvas, List<double> shots, _Prop weapon) {
    final (walkX, walk, stride) = _entrance();
    final first = shots.first;
    final last = shots.last;
    final twoHands = weapon == _Prop.tommy;
    final peek = _smooth(_span(t, 0.38, 0.46));
    final out = _smooth(_span(t, 0.46, 0.53));
    final leave = _smooth(_span(t, last + 0.12, last + 0.25));
    // Si sporge quel tanto che basta: la canna deve restare fuori dalla
    // schiena della vittima.
    final stand = _cornerX + _u * (twoHands ? 0.05 : 0.04);
    final killerX = _mix(
      _mix(_mix(_hiddenX, _peekX, peek), stand, out),
      _hiddenX,
      leave,
    );

    var kick = 0.0;
    var jolt = 0.0;
    for (final shot in shots) {
      final bang = _span(t, shot, shot + 0.025);
      if (bang > 0 && bang < 1) {
        kick = sin(pi * bang);
        jolt = sin(pi * bang);
      }
    }
    // Il mitra sale a ogni colpo: chi spara lo tiene giù a fatica.
    final climb = twoHands
        ? 0.16 *
              _span(t, first, last + 0.02) *
              (1 - _span(t, last, last + 0.06))
        : 0.0;
    final shake = twoHands && t > first && t < last + 0.025
        ? sin(t * 900) * 0.025
        : 0.0;

    final lean = leave > 0
        ? 0.05
        : 0.10 * out - (twoHands ? 0.04 : 0.08) * kick + shake;
    final arm = leave > 0
        ? 0.1
        : (twoHands
              ? _mix(0.2, 0.55, out) + 0.10 * kick + climb
              : _mix(0.2, pi / 2, out) + 0.24 * kick);
    final elbow = leave > 0
        ? 0.2
        : (twoHands ? _mix(0.2, 1.05, out) : 0.03 - 0.10 * kick);
    final facing = leave > 0.08 ? 1 : -1;
    _person(
      canvas,
      feet: Offset(killerX, _ground),
      facing: facing,
      walk: _prowl,
      stride: (out > 0 && out < 1) || (leave > 0 && leave < 1) ? 0.8 : 0,
      lean: lean,
      arm: arm,
      elbow: elbow,
      backArm: leave > 0 ? -0.1 : (twoHands ? _mix(-0.1, 1.25, out) : -0.1),
      backElbow: twoHands ? _mix(0.2, 0.55, out) : 0.2,
      prop: weapon,
      killer: true,
    );
    _wall(canvas);

    // Ogni colpo la spinge avanti di un passo, poi crolla in avanti.
    final pushed = walkX - _u * 0.07 * _span(t, first, last + 0.02);
    final fall = _span(t, last + 0.02, last + 0.13);
    _pool(
      canvas,
      Offset(pushed - _u * 0.50, _ground + _u * 0.04),
      _smooth(_span(t, last + 0.11, last + 0.28)),
    );
    _victim(
      canvas,
      x: pushed,
      facing: t < 0.37 ? 1 : -1,
      walk: walk,
      stride: stride,
      fall: fall,
      lean: 0.20 * jolt,
      smoking: t > 0.37 && t < first,
    );
    if (fall > 0.12) {
      final flight = _span(t, last + 0.03, last + 0.24);
      _looseHat(
        canvas,
        Offset(
          pushed - _u * (0.30 + 0.90 * flight),
          _ground -
              _u * 0.03 -
              _u * 0.8 * sin(pi * min(1, flight * 1.6)) * (1 - flight),
        ),
        flight < 1 ? -flight * 8 : -0.2,
      );
    }

    final (hand, along) = _handOf(
      feet: Offset(killerX, _ground),
      facing: facing,
      lean: lean,
      arm: arm,
      elbow: elbow,
      killer: true,
    );
    final muzzle = _muzzleOf(hand, along, weapon);
    final target = Offset(pushed + _u * 0.06, _ground - _u * 0.76);
    for (var i = 0; i < shots.length; i++) {
      final bang = _span(t, shots[i], shots[i] + 0.025);
      if (bang > 0 && bang < 1) {
        _muzzleFlash(
          canvas,
          muzzle,
          bang,
          toward: along,
          size: weapon == _Prop.silenced ? 0.45 : (0.75 + 0.2 * (i % 2)),
        );
        _star(
          canvas,
          muzzle,
          _u * (weapon == _Prop.silenced ? 0.05 : 0.09) * (1 - bang * 0.5),
          const Color(0xFFFFF3C4).withValues(alpha: 1 - bang),
        );
        _tracer(
          canvas,
          muzzle,
          target.translate(0, _u * 0.05 * sin(i * 2.1)),
          bang,
        );
      }
      _flash(canvas, bang, strength: weapon == _Prop.silenced ? 0.18 : 0.28);
      _spray(
        canvas,
        target.translate(-_u * 0.06, _u * 0.02),
        _span(t, shots[i], shots[i] + 0.16),
        seed: 20 + i,
        count: 9,
      );
    }
    _casings(
      canvas,
      hand + along * (_u * 0.12) + Offset(0, -_u * 0.03),
      shots,
      side: 1,
    );
    // Il filo di fumo dalla canna.
    final smoke = _span(t, first + 0.01, last + 0.16);
    if (smoke > 0 && smoke < 1) {
      _puff(
        canvas,
        muzzle.translate(_u * 0.05 * smoke, -_u * 0.30 * smoke),
        smoke,
        size: twoHands ? 0.5 : 0.32,
      );
    }
  }

  /// La scia di un colpo, da [from] a [to], che si spegne con [life].
  void _tracer(Canvas canvas, Offset from, Offset to, double life) {
    if (life <= 0 || life >= 1 || _holdsFire) return;
    final delta = to - from;
    final texture = sprites?.tracer;
    if (texture == null) {
      canvas.drawLine(
        from,
        to,
        Paint()
          ..color = _warm.withValues(alpha: 0.85 * (1 - life))
          ..strokeWidth = _u * 0.012,
      );
      return;
    }
    _tinted(
      canvas,
      texture,
      Offset.lerp(from, to, 0.5)!,
      width: _u * 0.16,
      height: delta.distance * 1.1,
      opacity: 1 - life,
      rotation: atan2(delta.dx, -delta.dy),
      tint: const Color(0xFFFFE2A0),
    );
  }

  void _car(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    // A tutta, senza frenare: il muso arriva sulla vittima esattamente al
    // colpo, e dopo l'urto tira dritto.
    final speed = _w * 12.0;
    final frontX = _victimX + speed * (t - strike);
    final hit = t >= strike;
    // Dove ricade, dopo il volo sopra il tetto: i piedi qui, la testa
    // verso il lampione.
    final landX = _w * 0.97;
    const landAt = 0.675;

    // Prima i fari, in fondo alla strada, da dove la vittima è arrivata.
    final glare = _span(t, 0.38, 0.50) * (1 - _span(t, 0.50, 0.54));
    if (glare > 0) {
      canvas.drawCircle(
        Offset(-_u * 0.1, _ground - _u * 0.30),
        _u * (0.3 + 0.9 * glare),
        Paint()
          ..color = _warm.withValues(alpha: 0.55 * glare)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, _u * 0.25),
      );
    }

    // La macchina passa dietro al corpo che vola: così si vede rotolare
    // sopra il cofano e il tetto.
    if (frontX > -_u * 2.6 && frontX - _u * 2.1 < _w + _u * 0.5) {
      final jolt = _u * 0.07 * sin(pi * _span(t, strike, strike + 0.035));
      canvas.save();
      canvas.translate(0, -jolt);
      _sedan(canvas, frontX);
      _carTrim(canvas, frontX);
      canvas.restore();
    }

    if (!hit) {
      // Si gira verso la luce, si ripara gli occhi, e resta lì impietrito.
      final alarm = _span(t, 0.46, 0.50);
      final freeze = _span(t, 0.50, 0.53);
      final shiver = t > 0.50 ? sin(t * 420) * 0.05 : 0.0;
      _person(
        canvas,
        feet: Offset(walkX, _ground),
        facing: t < 0.43 ? 1 : -1,
        walk: walk,
        stride: stride,
        lean: -0.14 * alarm - 0.06 * freeze,
        crouch: 0.22 * freeze,
        arm: _mix(0.08, 2.15, alarm) + shiver,
        elbow: _mix(0.2, 0.95, alarm),
        backArm: _mix(-0.10, 2.0, freeze) - shiver,
        backElbow: _mix(0.2, 1.1, freeze),
        hat: victimHat,
      );
      _exclaim(
        canvas,
        Offset(walkX + _u * 0.05, _ground - _u * 1.50),
        _span(t, 0.46, 0.535),
      );
    } else {
      // Fuori dalle scarpe, su in aria a girare, e giù oltre la macchina.
      final flight = _span(t, strike, landAt);
      if (flight < 1) {
        final spin = -2.5 * pi * flight;
        final center = Offset(
          _mix(_victimX, landX - _u * 0.5, flight),
          _mix(_ground - _u * 0.5, _ground - _u * 0.08, flight) -
              _u * 1.6 * 4 * flight * (1 - flight),
        );
        _person(
          canvas,
          feet: center + Offset(-_u * 0.5 * sin(spin), _u * 0.5 * cos(spin)),
          facing: -1,
          tilt: spin,
          arm: 2.6 + sin(t * 90) * 0.4,
          elbow: 0.4,
          backArm: -2.2 + cos(t * 80) * 0.4,
          backElbow: 0.5,
          crouch: 0.35,
          hat: victimHat,
          hatOn: false,
        );
      } else {
        final bounce = _span(t, landAt, landAt + 0.05);
        canvas.save();
        canvas.translate(0, -_u * 0.10 * sin(pi * bounce));
        _corpse(canvas, landX, -1);
        canvas.restore();
      }
      _dust(
        canvas,
        Offset(landX - _u * 0.45, _ground),
        _span(t, landAt, landAt + 0.20),
        seed: 3,
        size: 0.9,
        spread: 1.1,
      );

      // Le scarpe restano lì, e fumano.
      _shoes(canvas, _victimX);
      for (var i = 0; i < 3; i++) {
        final life = _span(
          t,
          strike + 0.02 + i * 0.03,
          strike + 0.16 + i * 0.03,
        );
        _puff(
          canvas,
          Offset(
            _victimX + _u * (0.02 + 0.05 * i),
            _ground - _u * (0.10 + 0.45 * life),
          ),
          life,
          size: 0.22,
          color: const Color(0xFF77726C),
        );
      }
      _dust(
        canvas,
        Offset(_victimX, _ground),
        _span(t, strike, strike + 0.16),
        seed: 4,
        size: 0.8,
      );

      // Il cappello va su più in alto di tutti, e torna giù planando.
      final hatUp = Curves.easeOut.transform(_span(t, strike, 0.62));
      final hatDown = _span(t, 0.62, 0.80);
      _looseHat(
        canvas,
        Offset(
          _victimX +
              _u * (0.15 * hatUp + 0.25 * hatDown) +
              sin(hatDown * 9) * _u * 0.14 * (1 - hatDown),
          hatDown > 0
              ? _mix(
                  _ground - _u * 2.3,
                  _ground - _u * 0.03,
                  Curves.easeIn.transform(hatDown),
                )
              : _mix(_ground - _u * 1.0, _ground - _u * 2.3, hatUp),
        ),
        hatUp * 4 * pi + 0.45 * sin(hatDown * 9) * (1 - hatDown),
      );

      // I segni delle gomme dove ha preso la vittima.
      final marks = Paint()
        ..color = Colors.black.withValues(alpha: 0.6)
        ..strokeWidth = _u * 0.02;
      for (final dy in [0.04, 0.10]) {
        canvas.drawLine(
          Offset(_victimX - _u * 0.5, _ground + _u * dy),
          Offset(min(frontX, _victimX + _u * 1.4), _ground + _u * dy),
          marks,
        );
      }
      // Il colpo: la stella dell'urto e i vetri del faro.
      _impactBurst(
        canvas,
        Offset(_victimX - _u * 0.10, _ground - _u * 0.45),
        _span(t, strike, strike + 0.045),
        size: 1.0,
      );
      _debris(
        canvas,
        Offset(_victimX, _ground - _u * 0.34),
        _span(t, strike, strike + 0.15),
        seed: 12,
        count: 12,
        colors: const [Color(0xFFFFF3C4), Color(0xFFD5DAE0)],
        size: 0.55,
        drift: 0.9,
        glints: true,
      );
    }
    _flash(canvas, _span(t, strike, strike + 0.05), strength: 0.7);
  }

  /// Quello che rende vera la berlina da vicino: cerchioni che girano,
  /// paraurti cromati, la griglia, il fanale rosso e il fumo di scarico.
  void _carTrim(Canvas canvas, double front) {
    final back = front - _u * 2.1;
    final chrome = Paint()..color = _steel.withValues(alpha: 0.85);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          front - _u * 0.10,
          _ground - _u * 0.23,
          front + _u * 0.05,
          _ground - _u * 0.175,
        ),
        Radius.circular(_u * 0.02),
      ),
      chrome,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          back - _u * 0.04,
          _ground - _u * 0.23,
          back + _u * 0.12,
          _ground - _u * 0.175,
        ),
        Radius.circular(_u * 0.02),
      ),
      chrome,
    );
    final grille = Paint()
      ..color = _steel.withValues(alpha: 0.45)
      ..strokeWidth = _u * 0.012;
    for (var i = 0; i < 3; i++) {
      final x = front - _u * (0.07 + 0.03 * i);
      canvas.drawLine(
        Offset(x, _ground - _u * 0.37),
        Offset(x, _ground - _u * 0.25),
        grille,
      );
    }
    // La maniglia e il profilo della portiera.
    final trim = Paint()
      ..color = _rim.withValues(alpha: 0.8)
      ..strokeWidth = _u * 0.012;
    canvas.drawLine(
      Offset(back + _u * 1.26, _ground - _u * 0.50),
      Offset(back + _u * 1.26, _ground - _u * 0.20),
      trim,
    );
    canvas.drawLine(
      Offset(back + _u * 1.12, _ground - _u * 0.44),
      Offset(back + _u * 1.20, _ground - _u * 0.44),
      trim..strokeWidth = _u * 0.02,
    );
    canvas.drawLine(
      Offset(back + _u * 0.10, _ground - _u * 0.28),
      Offset(front - _u * 0.12, _ground - _u * 0.28),
      Paint()
        ..color = _steel.withValues(alpha: 0.25)
        ..strokeWidth = _u * 0.01,
    );
    final tail = Offset(back + _u * 0.06, _ground - _u * 0.40);
    canvas.drawCircle(
      tail,
      _u * 0.10,
      Paint()
        ..color = const Color(0xFFE23A4A).withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, _u * 0.05),
    );
    canvas.drawCircle(
      tail,
      _u * 0.032,
      Paint()..color = const Color(0xFFE23A4A),
    );
    // I cerchioni: i raggi girano, e a quella velocità si sfumano.
    final turn = front / (_u * 0.21);
    final spoke = Paint()
      ..color = _steel.withValues(alpha: 0.45)
      ..strokeWidth = _u * 0.016
      ..strokeCap = StrokeCap.round;
    for (final x in [back + _u * 0.38, front - _u * 0.36]) {
      final hub = Offset(x, _ground - _u * 0.13);
      for (var i = 0; i < 3; i++) {
        final a = turn + i * pi / 3;
        final reach = Offset(cos(a), sin(a)) * (_u * 0.115);
        canvas.drawLine(hub - reach, hub + reach, spoke);
      }
      canvas.drawCircle(
        hub,
        _u * 0.125,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _u * 0.012
          ..color = _steel.withValues(alpha: 0.55),
      );
    }
    for (var i = 0; i < 3; i++) {
      final life = (t * 40 + i / 3) % 1;
      _puff(
        canvas,
        Offset(
          back - _u * (0.10 + 0.5 * life),
          _ground - _u * (0.16 + 0.15 * life),
        ),
        life,
        size: 0.22,
        color: const Color(0xFF6F6B66),
      );
    }
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
        ..shader =
            LinearGradient(
              colors: [
                _warm.withValues(alpha: 0.55),
                _warm.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromLTWH(lamp.dx, lamp.dy - _u * 0.4, _u * 2.6, _u * 0.5),
            ),
    );

    // La carrozzeria: cofano lungo, tetto tondo, parafanghi gonfi.
    canvas.drawPath(
      Path()
        ..moveTo(back + _u * 0.05, base)
        ..quadraticBezierTo(
          back - _u * 0.03,
          _ground - _u * 0.42,
          back + _u * 0.22,
          _ground - _u * 0.46,
        )
        ..quadraticBezierTo(
          back + _u * 0.42,
          _ground - _u * 0.86,
          back + _u * 0.82,
          _ground - _u * 0.86,
        )
        ..quadraticBezierTo(
          back + _u * 1.15,
          _ground - _u * 0.86,
          back + _u * 1.32,
          _ground - _u * 0.52,
        )
        ..quadraticBezierTo(
          back + _u * 1.80,
          _ground - _u * 0.52,
          front - _u * 0.04,
          _ground - _u * 0.40,
        )
        ..quadraticBezierTo(front + _u * 0.03, _ground - _u * 0.30, front, base)
        ..close(),
      ink,
    );
    canvas.drawPath(
      Path()
        ..moveTo(back + _u * 0.50, _ground - _u * 0.52)
        ..quadraticBezierTo(
          back + _u * 0.58,
          _ground - _u * 0.78,
          back + _u * 0.84,
          _ground - _u * 0.78,
        )
        ..quadraticBezierTo(
          back + _u * 1.06,
          _ground - _u * 0.78,
          back + _u * 1.20,
          _ground - _u * 0.52,
        )
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
      canvas.drawCircle(
        Offset(x, _ground - _u * 0.13),
        _u * 0.13,
        Paint()..color = const Color(0xFF17181C),
      );
      canvas.drawCircle(
        Offset(x, _ground - _u * 0.13),
        _u * 0.055,
        Paint()..color = _steel.withValues(alpha: 0.7),
      );
    }
    canvas.drawCircle(
      lamp,
      _u * 0.06,
      Paint()..color = const Color(0xFFFFF3C4),
    );
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
    // Appeso lassù, la corda scricchiola, cede a [snap] e la caduta accelera
    // fino al colpo.
    const snap = 0.50;
    final landed = t >= strike;
    final fall = _span(t, snap, strike);
    final hang = _ground - _u * 2.05;
    final bottom = landed ? _ground : _mix(hang, _ground, fall * fall);
    final after = _span(t, strike, strike + 0.10);
    final chandelier = act == DeathAct.chandelier;
    final safe = act == DeathAct.safe;
    final piano = !chandelier && !safe;
    final half = safe ? 0.44 : (chandelier ? 0.65 : 0.64);

    _killerSalute(canvas);
    _wall(canvas);

    // L'ombra che si allarga e si fa scura man mano che arriva.
    final shadow = _span(t, 0.38, strike);
    if (shadow > 0 && !landed) {
      final near = fall * fall;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(_victimX, _ground + _u * 0.04),
          width: _u * (0.5 + 0.9 * shadow) * _mix(1, 1.15, near),
          height: _u * 0.12 * (0.4 + shadow),
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.25 + 0.45 * near),
      );
    }

    if (!landed) {
      // Lo scricchiolio gli fa alzare gli occhi; quando cede, punta il dito;
      // all'ultimo si rannicchia con le braccia sulla testa.
      final glance = _smooth(_span(t, 0.44, 0.47)) * (1 - _span(t, 0.48, snap));
      final alarm = _span(t, snap, snap + 0.025);
      final cower = _span(t, 0.53, 0.55);
      final shiver = cower > 0 ? sin(t * 420) * 0.05 : 0.0;
      _person(
        canvas,
        feet: Offset(walkX, _ground),
        walk: walk,
        stride: stride,
        lean: -0.10 * glance - 0.16 * alarm * (1 - cower) + 0.06 * cower,
        crouch: 0.30 * cower,
        arm: _mix(_mix(0.08, 2.75, alarm), 2.95, cower) + shiver,
        elbow: _mix(_mix(0.2, 0.5, alarm), 1.0, cower),
        backArm: _mix(-0.10, 2.8, cower) - shiver,
        backElbow: _mix(0.2, 1.1, cower),
        hat: victimHat,
      );
      _exclaim(
        canvas,
        Offset(_victimX + _u * 0.30, _ground - _u * 1.40),
        _span(t, snap, snap + 0.05),
      );
    } else if (chandelier) {
      // Il lampadario è tutto archi: sotto la vittima si vede, stesa.
      _corpse(canvas, _victimX + _u * 0.45, -1);
    } else if (piano) {
      // Sotto la coda c'è luce fra le gambe: lì si vede, schiacciato.
      canvas.save();
      canvas.translate(0, _ground);
      canvas.scale(1, 0.6);
      canvas.translate(0, -_ground);
      _corpse(canvas, _victimX - _u * 0.72, 1);
      canvas.restore();
    } else {
      // Le gambe dalla parte del muro, dove la cinepresa le tiene in campo.
      canvas.save();
      canvas.translate(_victimX, 0);
      canvas.scale(-1, 1);
      canvas.translate(-_victimX, 0);
      _squashed(canvas, half);
      canvas.restore();
    }
    if (landed) {
      final roll = _span(t, strike, 0.80);
      _looseHat(
        canvas,
        Offset(
          _victimX - _u * (0.95 + 0.6 * Curves.easeOut.transform(roll)),
          _ground - _u * 0.03 - _u * 0.25 * sin(pi * _span(t, strike, 0.62)),
        ),
        -roll * 9,
      );
    }

    // La corda (o la catena) sopra: tesa finché regge, poi schizza su.
    final hook = hang - _u * (safe ? 1.20 : (chandelier ? 0.85 : 0.98));
    final recoil = Curves.easeOut.transform(_span(t, snap, snap + 0.07));
    final brokenEnd = t < snap ? hook : hook - _u * 1.6 * recoil;
    if (chandelier) {
      _chain(
        canvas,
        Offset(_victimX, -_h),
        Offset(_victimX + sin(t * 30) * _u * 0.05 * recoil, brokenEnd),
      );
    } else {
      final rope = Paint()
        ..color = const Color(0xFFC9B48A)
        ..strokeWidth = _u * 0.024
        ..strokeCap = StrokeCap.round;
      final whip = sin(t * 60) * _u * 0.08 * recoil * (1 - recoil * 0.5);
      canvas.drawLine(
        Offset(_victimX, -_h),
        Offset(_victimX + whip, brokenEnd),
        rope,
      );
      if (t >= snap) _fray(canvas, Offset(_victimX + whip, brokenEnd), -1);
    }
    _spray(
      canvas,
      Offset(_victimX, hook),
      _span(t, snap, snap + 0.06),
      seed: 21,
      color: chandelier ? _warm : const Color(0xFFC9B48A),
      count: 8,
      bias: const Offset(0, -0.4),
      reach: 0.5,
    );

    // L'oggetto: dondola appeso, si allunga mentre precipita, si schiaccia
    // all'urto e rimbalza appena.
    var sx = 1.0;
    var sy = 1.0;
    var lift = 0.0;
    var tilt = 0.0;
    if (!landed) {
      final creak = _span(t, 0.42, snap);
      tilt = sin(t * 22) * 0.025 + sin(t * 170) * 0.02 * creak + fall * 0.08;
      sy = 1 + 0.10 * fall * fall;
      sx = 1 - 0.04 * fall * fall;
    } else {
      final amp = chandelier ? 0.10 : (safe ? 0.10 : 0.16);
      final squash = after < 0.3
          ? sin(pi * after / 0.3)
          : -0.35 * sin(pi * _span(after, 0.3, 0.7));
      sy = 1 - amp * squash;
      sx = 1 + amp * 0.6 * squash;
      if (piano) {
        lift = _u * 0.10 * sin(pi * _span(after, 0.25, 0.6));
        tilt = 0.10 * _smooth(_span(after, 0.45, 0.9));
      }
    }
    final pivot = Offset(_victimX, bottom - lift);
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(tilt);
    canvas.scale(sx, sy);
    canvas.translate(-_victimX, -bottom);
    final top = bottom - _u * (safe ? 0.88 : (chandelier ? 0.85 : 0.66));
    if (!chandelier) {
      // L'imbracatura resta legata all'oggetto, col moncone sfilacciato.
      final slack = landed ? _smooth(_span(after, 0, 0.6)) : 0.0;
      final knot = Offset(
        _victimX,
        _mix(bottom - (hang - hook), top - _u * 0.05, slack),
      );
      final sling = Paint()
        ..color = const Color(0xFFC9B48A)
        ..strokeWidth = _u * 0.020
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      for (final side in [-1.0, 1.0]) {
        canvas.drawLine(
          knot,
          Offset(_victimX + side * _u * half * 0.7, top),
          sling,
        );
      }
      if (t >= snap) {
        canvas.drawLine(knot, knot.translate(0, -_u * 0.12), sling);
        _fray(canvas, knot.translate(0, -_u * 0.12), 1);
      }
    } else if (landed) {
      // Il pezzo di catena rimasto attaccato si affloscia sugli archi.
      final heap = Curves.easeIn.transform(_span(after, 0, 0.5));
      final crown = bottom - _u * 0.85 * 0.55;
      _chain(
        canvas,
        Offset(
          _victimX + _u * 0.45 * heap,
          _mix(crown - _u * 0.60, bottom - _u * 0.24, heap),
        ),
        Offset(_victimX, crown),
      );
    } else {
      _chain(canvas, Offset(_victimX, top - _u * 0.60), Offset(_victimX, top));
    }
    switch (act) {
      case DeathAct.safe:
        _safeShape(
          canvas,
          bottom,
          dial: landed
              ? 9 * Curves.easeOut.transform(_span(t, strike, 0.72))
              : 0,
        );
      case DeathAct.chandelier:
        _chandelierShape(canvas, bottom, landed);
      default:
        _pianoShape(canvas, bottom, broken: landed);
    }
    canvas.restore();

    if (!landed && fall > 0) {
      final rush = Paint()
        ..color = Colors.white.withValues(alpha: 0.35 * fall)
        ..strokeWidth = _u * 0.012;
      for (final dx in [-0.42, -0.1, 0.25, 0.45]) {
        canvas.drawLine(
          Offset(_victimX + _u * dx, top - _u * 0.15),
          Offset(_victimX + _u * dx, top - _u * (0.15 + 0.9 * fall)),
          rush,
        );
      }
    }

    // L'urto: polvere che scappa radente, pezzi che saltano via.
    final dust = _span(t, strike, strike + 0.26);
    _dust(
      canvas,
      Offset(_victimX, _ground),
      dust,
      seed: act.index,
      count: 8,
      size: safe ? 1.6 : (chandelier ? 1.1 : 1.4),
      spread: 1.5,
    );
    final burst = _span(t, strike, strike + 0.18);
    switch (act) {
      case DeathAct.safe:
        _cracks(canvas, half, _span(t, strike, strike + 0.02));
        _debris(
          canvas,
          Offset(_victimX, _ground - _u * 0.04),
          burst,
          seed: 14,
          count: 14,
          colors: const [Color(0xFF1A1B20), Color(0xFF34353D)],
          size: 1.1,
          reach: 1.3,
          lift: 0.8,
        );
      case DeathAct.chandelier:
        _debris(
          canvas,
          Offset(_victimX, _ground - _u * 0.20),
          burst,
          seed: 15,
          count: 28,
          colors: const [
            Color(0xFFE8F4FF),
            Color(0xFFBFD8F0),
            Color(0xFFFFF3C4),
          ],
          size: 0.6,
          reach: 1.5,
          lift: 1.1,
          glints: true,
        );
        _spray(
          canvas,
          Offset(_victimX, _ground - _u * 0.25),
          _span(t, strike, strike + 0.12),
          seed: 8,
          color: _warm,
          count: 14,
          bias: const Offset(0, -0.8),
          reach: 0.9,
        );
        // Le candele spente fumano ancora un po'.
        for (var i = 0; i < 5; i++) {
          final life = _span(
            t,
            strike + 0.02 + i * 0.02,
            strike + 0.24 + i * 0.02,
          );
          _puff(
            canvas,
            Offset(
              _victimX + _u * (i - 2) * 0.28,
              _ground - _u * (0.25 + 0.6 * life),
            ),
            life,
            size: 0.28,
            color: const Color(0xFF6F6B66),
          );
        }
      default:
        _debris(
          canvas,
          Offset(_victimX - _u * 0.50, _ground - _u * 0.40),
          burst,
          seed: 16,
          count: 16,
          colors: const [AppColors.textPrimary, _ink, AppColors.textPrimary],
          size: 0.8,
          reach: 1.1,
          lift: 1.1,
          drift: -0.3,
        );
        _debris(
          canvas,
          Offset(_victimX + _u * 0.30, _ground - _u * 0.25),
          burst,
          seed: 17,
          count: 8,
          colors: const [Color(0xFF3A2618), Color(0xFF5B3828)],
          size: 1.0,
          reach: 1.0,
          lift: 0.9,
          drift: 0.4,
        );
        _brokenLeg(canvas, _span(t, strike, strike + 0.14));
        _notes(canvas);
    }
    _flash(canvas, _span(t, strike, strike + 0.04), strength: 0.4);
  }

  /// Quello che resta sotto il pianoforte o la cassaforte: due gambe che
  /// spuntano da una parte, un braccio dall'altra. Scalciano una volta.
  void _squashed(Canvas canvas, double half) {
    final ink = Paint()..color = _ink;
    final rim = Paint()..color = _rim;
    final twitch = t > strike + 0.03
        ? sin(t * 70) * 0.30 * (1 - _span(t, strike + 0.04, strike + 0.14))
        : 0.0;
    for (final (dy, phase) in [(0.04, 0.0), (0.12, 1.3)]) {
      final hipX = _victimX - _u * (half - 0.08);
      final footX = _victimX - _u * (half + 0.30);
      for (final (paint, shift) in [(rim, -0.012), (ink, 0.0)]) {
        _limb(
          canvas,
          Offset(hipX, _ground - _u * dy),
          Offset(footX, _ground - _u * (dy + shift)),
          _u * 0.05,
          _u * 0.038,
          paint,
        );
        canvas.save();
        canvas.translate(footX, _ground - _u * (dy + shift));
        canvas.rotate(-twitch * (phase == 0 ? 1 : -0.7));
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(-_u * 0.07, -_u * 0.10, _u * 0.07, _u * 0.14),
            Radius.circular(_u * 0.03),
          ),
          paint,
        );
        canvas.restore();
      }
    }
    // Il braccio, con la mano aperta che si chiude piano.
    final close = _span(t, strike + 0.06, strike + 0.20);
    final from = Offset(_victimX + _u * (half - 0.08), _ground - _u * 0.05);
    final hand = Offset(_victimX + _u * (half + 0.17), _ground - _u * 0.04);
    for (final (paint, shift) in [(rim, -0.012), (ink, 0.0)]) {
      _limb(
        canvas,
        from.translate(0, _u * shift),
        hand.translate(0, _u * shift),
        _u * 0.040,
        _u * 0.032,
        paint,
      );
      canvas.drawCircle(hand.translate(0, _u * shift), _u * 0.036, paint);
      for (var i = 0; i < 3; i++) {
        final a = -0.9 + i * 0.45 + twitch * 0.6;
        final reach = _u * _mix(0.07, 0.035, close);
        canvas.drawLine(
          hand.translate(0, _u * shift),
          hand.translate(cos(a) * reach, sin(a) * reach + _u * shift),
          Paint()
            ..color = paint.color
            ..strokeWidth = _u * 0.016
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  /// Le crepe che la cassaforte apre nell'asfalto.
  void _cracks(Canvas canvas, double half, double grow) {
    if (grow <= 0) return;
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = _u * 0.016
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final rng = Random(5);
    for (final side in [-1.0, 1.0]) {
      for (var k = 0; k < 2; k++) {
        final path = Path()
          ..moveTo(
            _victimX + side * _u * (half - 0.1 * k),
            _ground + _u * 0.01,
          );
        var x = _victimX + side * _u * (half - 0.1 * k);
        var y = _ground + _u * 0.01;
        for (var i = 0; i < 4; i++) {
          x += side * _u * (0.08 + rng.nextDouble() * 0.08) * grow;
          y += _u * (0.012 + rng.nextDouble() * 0.03) * grow;
          path.lineTo(x, y);
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  /// Un moncone di corda sfilacciato: tre fili aperti verso [up] (1 in
  /// basso, -1 in alto).
  void _fray(Canvas canvas, Offset end, int up) {
    final paint = Paint()
      ..color = const Color(0xFFC9B48A)
      ..strokeWidth = _u * 0.010
      ..strokeCap = StrokeCap.round;
    for (final a in [-0.5, 0.0, 0.5]) {
      canvas.drawLine(
        end,
        end + Offset(sin(a) * _u * 0.05, up * cos(a) * _u * 0.06),
        paint,
      );
    }
  }

  /// Una catena di ottone, maglia per maglia, da [from] a [to].
  void _chain(Canvas canvas, Offset from, Offset to) {
    final length = (to - from).distance;
    if (length <= 0) return;
    final step = _u * 0.06;
    final count = min(80, (length / step).ceil());
    final dir = (to - from) / length;
    final link = Paint()
      ..color = const Color(0xFFB8913F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _u * 0.012;
    for (var i = 0; i < count; i++) {
      final c = to - dir * (step * (i + 0.5));
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(atan2(dir.dy, dir.dx));
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: step * 1.1,
          height: i.isEven ? _u * 0.035 : _u * 0.012,
        ),
        link,
      );
      canvas.restore();
    }
  }

  /// La gamba del pianoforte che si spezza e vola via.
  void _brokenLeg(Canvas canvas, double life) {
    if (life <= 0) return;
    final x = _victimX + _u * (0.52 + 0.30 * life);
    // Vola su girando e ricade stesa sull'asfalto.
    final y =
        _mix(_ground - _u * 0.18, _ground - _u * 0.035, life) -
        _u * 0.55 * sin(pi * life);
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(life * 3.5 * pi);
    _limb(
      canvas,
      Offset(0, -_u * 0.15),
      Offset(0, _u * 0.15),
      _u * 0.035,
      _u * 0.02,
      Paint()..color = _ink,
    );
    canvas.restore();
  }

  /// Le note che escono dal pianoforte schiacciato e salgono a perdersi.
  void _notes(Canvas canvas) {
    for (var i = 0; i < 3; i++) {
      final rise = _span(t, strike + 0.02 + i * 0.04, strike + 0.24 + i * 0.04);
      if (rise <= 0 || rise >= 1) continue;
      final note = Offset(
        _victimX + _u * (-0.3 + 0.3 * i) + sin(rise * 9 + i) * _u * 0.08,
        _ground - _u * (0.7 + 0.9 * rise),
      );
      final paint = Paint()..color = _warm.withValues(alpha: 1 - rise);
      canvas.drawOval(
        Rect.fromCenter(center: note, width: _u * 0.08, height: _u * 0.06),
        paint,
      );
      canvas.drawLine(
        note.translate(_u * 0.035, 0),
        note.translate(_u * 0.035, -_u * 0.16),
        paint..strokeWidth = _u * 0.014,
      );
      canvas.drawLine(
        note.translate(_u * 0.035, -_u * 0.16),
        note.translate(_u * 0.09, -_u * 0.11),
        paint,
      );
    }
  }

  void _pianoShape(Canvas canvas, double bottom, {bool broken = false}) {
    final x = _victimX;

    void body(Paint paint) {
      for (final dx in [-0.50, 0.06, if (!broken) 0.52]) {
        _limb(
          canvas,
          Offset(x + _u * dx, bottom - _u * 0.34),
          Offset(x + _u * dx, bottom - _u * 0.04),
          _u * 0.040,
          _u * 0.022,
          paint,
        );
        canvas.drawCircle(
          Offset(x + _u * dx, bottom - _u * 0.025),
          _u * 0.025,
          paint,
        );
      }
      // La lira dei pedali.
      canvas.drawRect(
        Rect.fromLTRB(
          x - _u * 0.10,
          bottom - _u * 0.32,
          x - _u * 0.04,
          bottom - _u * 0.10,
        ),
        paint,
      );
      // La cassa a coda, il coperchio alzato.
      canvas.drawPath(
        Path()
          ..moveTo(x - _u * 0.64, bottom - _u * 0.30)
          ..lineTo(x - _u * 0.64, bottom - _u * 0.56)
          ..quadraticBezierTo(
            x - _u * 0.20,
            bottom - _u * 0.66,
            x + _u * 0.20,
            bottom - _u * 0.64,
          )
          ..quadraticBezierTo(
            x + _u * 0.66,
            bottom - _u * 0.62,
            x + _u * 0.64,
            bottom - _u * 0.40,
          )
          ..quadraticBezierTo(
            x + _u * 0.62,
            bottom - _u * 0.30,
            x + _u * 0.50,
            bottom - _u * 0.30,
          )
          ..close(),
        paint,
      );
      canvas.drawPath(
        Path()
          ..moveTo(x - _u * 0.42, bottom - _u * 0.62)
          ..lineTo(x + _u * 0.58, bottom - _u * 1.10)
          ..lineTo(x + _u * 0.62, bottom - _u * 0.60)
          ..close(),
        paint,
      );
      canvas.drawLine(
        Offset(x + _u * 0.30, bottom - _u * 0.62),
        Offset(x + _u * 0.44, bottom - _u * 1.02),
        Paint()
          ..color = paint.color
          ..strokeWidth = _u * 0.018,
      );
    }

    // Come le figure: prima il filo di luce, poi il nero sopra.
    canvas.save();
    canvas.translate(-_u * 0.014, -_u * 0.012);
    body(Paint()..color = _rim);
    canvas.restore();
    body(Paint()..color = _ink);

    // I pedali d'ottone e il filetto dorato lungo la cassa.
    for (final dx in [-0.10, -0.07, -0.04]) {
      canvas.drawRect(
        Rect.fromLTWH(x + _u * dx, bottom - _u * 0.11, _u * 0.022, _u * 0.03),
        Paint()..color = AppColors.gold,
      );
    }
    canvas.drawLine(
      Offset(x - _u * 0.40, bottom - _u * 0.36),
      Offset(x + _u * 0.48, bottom - _u * 0.36),
      Paint()
        ..color = AppColors.gold.withValues(alpha: 0.7)
        ..strokeWidth = _u * 0.010,
    );
    // La tastiera: avorio e tasti neri a gruppi di due e tre.
    canvas.drawRect(
      Rect.fromLTRB(
        x - _u * 0.66,
        bottom - _u * 0.45,
        x - _u * 0.36,
        bottom - _u * 0.38,
      ),
      Paint()..color = AppColors.textPrimary,
    );
    for (var i = 0; i < 7; i++) {
      if (i == 2 || i == 6) continue;
      canvas.drawRect(
        Rect.fromLTWH(
          x - _u * 0.66 + (i + 0.7) * _u * 0.04,
          bottom - _u * 0.45,
          _u * 0.018,
          _u * 0.040,
        ),
        Paint()..color = _ink,
      );
    }
  }

  void _safeShape(Canvas canvas, double bottom, {double dial = 0}) {
    final box = Rect.fromLTRB(
      _victimX - _u * 0.44,
      bottom - _u * 0.88,
      _victimX + _u * 0.44,
      bottom,
    );
    // I piedini e il filo di luce sul bordo.
    for (final dx in [-0.36, 0.30]) {
      canvas.drawRect(
        Rect.fromLTWH(
          _victimX + _u * dx,
          bottom - _u * 0.03,
          _u * 0.06,
          _u * 0.03,
        ),
        Paint()..color = _ink,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        box.translate(-_u * 0.014, -_u * 0.012),
        Radius.circular(_u * 0.04),
      ),
      Paint()..color = _rim,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, Radius.circular(_u * 0.04)),
      Paint()..color = const Color(0xFF0C0D10),
    );
    final brass = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _u * 0.022;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        box.deflate(_u * 0.07),
        Radius.circular(_u * 0.03),
      ),
      brass,
    );
    // Le cerniere.
    for (final dy in [-0.24, 0.24]) {
      canvas.drawRect(
        Rect.fromCenter(
          center: box.center.translate(-_u * 0.39, _u * dy),
          width: _u * 0.04,
          height: _u * 0.10,
        ),
        Paint()..color = AppColors.gold.withValues(alpha: 0.85),
      );
    }
    final dialAt = box.center.translate(-_u * 0.08, 0);
    canvas.drawCircle(
      dialAt,
      _u * 0.12,
      Paint()..color = const Color(0xFF1C1D22),
    );
    canvas.drawCircle(dialAt, _u * 0.12, brass);
    for (var i = 0; i < 12; i++) {
      final spoke = Offset(cos(i * pi / 6 + dial), sin(i * pi / 6 + dial));
      canvas.drawLine(
        dialAt + spoke * (_u * (i.isEven ? 0.08 : 0.095)),
        dialAt + spoke * (_u * 0.12),
        brass,
      );
    }
    canvas.drawLine(
      dialAt,
      dialAt + Offset(sin(dial), -cos(dial)) * (_u * 0.07),
      brass,
    );
    canvas.drawCircle(dialAt, _u * 0.025, Paint()..color = AppColors.gold);
    // La maniglia a croce.
    final handle = box.center.translate(_u * 0.20, 0);
    for (var i = 0; i < 3; i++) {
      final a = i * pi / 3 + 0.3;
      final reach = Offset(cos(a), sin(a)) * (_u * 0.08);
      canvas.drawLine(handle - reach, handle + reach, brass);
    }
    canvas.drawCircle(handle, _u * 0.025, Paint()..color = AppColors.gold);
    for (final corner in [
      box.topLeft,
      box.topRight,
      box.bottomLeft,
      box.bottomRight,
    ]) {
      canvas.drawCircle(
        Offset.lerp(corner, box.center, 0.10)!,
        _u * 0.014,
        Paint()..color = AppColors.gold,
      );
    }
  }

  void _chandelierShape(Canvas canvas, double bottom, bool landed) {
    final x = _victimX;
    final squash = landed ? 0.55 : 1.0;
    final brassColor = const Color(0xFFB8913F);
    final ink = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = _u * 0.055
      ..strokeCap = StrokeCap.round;
    final brass = Paint()
      ..color = brassColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _u * 0.026
      ..strokeCap = StrokeCap.round;
    // La corona in alto e il fusto.
    final crown = Offset(x, bottom - _u * 0.85 * squash);
    canvas.drawLine(crown, Offset(x, bottom - _u * 0.02), ink);
    canvas.drawLine(crown, Offset(x, bottom - _u * 0.02), brass);
    canvas.drawOval(
      Rect.fromCenter(center: crown, width: _u * 0.16, height: _u * 0.08),
      Paint()..color = brassColor,
    );
    final crystal = Paint()..color = const Color(0xFFDCEBFA);
    final glint = sprites?.glint;
    for (final (width, lift) in [(1.30, 0.20), (0.94, 0.44), (0.56, 0.66)]) {
      final y = bottom - _u * lift * squash;
      final arc = Rect.fromCenter(
        center: Offset(x, y - _u * 0.10),
        width: _u * width,
        height: _u * 0.36 * squash,
      );
      canvas.drawArc(arc, 0, pi, false, ink);
      canvas.drawArc(arc, 0, pi, false, brass);
      for (var i = 0; i < 6; i++) {
        final cx = x - _u * width / 2 + _u * width * i / 5;
        final candle = Offset(cx, y - _u * 0.12);
        // I pendagli di cristallo sotto ogni braccio (dopo l'urto ne
        // restano pochi).
        if (!landed || i.isEven) {
          final drop = Offset(
            cx,
            y - _u * 0.10 + _u * 0.18 * squash * sin(pi * i / 5) + _u * 0.05,
          );
          canvas.drawPath(
            Path()
              ..moveTo(drop.dx, drop.dy - _u * 0.035)
              ..quadraticBezierTo(
                drop.dx + _u * 0.025,
                drop.dy + _u * 0.01,
                drop.dx,
                drop.dy + _u * 0.035,
              )
              ..quadraticBezierTo(
                drop.dx - _u * 0.025,
                drop.dy + _u * 0.01,
                drop.dx,
                drop.dy - _u * 0.035,
              ),
            crystal,
          );
          if (!landed && glint != null) {
            ParticleSprites.draw(
              canvas,
              glint,
              drop,
              width: _u * 0.14,
              height: _u * 0.14,
              opacity: max(0.0, sin(t * 90 + i * 1.7 + width * 3)),
            );
          }
        }
        // La candela: il cero bianco e la fiammella, finché è accesa.
        canvas.drawRect(
          Rect.fromCenter(
            center: candle.translate(0, _u * 0.02),
            width: _u * 0.026,
            height: _u * 0.07 * squash,
          ),
          Paint()..color = AppColors.textPrimary,
        );
        if (!landed) {
          final flame = candle.translate(0, -_u * 0.04);
          canvas.drawCircle(
            flame,
            _u * 0.07,
            Paint()
              ..color = _warm.withValues(alpha: 0.30)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, _u * 0.03),
          );
          canvas.drawOval(
            Rect.fromCenter(
              center: flame,
              width: _u * 0.026,
              height: _u * 0.05,
            ),
            Paint()..color = const Color(0xFFFFE9A8),
          );
        }
      }
    }
    // Il pendente in fondo.
    canvas.drawCircle(Offset(x, bottom - _u * 0.02), _u * 0.035, crystal);
  }

  // ------------------------------------------------ tonfi, schegge e polvere

  /// Dove arriva la mano di una figura ferma (niente passo né rotazione):
  /// serve a far partire dalle dita quello che cade o vola via.
  Offset _handAt(
    Offset feet, {
    int facing = 1,
    double lean = 0,
    double crouch = 0,
    double arm = 0.08,
    double elbow = 0.20,
  }) {
    final h = _u;
    final hip = Offset(-h * 0.03 * crouch, -h * (0.50 - 0.13 * crouch));
    final hand =
        Offset(h * 0.035, -h * 0.325) +
        _aim(arm) * (h * 0.185) +
        _aim(arm + elbow) * (h * 0.175);
    final turned = Offset(
      hand.dx * cos(lean) - hand.dy * sin(lean),
      hand.dx * sin(lean) + hand.dy * cos(lean),
    );
    final local = hip + turned;
    return feet + Offset(local.dx * facing, local.dy);
  }

  /// La polvere che si alza quando qualcosa di pesante arriva a terra:
  /// sbuffi che scappano di lato, radenti all'asfalto, e si gonfiano.
  void _dust(
    Canvas canvas,
    Offset at,
    double life, {
    int seed = 1,
    int count = 6,
    double size = 1,
    double spread = 1,
    Color color = const Color(0xFF8F8A84),
  }) {
    // Chi la scampa per fortuna non cade: niente polvere dove sarebbe caduto.
    if (life <= 0 || life >= 1 || _missed) return;
    final rng = Random(seed);
    final ease = Curves.easeOutCubic.transform(life);
    final fade = (1 - life) * (1 - life * 0.5);
    final textures = sprites;
    final grit = textures?.dirt ?? const [];
    if (grit.isNotEmpty) {
      ParticleSprites.drawTinted(
        canvas,
        grit[seed % grit.length],
        at.translate(0, -_u * 0.14 * ease),
        width: _u * size * (0.7 + 1.1 * ease),
        height: _u * size * (0.45 + 0.6 * ease),
        opacity: 0.6 * (1 - life),
        tint: color,
      );
    }
    final puffs = textures?.puffs ?? const [];
    for (var i = 0; i < count; i++) {
      final side = i.isEven ? 1.0 : -1.0;
      final reach = (0.25 + rng.nextDouble() * 0.85) * spread;
      final rise = 0.02 + rng.nextDouble() * 0.22;
      final grow = 0.30 + rng.nextDouble() * 0.30;
      final spin = rng.nextDouble() * 2 * pi;
      final center =
          at + Offset(side * _u * reach * ease, -_u * (0.06 + rise * ease));
      final radius = _u * size * grow * (0.5 + 0.8 * ease);
      if (puffs.isNotEmpty) {
        ParticleSprites.drawTinted(
          canvas,
          puffs[i % puffs.length],
          center,
          width: radius * 2,
          height: radius * 1.7,
          opacity: 0.38 * fade,
          rotation: spin + side * life * 0.8,
          tint: color,
        );
      } else {
        canvas.drawCircle(
          center,
          radius * 0.8,
          Paint()
            ..color = color.withValues(alpha: 0.45 * fade)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, _u * 0.05),
        );
      }
    }
  }

  /// Pezzi che saltano via da [origin], ricadono e restano sull'asfalto.
  void _debris(
    Canvas canvas,
    Offset origin,
    double life, {
    required int seed,
    int count = 10,
    List<Color> colors = const [Color(0xFF1E1F24)],
    double size = 1,
    double reach = 1,
    double lift = 1,
    double drift = 0,
    bool glints = false,
  }) {
    if (life <= 0) return;
    final rng = Random(seed);
    final g = _u * 14.0;
    final clock = life * 0.9;
    final glint = glints ? sprites?.glint : null;
    for (var i = 0; i < count; i++) {
      final vx = ((rng.nextDouble() * 2 - 1) + drift) * _u * 1.5 * reach;
      final vy = -(0.5 + rng.nextDouble()) * _u * 2.6 * lift;
      final spin = (rng.nextDouble() * 2 - 1) * 16;
      final width = _u * (0.022 + rng.nextDouble() * 0.04) * size;
      final height = width * (0.35 + rng.nextDouble() * 0.7);
      final floor = _ground + _u * (0.005 + rng.nextDouble() * 0.05);
      final twinkle = rng.nextDouble() * 2 * pi;
      final land =
          (-vy + sqrt(max(0.0, vy * vy + 2 * g * (floor - origin.dy)))) / g;
      final time = min(clock, land);
      var x = origin.dx + vx * time;
      final y = origin.dy + vy * time + 0.5 * g * time * time;
      if (clock > land) x += vx * 0.12 * min(1.0, (clock - land) * 8);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(spin * time);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: width, height: height),
        Paint()..color = colors[i % colors.length],
      );
      canvas.restore();
      if (glint != null) {
        ParticleSprites.draw(
          canvas,
          glint,
          Offset(x, y),
          width: width * 5,
          height: width * 5,
          opacity: max(0.0, sin(t * 120 + twinkle)) * 0.9,
        );
      }
    }
  }

  /// La stella frastagliata del fumetto, nel punto esatto dell'urto.
  void _impactBurst(
    Canvas canvas,
    Offset center,
    double life, {
    double size = 1,
    Color color = const Color(0xFFFFE27A),
  }) {
    if (life <= 0 || life >= 1) return;
    final pop = Curves.easeOutBack.transform(min(1.0, life * 3));
    final fade = 1 - _span(life, 0.45, 1);
    final r = _u * 0.30 * size * pop;
    final rng = Random(7);
    final path = Path();
    for (var i = 0; i < 20; i++) {
      final a = i * pi / 10 + 0.2;
      final rr = i.isEven ? r * (0.85 + rng.nextDouble() * 0.4) : r * 0.45;
      final p = center + Offset(cos(a), sin(a)) * rr;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()..color = color.withValues(alpha: 0.95 * fade),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _u * 0.014
        ..strokeJoin = StrokeJoin.round
        ..color = _ink.withValues(alpha: 0.8 * fade),
    );
    canvas.drawCircle(
      center,
      r * 0.35,
      Paint()..color = Colors.white.withValues(alpha: fade),
    );
    final glint = sprites?.glint;
    if (glint != null) {
      ParticleSprites.draw(
        canvas,
        glint,
        center,
        width: r * 3.4,
        height: r * 3.4,
        opacity: fade,
        tint: const Color(0xFFFFF3C4),
      );
    }
  }

  /// Una stellina a cinque punte, col bordo nero del fumetto.
  void _cartoonStar(
    Canvas canvas,
    Offset center,
    double r,
    double spin,
    Color color,
  ) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = spin - pi / 2 + i * pi / 5;
      final p = center + Offset(cos(a), sin(a)) * (i.isEven ? r : r * 0.45);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.35
        ..strokeJoin = StrokeJoin.round
        ..color = _ink.withValues(alpha: color.a),
    );
    canvas.drawPath(path, Paint()..color = color);
  }

  /// Le stelline che girano intorno alla testa, in prospettiva: quelle
  /// dietro più piccole.
  void _bonkStars(Canvas canvas, Offset head, double life) {
    if (life <= 0 || life >= 1) return;
    final fade = 1 - _span(life, 0.7, 1);
    for (var i = 0; i < 4; i++) {
      final a = life * 14 + i * pi / 2;
      final depth = 0.75 + 0.25 * sin(a);
      _cartoonStar(
        canvas,
        head + Offset(cos(a) * _u * 0.26, sin(a) * _u * 0.07),
        _u * 0.055 * depth,
        life * 6 + i,
        AppColors.gold.withValues(alpha: fade),
      );
    }
  }

  /// Fumo nero che sale a sbuffi da [base].
  void _soot(
    Canvas canvas,
    Offset base,
    double life, {
    int seed = 1,
    int count = 6,
    double size = 1,
  }) {
    if (life <= 0 || life >= 1) return;
    final frames = sprites?.blackSmoke ?? const [];
    final rng = Random(seed);
    for (var i = 0; i < count; i++) {
      final birth = i / count * 0.5;
      final l = _span(life, birth, birth + 0.5);
      if (l <= 0 || l >= 1) continue;
      final sideways = (rng.nextDouble() * 2 - 1) * _u * 0.35;
      final center =
          base +
          Offset(
            sideways * l + sin(l * 4 + i) * _u * 0.06,
            -_u * (0.1 + 1.5 * l),
          );
      final r = _u * size * (0.35 + 0.65 * l);
      if (frames.isNotEmpty) {
        ParticleSprites.draw(
          canvas,
          frames[i % frames.length],
          center,
          width: r * 2,
          height: r * 2,
          opacity: 0.85 * (1 - l),
          rotation: rng.nextDouble() * 6 + l,
        );
      } else {
        _puff(
          canvas,
          center,
          l,
          size: size * 0.6,
          color: const Color(0xFF2A2826),
        );
      }
    }
  }

  /// Uno sbuffo di fumo del colore giusto (verde di veleno, grigio di
  /// gomma bruciata) che sale e si allarga.
  void _haze(
    Canvas canvas,
    Offset center,
    double life, {
    double size = 1,
    required Color color,
  }) {
    if (life <= 0 || life >= 1) return;
    final smoke = sprites?.smoke;
    if (smoke == null) {
      _puff(canvas, center, life, size: size, color: color);
      return;
    }
    ParticleSprites.drawTinted(
      canvas,
      smoke,
      center,
      width: _u * size * (0.9 + 0.8 * life),
      height: _u * size * (0.9 + 0.8 * life),
      opacity: 0.85 * (1 - life),
      rotation: life * 1.5,
      tint: color,
    );
  }

  /// Il punto esclamativo che spunta sopra chi ha capito.
  void _exclaim(Canvas canvas, Offset at, double life) {
    if (life <= 0 || life >= 1) return;
    final pop = Curves.easeOutBack.transform(min(1.0, life * 4));
    final fade = 1 - _span(life, 0.75, 1);
    final mark = TextPainter(
      text: TextSpan(
        text: '!',
        style: TextStyle(
          fontFamily: 'Georgia',
          fontSize: _u * 0.34,
          fontWeight: FontWeight.w900,
          color: AppColors.gold.withValues(alpha: fade),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.scale(pop);
    mark.paint(canvas, Offset(-mark.width / 2, -mark.height / 2));
    canvas.restore();
  }

  void _blast(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    final gone = t >= strike;
    const topple = 0.70;
    const down = 0.775;

    // Il pacco: portato davanti, accostato all'orecchio e scosso, guardato da
    // vicino; poi, quando la miccia è agli sgoccioli, tenuto più lontano che
    // si può.
    final raise = _smooth(_span(t, 0.36, 0.42));
    final look = _smooth(_span(t, 0.47, 0.50));
    final away = _smooth(_span(t, 0.51, 0.54));
    var arm = _mix(_mix(_mix(0.5, 1.75, raise), 1.2, look), 1.55, away);
    final elbow = _mix(_mix(_mix(0.6, 1.8, raise), 0.6, look), 0.05, away);
    final lean = _mix(0.10 * look, -0.20, away);
    final shake = _span(t, 0.42, 0.47);
    if (shake > 0 && shake < 1) arm += sin(t * 300) * 0.10;
    if (away > 0 && !gone) arm += sin(t * 420) * 0.03 * away;
    final feet = Offset(walkX, _ground);
    final box =
        _handAt(feet, lean: lean, arm: arm, elbow: elbow) +
        Offset(_u * 0.06, -_u * 0.02);
    final centre =
        _handAt(
          Offset(_victimX, _ground),
          lean: -0.20,
          arm: 1.55,
          elbow: 0.05,
        ) +
        Offset(_u * 0.06, -_u * 0.02);

    _killerSalute(canvas);
    _wall(canvas);

    // La bruciatura resta sull'asfalto.
    if (gone) {
      final scorch = sprites?.scorch;
      final appear = _span(t, strike, strike + 0.02);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(_victimX + _u * 0.1, _ground + _u * 0.04),
          width: _u * 1.7,
          height: _u * 0.18,
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.75 * appear),
      );
      if (scorch != null) {
        ParticleSprites.drawTinted(
          canvas,
          scorch,
          Offset(_victimX + _u * 0.1, _ground + _u * 0.03),
          width: _u * 2.0,
          height: _u * 0.32,
          opacity: 0.8 * appear,
          tint: const Color(0xFF15100C),
        );
      }
      // La colonna di fumo nero: dietro la sagoma, perché si stagli.
      _soot(
        canvas,
        centre.translate(0, -_u * 0.2),
        _span(t, strike + 0.03, 0.92),
        seed: 2,
        count: 8,
        size: 1.5,
      );
    }

    if (!gone) {
      _person(
        canvas,
        feet: feet,
        walk: walk,
        stride: stride,
        lean: lean,
        arm: arm,
        elbow: elbow,
        hat: victimHat,
        prop: _Prop.box,
      );
      _fuse(canvas, box);
      _exclaim(
        canvas,
        Offset(walkX - _u * 0.05, _ground - _u * 1.45),
        _span(t, 0.51, 0.555),
      );
    } else if (t < down) {
      // Annerito, i capelli dritti, fermo com'era: poi va giù tutto d'un
      // pezzo, come un'asse.
      final tip = _span(t, topple, down);
      final tilt = -pi / 2 * 0.96 * Curves.easeIn.transform(tip);
      final sway = tip == 0 ? sin(t * 60) * 0.02 * _span(t, 0.64, topple) : 0.0;
      _person(
        canvas,
        feet: Offset(_victimX, _ground),
        tilt: tilt + sway,
        lean: -0.20,
        arm: 1.55,
        elbow: 0.05,
        backArm: -0.5,
        backElbow: 0.1,
        hat: victimHat,
        hatOn: false,
      );
      _frazzle(canvas, Offset(_victimX, _ground), tilt + sway, -0.20);
      for (var i = 0; i < 3; i++) {
        final life = ((t - strike) * 9 + i / 3) % 1;
        final head = Offset(
          _victimX + _u * 0.98 * sin(tilt + sway),
          _ground - _u * 0.98 * cos(tilt + sway),
        );
        _puff(
          canvas,
          head.translate(_u * (i - 1) * 0.08, -_u * (0.10 + 0.5 * life)),
          life,
          size: 0.25,
          color: const Color(0xFF3A3836),
        );
      }
    } else {
      _corpse(canvas, _victimX, -1);
      _soot(
        canvas,
        Offset(_victimX - _u * 0.4, _ground - _u * 0.1),
        _span(t, down, 0.95),
        seed: 7,
        count: 4,
        size: 0.5,
      );
    }
    _dust(
      canvas,
      Offset(_victimX - _u * 0.55, _ground),
      _span(t, down, down + 0.18),
      seed: 6,
      size: 0.9,
    );

    // L'esplosione: il lampo bianco, la palla di fuoco a strati, l'onda
    // d'urto, i pezzi del pacco e le braci.
    final boom = _span(t, strike - 0.001, strike + 0.14);
    if (boom > 0 && boom < 1) {
      final textures = sprites;
      if (textures != null) {
        final flare = _span(t, strike - 0.001, strike + 0.035);
        if (flare < 1 && textures.flashes.isNotEmpty) {
          final frames = textures.flashes;
          ParticleSprites.draw(
            canvas,
            frames[(flare * frames.length).floor().clamp(0, frames.length - 1)],
            centre,
            width: _u * 3.2 * (0.6 + 0.4 * flare),
            height: _u * 3.2 * (0.6 + 0.4 * flare),
            opacity: 1 - flare * 0.3,
          );
        }
        for (final (k, rot, dx, dy, scale) in const [
          (0, 0.0, 0.0, 0.0, 1.0),
          (1, 1.3, -0.45, 0.25, 0.7),
          (2, 2.4, 0.45, 0.15, 0.65),
        ]) {
          final p = _span(
            t,
            strike + 0.002 + k * 0.008,
            strike + 0.10 + k * 0.012,
          );
          if (p <= 0 || p >= 1) continue;
          ParticleSprites.draw(
            canvas,
            textures.explosionAt(p),
            centre + Offset(dx, dy - 0.3 * p) * _u,
            width:
                _u * 3.0 * scale * (0.45 + 0.55 * Curves.easeOut.transform(p)),
            height:
                _u * 3.0 * scale * (0.45 + 0.55 * Curves.easeOut.transform(p)),
            opacity: 1 - _span(p, 0.55, 1),
            rotation: rot + p * 0.4,
          );
        }
      } else {
        final grow = Curves.easeOut.transform(boom);
        for (final (scale, color) in [
          (1.0, const Color(0xFFFF6A2B)),
          (0.72, const Color(0xFFFFB13B)),
          (0.42, const Color(0xFFFFF3C4)),
        ]) {
          canvas.drawCircle(
            centre,
            _u * 1.5 * grow * scale,
            Paint()
              ..color = color.withValues(alpha: (1 - boom) * 0.95)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, _u * 0.05),
          );
        }
      }
      _spray(
        canvas,
        centre,
        boom,
        seed: 5,
        color: const Color(0xFFFFB13B),
        count: 30,
        bias: Offset.zero,
        reach: 2.2,
      );
    }
    final ring = _span(t, strike - 0.001, strike + 0.06);
    if (ring > 0 && ring < 1) {
      canvas.drawOval(
        Rect.fromCenter(
          center: centre,
          width: _u * (0.6 + 6.0 * ring),
          height: _u * (0.5 + 4.0 * ring),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _u * 0.06 * (1 - ring)
          ..color = Colors.white.withValues(alpha: 0.7 * (1 - ring)),
      );
    }
    _debris(
      canvas,
      centre,
      _span(t, strike, strike + 0.20),
      seed: 9,
      count: 14,
      colors: const [Color(0xFF7A1B22), AppColors.gold, Color(0xFF4A1015)],
      size: 1.2,
      reach: 1.4,
      lift: 1.2,
    );

    // Il cappello, sparato in cielo, torna giù e si posa sul petto.
    final fallBack = _span(t, 0.68, 0.80);
    if (fallBack > 0) {
      _looseHat(
        canvas,
        Offset(
          _victimX -
              _u * 0.52 +
              sin(fallBack * 10) * _u * 0.12 * (1 - fallBack),
          _mix(
            -_u * 1.4,
            _ground - _u * 0.17,
            Curves.easeIn.transform(fallBack),
          ),
        ),
        fallBack < 1 ? 0.2 + sin(fallBack * 10) * 0.5 * (1 - fallBack) : 0.2,
      );
    }
    _flash(canvas, _span(t, strike - 0.001, strike + 0.06), strength: 1);
  }

  /// La miccia sul pacco: si accorcia sfrigolando, con le scintille in punta.
  void _fuse(Canvas canvas, Offset box) {
    final burn = _span(t, 0.40, strike);
    final left = 1 - burn;
    final base = box.translate(_u * 0.05, -_u * 0.075);
    Offset along(double s) =>
        base + Offset(_u * 0.07 * s + _u * 0.025 * sin(s * 5), -_u * 0.13 * s);
    final path = Path()..moveTo(base.dx, base.dy);
    for (var i = 1; i <= 12; i++) {
      final p = along(left * i / 12);
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _u * 0.014
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF2A2420),
    );
    if (burn <= 0) return;
    final tip = along(left);
    final crackle = 0.6 + 0.4 * sin(t * 500).abs();
    canvas.drawCircle(
      tip,
      _u * 0.10 * crackle,
      Paint()
        ..color = _warm.withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, _u * 0.04),
    );
    _star(
      canvas,
      tip,
      _u * (0.05 + 0.04 * sin(t * 500).abs()),
      const Color(0xFFFFF3C4).withValues(alpha: crackle),
    );
    final rng = Random((t * 900).floor());
    final spark = Paint()..color = const Color(0xFFFFD27A);
    for (var i = 0; i < 6; i++) {
      final a = rng.nextDouble() * 2 * pi;
      final r = _u * (0.03 + rng.nextDouble() * 0.08);
      canvas.drawCircle(tip + Offset(cos(a), sin(a)) * r, _u * 0.008, spark);
    }
    final wisp = (t * 30) % 1;
    _puff(
      canvas,
      tip.translate(_u * 0.03 * wisp, -_u * 0.25 * wisp),
      wisp,
      size: 0.15,
      color: const Color(0xFF8E8A86),
    );
  }

  /// I capelli dritti in testa di chi è appena saltato in aria.
  void _frazzle(Canvas canvas, Offset feet, double tilt, double lean) {
    canvas.save();
    canvas.translate(feet.dx, feet.dy);
    canvas.rotate(tilt);
    canvas.translate(0, -_u * 0.50);
    canvas.rotate(lean);
    final head = Offset(_u * 0.03, -_u * 0.485);
    final ink = Paint()
      ..color = _ink
      ..strokeWidth = _u * 0.016
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 7; i++) {
      final a = -pi / 2 + (i - 3) * 0.32;
      final from = head + Offset(cos(a), sin(a)) * (_u * 0.07);
      final to = head + Offset(cos(a), sin(a)) * (_u * (0.14 + 0.02 * (i % 2)));
      canvas.drawLine(from, to, ink);
    }
    canvas.restore();
  }

  void _poison(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    const smash = 0.597;
    final fall = _span(t, 0.62, 0.72);
    final stagger = _smooth(_span(t, strike, 0.62));
    final x = walkX - _u * 0.10 * stagger;
    final dropped = t >= strike;

    _killerSalute(canvas);
    _wall(canvas);

    // La pozza verde, che si allarga e fa le bolle.
    final spot = Offset(_victimX + _u * 0.30, _ground - _u * 0.02);
    if (t >= smash) {
      final grown = _span(t, smash, 0.75);
      canvas.drawOval(
        Rect.fromCenter(
          center: spot.translate(0, _u * 0.06),
          width: _u * 0.50 * Curves.easeOut.transform(grown),
          height: _u * 0.06,
        ),
        Paint()..color = const Color(0xFF6FBF4A).withValues(alpha: 0.85),
      );
      for (var i = 0; i < 3; i++) {
        final pop = ((t - smash) * 14 + i * 0.37) % 1;
        canvas.drawCircle(
          spot.translate(
            _u * (i - 1) * 0.12 * grown,
            _u * 0.05 - _u * 0.03 * pop,
          ),
          _u * 0.018 * pop * grown,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = _u * 0.006
            ..color = const Color(0xFFB6F08F).withValues(alpha: 1 - pop),
        );
      }
      for (var i = 0; i < 3; i++) {
        final life = _span(t, smash + 0.02 + i * 0.05, smash + 0.20 + i * 0.05);
        _haze(
          canvas,
          spot.translate(_u * (i - 1) * 0.1, -_u * (0.1 + 0.5 * life)),
          life,
          size: 0.35,
          color: const Color(0xFF6FBF4A),
        );
      }
    }

    if (fall <= 0) {
      // Il sorso, la tazzina giù al petto, un attimo di quiete; poi la tosse
      // che lo piega, e le mani alla gola.
      final raise =
          _smooth(_span(t, 0.37, 0.42)) - _smooth(_span(t, 0.455, 0.49));
      final sip = _span(t, 0.42, 0.455);
      var cough = 0.0;
      for (final at in const [0.505, 0.525, 0.545]) {
        final c = _span(t, at, at + 0.016);
        if (c > 0 && c < 1) cough = max(cough, sin(pi * c));
      }
      final choke = _span(t, strike, strike + 0.02);
      final shiver = dropped ? sin(t * 380) * 0.06 : 0.0;
      _person(
        canvas,
        feet: Offset(x, _ground),
        walk: dropped ? -t * 140 : walk,
        stride: dropped ? 0.35 * (1 - _span(t, 0.60, 0.62)) : stride,
        lean:
            -0.08 * sin(pi * sip) + 0.28 * cough - 0.10 * choke + shiver * 0.5,
        crouch: 0.10 * cough + 0.15 * choke,
        arm: _mix(_mix(0.75, 1.6, raise), 2.0, choke) + shiver,
        elbow: _mix(_mix(1.6, 2.37, raise), 2.71, choke),
        backArm: _mix(-0.10, 2.0, choke) - shiver,
        backElbow: _mix(0.2, 2.71, choke),
        hat: victimHat,
        prop: dropped || t < 0.34 ? _Prop.none : _Prop.cup,
      );
      // Ogni colpo di tosse, uno sbuffo verde.
      for (final at in const [0.505, 0.525, 0.545]) {
        final life = _span(t, at, at + 0.06);
        _haze(
          canvas,
          Offset(
            x + _u * (0.16 + 0.18 * life),
            _ground - _u * (0.90 + 0.06 * life),
          ),
          life,
          size: 0.30,
          color: const Color(0xFF8BD66A),
        );
      }
    } else {
      // Le ginocchia cedono con le mani ancora alla gola, poi va giù
      // all'indietro.
      if (fall >= 1) {
        _corpse(canvas, x, -1);
      } else {
        final buckle = Curves.easeOut.transform(min(1.0, fall * 1.6));
        final topple = Curves.easeIn.transform(fall);
        _person(
          canvas,
          feet: Offset(x, _ground),
          crouch: buckle * 0.95,
          tilt: -(0.10 * buckle + 1.20 * topple),
          lean: 0.25 * buckle,
          arm: _mix(2.0, 2.4, topple),
          elbow: _mix(2.71, 1.2, topple),
          backArm: _mix(2.0, -1.3, topple),
          backElbow: _mix(2.71, 0.7, topple),
          hat: victimHat,
          hatOn: false,
        );
      }
    }
    if (fall > 0.12) {
      final flight = _span(t, 0.635, 0.82);
      _looseHat(
        canvas,
        Offset(
          x - _u * (0.30 + 0.90 * flight),
          _ground -
              _u * 0.03 -
              _u * 0.35 * sin(pi * min(1.0, flight * 1.6)) * (1 - flight),
        ),
        flight < 1 ? -flight * 7 : -0.2,
      );
    }
    _dust(
      canvas,
      Offset(x - _u * 0.5, _ground),
      _span(t, 0.72, 0.90),
      seed: 11,
      size: 0.8,
    );

    // La tazzina scivola di mano, gira, e va in pezzi sull'asfalto.
    if (dropped) {
      final from =
          _handAt(Offset(walkX, _ground), arm: 0.75, elbow: 1.6) +
          Offset(_u * 0.035, -_u * 0.02);
      final tumble = _span(t, strike, smash);
      if (tumble < 1) {
        _teacup(
          canvas,
          Offset(
            _mix(from.dx, spot.dx, tumble),
            _mix(from.dy, spot.dy, tumble * tumble),
          ),
          _u,
          spin: tumble * 2.6,
          steam: false,
        );
      } else {
        _debris(
          canvas,
          spot,
          _span(t, smash, smash + 0.12),
          seed: 4,
          count: 9,
          colors: const [AppColors.textPrimary, Color(0xFFCFC8BA)],
          size: 0.55,
          reach: 0.6,
          lift: 0.55,
        );
        _spray(
          canvas,
          spot,
          _span(t, smash, smash + 0.10),
          seed: 13,
          color: const Color(0xFF6FBF4A),
          count: 10,
          bias: const Offset(0, -0.7),
          reach: 0.45,
        );
      }
    }
  }

  /// La tazzina avvelenata: porcellana, filo d'oro, e un vapore verdognolo.
  void _teacup(
    Canvas canvas,
    Offset center,
    double h, {
    double spin = 0,
    bool steam = true,
  }) {
    final china = Paint()..color = AppColors.textPrimary;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(spin);
    canvas.drawCircle(
      Offset(-h * 0.046, -h * 0.004),
      h * 0.020,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.011
        ..color = AppColors.textPrimary,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-h * 0.046, -h * 0.034)
        ..lineTo(h * 0.046, -h * 0.034)
        ..quadraticBezierTo(h * 0.044, h * 0.030, 0, h * 0.032)
        ..quadraticBezierTo(-h * 0.044, h * 0.030, -h * 0.046, -h * 0.034)
        ..close(),
      china,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, -h * 0.034),
        width: h * 0.092,
        height: h * 0.018,
      ),
      Paint()..color = const Color(0xFF2E4A22),
    );
    canvas.drawLine(
      Offset(-h * 0.044, -h * 0.018),
      Offset(h * 0.044, -h * 0.018),
      Paint()
        ..color = AppColors.gold
        ..strokeWidth = h * 0.006,
    );
    canvas.restore();
    if (!steam) return;
    final vapour = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.009
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF8BD66A).withValues(alpha: 0.55);
    for (final dx in [-0.015, 0.018]) {
      final path = Path()..moveTo(center.dx + h * dx, center.dy - h * 0.05);
      for (var i = 1; i <= 5; i++) {
        path.lineTo(
          center.dx + h * dx + sin(t * 40 + i * 1.2 + dx * 90) * h * 0.016,
          center.dy - h * (0.05 + 0.025 * i),
        );
      }
      canvas.drawPath(path, vapour);
    }
  }

  void _noose(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    // Scende piano alle sue spalle, gli cade sulla testa, si stringe; poi
    // tre strattoni lo tirano su.
    final lower = Curves.easeOut.transform(_span(t, 0.36, 0.50));
    final drop = Curves.easeIn.transform(_span(t, 0.50, 0.535));
    final cinch = _span(t, 0.535, 0.55);
    final hoisted = t >= strike;
    final lift =
        _u *
        (0.25 * Curves.easeOut.transform(_span(t, strike, 0.58)) +
            0.15 * Curves.easeOut.transform(_span(t, 0.60, 0.62)) +
            0.12 * Curves.easeOut.transform(_span(t, 0.64, 0.66)));
    var jolt = 0.0;
    for (final at in const [strike, 0.60, 0.64]) {
      final j = _span(t, at, at + 0.05);
      if (j > 0 && j < 1) jolt += sin(pi * j) * (1 - j);
    }
    final calm = _span(t, 0.68, 0.86);
    final sway = hoisted
        ? sin((t - strike) * 26) * 0.10 * (1 - calm * 0.7)
        : 0.0;
    final kick = hoisted ? 1 - calm : 0.0;

    _killerSalute(canvas);
    _wall(canvas);

    final rope = Paint()
      ..color = const Color(0xFFC9B48A)
      ..strokeWidth = _u * 0.024
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Dove sta il cappio: sopra la testa che dondola, poi giù intorno al
    // collo, poi al collo di uno che sale.
    final Offset loop;
    final double loopW;
    final double loopH;
    if (hoisted) {
      loop = Offset(
        _victimX + sin(sway) * _u * 0.5,
        _ground - lift - _u * 0.88 - _u * 0.02 * jolt,
      );
      loopW = _u * 0.17;
      loopH = _u * 0.07;
    } else {
      final swing = sin(t * 14) * _u * 0.04 * (1 - drop);
      loop = Offset(
        _victimX + swing,
        drop > 0
            ? _mix(_ground - _u * 1.35, _ground - _u * 0.90, drop)
            : _mix(-_u * 1.2, _ground - _u * 1.35, lower),
      );
      loopW = _u * _mix(_mix(0.30, 0.22, drop), 0.17, cinch);
      loopH = _u * _mix(_mix(0.30, 0.20, drop), 0.07, cinch);
    }
    final knot = loop.translate(0, -loopH / 2);

    if (hoisted) {
      final tilt = -sway * 0.8;
      final feet = Offset(
        loop.dx - _u * 0.88 * sin(tilt),
        loop.dy + _u * 0.88 * cos(tilt),
      );
      final limp = _smooth(_span(t, 0.68, 0.73));
      _person(
        canvas,
        feet: feet,
        tilt: tilt,
        dangle: sin(t * 95) * 0.75 * kick + 0.12,
        arm: _mix(2.75 + 0.2 * sin(t * 70) * kick, 0.15, limp),
        elbow: _mix(0.6, 0.1, limp),
        backArm: _mix(2.6 + 0.2 * cos(t * 64) * kick, -0.1, limp),
        backElbow: _mix(0.7, 0.1, limp),
        hat: victimHat,
        hatOn: false,
      );
    } else {
      final grab = _span(t, 0.535, 0.55);
      final shiver = grab > 0 ? sin(t * 380) * 0.05 : 0.0;
      if (t < 0.535) {
        _victim(
          canvas,
          x: walkX,
          walk: walk,
          stride: stride,
          smoking: t > 0.37,
        );
      } else {
        _person(
          canvas,
          feet: Offset(walkX, _ground),
          lean: -0.08 * grab,
          arm: _mix(0.08, 2.9, grab) + shiver,
          elbow: _mix(0.2, 0.3, grab),
          backArm: _mix(-0.10, 2.8, grab) - shiver,
          backElbow: _mix(0.2, 0.4, grab),
          hat: victimHat,
        );
      }
    }

    // La corda, il nodo a spire e l'anello.
    canvas.drawLine(Offset(_victimX, -_h), knot.translate(0, -_u * 0.14), rope);
    for (var i = 0; i < 5; i++) {
      canvas.drawLine(
        knot.translate(-_u * 0.035, -_u * (0.025 + 0.025 * i)),
        knot.translate(_u * 0.035, -_u * (0.025 + 0.025 * i)),
        rope,
      );
    }
    canvas.drawOval(
      Rect.fromCenter(center: loop, width: loopW, height: loopH),
      rope,
    );

    // La sigaretta cade di bocca quando arriva il cappio.
    final butt = _span(t, 0.535, 0.57);
    if (butt > 0) {
      final ember = Offset(
        _mix(_victimX + _u * 0.16, _victimX + _u * 0.30, butt),
        _mix(_ground - _u * 0.93, _ground - _u * 0.015, butt * butt),
      );
      canvas.drawLine(
        ember,
        ember.translate(-_u * 0.06, 0),
        Paint()
          ..color = const Color(0xFFE9E4D8)
          ..strokeWidth = _u * 0.014,
      );
      canvas.drawCircle(
        ember,
        _u * 0.012,
        Paint()..color = const Color(0xFFFF7A3B),
      );
      if (butt >= 1) _wisp(canvas, ember);
    }

    // I piedi lasciano terra: un velo di polvere. Al secondo strattone
    // salta via una scarpa.
    _dust(
      canvas,
      Offset(walkX, _ground),
      _span(t, strike, strike + 0.14),
      seed: 9,
      count: 4,
      size: 0.6,
      spread: 0.6,
    );
    final shoe = _span(t, 0.60, 0.635);
    if (shoe > 0) {
      final at = Offset(
        _victimX + _u * (0.08 + 0.25 * shoe),
        _mix(_ground - _u * 0.40, _ground, shoe * shoe),
      );
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(shoe < 1 ? shoe * 7 : 0);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(-_u * 0.06, -_u * 0.05, _u * 0.09, 0),
          topLeft: Radius.circular(_u * 0.02),
          topRight: Radius.circular(_u * 0.045),
        ),
        Paint()..color = _ink,
      );
      canvas.restore();
      _dust(
        canvas,
        Offset(at.dx, _ground),
        _span(t, 0.635, 0.72),
        seed: 10,
        count: 3,
        size: 0.35,
        spread: 0.4,
      );
    }
    if (hoisted) {
      final dropHat = Curves.easeIn.transform(
        _span(t, strike + 0.01, strike + 0.08),
      );
      _looseHat(
        canvas,
        Offset(
          _victimX - _u * 0.40 * dropHat,
          _mix(_ground - _u * 1.05, _ground - _u * 0.03, dropHat),
        ),
        dropHat < 1 ? dropHat * 5 : 0.15,
      );
    }
  }

  void _grab(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    final drag = _smooth(_span(t, strike + 0.03, strike + 0.20));
    final held = t >= strike;

    // Escono in punta di piedi, chinati, le mani avanti; al colpo lo
    // agguantano, e poi se lo tirano dietro l'angolo.
    for (final (gap, delay) in [(0.40, 0.0), (0.82, 0.035)]) {
      final come = _smooth(_span(t, 0.43 + delay, strike));
      final x = _mix(
        _mix(_hiddenX + _u * gap, _victimX + _u * gap, come),
        _hiddenX + _u * gap,
        drag,
      );
      final sneaking = come > 0 && come < 1;
      final moving = sneaking || (drag > 0 && drag < 1);
      final clamp = held && drag < 1;
      _person(
        canvas,
        feet: Offset(x, _ground),
        facing: drag > 0.05 ? 1 : -1,
        walk: sneaking ? _prowl * 0.6 + gap * 5 : _prowl + gap * 5,
        stride: moving ? (sneaking ? 0.6 : 0.9) : 0,
        lean: sneaking ? 0.20 : (clamp ? 0.10 : 0),
        crouch: sneaking ? 0.12 : 0,
        arm: clamp ? 1.45 : _mix(0.1, 1.75, come),
        elbow: clamp ? 0.15 : _mix(0.2, -0.25, come),
        backArm: clamp ? 1.3 : _mix(-0.1, 1.4, come),
        backElbow: clamp ? 0.3 : _mix(0.2, -0.1, come),
        killer: true,
      );
    }

    // La vittima viene trascinata dietro il muro: per questo va disegnata prima.
    final victimX = _mix(walkX, _hiddenX, drag);
    if (!held) {
      _victim(
        canvas,
        x: walkX,
        facing: t < 0.37 ? 1 : -1,
        walk: walk,
        stride: stride,
        smoking: t > 0.37,
      );
    } else {
      final jerk = sin(pi * _span(t, strike, strike + 0.03));
      _person(
        canvas,
        feet: Offset(victimX, _ground - _u * 0.08 * jerk),
        facing: -1,
        tilt: 0.45,
        crouch: 0.35,
        walk: t * 520,
        stride: drag > 0 && drag < 1 ? 0.8 : 0.3,
        arm: 2.2 + 0.4 * sin(t * 120),
        elbow: 0.5,
        backArm: -1.6 + 0.4 * cos(t * 130),
        hat: victimHat,
        hatOn: false,
      );
    }
    _wall(canvas);

    if (held) {
      // Il cappello salta via, la sigaretta cade e resta lì a fumare.
      final hat = _span(t, strike, strike + 0.07);
      _looseHat(
        canvas,
        Offset(
          _mix(_victimX - _u * 0.02, _victimX - _u * 0.25, hat),
          _mix(_ground - _u * 1.05, _ground - _u * 0.03, hat) -
              _u * 0.45 * sin(pi * hat),
        ),
        hat < 1 ? -hat * 6 : 0.2,
      );
      final butt = _span(t, strike, strike + 0.03);
      final ember = Offset(
        _mix(_victimX - _u * 0.16, _victimX - _u * 0.45, butt),
        _mix(_ground - _u * 0.93, _ground - _u * 0.015, butt * butt),
      );
      canvas.drawLine(
        ember,
        ember.translate(_u * 0.06, 0),
        Paint()
          ..color = const Color(0xFFE9E4D8)
          ..strokeWidth = _u * 0.014,
      );
      canvas.drawCircle(
        ember,
        _u * (0.011 + 0.005 * sin(t * 160).abs()),
        Paint()..color = const Color(0xFFFF7A3B),
      );
      if (butt >= 1) _wisp(canvas, ember);

      // I tacchi che strisciano sull'asfalto, e la polvere che sollevano.
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
      for (var k = 0; k < 4; k++) {
        final at = strike + 0.04 + k * 0.035;
        final heel = _mix(
          walkX,
          _hiddenX,
          _smooth(_span(at, strike + 0.03, strike + 0.20)),
        );
        if (heel > _cornerX) continue;
        _dust(
          canvas,
          Offset(heel, _ground),
          _span(t, at, at + 0.08),
          seed: 20 + k,
          count: 3,
          size: 0.35,
          spread: 0.4,
        );
      }
    }
    // Da dietro l'angolo: un tonfo, e la polvere del cemento.
    const pour = strike + 0.22;
    _puff(
      canvas,
      Offset(_cornerX + _u * 0.05, _ground - _u * 0.25),
      _span(t, pour, pour + 0.14),
      size: 1.6,
      color: const Color(0xFFB9B4AC),
    );
    _puff(
      canvas,
      Offset(_cornerX + _u * 0.20, _ground - _u * 0.8),
      _span(t, pour + 0.03, pour + 0.18),
      size: 1.4,
      color: const Color(0xFFB9B4AC),
    );
    _dust(
      canvas,
      Offset(_cornerX, _ground),
      _span(t, pour, pour + 0.20),
      seed: 24,
      count: 6,
      size: 1.0,
      spread: 1.0,
      color: const Color(0xFFB9B4AC),
    );
    _debris(
      canvas,
      Offset(_cornerX + _u * 0.05, _ground - _u * 0.3),
      _span(t, pour, pour + 0.15),
      seed: 25,
      count: 8,
      colors: const [Color(0xFF9C978F), Color(0xFF7A766F)],
      size: 0.9,
      reach: 0.8,
      lift: 0.8,
      drift: -0.6,
    );
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
    if (flight <= 0 || _doctorLayer) return;
    _looseHat(
      canvas,
      Offset(
        _victimX - _u * (0.30 + 0.92 * flight),
        _ground -
            _u * 0.03 -
            _u * height * sin(pi * min(1, flight * 1.6)) * (1 - flight),
      ),
      flight < 1 ? -flight * 9 : -0.2,
    );
  }

  void _bat(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    final peek = _smooth(_span(t, 0.38, 0.46));
    final dash = Curves.easeIn.transform(_span(t, 0.47, 0.53));
    final leave = _smooth(_span(t, 0.72, 0.86));
    final killerX = _mix(
      _mix(_mix(_hiddenX, _peekX, peek), _victimX + _u * 0.50, dash),
      _hiddenX,
      leave,
    );
    final running = (dash > 0 && dash < 1) || (leave > 0 && leave < 1);
    // Su la mazza, ancora un po' più indietro (il respiro prima del colpo),
    // giù di schianto, e il braccio che va oltre; poi se la rimette in spalla.
    final windUp = _smooth(_span(t, 0.46, 0.52));
    final cock = _smooth(_span(t, 0.52, 0.545));
    final swing = Curves.easeIn.transform(_span(t, 0.545, strike));
    final follow = Curves.easeOut.transform(_span(t, strike, strike + 0.05));
    final recover = _smooth(_span(t, strike + 0.07, strike + 0.15));
    double pose(List<double> keys) {
      var v = _mix(keys[0], keys[1], windUp);
      v = _mix(v, keys[2], cock);
      v = _mix(v, keys[3], swing);
      v = _mix(v, keys[4], follow);
      return _mix(v, keys[5], recover);
    }

    final lean =
        pose(const [0.0, 0.0, -0.12, 0.32, 0.38, 0.04]) +
        0.10 * dash * (1 - windUp);
    _person(
      canvas,
      feet: Offset(killerX, _ground),
      facing: leave > 0.08 ? 1 : -1,
      walk: _prowl,
      stride: running ? 1 : 0,
      lean: leave > 0 ? 0.04 : lean,
      crouch: 0.15 * swing * (1 - recover),
      arm: leave > 0 ? 2.5 : pose(const [0.5, 2.7, 2.9, 1.55, 0.55, 2.5]),
      elbow: leave > 0 ? 1.1 : pose(const [2.3, 0.6, 0.6, 0.2, 0.3, 1.1]),
      prop: _Prop.bat,
      killer: true,
    );
    // La scia della mazza: un ventaglio chiaro dietro la punta, da sopra la
    // testa fino al colpo, che svanisce subito dopo.
    final smear = _span(t, 0.545, strike + 0.025);
    if (smear > 0 && smear < 1) {
      final shoulder = Offset(killerX - _u * 0.04, _ground - _u * 0.89);
      final reach = _mix(1.5 * pi, pi + 0.15, swing);
      final fade = t < strike ? 1.0 : 1 - _span(t, strike, strike + 0.025);
      for (final (radius, width, alpha) in const [
        (0.62, 0.36, 0.22),
        (0.74, 0.10, 0.45),
      ]) {
        canvas.drawArc(
          Rect.fromCircle(center: shoulder, radius: _u * radius),
          reach,
          1.5 * pi - reach,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = _u * width
            ..color = const Color(0xFFFFE2B0).withValues(alpha: alpha * fade)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, _u * 0.02),
        );
      }
    }
    _wall(canvas);

    final dazed = _span(t, strike, strike + 0.09);
    final fall = _span(t, strike + 0.08, strike + 0.19);
    final knock = dazed > 0 ? 0.30 * sin(pi * min(1.0, dazed * 2.5)) : 0.0;
    _victim(
      canvas,
      x: walkX,
      facing: t < 0.37 ? 1 : -1,
      walk: walk,
      stride: stride,
      fall: fall,
      lean: dazed > 0 && fall == 0 ? knock + sin(t * 100) * 0.16 * dazed : 0,
      smoking: t > 0.37 && t < strike,
    );
    _hatOff(canvas, strike, strike + 0.26, height: 1.5);

    // La sigaretta schizza via di bocca e resta a fumare per terra.
    final butt = _span(t, strike, strike + 0.06);
    if (butt > 0) {
      final ember = Offset(
        _mix(_victimX - _u * 0.16, _victimX - _u * 0.70, butt),
        _mix(_ground - _u * 0.93, _ground - _u * 0.015, butt * butt) -
            _u * 0.35 * sin(pi * butt),
      );
      canvas.save();
      canvas.translate(ember.dx, ember.dy);
      canvas.rotate(butt < 1 ? butt * 9 : 0);
      canvas.drawLine(
        Offset.zero,
        Offset(_u * 0.06, 0),
        Paint()
          ..color = const Color(0xFFE9E4D8)
          ..strokeWidth = _u * 0.014,
      );
      canvas.restore();
      canvas.drawCircle(
        ember,
        _u * (0.011 + 0.005 * sin(t * 160).abs()),
        Paint()..color = const Color(0xFFFF7A3B),
      );
      if (butt >= 1) _wisp(canvas, ember);
    }

    // Il colpo: la stella dell'urto, le schegge di legno, le stelline.
    final head = Offset(_victimX + _u * 0.02, _ground - _u * 1.0);
    _impactBurst(canvas, head, _span(t, strike, strike + 0.06), size: 0.9);
    _debris(
      canvas,
      head,
      _span(t, strike, strike + 0.12),
      seed: 33,
      count: 6,
      colors: const [Color(0xFFC9A26B), Color(0xFF9A7448)],
      size: 0.5,
      reach: 0.7,
      lift: 0.6,
      drift: -0.4,
    );
    _spray(
      canvas,
      head.translate(0, _u * 0.05),
      _span(t, strike, strike + 0.10),
      seed: 31,
      color: _warm,
      count: 10,
      reach: 0.8,
    );
    _bonkStars(
      canvas,
      Offset(_victimX - _u * 0.03, _ground - _u * 1.12),
      _span(t, strike + 0.01, strike + 0.11),
    );
    _dust(
      canvas,
      Offset(_victimX - _u * 0.5, _ground),
      _span(t, strike + 0.19, strike + 0.36),
      seed: 34,
      size: 0.8,
    );
    _flash(canvas, _span(t, strike, strike + 0.03), strength: 0.45);
  }

  void _lupara(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    final peek = _smooth(_span(t, 0.38, 0.46));
    final out = _smooth(_span(t, 0.46, 0.53));
    final leave = _smooth(_span(t, 0.74, 0.88));
    final killerX = _mix(
      _mix(_mix(_hiddenX, _peekX, peek), _cornerX + _u * 0.16, out),
      _hiddenX,
      leave,
    );
    final bang = _span(t, strike, strike + 0.045);
    // Il rinculo spinge su la doppietta e indietro le spalle, poi torna giù
    // piano: la lupara pesa.
    final recoil = t < strike
        ? 0.0
        : sin(pi / 2 * min(1, _span(t, strike, strike + 0.02))) *
              (1 - _smooth(_span(t, strike + 0.02, strike + 0.11)));
    final lean = leave > 0 ? 0.04 : 0.10 * out - 0.22 * recoil;
    final arm = leave > 0 ? 0.3 : _mix(0.3, 1.38, out) + 0.55 * recoil;
    final elbow = leave > 0 ? 0.2 : 0.18;
    final facing = leave > 0.08 ? 1 : -1;

    _person(
      canvas,
      feet: Offset(killerX, _ground),
      facing: facing,
      walk: _prowl,
      stride: (out > 0 && out < 1) || (leave > 0 && leave < 1) ? 0.8 : 0,
      lean: lean,
      arm: arm,
      elbow: elbow,
      backArm: leave > 0 ? -0.1 : _mix(-0.1, 1.50, out) + 0.4 * recoil,
      backElbow: 0.25,
      prop: _Prop.lupara,
      killer: true,
    );
    _wall(canvas);

    // La vittima non cade: decolla, e il colpo la porta indietro.
    final blown = _span(t, strike, strike + 0.14);
    final drift = _u * 0.25 * Curves.easeOut.transform(blown);
    _pool(
      canvas,
      Offset(_victimX - drift - _u * 0.50, _ground + _u * 0.04),
      _smooth(_span(t, strike + 0.16, strike + 0.32)),
    );
    if (blown <= 0 || blown >= 1 || _missed) {
      _victim(
        canvas,
        x: walkX - drift,
        facing: t < 0.37 ? 1 : -1,
        walk: walk,
        stride: stride,
        fall: blown,
        smoking: t > 0.37 && t < strike,
      );
    } else {
      final lift = sin(pi * blown);
      _person(
        canvas,
        feet: Offset(_victimX - drift, _ground - _u * 0.28 * lift),
        facing: -1,
        tilt: -Curves.easeIn.transform(blown) * pi * 0.47,
        crouch: 0.4 * lift,
        arm: _mix(2.6, 2.9, blown),
        elbow: 0.2,
        backArm: _mix(-2.0, -2.6, blown),
        hat: victimHat,
        hatOn: false,
      );
    }
    _dust(
      canvas,
      Offset(_victimX - _u * 0.25 - _u * 0.45, _ground),
      _span(t, strike + 0.125, strike + 0.32),
    );
    _hatOff(canvas, strike, strike + 0.30, height: 1.9);

    // I pallini partono da dove stava la canna quando ha tirato il
    // grilletto; la vampata resta attaccata alla canna che sale.
    final (hand, along) = _handOf(
      feet: Offset(killerX, _ground),
      facing: facing,
      lean: lean,
      arm: arm,
      elbow: elbow,
      killer: true,
    );
    final smoking = _muzzleOf(hand, along, _Prop.lupara);
    final (aimHand, aimAlong) = _handOf(
      feet: Offset(killerX, _ground),
      facing: facing,
      lean: 0.10 * out,
      arm: _mix(0.3, 1.38, out),
      elbow: elbow,
      killer: true,
    );
    final muzzle = _muzzleOf(aimHand, aimAlong, _Prop.lupara);
    final blaze = _span(t, strike, strike + 0.032);
    _muzzleFlash(canvas, smoking, blaze, toward: along, size: 1.25);
    if (bang > 0 && bang < 1 && !_holdsFire) {
      _star(
        canvas,
        smoking,
        _u * 0.16 * (1 - bang * 0.4),
        const Color(0xFFFFF3C4).withValues(alpha: 1 - bang),
      );
      final pellets = Paint()
        ..color = _warm.withValues(alpha: 0.9 * (1 - bang))
        ..strokeWidth = _u * 0.010;
      for (var i = -3; i <= 3; i++) {
        final target = Offset(
          _victimX + _u * 0.05,
          _ground - _u * (0.74 + i * 0.07),
        );
        canvas.drawLine(
          Offset.lerp(muzzle, target, bang * 0.5)!,
          Offset.lerp(muzzle, target, min(1, bang * 0.5 + 0.5))!,
          pellets,
        );
      }
    }
    _puff(
      canvas,
      Offset.lerp(muzzle, smoking, 0.5)!.translate(-_u * 0.1, -_u * 0.1),
      _span(t, strike + 0.01, strike + 0.20),
      size: 0.9,
    );
    _puff(
      canvas,
      smoking.translate(_u * 0.02, -_u * 0.18 * _span(t, strike + 0.05, 0.80)),
      _span(t, strike + 0.05, 0.80),
      size: 0.35,
    );
    _spray(
      canvas,
      Offset(_victimX, _ground - _u * 0.74),
      _span(t, strike, strike + 0.22),
      seed: 41,
      count: 26,
      reach: 1.3,
    );
    _flash(canvas, bang, strength: 0.75);
  }

  void _driveBy(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    const shots = [0.535, 0.552, 0.569, 0.586, 0.603, 0.620];
    // Il quarto colpo va a vuoto e scheggia il palo, l'ultimo spegne il
    // lampione: gli altri vanno a segno.
    const miss = 3;
    const lampShot = 5;
    final lampHead = Offset(_w * 0.26 + _u * 0.24, _ground - _u * 1.38);
    final post = Offset(_w * 0.26, _ground - _u * 0.80);

    // L'auto arriva da destra, rallenta fino a passo d'uomo davanti alla
    // vittima, svuota il caricatore e riparte sgommando.
    final arrive = Curves.easeOut.transform(_span(t, 0.40, 0.535));
    final crawl = _span(t, 0.535, 0.63);
    final away = Curves.easeIn.transform(_span(t, 0.63, 0.73));
    final nose =
        _mix(_w + _u * 0.4, _victimX - _u * 0.40, arrive) -
        _u * 0.16 * crawl -
        (_w + _u * 3.2) * away;

    var hits = 0;
    var jolt = 0.0;
    var kick = 0.0;
    for (var i = 0; i < shots.length; i++) {
      final lands = i != miss && i != lampShot;
      if (t >= shots[i] && lands) hits++;
      final bang = _span(t, shots[i], shots[i] + 0.016);
      if (bang > 0 && bang < 1) {
        kick = sin(pi * bang);
        if (lands) jolt = sin(pi * bang);
      }
    }
    final fall = _span(t, 0.625, 0.71);
    final victimX = walkX - _u * 0.02 * hits;

    _wall(canvas);
    _pool(
      canvas,
      Offset(victimX + _u * 0.50, _ground + _u * 0.04),
      _smooth(_span(t, 0.68, 0.80)),
    );
    // Abbagliata dai fari si ripara gli occhi; ogni colpo la spinge indietro,
    // e alla fine crolla in avanti, dietro all'auto che se ne va.
    final shield = _span(t, 0.48, 0.50);
    _victim(
      canvas,
      x: victimX,
      walk: walk,
      stride: stride,
      fall: fall,
      fallTo: 1,
      lean: -0.24 * jolt - 0.06 * shield * (1 - fall),
      arm: _mix(0.08, 2.3, shield),
      elbow: _mix(0.2, 0.6, shield),
      smoking: t > 0.37 && t < 0.50,
    );
    _hatOff(canvas, 0.625, 0.625 + 0.22);

    // Il colpo che scheggia il palo e quello che fa saltare il lampione.
    final chip = _span(t, shots[miss] + 0.004, shots[miss] + 0.07);
    if (chip > 0 && chip < 1) {
      _sprite(
        canvas,
        sprites?.electric,
        post,
        _u * 0.30 * (1 - chip * 0.5),
        opacity: 1 - chip,
        rotation: 0.7,
        tint: _warm,
      );
    }
    _spray(
      canvas,
      post,
      chip,
      seed: 59,
      color: _warm,
      count: 8,
      bias: const Offset(0.4, -0.6),
      reach: 0.5,
    );
    _spray(
      canvas,
      lampHead,
      _span(t, 0.63, 0.74),
      seed: 60,
      color: _warm,
      count: 18,
      bias: const Offset(0, -0.3),
      reach: 0.9,
    );
    final pop = _span(t, 0.625, 0.67);
    if (pop > 0 && pop < 1) {
      _sprite(
        canvas,
        sprites?.electric,
        lampHead,
        _u * 0.45,
        opacity: (1 - pop) * (0.6 + 0.4 * sin(t * 700).abs()),
        rotation: t * 40,
        tint: const Color(0xFFBFE3FF),
      );
      _sprite(
        canvas,
        sprites?.glow,
        lampHead,
        _u * 0.8 * (1 - pop),
        opacity: 1 - pop,
        tint: _warm,
      );
    }

    for (var i = 0; i < shots.length; i++) {
      if (i == miss || i == lampShot) continue;
      _spray(
        canvas,
        Offset(victimX - _u * 0.02, _ground - _u * 0.74),
        _span(t, shots[i], shots[i] + 0.12),
        seed: 50 + i,
        count: 7,
      );
    }

    if (away >= 1) return;
    // L'auto passa davanti a tutto. È vista dal lato destro: corre verso
    // sinistra, col muso avanti.
    final bob = sin(t * 260) * _u * 0.006;
    canvas.save();
    canvas.translate(0, _u * 0.15 + bob);
    canvas.save();
    canvas.scale(-1, 1);
    _sedan(canvas, -nose);
    canvas.restore();

    // Al volante, una tesa e una sagoma dietro il vetro.
    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(
        nose + _u * 0.92,
        _ground - _u * 0.76,
        nose + _u * 1.22,
        _ground - _u * 0.53,
      ),
    );
    const driverScale = 0.75;
    _person(
      canvas,
      feet: Offset(
        nose + _u * (1.05 + 0.03 * driverScale),
        _ground - _u * (0.62 - 0.985 * driverScale),
      ),
      facing: -1,
      arm: 1.3,
      elbow: 0.4,
    );
    canvas.restore();

    // Dal finestrino dietro si sporge chi spara, seduto sulla portiera, col
    // mitra sopra il tetto. Insegue il bersaglio, e alla fine punta il lampione.
    const scale = 0.8;
    final seat = Offset(nose + _u * 1.42, _ground - _u * 0.19);
    final raise = _smooth(_span(t, 0.47, 0.53)) * (1 - away);
    final skyward =
        _smooth(_span(t, shots[lampShot] - 0.016, shots[lampShot])) -
        _smooth(_span(t, 0.64, 0.68));
    final shake = t > shots.first && t < shots.last + 0.016
        ? sin(t * 900) * 0.03
        : 0.0;
    final lean = 0.22 * raise - 0.06 * kick + shake;
    final arm = _mix(0.3, 1.45, raise) + 0.10 * kick + _mix(0, 0.95, skyward);
    final elbow = _mix(0.4, 0.12, raise);
    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(-_w * 2, -_h * 2, _w * 3, _ground - _u * 0.55),
    );
    canvas.translate(seat.dx, seat.dy);
    canvas.scale(scale);
    _person(
      canvas,
      feet: Offset.zero,
      facing: -1,
      lean: lean,
      arm: arm,
      elbow: elbow,
      backArm: _mix(-0.1, 1.25, raise) + _mix(0, 0.8, skyward),
      backElbow: 0.35,
      prop: _Prop.tommy,
      killer: true,
    );
    canvas.restore();

    final (handLocal, along) = _handOf(
      feet: Offset.zero,
      facing: -1,
      lean: lean,
      arm: arm,
      elbow: elbow,
      killer: true,
    );
    final hand = seat + handLocal * scale;
    final muzzle = seat + _muzzleOf(handLocal, along, _Prop.tommy) * scale;
    for (var i = 0; i < shots.length; i++) {
      final bang = _span(t, shots[i], shots[i] + 0.016);
      if (bang <= 0 || bang >= 1) continue;
      final target = i == miss
          ? post
          : i == lampShot
          ? lampHead
          : Offset(
              victimX + _u * 0.08,
              _ground - _u * (0.72 + 0.06 * sin(i * 2.3)),
            );
      _muzzleFlash(
        canvas,
        muzzle,
        bang,
        toward: along,
        size: 0.7 + 0.18 * (i % 2),
      );
      _star(
        canvas,
        muzzle,
        _u * 0.08,
        const Color(0xFFFFF3C4).withValues(alpha: 1 - bang),
      );
      // Il bersaglio sta più in alto della strada: la scia va corretta
      // dello spostamento dell'auto.
      _tracer(canvas, muzzle, target.translate(0, -_u * 0.15 - bob), bang);
      _flash(canvas, bang, strength: 0.22);
    }
    _casings(canvas, hand + Offset(0, -_u * 0.03), shots, side: 1);
    // Il fumo della raffica resta indietro, e le gomme fumano quando riparte.
    final haze = _span(t, 0.55, 0.72);
    _puff(
      canvas,
      muzzle.translate(_u * 0.25 * haze, -_u * 0.15),
      haze,
      size: 0.5,
    );
    final screech = _span(t, 0.63, 0.70);
    _puff(
      canvas,
      Offset(nose + _u * 1.72 + _u * 0.4 * screech, _ground - _u * 0.02),
      screech,
      size: 0.7,
    );
    canvas.restore();
  }

  void _garrote(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    final peek = _smooth(_span(t, 0.38, 0.45));
    final creep = _smooth(_span(t, 0.46, 0.53));
    // Le mani salgono col filo teso sopra il cappello, poi calano di colpo.
    final raise = _smooth(_span(t, 0.50, 0.535));
    final drop = Curves.easeIn.transform(_span(t, 0.545, strike));
    final choke = _span(t, strike, 0.70);
    final limp = _smooth(_span(t, 0.66, 0.71));
    final lower = _smooth(_span(t, 0.70, 0.745));
    final released = t >= 0.745;
    final topple = Curves.easeIn.transform(_span(t, 0.745, 0.82));
    final snap = _span(t, 0.75, 0.775);
    final leave = _smooth(_span(t, 0.775, 0.88));
    final gripping = t >= strike && !released;
    final fight = gripping ? 1 - limp : 0.0;

    final killerX = _mix(
      _mix(_mix(_hiddenX, _peekX, peek), _victimX + _u * 0.34, creep),
      _hiddenX,
      leave,
    );
    // Chi strangola si butta indietro e tira; mentre la cala giù si china.
    final killerLean = gripping
        ? -0.18 * (1 - lower) + 0.30 * lower + 0.03 * sin(t * 260) * fight
        : (released ? 0.04 * (1 - leave) : 0.08 * creep);
    final killerCrouch = gripping
        ? 0.10 + 0.25 * lower
        : (released ? 0.0 : 0.26 * creep * (1 - raise));
    final double arm;
    final double elbow;
    final double backArm;
    final double backElbow;
    if (gripping) {
      (arm, elbow, backArm, backElbow) = (0.95, 1.85, 1.10, 1.70);
    } else if (released) {
      final taut = 1 - leave;
      (arm, elbow, backArm, backElbow) = (
        _mix(0.1, 1.05, taut),
        _mix(0.2, 0.5, taut),
        _mix(-0.1, 1.25, taut),
        _mix(0.2, 0.3, taut),
      );
    } else {
      (arm, elbow, backArm, backElbow) = (
        _mix(_mix(0.2, 2.25, raise), 0.95, drop),
        _mix(_mix(0.5, 0.25, raise), 1.85, drop),
        _mix(_mix(-0.1, 2.85, raise), 1.10, drop),
        _mix(_mix(0.5, 0.15, raise), 1.70, drop),
      );
    }
    final killerFacing = leave > 0.08 ? 1 : -1;
    final killerFeet = Offset(killerX, _ground);
    _person(
      canvas,
      feet: killerFeet,
      facing: killerFacing,
      walk: _prowl * 0.7,
      stride: (creep > 0 && creep < 1)
          ? 0.55
          : (leave > 0 && leave < 1 ? 0.9 : 0),
      crouch: killerCrouch,
      lean: killerLean,
      arm: arm,
      elbow: elbow,
      backArm: backArm,
      backElbow: backElbow,
      killer: true,
    );
    _wall(canvas);
    (Offset, Offset) hand({required bool back}) => _handOf(
      feet: killerFeet,
      facing: killerFacing,
      lean: killerLean,
      crouch: killerCrouch,
      arm: back ? backArm : arm,
      elbow: back ? backElbow : elbow,
      back: back,
      killer: true,
    );
    final (front, _) = hand(back: false);
    final (rear, _) = hand(back: true);

    // La vittima: sollevata sulle punte, le mani al collo, scalcia; poi
    // si affloscia, la calano in ginocchio e crolla in avanti.
    final victimFeet = Offset(
      _victimX + _u * 0.04 * choke * (1 - lower),
      _ground - _u * 0.04 * fight,
    );
    final victimTilt = gripping
        ? 0.12 * (1 - lower) + 0.04 * sin(t * 180) * fight
        : -1.30 * topple;
    final victimLean = gripping
        ? -0.12 * fight + 0.25 * lower
        : 0.25 - 0.10 * topple;
    final victimCrouch = gripping
        ? 0.10 * limp + 0.55 * lower
        : 0.65 + 0.30 * topple;
    if (!gripping && !released) {
      _victim(
        canvas,
        x: walkX,
        facing: t < 0.37 ? 1 : -1,
        walk: walk,
        stride: stride,
        smoking: t > 0.37,
      );
    } else if (topple >= 1) {
      _corpse(canvas, _victimX, -1);
    } else {
      final claw = sin(t * 300) * 0.15 * fight;
      _person(
        canvas,
        feet: victimFeet,
        facing: -1,
        tilt: victimTilt,
        lean: victimLean,
        crouch: victimCrouch,
        walk: t * 420,
        stride: 0.6 * fight * (1 - choke * 0.4),
        arm: _mix(1.9 + claw, 0.35, max(limp, topple)),
        elbow: _mix(2.7, 0.3, max(limp, topple)),
        backArm: _mix(1.95 - claw, -0.25, max(limp, topple)),
        backElbow: _mix(2.6, 0.3, max(limp, topple)),
        hat: victimHat,
        hatOn: false,
      );
    }
    _dust(canvas, Offset(_victimX, _ground), _span(t, 0.60, 0.68), size: 0.6);
    _dust(canvas, Offset(_victimX - _u * 0.6, _ground), _span(t, 0.81, 0.92));

    // Il filo: teso fra le mani, poi stretto intorno al collo.
    final wire = Paint()
      ..color = _steel
      ..strokeWidth = _u * 0.012
      ..strokeCap = StrokeCap.round;
    final wood = Paint()
      ..color = const Color(0xFF8A6038)
      ..strokeWidth = _u * 0.035
      ..strokeCap = StrokeCap.round;
    if (gripping) {
      Offset neck(double dx) => _onBody(
        Offset(dx, -0.365),
        feet: victimFeet,
        facing: -1,
        lean: victimLean,
        crouch: victimCrouch,
        tilt: victimTilt,
      );
      final throat = neck(0.075);
      final nape = neck(-0.045);
      canvas.drawLine(front, throat, wire);
      canvas.drawLine(rear, nape, wire);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.lerp(throat, nape, 0.5)!,
          width: (throat - nape).distance,
          height: _u * 0.028,
        ),
        wire..style = PaintingStyle.stroke,
      );
      wire.style = PaintingStyle.fill;
    } else if (raise > 0 && leave < 0.6) {
      final sag = released ? 0.0 : _u * 0.03 * (1 - raise);
      canvas.drawPath(
        Path()
          ..moveTo(front.dx, front.dy)
          ..quadraticBezierTo(
            (front.dx + rear.dx) / 2,
            (front.dy + rear.dy) / 2 + sag,
            rear.dx,
            rear.dy,
          ),
        Paint()
          ..color = _steel
          ..strokeWidth = _u * 0.012
          ..style = PaintingStyle.stroke,
      );
    }
    if (raise > 0 && leave < 0.6) {
      for (final grip in [front, rear]) {
        canvas.drawLine(
          grip.translate(0, -_u * 0.03),
          grip.translate(0, _u * 0.03),
          wood,
        );
      }
    }
    // Il luccichio del filo prima del colpo, e quando lo tende di nuovo.
    for (final shine in [_span(t, 0.525, 0.55), snap]) {
      if (shine > 0 && shine < 1) {
        _sprite(
          canvas,
          sprites?.glint,
          Offset.lerp(front, rear, 0.5)!,
          _u * 0.35 * sin(pi * shine),
          opacity: sin(pi * shine),
        );
      }
    }
    _droppedCigarette(
      canvas,
      Offset(_victimX - _u * 0.11, _ground - _u * 0.935),
      _span(t, strike, strike + 0.05),
    );
    _hatOff(canvas, strike, strike + 0.20, height: 0.5);
  }

  /// La sigaretta che cade di bocca e resta sull'asfalto, con la brace
  /// ancora accesa.
  void _droppedCigarette(Canvas canvas, Offset from, double life) {
    if (life <= 0) return;
    final at = Offset(
      from.dx - _u * 0.12 * life,
      _mix(from.dy, _ground - _u * 0.012, life * life),
    );
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(life < 1 ? -life * 7 : 0);
    canvas.drawLine(
      Offset(-_u * 0.035, 0),
      Offset(_u * 0.035, 0),
      Paint()
        ..color = const Color(0xFFE9E4D8)
        ..strokeWidth = _u * 0.014,
    );
    canvas.drawCircle(
      Offset(-_u * 0.035, 0),
      _u * (0.010 + 0.005 * sin(t * 90).abs()),
      Paint()..color = const Color(0xFFFF7A3B),
    );
    canvas.restore();
  }

  void _flowerPot(Canvas canvas, Offset center, double spin) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(spin);
    for (final (dx, dy) in [(-0.10, -0.20), (0.0, -0.26), (0.10, -0.20)]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(_u * dx, _u * (dy + 0.08)),
          width: _u * 0.10,
          height: _u * 0.17,
        ),
        Paint()..color = const Color(0xFF3E7B3A),
      );
      canvas.drawCircle(
        Offset(_u * dx, _u * dy),
        _u * 0.05,
        Paint()..color = const Color(0xFFD9303C),
      );
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
    final drop = _span(t, 0.47, strike);
    final landed = t >= strike;
    // Alza gli occhi quando ormai è tardi.
    final notice = _smooth(_span(t, 0.528, 0.548)) * (landed ? 0 : 1);
    const terracotta = Color(0xFFB5552E);

    _killerSalute(canvas);
    _wall(canvas);

    // L'ombra che si allarga sull'asfalto: qualcosa sta arrivando dall'alto.
    if (!landed && drop > 0) {
      final near = drop * drop;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(_victimX + _u * 0.03, _ground + _u * 0.025),
          width: _u * (0.10 + 0.40 * near),
          height: _u * (0.025 + 0.05 * near),
        ),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.25 + 0.45 * near)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, _u * 0.02),
      );
    }
    final head = Offset(_victimX + _u * 0.03, _ground - _u * 1.07);
    if (landed) _potShards(canvas, head, _span(t, strike, strike + 0.13));

    final squash = sin(pi * _span(t, strike, strike + 0.035));
    final rub = _smooth(_span(t, strike + 0.02, strike + 0.05));
    final fall = _span(t, strike + 0.09, strike + 0.20);
    final wobble = landed && fall == 0
        ? sin(t * 95) * 0.15 * (1 - squash)
        : 0.0;
    canvas.save();
    // Il colpo lo schiaccia per un attimo, come una molla.
    canvas.translate(walkX, _ground);
    canvas.scale(1 + 0.10 * squash, 1 - 0.14 * squash);
    canvas.translate(-walkX, -_ground);
    _victim(
      canvas,
      x: walkX,
      walk: walk,
      stride: stride,
      fall: fall,
      lean: wobble - 0.16 * notice,
      arm: _mix(0.08, 2.55, rub),
      elbow: _mix(0.2, 1.65, rub),
      smoking: t > 0.37 && !landed,
    );
    canvas.restore();

    // Il fiore gli resta piantato in testa, finché non va giù.
    if (landed && fall == 0) {
      final crown = _onBody(
        const Offset(0.03, -0.62),
        feet: Offset(walkX, _ground),
        lean: wobble,
      );
      canvas.save();
      canvas.translate(crown.dx, crown.dy);
      canvas.rotate(wobble * 1.5 + 0.2);
      canvas.drawLine(
        Offset.zero,
        Offset(0, -_u * 0.16),
        Paint()
          ..color = const Color(0xFF3E7B3A)
          ..strokeWidth = _u * 0.018,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(_u * 0.04, -_u * 0.07),
          width: _u * 0.07,
          height: _u * 0.035,
        ),
        Paint()..color = const Color(0xFF3E7B3A),
      );
      canvas.drawCircle(
        Offset(0, -_u * 0.17),
        _u * 0.045,
        Paint()..color = const Color(0xFFD9303C),
      );
      canvas.restore();
    }

    if (!landed) {
      if (drop > 0) {
        final center = Offset(
          _victimX + _u * 0.03,
          _mix(_ground - _u * 2.7, head.dy - _u * 0.13, drop * drop),
        );
        // Un po' di terra che si stacca mentre cade.
        for (var i = 0; i < 4; i++) {
          canvas.drawCircle(
            center.translate(
              _u * 0.05 * sin(i * 2.1 + t * 40),
              -_u * (0.16 + 0.10 * i) * drop,
            ),
            _u * 0.012,
            Paint()..color = const Color(0xFF3A2A1C),
          );
        }
        _flowerPot(canvas, center, drop * 2.6);
      }
    } else {
      final burst = _span(t, strike, strike + 0.12);
      if (burst < 1) {
        _sprite(
          canvas,
          sprites?.debris,
          head.translate(0, -_u * 0.08 - _u * 0.10 * burst),
          _u * (0.35 + 0.65 * burst),
          opacity: 1 - burst,
          rotation: burst,
          tint: terracotta,
        );
      }
      _puff(
        canvas,
        head.translate(0, -_u * 0.10 - _u * 0.15 * burst),
        burst,
        size: 0.7,
        color: const Color(0xFF5C4630),
      );
      final ding = _span(t, strike, strike + 0.04);
      if (ding < 1) {
        _star(
          canvas,
          head.translate(0, -_u * 0.08),
          _u * 0.16 * (1 - ding * 0.5),
          Colors.white.withValues(alpha: 1 - ding),
        );
      }
      _spray(
        canvas,
        head,
        _span(t, strike, strike + 0.22),
        seed: 72,
        color: const Color(0xFFD9303C),
        count: 10,
        bias: const Offset(0.2, -0.9),
        reach: 1.1,
      );
      _spray(
        canvas,
        head,
        _span(t, strike, strike + 0.16),
        seed: 73,
        color: const Color(0xFF3A2A1C),
        count: 12,
        bias: const Offset(-0.1, -0.5),
        reach: 0.7,
      );
      _dizzy(canvas, head, _span(t, strike + 0.01, strike + 0.14));
    }
    _dust(
      canvas,
      Offset(_victimX - _u * 0.55, _ground),
      _span(t, strike + 0.19, strike + 0.30),
    );
    _hatOff(canvas, strike + 0.09, strike + 0.30, height: 0.6);
    _flash(canvas, _span(t, strike, strike + 0.03), strength: 0.3);
  }

  /// I cocci del vaso: saltano via dalla testa e restano sparsi a terra,
  /// con la terra rovesciata.
  void _potShards(Canvas canvas, Offset from, double life) {
    const shards = [
      (-0.42, 0.9, 0.06),
      (-0.20, 1.3, 0.05),
      (0.22, 1.1, 0.07),
      (0.40, 0.7, 0.045),
      (-0.05, 1.5, 0.04),
    ];
    final clay = Paint()..color = const Color(0xFFB5552E);
    final soil = _span(life, 0.6, 1);
    if (soil > 0) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(_victimX + _u * 0.16, _ground + _u * 0.005),
          width: _u * 0.26 * soil,
          height: _u * 0.05 * soil,
        ),
        Paint()..color = const Color(0xFF3A2A1C),
      );
    }
    for (final (i, (dx, arc, size)) in shards.indexed) {
      final landing = Offset(_victimX + _u * dx, _ground - _u * size * 0.3);
      final at =
          Offset.lerp(from, landing, life)! +
          Offset(0, -_u * 0.45 * arc * sin(pi * life));
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(life * (6 + i) + i);
      canvas.drawPath(
        Path()
          ..moveTo(-_u * size, 0)
          ..lineTo(0, -_u * size * 0.7)
          ..lineTo(_u * size, -_u * size * 0.1)
          ..lineTo(_u * size * 0.3, _u * size * 0.4)
          ..close(),
        clay,
      );
      canvas.restore();
    }
  }

  void _manhole(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    // Il chiusino trema, poi una mano da sotto lo spinge via; dopo il tonfo
    // la stessa mano lo richiude.
    final rattle = _span(t, 0.45, 0.50);
    final open = _smooth(_span(t, 0.50, 0.555));
    final drop = Curves.easeIn.transform(_span(t, strike, strike + 0.07));
    final close = _smooth(_span(t, strike + 0.13, strike + 0.19));
    final slide = (open - close) * _u * 0.62;
    final hole = Rect.fromCenter(
      center: Offset(_victimX, _ground + _u * 0.045),
      width: _u * 0.66,
      height: _u * 0.11,
    );
    // A cose fatte il chiusino si solleva di un dito: due occhi, e giù.
    final peek =
        _smooth(_span(t, 0.785, 0.81)) - _smooth(_span(t, 0.85, 0.875));

    _wall(canvas);

    if (open > 0 || peek > 0) {
      canvas.drawOval(hole, Paint()..color = Colors.black);
    }
    final jiggle = rattle > 0 && rattle < 1
        ? sin(t * 900) * _u * 0.006 * sin(pi * rattle)
        : 0.0;
    final lift = peek * _u * 0.07;
    final lid = hole.shift(
      Offset(slide + jiggle, -_u * 0.012 - jiggle.abs() - lift),
    );
    final grip = open > 0 && open < 1 || close > 0 && close < 1 || peek > 0;
    if (grip) {
      // La mano guantata sul bordo del chiusino.
      final fist = peek > 0
          ? lid.bottomCenter.translate(-_u * 0.20, -_u * 0.01)
          : lid.centerLeft.translate(-_u * 0.01, -_u * 0.005);
      final sleeve = Paint()..color = _ink;
      canvas.drawRect(
        Rect.fromLTRB(
          fist.dx - _u * 0.03,
          fist.dy,
          fist.dx + _u * 0.03,
          hole.center.dy + _u * 0.02,
        ),
        sleeve,
      );
      canvas.drawCircle(fist, _u * 0.038, sleeve);
      canvas.drawArc(
        Rect.fromCircle(center: fist, radius: _u * 0.038),
        pi,
        pi * 0.8,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _u * 0.008
          ..color = _rim,
      );
    }
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

    // Due occhi nel buio del tombino, che guardano in su.
    final watching =
        _span(t, 0.53, 0.545) - _span(t, strike, strike + 0.01) > 0 &&
        open - close > 0.3;
    if (watching || peek > 0.3) {
      final glint = Paint()..color = const Color(0xFFFFF3C4);
      final at = peek > 0
          ? Offset(hole.center.dx - _u * 0.05, lid.bottom + _u * 0.012)
          : hole.center.translate(-_u * 0.10, -_u * 0.01);
      canvas.drawCircle(at, _u * 0.013, glint);
      canvas.drawCircle(at.translate(_u * 0.05, 0), _u * 0.013, glint);
    }

    if (drop < 1) {
      // Il chiusino gli scivola via da sotto i piedi: un attimo sospeso nel
      // vuoto, le gambe che pedalano, uno sguardo in giù, poi giù davvero.
      final aware = _span(t, 0.535, strike);
      canvas.save();
      canvas.clipPath(
        Path()
          ..addRect(Rect.fromLTRB(-_w, -_h * 2, _w * 3, hole.center.dy))
          ..addOval(hole),
      );
      _person(
        canvas,
        feet: Offset(walkX, _ground + drop * _u * 1.25),
        walk: aware > 0 && drop == 0 ? t * 600 : walk,
        stride: aware > 0 && drop == 0 ? 0.6 * aware : stride,
        lean: 0.20 * aware * (1 - drop),
        arm: _mix(0.08, 2.9, max(aware * 0.35, drop)),
        elbow: 0.3,
        backArm: _mix(-0.1, -2.6, max(aware * 0.3, drop)),
        hat: victimHat,
        hatOn: drop <= 0,
        smoking: t > 0.37 && t < 0.52,
      );
      canvas.restore();
      if (aware > 0 && drop <= 0) {
        _mark(canvas, '?', Offset(_victimX + _u * 0.28, _ground - _u * 1.36));
      }
    }
    // Il cappello resta in aria, poi si posa sul chiusino.
    if (drop > 0) {
      final settle = Curves.easeIn.transform(
        _span(t, strike + 0.05, strike + 0.20),
      );
      final slip = _smooth(_span(t, 0.795, 0.82));
      _looseHat(
        canvas,
        Offset(
          _victimX + _u * 0.02 + _u * 0.30 * slip,
          _mix(_ground - _u * 1.02, _ground - _u * 0.045, settle) -
              lift +
              _u * 0.02 * slip,
        ),
        sin(settle * pi) * 0.35 + 0.3 * slip,
      );
    }
    // Lo spruzzo dell'acqua di fogna, in alto fuori dal buco.
    final splash = _span(t, strike + 0.07, strike + 0.20);
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(-_w, -_h * 2, _w * 3, hole.center.dy));
    _spray(
      canvas,
      hole.center,
      splash,
      seed: 81,
      color: const Color(0xFF7FA8C9),
      count: 18,
      bias: const Offset(0, -1.2),
      reach: 1.0,
    );
    canvas.restore();
    _puff(
      canvas,
      hole.center.translate(0, -_u * 0.25 * splash),
      splash,
      size: 0.6,
      color: const Color(0xFFA9C7DE),
    );
    // Le bolle dalle fessure del chiusino.
    final bubbles = _span(t, 0.78, 0.86);
    if (bubbles > 0 && bubbles < 1) {
      for (var i = 0; i < 5; i++) {
        final life = (bubbles * 2.2 + i * 0.27) % 1;
        canvas.drawCircle(
          hole.center.translate(
            _u * (-0.16 + 0.08 * i) + sin(life * 9 + i) * _u * 0.015,
            -_u * 0.03 - _u * 0.22 * life,
          ),
          _u * (0.012 + 0.008 * (i % 2)) * (1 - life * 0.5),
          Paint()
            ..color = const Color(0xFFBFD8EA).withValues(alpha: 1 - life)
            ..style = PaintingStyle.stroke
            ..strokeWidth = _u * 0.006,
        );
      }
    }
  }

  void _blackout(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    final creep = _smooth(_span(t, 0.50, strike));
    final leave = _smooth(_span(t, 0.585, 0.655));
    final killerX = _mix(
      _mix(_hiddenX, _victimX + _u * 0.42, creep),
      _hiddenX,
      leave,
    );
    final night = 1 - _lampPower;
    final lampHead = Offset(_w * 0.26 + _u * 0.24, _ground - _u * 1.38);
    // Il coltello: si alza nel buio, cala al colpo.
    final raise = _smooth(_span(t, 0.52, 0.55));
    final blow = _span(t, strike, strike + 0.03);
    final facing = leave > 0.05 ? 1 : -1;
    final arm = leave > 0 ? 0.1 : _mix(_mix(0.4, 2.7, raise), 1.35, blow);
    final elbow = leave > 0 ? 0.2 : _mix(_mix(0.6, 0.5, raise), 0.1, blow);
    final lean = leave > 0 ? 0.05 : 0.22 * sin(pi * blow);

    _person(
      canvas,
      feet: Offset(killerX, _ground),
      facing: facing,
      walk: _prowl,
      stride: (creep > 0 && creep < 1) || (leave > 0 && leave < 1) ? 1 : 0,
      lean: lean,
      arm: arm,
      elbow: elbow,
      prop: _Prop.knife,
      killer: true,
    );
    _wall(canvas);
    _pool(
      canvas,
      Offset(_victimX - _u * 0.50, _ground + _u * 0.04),
      _smooth(_span(t, 0.70, 0.84)),
    );
    final fall = _span(t, strike, strike + 0.07);
    _victim(
      canvas,
      x: walkX,
      facing: t < 0.37 ? 1 : -1,
      walk: walk,
      stride: stride,
      fall: fall,
      lean: t > 0.44 && t < 0.50 ? -0.10 : 0,
      smoking: t > 0.37 && t < strike,
    );
    if (t > strike + 0.07) {
      _looseHat(
        canvas,
        Offset(_victimX - _u * 1.15, _ground - _u * 0.03),
        -0.2,
      );
    }
    _spray(
      canvas,
      Offset(_victimX, _ground - _u * 0.74),
      _span(t, strike, strike + 0.18),
      seed: 6,
      count: 14,
    );

    // Il lampione che sfrigola: una scarica a ogni singhiozzo, e quando torna.
    for (final (from, size) in [(0.44, 1.0), (0.475, 0.8), (0.655, 0.7)]) {
      final zap = _span(t, from, from + 0.025);
      if (zap <= 0 || zap >= 1) continue;
      _sprite(
        canvas,
        sprites?.electric,
        lampHead.translate(_u * 0.02, _u * 0.08),
        _u * 0.55 * size,
        opacity: (1 - zap) * (0.5 + 0.5 * sin(t * 900).abs()),
        rotation: from * 30,
        tint: const Color(0xFFCFE8FF),
      );
      _spray(
        canvas,
        lampHead,
        zap,
        seed: (from * 100).round(),
        color: _warm,
        count: 6,
        bias: const Offset(0.1, -0.2),
        reach: 0.5,
      );
    }

    // Il buio: nel nero restano due occhi, la brace della sigaretta e un
    // lampo d'acciaio.
    if (night > 0) {
      canvas.drawRect(
        Rect.fromLTWH(-_w * 2, -_h * 2, _w * 5, _h * 5),
        Paint()..color = Colors.black.withValues(alpha: 0.88 * night),
      );
    }
    if (night > 0.5) {
      final killerHeight = _u * 1.08;
      final eyes = Offset(
        killerX + facing * killerHeight * 0.075,
        _ground - killerHeight * 0.995,
      );
      final glint = Paint()..color = const Color(0xFFFFF3C4);
      canvas.drawCircle(eyes, _u * 0.014, glint);
      canvas.drawCircle(
        eyes.translate(-facing * _u * 0.045, 0),
        _u * 0.014,
        glint,
      );
      // La brace: è lì che sta la vittima, finché non le cade di bocca.
      final ember = t < strike
          ? Offset(_victimX - _u * 0.185, _ground - _u * 0.923)
          : null;
      if (ember != null) {
        _sprite(
          canvas,
          sprites?.glow,
          ember,
          _u * 0.30,
          opacity: 0.45 + 0.15 * sin(t * 160),
          tint: const Color(0xFFFF7A3B),
        );
        canvas.drawCircle(
          ember,
          _u * 0.016,
          Paint()..color = const Color(0xFFFF7A3B),
        );
      }
    }
    // Lo scatto della lama e il suo riflesso quando sale.
    final (hand, along) = _handOf(
      feet: Offset(killerX, _ground),
      facing: facing,
      lean: lean,
      arm: arm,
      elbow: elbow,
      killer: true,
    );
    final tip = hand + along * (_u * 1.08 * 0.22);
    for (final shine in [_span(t, 0.50, 0.52), _span(t, 0.535, 0.555)]) {
      if (shine <= 0 || shine >= 1) continue;
      _sprite(
        canvas,
        sprites?.glint,
        tip,
        _u * 0.40 * sin(pi * shine),
        opacity: sin(pi * shine),
      );
    }
    // Il fendente nel buio, e la sigaretta che cade accesa sull'asfalto.
    if (blow > 0 && blow < 1) {
      final texture = sprites?.slash;
      final center = Offset(_victimX + _u * 0.10, _ground - _u * 0.80);
      if (texture != null) {
        _tinted(
          canvas,
          texture,
          center,
          width: _u * 0.85,
          height: _u * 0.85,
          opacity: 1 - blow,
          rotation: -0.9 + 0.5 * blow,
        );
      } else {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: _u * 0.46),
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
    _droppedCigarette(
      canvas,
      Offset(_victimX - _u * 0.185, _ground - _u * 0.923),
      _span(t, strike, strike + 0.05),
    );
  }

  void _heart(Canvas canvas, Offset center, double size, Color color) {
    canvas.drawPath(
      Path()
        ..moveTo(center.dx, center.dy + size * 0.55)
        ..cubicTo(
          center.dx - size * 1.1,
          center.dy - size * 0.1,
          center.dx - size * 0.55,
          center.dy - size * 0.85,
          center.dx,
          center.dy - size * 0.30,
        )
        ..cubicTo(
          center.dx + size * 0.55,
          center.dy - size * 0.85,
          center.dx + size * 1.1,
          center.dy - size * 0.1,
          center.dx,
          center.dy + size * 0.55,
        )
        ..close(),
      Paint()..color = color,
    );
  }

  void _kiss(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    final come = _smooth(_span(t, 0.37, 0.51));
    final leanIn =
        _smooth(_span(t, 0.51, strike)) -
        _smooth(_span(t, strike + 0.03, strike + 0.07));
    final leave = _smooth(_span(t, 0.66, 0.84));
    final dameX = _mix(
      _mix(_hiddenX, _victimX + _u * 0.36, come),
      _hiddenX,
      leave,
    );
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

    // Si tocca il cappello, si lascia baciare; poi il veleno del rossetto:
    // la mano alla gola, il fiato verde, e giù.
    final tipsHat = _span(t, 0.43, 0.47) - _span(t, 0.49, 0.52);
    final queasy = _span(t, 0.60, 0.66);
    final clutch = _smooth(_span(t, 0.598, 0.625));
    final fall = _span(t, 0.66, 0.77);
    final lean =
        0.18 * leanIn +
        (queasy > 0 && fall == 0 ? sin(t * 110) * 0.14 * queasy : 0) +
        0.12 * clutch * (1 - fall);
    _victim(
      canvas,
      x: walkX,
      walk: walk,
      stride: stride,
      fall: fall,
      lean: lean,
      arm: _mix(_mix(0.08, 2.35, tipsHat), 1.9, clutch),
      elbow: _mix(_mix(0.2, 1.3, tipsHat), 2.7, clutch),
    );
    _hatOff(canvas, 0.68, 0.84, height: 0.5);

    final feet = Offset(walkX, _ground);
    if (t > strike + 0.01 && fall == 0) {
      // Il segno del rossetto sulla guancia.
      final cheek = _onBody(const Offset(0.085, -0.47), feet: feet, lean: lean);
      _heart(canvas, cheek, _u * 0.028, const Color(0xFFE23A4A));
    }
    for (final from in [0.61, 0.635]) {
      final breath = _span(t, from, from + 0.07);
      if (breath <= 0 || breath >= 1 || fall > 0.3) continue;
      final mouth = _onBody(const Offset(0.11, -0.435), feet: feet, lean: lean);
      _sprite(
        canvas,
        sprites?.glow,
        mouth.translate(_u * 0.10 * breath, -_u * 0.22 * breath),
        _u * 0.35,
        opacity: 0.7 * (1 - breath),
        tint: const Color(0xFF7BEA4A),
      );
      _sprite(
        canvas,
        sprites?.smoke,
        mouth.translate(_u * 0.10 * breath, -_u * 0.22 * breath),
        _u * 0.32 * (0.7 + breath),
        opacity: 0.8 * (1 - breath),
        tint: const Color(0xFF9BF06A),
      );
    }

    // Lo schiocco del bacio.
    final smack = _span(t, strike, strike + 0.04);
    if (smack > 0 && smack < 1) {
      final lips = Offset(_victimX + _u * 0.17, _ground - _u * 0.93);
      _sprite(
        canvas,
        sprites?.glint,
        lips,
        _u * 0.45 * sin(pi * smack),
        opacity: 1 - smack,
        tint: const Color(0xFFFF9EC0),
      );
    }

    // Il cuore sale rosso, e mentre sale diventa verde; poi si spezza.
    final love = _span(t, strike, 0.66);
    final crack = _span(t, 0.645, 0.72);
    if (love > 0 && crack < 1) {
      final center = Offset(
        _victimX + _u * 0.18 + sin(love * 9) * _u * 0.04 * (1 - crack),
        _ground - _u * (1.15 + 0.55 * love),
      );
      final size = _u * (0.10 + 0.05 * sin(love * 30).abs() * (1 - crack));
      final color = Color.lerp(
        const Color(0xFFE23A4A),
        const Color(0xFF6FBF4A),
        _span(love, 0.35, 0.8),
      )!;
      _sprite(
        canvas,
        sprites?.glow,
        center,
        size * 4,
        opacity: 0.5 * (1 - crack),
        tint: color,
      );
      if (crack <= 0) {
        _heart(canvas, center, size, color);
      } else {
        // Le due metà si separano e cadono.
        for (final side in [-1, 1]) {
          canvas.save();
          canvas.translate(side * _u * 0.10 * crack, _u * 0.45 * crack * crack);
          canvas.translate(center.dx, center.dy);
          canvas.rotate(side * 0.6 * crack);
          canvas.translate(-center.dx, -center.dy);
          canvas.clipRect(
            side < 0
                ? Rect.fromLTRB(
                    center.dx - size * 2,
                    center.dy - size * 2,
                    center.dx,
                    center.dy + size * 2,
                  )
                : Rect.fromLTRB(
                    center.dx,
                    center.dy - size * 2,
                    center.dx + size * 2,
                    center.dy + size * 2,
                  ),
          );
          _heart(canvas, center, size, color.withValues(alpha: 1 - crack));
          canvas.restore();
        }
      }
    }
  }

  // ------------------------------------------------------------------ dopo

  /// Il dettaglio finale del copione, messo in scena: il gatto che passa, le
  /// sirene che arrivano tardi, una carta lasciata lì, la musica dal bar.
  void _aftermath(Canvas canvas) {
    switch (epilogue) {
      case 'gatto':
        final stroll = _span(t, 0.66, 0.86);
        if (stroll > 0) {
          _cat(canvas, _mix(_w * 1.15, -_w * 0.25, stroll), t * 260);
        }
      case 'sirene':
        final arriving = _span(t, 0.68, 0.84);
        if (arriving > 0) {
          final red = (t * 70).floor().isEven;
          canvas.drawCircle(
            Offset(-_u * 0.3, _ground - _u * 0.5),
            _u * (1.2 + 1.6 * arriving),
            Paint()
              ..color =
                  (red ? const Color(0xFFE23A4A) : const Color(0xFF3B6BFF))
                      .withValues(alpha: 0.30 * arriving)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, _u * 0.5),
          );
        }
      case 'carta':
        final flutter = _span(t, 0.66, 0.76);
        if (flutter > 0) {
          final landed = flutter >= 1;
          canvas.save();
          canvas.translate(
            _victimX +
                _u * (0.55 - 0.15 * flutter) +
                sin(flutter * 12) * _u * 0.10 * (1 - flutter),
            _mix(
              _ground - _u * 1.1,
              _ground - _u * 0.02,
              Curves.easeIn.transform(flutter),
            ),
          );
          canvas.rotate(landed ? 0.25 : flutter * 7);
          canvas.scale(1, landed ? 0.35 : 1);
          final card = RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: _u * 0.12,
              height: _u * 0.17,
            ),
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
            _cornerX +
                _u * (0.10 - 0.55 * rise) +
                sin(rise * 10 + i) * _u * 0.05,
            _ground - _u * (1.70 + 0.55 * rise),
          );
          final paint = Paint()..color = _warm.withValues(alpha: 1 - rise);
          canvas.drawOval(
            Rect.fromCenter(center: note, width: _u * 0.07, height: _u * 0.05),
            paint,
          );
          canvas.drawLine(
            note.translate(_u * 0.03, 0),
            note.translate(_u * 0.03, -_u * 0.14),
            paint..strokeWidth = _u * 0.012,
          );
          canvas.drawLine(
            note.translate(_u * 0.03, -_u * 0.14),
            note.translate(_u * 0.08, -_u * 0.10),
            paint,
          );
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
    for (final (dx, phase) in [
      (-0.10, 0.0),
      (-0.06, pi),
      (0.08, pi),
      (0.12, 0.0),
    ]) {
      canvas.drawLine(
        Offset(x + _u * dx, y + _u * 0.02),
        Offset(x + _u * dx + sin(step + phase) * _u * 0.04, _ground),
        legs,
      );
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, y),
        width: _u * 0.32,
        height: _u * 0.11,
      ),
      ink,
    );
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
        ..quadraticBezierTo(
          x + _u * 0.30,
          y - _u * 0.02,
          x + _u * 0.27,
          y - _u * (0.24 + 0.03 * sin(step * 0.3)),
        ),
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = _u * 0.028
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      head.translate(-_u * 0.025, -_u * 0.005),
      _u * 0.011,
      Paint()..color = const Color(0xFFE8D24A),
    );
  }

  /// Il sipario di velluto che cala sulla scena.
  void _curtain(Canvas canvas, double drop) {
    if (drop <= 0) return;
    final bottom = _h * 1.08 * Curves.easeIn.transform(drop);
    final folds = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF6A0F17),
          Color(0xFF9C1B26),
          Color(0xFF5A0C13),
          Color(0xFF9C1B26),
          Color(0xFF6A0F17),
        ],
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
      path.quadraticBezierTo(
        (left + right) / 2,
        bottom + _h * 0.035,
        left,
        bottom,
      );
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
      DeathAct.bowling => ('STRIKE!', strike, 0.14),
      DeathAct.swordfish => ('SPLOSH!', strike, 0.12),
      DeathAct.harpoon => ('THUNK!', strike, 0.12),
      DeathAct.pie => ('BOOM!', strike, 0.16),
      DeathAct.trombone => ('BLAM!', strike, 0.12),
      DeathAct.tango => ('OLÉ!', strike, 0.12),
      DeathAct.bouquet => ('RATATATA!', 0.555, 0.14),
      DeathAct.laundry => ('MMPH!', strike, 0.12),
      DeathAct.sniper => ('PAM!', strike, 0.12),
      DeathAct.rescue => ('BANG!', strike, 0.10),
      DeathAct.lucky => ('DING!', strike, 0.12),
      DeathAct.belfry => ('DONG!', strike, 0.14),
      DeathAct.phoneBooth => ('KRAK!', strike, 0.12),
      DeathAct.carDoor => ('PAM!', strike, 0.12),
      DeathAct.defibrillator ||
      DeathAct.pliers ||
      DeathAct.ambulance ||
      DeathAct.stitches => ('BANG!', strike, 0.10),
      DeathAct.bible => ('THUNK!', strike, 0.12),
      DeathAct.jam => ('CLICK!', strike, 0.07),
      DeathAct.banana => ('SLIP!', 0.525, 0.07),
      DeathAct.blackCat => ('MRAOW!', 0.545, 0.08),
    };
    // In un filmato composto la scritta del colpo è una sola: quella
    // dell'agguato se va a segno, quella della fortuna se va a vuoto.
    final silent = (_missed) || _doctorLayer;
    if (!silent) {
      _word(
        canvas,
        word,
        from,
        length,
        act == DeathAct.kiss ? const Color(0xFFFF7AA8) : const Color(0xFFFFE27A),
      );
    }
    // Il cuore che riparte.
    if (act == DeathAct.rescue) {
      _word(canvas, 'TU-TUM!', 0.765, 0.09, const Color(0xFF8BE0A4));
    }
    _savesSfx(canvas);
  }

  void _word(
    Canvas canvas,
    String word,
    double from,
    double length,
    Color fill,
  ) {
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
    letters(color: _blood.withValues(alpha: fade))
        .paint(canvas, origin.translate(size * 0.05, size * 0.05));
    letters(color: fill.withValues(alpha: fade)).paint(canvas, origin);
    canvas.restore();
  }

  /// Il filo di fumo di una sigaretta accesa.
  void _wisp(Canvas canvas, Offset from) {
    final path = Path()..moveTo(from.dx, from.dy);
    for (var i = 1; i <= 6; i++) {
      path.lineTo(
        from.dx + sin(t * 70 + i * 0.9) * _u * 0.012 * i,
        from.dy - i * _u * 0.07,
      );
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
      Rect.fromCenter(
        center: center.translate(0, -h * 0.07),
        width: h * 0.10,
        height: h * 0.08,
      ),
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
    canvas.drawCircle(
      center,
      h * 0.046,
      Paint()..color = const Color(0xFFE9E4D8),
    );
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
    // Sopra un agguato, il killer è quello dell'agguato.
    if (_cut == _Cut.rescue) return _handover!.killer?.dx ?? _cornerX;
    final peek = _smooth(_span(t, 0.38, 0.46));
    final out = _smooth(_span(t, 0.46, 0.53));
    final leave = _smooth(_span(t, leaveAt, leaveAt + 0.08));
    final killerX = _mix(
      _mix(_mix(_hiddenX, _peekX, peek), _cornerX, out),
      _hiddenX,
      leave,
    );
    final bang = _span(t, strike, strike + 0.025);
    final kick = bang > 0 && bang < 1 ? sin(pi * bang) : 0.0;
    final facing = leave > 0.08 ? 1 : -1;
    final lean = leave > 0 ? 0.05 : 0.10 * out - 0.08 * kick + 0.14 * puzzled;
    final arm = leave > 0
        ? 0.1
        : _mix(_mix(0.2, pi / 2, out) + 0.24 * kick, 0.9, puzzled);
    final elbow = leave > 0 ? 0.2 : _mix(0.03 - 0.10 * kick, 0.9, puzzled);

    _person(
      canvas,
      feet: Offset(killerX, _ground),
      facing: facing,
      walk: _prowl,
      stride: (out > 0 && out < 1) || (leave > 0 && leave < 1) ? 0.9 : 0,
      lean: lean,
      arm: arm,
      elbow: elbow,
      prop: _Prop.pistol,
      killer: true,
    );

    final (hand, along) = _handOf(
      feet: Offset(killerX, _ground),
      facing: facing,
      lean: lean,
      arm: arm,
      elbow: elbow,
      killer: true,
    );
    final muzzle = _muzzleOf(hand, along, _Prop.pistol);
    if (bang > 0 && bang < 1) {
      _muzzleFlash(canvas, muzzle, bang, toward: along, size: 0.7);
      _star(
        canvas,
        muzzle,
        _u * 0.08 * (1 - bang * 0.5),
        const Color(0xFFFFF3C4).withValues(alpha: 1 - bang),
      );
      _tracer(
        canvas,
        muzzle,
        Offset(_victimX + _u * 0.06, _ground - _u * 0.74),
        bang,
      );
    }
    _casings(canvas, hand + Offset(0, -_u * 0.04), const [strike]);
    final smoke = _span(t, strike + 0.02, strike + 0.14);
    if (smoke > 0 && smoke < 1) {
      _puff(canvas, muzzle.translate(0, -_u * 0.25 * smoke), smoke, size: 0.3);
    }
    return killerX;
  }

  /// Il colpo del Cecchino: nessuno dietro l'angolo, solo una finestra buia,
  /// il riflesso di una lente e un mirino che trova il bersaglio.
  void _sniper(Canvas canvas) {
    final (walkX, walk, stride) = _entrance();
    _wall(canvas);

    final fall = _span(t, strike + 0.01, strike + 0.11);
    _pool(
      canvas,
      Offset(_victimX - _u * 0.50, _ground + _u * 0.04),
      _smooth(_span(t, 0.67, 0.84)),
    );
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
    if (glint > 0) {
      _star(
        canvas,
        nest,
        _u * 0.10 * glint,
        Colors.white.withValues(alpha: glint),
      );
    }

    final aim = _smooth(_span(t, 0.39, 0.535));
    // La canna scende piano sul bersaglio, e al colpo sobbalza.
    final shotAt = chest - nest;
    final kick = sin(pi * _span(t, strike, strike + 0.05));
    final angle =
        atan2(-shotAt.dy, -shotAt.dx) * _mix(0.55, 1, aim) - 0.18 * kick;
    if (aim > 0) {
      canvas.saveLayer(
        Rect.fromCircle(center: nest, radius: _u * 0.55),
        Paint()..color = Colors.white.withValues(alpha: aim),
      );
      canvas.translate(nest.dx, nest.dy);
      canvas.rotate(angle);
      canvas.translate(-nest.dx + _u * 0.05 * kick, -nest.dy);
      _drawSniperRifle(canvas, nest, _u * 0.72);
      canvas.restore();
    }
    if (aim > 0 && t < strike + 0.02) {
      final wander = (1 - aim) * _u;
      final sight =
          chest +
          Offset(sin(t * 55) * 0.5 + 0.55, cos(t * 41) * 0.28 - 0.40) * wander;
      final radius = _u * _mix(0.36, 0.15, aim);
      final red = Paint()
        ..color = const Color(0xFFFF3B30)
            .withValues(alpha: 0.9 * min(1, aim * 4))
        ..style = PaintingStyle.stroke
        ..strokeWidth = _u * 0.014;
      canvas.drawCircle(sight, radius, red);
      for (final side in const [
        Offset(1, 0),
        Offset(-1, 0),
        Offset(0, 1),
        Offset(0, -1),
      ]) {
        canvas.drawLine(
          sight + side * (radius * 0.45),
          sight + side * (radius * 1.35),
          red,
        );
      }
      canvas.drawCircle(sight, _u * 0.012, Paint()..color = red.color);
    }

    final bang = _span(t, strike, strike + 0.03);
    if (bang > 0 && bang < 1) {
      _muzzleFlash(canvas, nest, bang, toward: shotAt, size: 0.8);
      _star(
        canvas,
        nest,
        _u * 0.10 * (1 - bang * 0.5),
        const Color(0xFFFFF3C4).withValues(alpha: 1 - bang),
      );
      _tracer(canvas, nest, chest, bang);
    }
    _puff(
      canvas,
      nest.translate(-_u * 0.05, -_u * 0.1),
      _span(t, strike + 0.02, strike + 0.16),
      size: 0.4,
    );
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
    _hatOff(canvas, strike + 0.01, strike + 0.20, height: 0.9);

    // Il Dottore arriva di corsa con la borsa, la posa e si inginocchia
    // accanto al petto: benda, iniezione, il cuore che riparte.
    final come = _span(t, 0.62, 0.70);
    final kneelX = _victimX - _u * 0.78;
    final doctorX = _mix(-_w * 0.45, kneelX, Curves.easeOut.transform(come));
    final kneel =
        _smooth(_span(t, 0.70, 0.72)) - _smooth(_span(t, 0.80, 0.835));
    final wrap = _span(t, 0.725, 0.745);
    final tape = _span(t, 0.785, 0.80);
    final jab = _span(t, 0.742, 0.765);
    final helping =
        _smooth(_span(t, 0.80, 0.83)) - _smooth(_span(t, 0.86, 0.88));
    final salute = _smooth(_span(t, 0.875, 0.90));
    final working = kneel > 0.5 && t < 0.80;
    final rub = working ? sin(t * 260) * 0.12 : 0.0;
    final double doctorArm;
    final double doctorElbow;
    if (come < 1) {
      (doctorArm, doctorElbow) = (0.3, 0.3);
    } else if (jab > 0 && jab < 1) {
      // Su la siringa, e giù nel braccio.
      final up = sin(pi * min(1, jab * 1.6));
      (doctorArm, doctorElbow) = (_mix(1.05, 2.2, up), _mix(0.4, 0.6, up));
    } else if (working) {
      (doctorArm, doctorElbow) = (1.05 + rub, 0.4);
    } else {
      (doctorArm, doctorElbow) = (
        _mix(_mix(0.3, 1.45, helping), 2.35, salute),
        _mix(_mix(0.3, 0.2, helping), 1.25, salute),
      );
    }
    final doctorLean = come < 1 ? 0.22 : 0.45 * kneel + 0.10 * helping;
    final doctorCrouch = 0.9 * kneel;
    final doctorFeet = Offset(doctorX, _ground);
    if (come > 0) {
      if (come >= 1) {
        _bag(canvas, Offset(doctorX - _u * 0.26, _ground - _u * 0.07), _u);
        // La borsa aperta: un rotolo di garza sull'asfalto.
        if (t > 0.715) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset(doctorX - _u * 0.05, _ground - _u * 0.03),
                width: _u * 0.08,
                height: _u * 0.06,
              ),
              Radius.circular(_u * 0.015),
            ),
            Paint()..color = const Color(0xFFE9E4D8),
          );
        }
      }
      _person(
        canvas,
        feet: doctorFeet,
        walk: t * 300,
        stride: come < 1 ? 1 : 0,
        lean: doctorLean,
        crouch: doctorCrouch,
        arm: doctorArm,
        elbow: doctorElbow,
        backArm: working ? 0.9 - rub : -0.1,
        backElbow: working ? 0.5 : 0.2,
        hat: AvatarHead.bowler,
        cloth: const Color(0xFFE9E4D8),
        prop: come < 1 ? _Prop.bag : _Prop.none,
      );
      if (jab > 0 && jab < 1) {
        final (hand, along) = _handOf(
          feet: doctorFeet,
          lean: doctorLean,
          crouch: doctorCrouch,
          arm: doctorArm,
          elbow: doctorElbow,
        );
        canvas.drawLine(
          hand - along * (_u * 0.02),
          hand + along * (_u * 0.10),
          Paint()
            ..color = const Color(0xFFDDE9F0)
            ..strokeWidth = _u * 0.026,
        );
        canvas.drawLine(
          hand + along * (_u * 0.10),
          hand + along * (_u * 0.15),
          Paint()
            ..color = _steel
            ..strokeWidth = _u * 0.006,
        );
        canvas.drawLine(
          hand + along * (_u * 0.02),
          hand + along * (_u * 0.08),
          Paint()
            ..color = const Color(0xFF8BE0A4)
            ..strokeWidth = _u * 0.014,
        );
      }
    }

    // Chi era a terra: un sussulto, si tira su a sedere, poi in piedi.
    final wake = _span(t, 0.80, 0.85);
    final bandage = Paint()..color = const Color(0xFFF2EEE6);
    if (wake <= 0) {
      _victim(
        canvas,
        x: walkX,
        facing: t < 0.37 ? 1 : -1,
        walk: walk,
        stride: stride,
        fall: fall,
        lean: bang > 0 && bang < 1 ? 0.20 * sin(pi * bang) : 0,
        smoking: t > 0.37 && t < strike,
      );
      if (wrap > 0) {
        // La fascia intorno al petto, che si stringe giro dopo giro.
        for (final (dx, grow) in [(-0.52, wrap), (-0.42, tape)]) {
          if (grow <= 0) continue;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTRB(
                _victimX + _u * (dx - 0.035),
                _ground - _u * (0.015 + 0.165 * grow),
                _victimX + _u * (dx + 0.035),
                _ground - _u * 0.008,
              ),
              Radius.circular(_u * 0.012),
            ),
            bandage,
          );
        }
      }
    } else {
      final sit = Curves.easeOut.transform(_span(wake, 0, 0.4));
      final stand = _smooth(_span(wake, 0.4, 1));
      final tilt = -1.30 * (1 - sit * 0.55) * (1 - stand);
      final crouch = 0.95 * (1 - stand);
      final wave = _smooth(_span(t, 0.855, 0.875));
      final feet = Offset(_victimX, _ground);
      final lean = 0.10 * (1 - stand);
      _person(
        canvas,
        feet: feet,
        facing: -1,
        tilt: tilt,
        crouch: crouch,
        lean: lean,
        arm: _mix(_mix(2.3, 1.45, sit), 2.7 + 0.2 * sin(t * 140), wave),
        elbow: _mix(0.25, 0.45, wave),
        backArm: _mix(-1.3, -0.1, stand),
        hat: victimHat,
        hatOn: false,
      );
      // La fascia resta: di traverso sul petto.
      canvas.drawLine(
        _onBody(
          const Offset(0.10, -0.33),
          feet: feet,
          facing: -1,
          tilt: tilt,
          crouch: crouch,
          lean: lean,
        ),
        _onBody(
          const Offset(-0.11, -0.10),
          feet: feet,
          facing: -1,
          tilt: tilt,
          crouch: crouch,
          lean: lean,
        ),
        bandage
          ..strokeWidth = _u * 0.055
          ..strokeCap = StrokeCap.round,
      );
    }
    if (_cut != _Cut.rescue) {
      _spray(
        canvas,
        Offset(_victimX, _ground - _u * 0.74),
        _span(t, strike, strike + 0.16),
        seed: 95,
        count: 9,
      );
      _flash(canvas, bang, strength: 0.4);
    }

    // La cura: una croce che pulsa sopra il petto, e le scintille intorno.
    final cure = _span(t, 0.745, 0.80);
    if (cure > 0 && cure < 1) {
      final heart = Offset(
        _victimX - _u * 0.50,
        _ground - _u * (0.30 + 0.14 * cure),
      );
      final beat = sin(cure * pi * 6).abs();
      final pulse = 1 + 0.25 * beat;
      final fade = 1 - cure * cure;
      _sprite(
        canvas,
        sprites?.glow,
        heart,
        _u * 0.9 * pulse,
        opacity: 0.55 * fade,
        tint: const Color(0xFF8BE0A4),
      );
      canvas.drawCircle(
        heart,
        _u * 0.10 * pulse,
        Paint()..color = const Color(0xFFE9E4D8).withValues(alpha: fade),
      );
      _cross(canvas, heart, _u * 0.065 * pulse);
      for (var i = 0; i < 5; i++) {
        final angle = cure * 5 + i * 2 * pi / 5;
        _star(
          canvas,
          heart +
              Offset(cos(angle), sin(angle) * 0.6) *
                  (_u * (0.24 + 0.22 * cure)),
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
    final puzzled =
        _smooth(_span(t, strike + 0.035, strike + 0.07)) -
        _smooth(_span(t, 0.655, 0.67));
    final killerX = _gunman(canvas, leaveAt: 0.67, puzzled: puzzled);
    _wall(canvas);
    if (puzzled > 0.5) {
      _mark(canvas, '?!', Offset(killerX - _u * 0.05, _ground - _u * 1.52));
    }

    // Sente il cane armarsi e si gira: il colpo lo prende in pieno petto.
    final facing = _luckyFacing(t < 0.37 ? 1 : (t < 0.512 ? -1 : 1));
    final stagger = sin(pi * _span(t, strike, strike + 0.09));
    final back =
        _u * 0.12 * Curves.easeOut.transform(_span(t, strike, strike + 0.05));
    final clutch =
        _smooth(_span(t, strike + 0.005, strike + 0.03)) -
        _smooth(_span(t, 0.625, 0.65));
    final look = _smooth(_span(t, 0.60, 0.63)) - _smooth(_span(t, 0.66, 0.69));
    final pull = _smooth(_span(t, 0.64, 0.69));
    final swig =
        _smooth(_span(t, 0.775, 0.80)) - _smooth(_span(t, 0.845, 0.87));
    final x = walkX - back;
    final lean = -0.34 * stagger + 0.18 * look - 0.12 * swig;
    final arm = _mix(_mix(_mix(0.08, 0.2, clutch), 1.95, pull), 1.2, swig);
    final elbow = _mix(_mix(_mix(0.2, 2.4, clutch), 0.85, pull), 1.9, swig);
    _victim(
      canvas,
      x: x,
      facing: facing,
      walk: walk,
      stride: stride,
      lean: lean,
      arm: arm,
      elbow: elbow,
      smoking: t > 0.37 && t < strike,
    );
    _droppedCigarette(
      canvas,
      _onBody(
        const Offset(0.11, -0.435),
        feet: Offset(walkX, _ground),
        facing: 1,
      ),
      _span(t, strike + 0.005, strike + 0.055),
    );

    // La scintilla sul metallo, al posto del sangue, e il colpo che rimbalza
    // via verso il cielo.
    final chest = Offset(x + _u * 0.10, _ground - _u * 0.76);
    final ding = _span(t, strike, strike + 0.05);
    if (ding > 0 && ding < 1) {
      _star(
        canvas,
        chest,
        _u * 0.22 * (1 - ding * 0.4),
        AppColors.gold.withValues(alpha: 1 - ding),
      );
      _sprite(
        canvas,
        sprites?.glint,
        chest,
        _u * 0.7 * (1 - ding * 0.5),
        opacity: 1 - ding,
      );
    }
    final ricochet = _span(t, strike + 0.004, strike + 0.035);
    _tracer(
      canvas,
      chest,
      chest + Offset(-_u * 0.55, -_u * 1.25) * min(1, ricochet * 1.5),
      ricochet,
    );
    _spray(
      canvas,
      chest,
      _span(t, strike, strike + 0.14),
      seed: 97,
      color: _warm,
      count: 12,
      bias: const Offset(-0.3, -0.9),
      reach: 0.8,
    );
    _flash(canvas, _span(t, strike, strike + 0.03), strength: 0.4);

    // La fiaschetta tirata fuori dal taschino: ammaccata, col proiettile
    // schiacciato nel mezzo. Poi un sorso, per festeggiare.
    if (pull > 0.15) {
      final (hand, _) = _handOf(
        feet: Offset(x, _ground),
        facing: facing,
        lean: lean,
        arm: arm,
        elbow: elbow,
      );
      _flask(
        canvas,
        hand.translate(_u * 0.01, -_u * 0.06),
        tip: swig * 1.9,
        shine: pull > 0.9 && swig < 0.5 ? sin(t * 60).abs() : 0,
      );
    }
  }

  /// La fiaschetta d'argento con l'ammaccatura del colpo.
  void _flask(
    Canvas canvas,
    Offset center, {
    double tip = 0,
    double shine = 0,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-tip);
    final body = Rect.fromCenter(
      center: Offset.zero,
      width: _u * 0.12,
      height: _u * 0.16,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: body.topCenter.translate(0, -_u * 0.015),
        width: _u * 0.04,
        height: _u * 0.035,
      ),
      Paint()..color = _gunmetal,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(_u * 0.025)),
      Paint()..color = _steel,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        body.deflate(_u * 0.012),
        Radius.circular(_u * 0.018),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _u * 0.006
        ..color = const Color(0xFF9AA2AB),
    );
    // L'ammaccatura, col piombo schiacciato dentro.
    canvas.drawCircle(
      const Offset(0, 0).translate(_u * 0.005, _u * 0.01),
      _u * 0.030,
      Paint()..color = const Color(0xFF7D858E),
    );
    canvas.drawCircle(
      Offset(_u * 0.005, _u * 0.01),
      _u * 0.017,
      Paint()..color = const Color(0xFFB08A3E),
    );
    canvas.restore();
    if (shine > 0) {
      _sprite(
        canvas,
        sprites?.glint,
        center.translate(-_u * 0.035, -_u * 0.05),
        _u * 0.28 * shine,
        opacity: shine,
      );
      if (sprites == null) {
        _star(
          canvas,
          center.translate(-_u * 0.035, -_u * 0.05),
          _u * 0.05 * shine,
          Colors.white.withValues(alpha: shine),
        );
      }
    }
  }

  @override
  bool shouldRepaint(DeathScenePainter old) =>
      old.t != t ||
      old.act != act ||
      old.save != save ||
      old.victimHat != victimHat ||
      old.epilogue != epilogue;
}
