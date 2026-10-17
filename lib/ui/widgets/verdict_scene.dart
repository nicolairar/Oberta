import 'dart:async';
import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_strings.dart';
import '../../roster/portrait_registry.dart';
import '../../sound/scene_cues.dart';
import '../../sound/verdict_cues.dart';
import '../../sound/sound_stage.dart';
import '../../sound/verdict_stage.dart';
import '../theme/app_theme.dart';
import 'city_backdrop.dart';
import 'mugshot_frame.dart';
import 'noir_avatar.dart';
import 'particle_sprites.dart';
import '../press.dart';

/// I modi in cui la piazza si libera di qualcuno, più quello in cui non si
/// libera di nessuno.
enum VerdictTake {
  /// Giù al molo, con le scarpe di cemento.
  molo,

  /// Accompagnato al cartello di fine città, e via a piedi.
  cartello,

  /// Messo sull'ultimo treno della sera.
  treno,

  /// Sparato col cannone del circo.
  cannone,

  /// Nessuna condanna: si litiga, si alzano le spalle, tutti a casa.
  assoluzione;

  static const condemnations = [molo, cartello, treno, cannone];

  bool get condemns => this != assoluzione;

  /// Quanto dura il film, dal buio in sala alla carta finale.
  Duration get length => condemns ? const Duration(seconds: 11) : const Duration(seconds: 7);

  /// Il momento della battuta finale: lì il telefono dà un colpo nella mano.
  double get payoff => switch (this) {
        molo => VerdictBeats.splash,
        cartello => VerdictBeats.carPass,
        treno => VerdictBeats.whistle,
        cannone => VerdictBeats.boom,
        assoluzione => VerdictBeats.shrug,
      };

  /// Quando arriva il primo piano del condannato, se c'è un condannato.
  double? get closeUpAt => switch (this) {
        molo => VerdictBeats.pierCloseUp,
        cartello => VerdictBeats.signCloseUp,
        treno => VerdictBeats.trainCloseUp,
        cannone => VerdictBeats.cannonCloseUp,
        assoluzione => null,
      };

  /// La variante che si chiama [id]; per un nome che non c'è, una a caso.
  static VerdictTake pick(String? id, Random random) {
    for (final take in condemnations) {
      if (take.name == id) return take;
    }
    return condemnations[random.nextInt(condemnations.length)];
  }
}

/// Le parole da fumetto che cambiano con la lingua.
enum VerdictWord { thud, byeBye, glub, getOut, cough, toot, sniff, ping, bonk, shrug }

/// I tempi del film, da 0 a 1: li usano il pittore e la colonna sonora.
abstract final class VerdictBeats {
  static const marchFrom = 0.03;
  static const marchTo = 0.30;
  static const card = 0.86;

  // Il molo.
  static const turn = 0.315;
  static const cementDrop = 0.355;
  static const cementLands = 0.39;
  static const pierCloseUp = 0.42;
  static const wave = 0.53;
  static const poke = 0.615;
  static const teeter = 0.628;
  static const hang = 0.662;
  static const drop = 0.69;
  static const splash = 0.697;
  static const lastBubble = 0.80;

  // Il cartello.
  static const signCloseUp = 0.31;
  static const point = 0.42;
  static const leave = 0.48;
  static const road = 0.53;
  static const carIn = 0.57;
  static const carPass = 0.61;
  static const cough = 0.71;
  static const tumbleweed = 0.72;

  // Il treno.
  static const board = 0.255;
  static const doorShuts = 0.325;
  static const trainCloseUp = 0.36;
  static const whistle = 0.47;
  static const depart = 0.50;
  static const sniff = 0.62;
  static const kerchief = 0.72;

  // Il cannone.
  static const jump = 0.26;
  static const slide = 0.32;
  static const cannonCloseUp = 0.37;
  static const torch = 0.42;
  static const fuse = 0.48;
  static const boom = 0.56;
  static const ping = 0.68;
  static const shoe = 0.72;
  static const bonk = 0.785;

  // L'assoluzione.
  static const shrug = 0.46;
  static const disperse = 0.58;
  static const emptySquare = 0.70;
}

/// Quello che la piazza ha deciso, messo in scena come un film comico:
/// la folla accompagna il condannato fuori dalla partita, nel modo più
/// esagerato possibile, e si chiude sul suo ritratto.
///
/// La scena non riceve il ruolo di nessuno, e non potrebbe svelarlo: quello
/// lo dice la carta che il narratore gira dopo.
class VerdictScene extends StatefulWidget {
  /// Chi è stato condannato; nessuno, nell'assoluzione.
  final String? condemnedName;

  /// La variante ([VerdictTake.name]); senza, la sceglie la scena a caso.
  final String? variant;

  /// Il nome della città, per il cartello di fine città.
  final String town;
  final SkylineStyle style;
  final VoidCallback onFinished;

  /// Online: il film va in onda per tutti nello stesso momento, deciso dal
  /// server. [startAt] è quanto ne è già passato quando questa scena parte
  /// (chi arriva in ritardo entra a metà). Così non si salta, non c'è il
  /// pulsante per andare avanti, e [onFinished] scatta da solo alla fine.
  final Duration? startAt;

  /// I nomi delle varianti di condanna, per chi vuole sceglierne una.
  static final variants = [for (final take in VerdictTake.condemnations) take.name];

  const VerdictScene({
    super.key,
    required String this.condemnedName,
    required this.onFinished,
    this.style = SkylineStyle.metropolis,
    this.variant,
    this.town = '',
    this.startAt,
  });

  /// La piazza non condanna nessuno.
  const VerdictScene.acquittal({
    super.key,
    required this.onFinished,
    this.style = SkylineStyle.metropolis,
    this.startAt,
  })  : condemnedName = null,
        variant = null,
        town = '';

  @override
  State<VerdictScene> createState() => _VerdictSceneState();
}

class _VerdictSceneState extends State<VerdictScene> with SingleTickerProviderStateMixin {
  late final List<SceneCue> _cues = verdictCuesFor(_take, memes: SoundStage.instance.memeMode);
  int _nextCue = 0;

  late final VerdictTake _take =
      widget.condemnedName == null ? VerdictTake.assoluzione : VerdictTake.pick(widget.variant, Random());
  late final AnimationController _film;
  late final Future<ParticleSprites> _particles = ParticleSprites.shared;
  final List<Timer> _tuning = [];
  bool _struck = false;
  bool _ended = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    // Come le scene della notte: il film va in onda anche per chi riduce le
    // animazioni, perché è il racconto di quello che è successo.
    _film = AnimationController(vsync: this, duration: _take.length, animationBehavior: AnimationBehavior.preserve)
      ..addListener(() {
        if (!_struck && _film.value >= _take.payoff) {
          _struck = true;
          HapticFeedback.mediumImpact();
        }
        while (_nextCue < _cues.length && _film.value >= _cues[_nextCue].t) {
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
      final from = (startAt.inMicroseconds / _take.length.inMicroseconds).clamp(0.0, 1.0);
      while (_nextCue < _cues.length && _cues[_nextCue].t < from) {
        _nextCue++;
      }
      _struck = from >= _take.payoff;
      SoundStage.instance.duckMusic(true);
      if (startAt < const Duration(milliseconds: 700)) SoundStage.instance.playVerdict(_take);
      _film.forward(from: from);
      return;
    }

    SoundStage.instance.duckMusic(true);
    final music = SoundStage.instance.playVerdict(_take);
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

  /// Rimette il film a tempo col nastro, presto, mentre la folla cammina.
  Future<void> _tune() async {
    final heard = await SoundStage.instance.position();
    if (heard == null || !mounted || !_film.isAnimating) return;
    final film = _take.length * _film.value;
    final drift = (heard - film).abs();
    if (drift <= const Duration(milliseconds: 40) || drift >= const Duration(milliseconds: 800)) return;
    if (heard >= _take.length) return;
    _film.forward(from: heard.inMicroseconds / _take.length.inMicroseconds);
  }

  bool get _synced => widget.startAt != null;

  /// Chi salta arriva alla carta finale, e avanti si va solo col pulsante.
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
    SoundStage.instance.duckMusic(false);
    for (final timer in _tuning) {
      timer.cancel();
    }
    SoundStage.instance.stop();
    _film.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final name = widget.condemnedName;
    final hat = avatarHeadFor(name ?? '');
    final caption = strings.verdictCaption(_take);
    final town = widget.town.trim().isEmpty ? strings.townSign : widget.town.trim();
    return Stack(
      fit: StackFit.expand,
      children: [
        CityBackdrop(mood: SceneMood.dusk, style: widget.style, child: const SizedBox.expand()),
        FutureBuilder<ParticleSprites>(
          future: _particles,
          builder: (context, snapshot) => AnimatedBuilder(
            animation: _film,
            builder: (context, _) => CustomPaint(
              painter: VerdictScenePainter(
                t: _film.value,
                take: _take,
                hat: hat,
                town: town,
                strings: strings,
                sprites: snapshot.data,
              ),
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _film,
          builder: (context, _) {
            final t = _film.value;
            final typed = (caption.length * _span(t, 0.02, 0.18)).round();
            final card = _span(t, VerdictBeats.card, VerdictBeats.card + 0.07);
            return Stack(
              fit: StackFit.expand,
              children: [
                Align(
                  alignment: const Alignment(0, 0.93),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Opacity(
                      opacity: 1 - _span(t, 0.80, 0.86),
                      child: Text(
                        caption.substring(0, typed),
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
                    child: name == null ? _acquittalCard(strings) : _condemnedCard(strings, name, card),
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
                      child: ElevatedButton(onPressed: pressed(_finish, Press.confirm), child: Text(strings.next)),
                    ),
                  ),
                )
              : Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: pressed(_skip, Press.back),
                    child: Text(strings.skip, style: const TextStyle(color: AppColors.textSecondary)),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _condemnedCard(AppStrings strings, String name, double reveal) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _VerdictPortrait(name: name, stamp: strings.verdictStamp(_take), reveal: reveal),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(name.toUpperCase(), style: AppText.display(44, color: AppColors.textPrimary)),
            ),
          ),
          const SizedBox(height: 8),
          Text(strings.verdictLine, style: AppText.overline),
        ],
      );

  Widget _acquittalCard(AppStrings strings) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(strings.acquittalTitle, style: AppText.display(38, color: AppColors.textPrimary)),
              ),
              const SizedBox(height: 10),
              Text(strings.acquittalLine, textAlign: TextAlign.center, style: AppText.overline),
            ],
          ),
        ),
      );
}

/// Il ritratto del condannato sbattuto sul tavolo, col timbro di traverso.
class _VerdictPortrait extends StatelessWidget {
  final String name;
  final String stamp;
  final double reveal;

  const _VerdictPortrait({required this.name, required this.stamp, required this.reveal});

  @override
  Widget build(BuildContext context) {
    final registry = PortraitRegistry.instance;
    final landed = Curves.easeOutCubic.transform(reveal);
    return ListenableBuilder(
      listenable: registry,
      builder: (context, _) => Transform.rotate(
        angle: lerpDouble(0.55, 0.05, landed)!,
        child: Transform.scale(
          scale: lerpDouble(2.4, 1, landed)!,
          child: SizedBox(
            width: 184,
            child: MugshotFrame(name: name, photo: registry.photoOf(name), placard: false, stamp: stamp),
          ),
        ),
      ),
    );
  }
}

double _span(double t, double from, double to) => ((t - from) / (to - from)).clamp(0.0, 1.0);

double _mix(double a, double b, double t) => a + (b - a) * t;

double _smooth(double t) => Curves.easeInOut.transform(t);

/// Direzione di un arto: 0 punta in basso, pi/2 in avanti, pi in alto.
Offset _aim(double angle) => Offset(sin(angle), cos(angle));

/// Quello che uno della folla si porta dietro.
enum _Kit { none, torch, fork, kerchief, bindle }

/// Uno della folla: dove si ferma (in frazione di larghezza), quanto è alto,
/// che cappello ha, cosa porta, e un ritmo suo per non muoversi all'unisono.
class _Extra {
  final double x;
  final double scale;
  final AvatarHead hat;
  final _Kit kit;
  final double phase;

  const _Extra(this.x, this.scale, this.hat, this.kit, this.phase);

  bool get dame => hat == AvatarHead.wideBrim;

  /// Chi porta una torcia o un forcone, o ha solo il pugno, lo agita.
  bool get angry => kit == _Kit.torch || kit == _Kit.fork || (kit == _Kit.none && phase > 0.5);
}

// Le parole da fumetto uguali in tutte le lingue.
const _splashWord = 'SPLASH!';
const _vroomWord = 'VROOM!';
const _boomWord = 'BOOM!';
const _curses = ['#@!', '?!', '%&!', '!!', '@#?', '*!'];

/// Disegna un fotogramma del verdetto. [t] va da 0 a 1 lungo tutto il film.
///
/// Tutte le varianti hanno lo stesso canovaccio: la folla porta il
/// condannato sul posto, il primo piano, la battuta, e lo schermo si
/// scurisce per la carta finale. Di ruoli qui non si sa niente.
class VerdictScenePainter extends CustomPainter {
  final double t;
  final VerdictTake take;
  final ParticleSprites? sprites;

  /// Il cappello del condannato, lo stesso del suo ritratto.
  final AvatarHead hat;

  /// Il nome sul cartello di fine città.
  final String town;
  final AppStrings strings;

  VerdictScenePainter({
    required this.t,
    required this.take,
    required this.strings,
    this.hat = AvatarHead.fedora,
    this.town = '',
    this.sprites,
  });

  static const _ink = Color(0xFF050506);
  static const _rim = Color(0xFF7A5A34);
  static const _warm = Color(0xFFFFD27A);
  static const _steel = Color(0xFFD5DAE0);
  static const _cloth = Color(0xFFF2EEE6);
  static const _cement = Color(0xFF9C978E);
  static const _red = Color(0xFFB3202A);

  late double _w;
  late double _h;
  late double _u;

  @override
  void paint(Canvas canvas, Size size) {
    _w = size.width;
    _h = size.height;
    _u = min(_h * 0.21, _w * 0.38);

    canvas.save();
    final quake = take == VerdictTake.cannone ? _span(t, VerdictBeats.boom, VerdictBeats.boom + 0.06) : 0.0;
    if (quake > 0 && quake < 1) {
      final force = (1 - quake) * _u * 0.07;
      canvas.translate(sin(t * 900) * force, cos(t * 760) * force);
    }
    switch (take) {
      case VerdictTake.molo:
        _pier(canvas);
      case VerdictTake.cartello:
        _townLine(canvas);
      case VerdictTake.treno:
        _station(canvas);
      case VerdictTake.cannone:
        _circus(canvas);
      case VerdictTake.assoluzione:
        _square(canvas);
    }
    canvas.restore();

    final rect = Offset.zero & size;
    final close = _span(t, 0.82, 0.92);
    if (close > 0) canvas.drawRect(rect, Paint()..color = const Color(0xFF07060A).withValues(alpha: close * 0.84));
    // Le bande nere del cinema.
    final bar = _h * 0.105 * Curves.easeOut.transform(_span(t, 0, 0.05));
    final black = Paint()..color = Colors.black;
    canvas.drawRect(Rect.fromLTWH(0, 0, _w, bar), black);
    canvas.drawRect(Rect.fromLTWH(0, _h - bar * 1.5, _w, bar * 1.5), black);
  }

  // ------------------------------------------------------------------ la folla

  /// Dove sta, a che punto del passo, e quanto è lungo il passo di chi
  /// arriva in marcia fino a [end].
  ///
  /// Il passo si accorcia mentre la marcia rallenta, e la fase del passo è
  /// l'integrale della strada fatta diviso la lunghezza del passo: il piede
  /// che appoggia resta piantato a terra, senza pattinare. [lag] ritarda
  /// l'arrivo di uno della folla; [until] anticipa quello del condannato.
  (double, double, double) _marchTo(double end, double h, {double lag = 0, double? until}) {
    final distance = _w * 0.95;
    final p = _span(t, VerdictBeats.marchFrom + lag, (until ?? VerdictBeats.marchTo) + lag);
    final eased = 1 - pow(1 - p, 1.6).toDouble();
    final x = end - distance * (1 - eased);
    final stride = pow(1 - p, 0.35).toDouble();
    // ∫ dx / stride, con dx = 1.6 (1-p)^0.6 dp e stride = (1-p)^0.35.
    final travelled = distance * 1.28 * (1 - pow(1 - p, 1.25).toDouble());
    return (x, 2 * pi * travelled / (0.84 * h), stride);
  }

  /// Nelle condanne la folla sta un passo indietro e un palmo più bassa: il
  /// condannato deve spiccare a colpo d'occhio.
  double get _extraSize => take.condemns ? 0.80 : 1.0;

  /// L'occhio di bue sul condannato, finché resta in scena.
  void _spotlight(Canvas canvas, double x, double ground, double strength) {
    if (strength <= 0) return;
    canvas.drawPath(
      Path()
        ..moveTo(x - _u * 0.10, _h * 0.10)
        ..lineTo(x + _u * 0.10, _h * 0.10)
        ..lineTo(x + _u * 0.55, ground)
        ..lineTo(x - _u * 0.55, ground)
        ..close(),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_warm.withValues(alpha: 0.02 * strength), _warm.withValues(alpha: 0.20 * strength)],
        ).createShader(Rect.fromLTRB(0, _h * 0.10, _w, ground)),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, ground + _u * 0.01), width: _u * 1.2, height: _u * 0.12),
      Paint()
        ..color = _warm.withValues(alpha: 0.28 * strength)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, _u * 0.05),
    );
  }

  /// Chi è in fondo arriva un passo dopo: la folla non marcia come un plotone.
  double _lagOf(_Extra e) => 0.012 + 0.018 * ((e.phase * 7) % 1);

  /// Chi sta fermo respira e sposta il peso: un dondolio lento, a ritmo suo.
  double _idle(_Extra e, double stride) => 0.022 * (1 - stride) * sin(t * 19 + e.phase * 9);

  /// Il braccio di chi protesta: su e giù, a ritmo suo.
  double _shake(_Extra e) => 2.7 + 0.22 * sin(t * 55 + e.phase * 7);

  /// La folla che marcia e poi resta lì. [pose] cambia il gesto di ognuno.
  void _crowd(
    Canvas canvas,
    List<_Extra> crowd,
    double ground, {
    double Function(int i, _Extra e)? arm,
    double Function(int i, _Extra e)? elbow,
    double Function(int i, _Extra e)? lean,
    _Kit Function(int i, _Extra e)? kit,
    double Function(int i, _Extra e)? backArm,
    double Function(int i, _Extra e)? backElbow,
  }) {
    for (final (i, e) in crowd.indexed) {
      final h = _u * e.scale * _extraSize;
      final (x, walk, stride) = _marchTo(_w * e.x, h, lag: _lagOf(e));
      final raised = e.angry || e.kit == _Kit.torch;
      _person(
        canvas,
        feet: Offset(x, ground),
        h: h,
        walk: walk + e.phase * 3,
        stride: stride,
        lean: (lean?.call(i, e) ?? 0) + _idle(e, stride),
        arm: arm?.call(i, e) ?? (raised ? _shake(e) : 0.08),
        elbow: elbow?.call(i, e) ?? (raised ? 0.3 : 0.2),
        backArm: backArm?.call(i, e) ?? -0.10,
        backElbow: backElbow?.call(i, e) ?? 0.2,
        hat: e.hat,
        dame: e.dame,
        kit: kit?.call(i, e) ?? e.kit,
      );
    }
  }

  // ----------------------------------------------------------------- il molo

  static const _pierCrowd = [
    _Extra(0.07, 0.94, AvatarHead.fedora, _Kit.torch, 0.1),
    _Extra(0.20, 1.00, AvatarHead.bowler, _Kit.none, 0.8),
    _Extra(0.32, 0.90, AvatarHead.wideBrim, _Kit.kerchief, 0.3),
    _Extra(0.44, 1.03, AvatarHead.coppola, _Kit.fork, 0.6),
  ];

  void _pier(Canvas canvas) {
    final deck = _h * 0.74;
    final surface = deck + _u * 0.14;
    final edge = _w * 0.76;
    final standX = edge - _u * 0.10;
    final dropX = edge + _u * 0.24;

    _sea(canvas, top: _h * 0.69, surface: surface);
    // Gli anelli sull'acqua, dopo il tuffo.
    for (var i = 0; i < 3; i++) {
      final ring = _span(t, VerdictBeats.splash + 0.02 + i * 0.04, VerdictBeats.splash + 0.20 + i * 0.04);
      if (ring <= 0 || ring >= 1) continue;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(dropX, surface + _u * 0.02), width: _u * (0.3 + 1.6 * ring), height: _u * (0.05 + 0.12 * ring)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _u * 0.012
          ..color = const Color(0xFFBFE3FF).withValues(alpha: 0.6 * (1 - ring)),
      );
    }
    _jetty(canvas, deck, edge);
    _spotlight(canvas, _marchTo(standX, _u).$1, deck, 1 - _span(t, VerdictBeats.hang, VerdictBeats.splash + 0.04));

    // Il secchio di cemento: prima l'ombra che si allarga sulle assi, poi il
    // colpo, che fa tremare il pontile.
    final fall = Curves.easeIn.transform(_span(t, VerdictBeats.cementDrop, VerdictBeats.cementLands));
    final shod = t >= VerdictBeats.cementLands;
    final jolt = _span(t, VerdictBeats.cementLands, VerdictBeats.cementLands + 0.025);
    final shake = jolt > 0 && jolt < 1 ? sin(jolt * pi * 6) * (1 - jolt) * _u * 0.025 : 0.0;
    canvas.save();
    canvas.translate(0, shake);

    // La folla: chi spinge sta attaccato al condannato, gli altri dietro.
    final waving = _span(t, VerdictBeats.wave, VerdictBeats.wave + 0.02) * (1 - _span(t, VerdictBeats.poke - 0.03, VerdictBeats.poke - 0.02));
    final peering = _smooth(_span(t, 0.70, 0.75));
    _crowd(
      canvas,
      _pierCrowd,
      deck,
      arm: (i, e) => waving > 0 && !e.angry ? _mix(0.08, 2.6, waving) : (e.angry || e.kit == _Kit.torch ? _shake(e) : 0.08),
      elbow: (i, e) => waving > 0 && !e.angry ? 0.5 + 0.5 * sin(t * 150 + i) : (e.angry ? 0.3 : 0.2),
      lean: (i, e) => 0.12 * peering,
    );

    // Chi spinge: carica il braccio all'indietro, poi la spinta secca, tiene
    // il braccio teso un attimo, e torna a guardare giù.
    final pushH = _u * 0.86;
    final pushEnd = standX - _u * 0.36;
    final (pushX, pushWalk, pushStride) = _marchTo(pushEnd, pushH);
    final windUp = _smooth(_span(t, VerdictBeats.poke - 0.022, VerdictBeats.poke - 0.002));
    final jab = Curves.easeOutBack.transform(_span(t, VerdictBeats.poke - 0.002, VerdictBeats.poke + 0.006));
    final recover = _smooth(_span(t, VerdictBeats.poke + 0.03, VerdictBeats.poke + 0.05));
    final thrust = jab * (1 - recover);
    final cocked = windUp * (1 - jab);
    final marching = t < VerdictBeats.marchTo;
    _person(
      canvas,
      feet: Offset(pushX + thrust * _u * 0.10 - cocked * _u * 0.03, deck),
      h: pushH,
      walk: pushWalk,
      stride: pushStride,
      lean: marching ? 0.18 * pushStride : -0.14 * cocked + 0.16 * thrust + 0.12 * peering + 0.12 * (1 - pushStride) * (marching ? 1 : 0),
      crouch: 0.15 * cocked,
      arm: marching
          ? 1.45
          : (cocked > 0 || thrust > 0
              ? _mix(_mix(0.1, 0.5, cocked), pi / 2, thrust)
              : (waving > 0 ? _mix(0.08, 2.6, waving) : 0.1)),
      elbow: marching ? 0.1 : (cocked > 0 || thrust > 0 ? _mix(_mix(0.2, 1.9, cocked), 0.0, thrust) : (waving > 0 ? 0.5 + 0.5 * sin(t * 150) : 0.2)),
      backArm: marching ? 1.30 : -0.1 - 0.5 * thrust,
      backElbow: marching ? 0.15 : 0.2,
      hat: AvatarHead.fedora,
    );

    if (fall > 0 && !shod) {
      // L'ombra sulle assi cresce mentre il secchio scende.
      canvas.drawOval(
        Rect.fromCenter(center: Offset(standX + _u * 0.02, deck + _u * 0.005), width: _u * 0.42 * (0.3 + 0.7 * fall), height: _u * 0.05 * (0.3 + 0.7 * fall)),
        Paint()..color = Colors.black.withValues(alpha: 0.55 * fall),
      );
      final at = Offset(standX + _u * 0.02, _mix(-_u * 0.4, deck, fall));
      // Le righe della caduta, sopra al secchio.
      final lines = Paint()
        ..color = Colors.white.withValues(alpha: 0.45)
        ..strokeWidth = max(1, _u * 0.010)
        ..strokeCap = StrokeCap.round;
      for (final dx in const [-0.10, 0.0, 0.10]) {
        canvas.drawLine(at.translate(_u * dx, -_u * 0.26), at.translate(_u * dx, -_u * (0.26 + 0.35 * fall)), lines);
      }
      _cementBlock(canvas, at, _u);
    }

    // Il condannato. Al colpo del cemento si piega sulle ginocchia e rimbalza.
    final (walkX, walk, stride) = _marchTo(standX, _u);
    final turned = t >= VerdictBeats.turn;
    final landing = _span(t, VerdictBeats.cementLands, VerdictBeats.cementLands + 0.06);
    final buckle = landing > 0 && landing < 1 ? 0.45 * (1 - landing) * cos(landing * pi * 2.5).abs() : 0.0;
    final wave = waving;
    // La spinta gli arriva nella schiena: un sobbalzo in avanti, poi ruota le
    // braccia sull'orlo, poi resta sospeso nel vuoto il tempo di capirlo.
    final hit = _span(t, VerdictBeats.poke + 0.004, VerdictBeats.poke + 0.02);
    final teeter = _span(t, VerdictBeats.teeter, VerdictBeats.hang);
    final step = _smooth(_span(t, VerdictBeats.hang - 0.012, VerdictBeats.hang));
    final drop = Curves.easeIn.transform(_span(t, VerdictBeats.drop, VerdictBeats.drop + 0.025));
    final overboard = t >= VerdictBeats.hang;
    final hanging = overboard && drop <= 0;
    final windmill = teeter > 0 && !overboard;
    final feetX = turned ? _mix(standX, dropX, step) : walkX;
    final feetY = deck + drop * (surface - deck + _u * 1.4);
    final jerk = hit > 0 && hit < 1 ? sin(pi * hit) : 0.0;
    final gulp = hanging ? _span(t, VerdictBeats.hang, VerdictBeats.hang + 0.012) : 0.0;

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(-_w, -_h, _w * 2, t >= VerdictBeats.drop ? surface : _h * 2));
    _person(
      canvas,
      feet: Offset(feetX, feetY),
      h: _u,
      facing: turned ? -1 : 1,
      walk: walk,
      stride: turned ? 0 : stride,
      lean: turned ? (windmill ? 0.10 * sin(t * 140) - 0.25 * jerk : -0.25 * jerk) - 0.10 * drop : -0.12 * stride,
      tilt: windmill ? (0.10 * sin(t * 120) + 0.10 * teeter) : (hanging ? 0.04 * sin(t * 60) : 0),
      crouch: buckle + 0.12 * jerk,
      arm: windmill
          ? 2.2 + 1.4 * sin(t * 150)
          : hanging || drop > 0
              ? _mix(2.9, 3.05, gulp)
              : (wave > 0 ? _mix(0.08, 2.7, wave) : (jerk > 0 ? 0.08 + 1.2 * jerk : 0.08)),
      elbow: windmill ? 0.4 : (hanging ? 0.15 : (wave > 0 ? 0.4 + 0.6 * sin(t * 170) : 0.2)),
      backArm: windmill ? 2.2 + 1.4 * sin(t * 150 + pi) : (hanging || drop > 0 ? 2.7 : -0.1 - 0.8 * jerk),
      hat: hat,
      hatOn: !overboard,
      cement: shod,
    );
    canvas.restore();

    // Una goccia di sudore, mentre sta sospeso.
    if (hanging) {
      final sweat = Offset(dropX + _u * 0.12, deck - _u * (1.02 - 0.10 * gulp));
      canvas.drawPath(
        Path()
          ..moveTo(sweat.dx, sweat.dy - _u * 0.05)
          ..quadraticBezierTo(sweat.dx + _u * 0.03, sweat.dy, sweat.dx, sweat.dy + _u * 0.015)
          ..quadraticBezierTo(sweat.dx - _u * 0.03, sweat.dy, sweat.dx, sweat.dy - _u * 0.05),
        Paint()..color = const Color(0xFFBFE3FF),
      );
    }

    // Il cemento che arriva: la polvere grigia e qualche schizzo sulle assi.
    _puff(canvas, Offset(standX - _u * 0.10, deck - _u * 0.06), _span(t, VerdictBeats.cementLands, VerdictBeats.cementLands + 0.10), size: 0.6, color: const Color(0xFFC9C3B8));
    _puff(canvas, Offset(standX + _u * 0.18, deck - _u * 0.05), _span(t, VerdictBeats.cementLands + 0.004, VerdictBeats.cementLands + 0.11), size: 0.55, color: const Color(0xFFC9C3B8));
    _spray(canvas, Offset(standX + _u * 0.02, deck - _u * 0.14), _span(t, VerdictBeats.cementLands, VerdictBeats.cementLands + 0.05),
        seed: 11, color: _cement, count: 10, bias: const Offset(0, -0.8), reach: 0.45);
    canvas.restore();

    // Il cappello resta un attimo per aria, poi si posa sull'acqua e galleggia.
    if (overboard) {
      final pop = sin(pi * _span(t, VerdictBeats.drop, VerdictBeats.drop + 0.03)) * _u * 0.14;
      final settle = Curves.easeIn.transform(_span(t, VerdictBeats.splash + 0.02, VerdictBeats.splash + 0.05));
      final bob = settle >= 1 ? sin(t * 40) * _u * 0.015 : 0.0;
      final drift = _u * 0.25 * _span(t, VerdictBeats.splash + 0.05, 1);
      _looseHat(
        canvas,
        Offset(dropX + drift, _mix(deck - _u * 1.03 - pop, surface - _u * 0.01, settle) + bob),
        settle >= 1 ? 0.08 * sin(t * 30) : 0.3 * settle - 0.2 * pop / _u,
      );
    }

    // Lo spruzzo: la colonna, la corona, le gocce, la schiuma; poi le bolle.
    final splash = _span(t, VerdictBeats.splash, VerdictBeats.splash + 0.09);
    if (splash > 0 && splash < 1) _crown(canvas, Offset(dropX, surface), splash);
    _spray(canvas, Offset(dropX, surface - _u * 0.05), _span(t, VerdictBeats.splash, VerdictBeats.splash + 0.11),
        seed: 5, color: const Color(0xFFD9EEFF), count: 30, bias: const Offset(0, -1.6), reach: 1.25);
    _spray(canvas, Offset(dropX, surface - _u * 0.05), _span(t, VerdictBeats.splash + 0.012, VerdictBeats.splash + 0.10),
        seed: 6, color: Colors.white, count: 14, bias: const Offset(0, -1.1), reach: 0.8);
    final foam = _span(t, VerdictBeats.splash + 0.03, VerdictBeats.splash + 0.16);
    if (foam > 0 && foam < 1) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(dropX, surface + _u * 0.015), width: _u * (0.55 + 0.4 * foam), height: _u * 0.07),
        Paint()..color = Colors.white.withValues(alpha: 0.55 * (1 - foam)),
      );
    }
    for (var i = 0; i < 7; i++) {
      final from = 0.72 + i * 0.012;
      final rise = _span(t, from, from + 0.05);
      if (rise <= 0 || rise >= 1) continue;
      _bubble(canvas, Offset(dropX + sin(i * 2.3 + t * 40) * _u * 0.06, _mix(surface + _u * 0.55, surface, rise)), _u * (0.025 + 0.012 * (i % 3)));
    }
    final last = _span(t, VerdictBeats.lastBubble - 0.03, VerdictBeats.lastBubble);
    if (last > 0 && last < 1) _bubble(canvas, Offset(dropX, _mix(surface + _u * 0.5, surface, last)), _u * 0.075);

    final head = Offset(standX, deck - _u * 1.35);
    _word(canvas, strings.verdictWord(VerdictWord.thud), VerdictBeats.cementLands, 0.08, Offset(standX - _u * 0.1, deck - _u * 0.45), size: 0.26);
    _word(canvas, strings.verdictWord(VerdictWord.byeBye), VerdictBeats.wave + 0.01, 0.08, head.translate(-_u * 0.35, 0));
    _word(canvas, _splashWord, VerdictBeats.splash, 0.11, Offset(_w * 0.64, deck - _u * 1.2));
    _word(canvas, strings.verdictWord(VerdictWord.glub), VerdictBeats.lastBubble, 0.06, Offset(dropX - _u * 0.15, surface - _u * 0.35), size: 0.22);
  }

  void _sea(Canvas canvas, {required double top, required double surface}) {
    final water = Rect.fromLTRB(-_w, top, _w * 2, _h * 1.3);
    canvas.drawRect(
      water,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4A2634), Color(0xFF1A1724), Color(0xFF07090F)],
          stops: [0, 0.35, 1],
        ).createShader(Rect.fromLTRB(0, top, _w, _h)),
    );
    // I riflessi del tramonto, che tremano.
    final rng = Random(3);
    for (var i = 0; i < 26; i++) {
      final y = top + (surface - top + _u * 0.6) * pow(rng.nextDouble(), 1.4);
      final x = rng.nextDouble() * _w;
      final len = _u * (0.08 + rng.nextDouble() * 0.25);
      final shimmer = 0.5 + 0.5 * sin(t * 30 + i * 1.7);
      canvas.drawLine(
        Offset(x, y),
        Offset(x + len, y),
        Paint()
          ..color = const Color(0xFFFF9A55).withValues(alpha: 0.10 + 0.22 * shimmer)
          ..strokeWidth = max(1, _u * 0.010),
      );
    }
  }

  /// Il pontile di legno: le assi, la trave di testa, i pali con le
  /// crociere che entrano nell'acqua, e il palo d'ormeggio in punta.
  void _jetty(Canvas canvas, double deck, double edge) {
    final wood = Paint()..color = const Color(0xFF1C140F);
    final beam = Paint()
      ..color = const Color(0xFF15100C)
      ..strokeWidth = max(1, _u * 0.025);
    final piles = <double>[for (var x = edge - _u * 0.05; x > -_u; x -= _u * 0.55) x];
    for (final (i, x) in piles.indexed) {
      canvas.drawRect(Rect.fromLTWH(x - _u * 0.04, deck, _u * 0.08, _h), wood);
      if (i + 1 < piles.length) {
        final next = piles[i + 1];
        canvas.drawLine(Offset(x, deck + _u * 0.08), Offset(next, deck + _u * 0.30), beam);
        canvas.drawLine(Offset(next, deck + _u * 0.08), Offset(x, deck + _u * 0.30), beam);
      }
    }
    // La trave di testa, con le teste delle assi segnate.
    canvas.drawRect(Rect.fromLTRB(-_w, deck, edge, deck + _u * 0.08), Paint()..color = const Color(0xFF2E2118));
    final seam = Paint()
      ..color = const Color(0xFF120C08)
      ..strokeWidth = max(1, _u * 0.008);
    for (var x = edge - _u * 0.12; x > -_u; x -= _u * 0.12) {
      canvas.drawLine(Offset(x, deck + _u * 0.012), Offset(x, deck + _u * 0.08), seam);
    }
    canvas.drawRect(Rect.fromLTRB(-_w, deck, edge, deck + _u * 0.014), Paint()..color = _rim);
    // Il palo d'ormeggio in punta, più alto delle assi: dice dove finisce.
    final post = Rect.fromLTRB(edge - _u * 0.05, deck - _u * 0.20, edge + _u * 0.03, _h);
    canvas.drawRRect(RRect.fromRectAndCorners(post, topLeft: Radius.circular(_u * 0.03), topRight: Radius.circular(_u * 0.03)), wood);
    canvas.drawRect(Rect.fromLTRB(post.left, post.top + _u * 0.04, post.right, post.top + _u * 0.06), Paint()..color = _rim);
    // La bitta, con la cima arrotolata che pende.
    final bollard = Offset(edge - _u * 0.62, deck);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: bollard.translate(0, -_u * 0.06), width: _u * 0.10, height: _u * 0.12), Radius.circular(_u * 0.03)),
      Paint()..color = _ink,
    );
    canvas.drawPath(
      Path()
        ..moveTo(bollard.dx + _u * 0.04, deck - _u * 0.07)
        ..quadraticBezierTo(bollard.dx + _u * 0.16, deck + _u * 0.06, bollard.dx + _u * 0.10, deck + _u * 0.20),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1, _u * 0.018)
        ..color = const Color(0xFF8A7458),
    );
  }

  /// Il secchio di cemento: un mastello di latta col bordo ribattuto, il
  /// cemento grigio che fa la gobba e cola giù dai lati.
  void _cementBlock(Canvas canvas, Offset bottom, double h) {
    final top = bottom.dy - h * 0.17;
    final tub = Path()
      ..moveTo(bottom.dx - h * 0.17, top)
      ..lineTo(bottom.dx + h * 0.19, top)
      ..lineTo(bottom.dx + h * 0.155, bottom.dy)
      ..lineTo(bottom.dx - h * 0.135, bottom.dy)
      ..close();
    canvas.drawPath(tub, Paint()..color = const Color(0xFF5E636B));
    canvas.drawPath(
      tub,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1, h * 0.012)
        ..color = _ink,
    );
    final hoop = Paint()
      ..color = const Color(0xFF3A3E44)
      ..strokeWidth = max(1, h * 0.016);
    canvas.drawLine(Offset(bottom.dx - h * 0.155, top + h * 0.06), Offset(bottom.dx + h * 0.177, top + h * 0.06), hoop);
    canvas.drawLine(Offset(bottom.dx - h * 0.143, bottom.dy - h * 0.035), Offset(bottom.dx + h * 0.163, bottom.dy - h * 0.035), hoop);
    // La luce del tramonto sulla latta.
    canvas.drawLine(
      Offset(bottom.dx + h * 0.15, top + h * 0.02),
      Offset(bottom.dx + h * 0.125, bottom.dy - h * 0.01),
      Paint()
        ..color = _warm.withValues(alpha: 0.45)
        ..strokeWidth = max(1, h * 0.012),
    );
    // Il cemento: la gobba sopra e due colate.
    final cement = Paint()..color = _cement;
    canvas.drawPath(
      Path()
        ..moveTo(bottom.dx - h * 0.185, top + h * 0.012)
        ..quadraticBezierTo(bottom.dx, top - h * 0.07, bottom.dx + h * 0.205, top + h * 0.012)
        ..close(),
      cement,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bottom.dx - h * 0.10, top, h * 0.035, h * 0.075), Radius.circular(h * 0.018)), cement);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bottom.dx + h * 0.08, top, h * 0.03, h * 0.045), Radius.circular(h * 0.015)), cement);
    canvas.drawLine(
      Offset(bottom.dx - h * 0.18, top + h * 0.006),
      Offset(bottom.dx + h * 0.20, top + h * 0.006),
      Paint()
        ..color = const Color(0xFF2B2E33)
        ..strokeWidth = max(1, h * 0.014),
    );
  }

  /// Il tuffo: una colonna d'acqua che sale e ricade, con intorno la corona
  /// a punte che si apre. [life] va da 0 a 1.
  void _crown(Canvas canvas, Offset at, double life) {
    final rise = sin(pi * min(1.0, life * 1.15));
    final open = Curves.easeOut.transform(life);
    final water = Paint()..color = const Color(0xFFD9EEFF).withValues(alpha: 0.9 * (1 - _span(life, 0.7, 1)));
    // La colonna in mezzo, più alta, con la testa che si gonfia.
    final column = _u * 0.95 * rise;
    if (column > 1) {
      canvas.drawPath(
        Path()
          ..moveTo(at.dx - _u * 0.10, at.dy)
          ..quadraticBezierTo(at.dx - _u * 0.04, at.dy - column * 0.6, at.dx - _u * 0.05, at.dy - column)
          ..quadraticBezierTo(at.dx, at.dy - column - _u * 0.07, at.dx + _u * 0.05, at.dy - column)
          ..quadraticBezierTo(at.dx + _u * 0.04, at.dy - column * 0.6, at.dx + _u * 0.10, at.dy)
          ..close(),
        water,
      );
      canvas.drawCircle(Offset(at.dx, at.dy - column - _u * 0.02), _u * 0.06 * rise, water);
    }
    // La corona: punte curve che si aprono verso fuori, con la goccia in cima.
    for (var i = 0; i < 10; i++) {
      final side = i < 5 ? -1.0 : 1.0;
      final k = (i % 5) / 4;
      final base = at.dx + side * _u * (0.12 + 0.30 * k) * (0.6 + 0.6 * open);
      final tall = _u * (0.55 - 0.32 * k + 0.08 * sin(i * 2.1)) * rise;
      if (tall < 1) continue;
      final tip = Offset(base + side * _u * (0.10 + 0.12 * k) * open, at.dy - tall);
      canvas.drawPath(
        Path()
          ..moveTo(base - _u * 0.05, at.dy)
          ..quadraticBezierTo(base, at.dy - tall * 0.5, tip.dx, tip.dy)
          ..quadraticBezierTo(base + side * _u * 0.02, at.dy - tall * 0.4, base + _u * 0.05, at.dy)
          ..close(),
        water,
      );
      canvas.drawCircle(tip.translate(side * _u * 0.02, -_u * 0.03 * open), _u * 0.022, water);
    }
    canvas.drawOval(Rect.fromCenter(center: at, width: _u * (0.7 + 0.5 * open), height: _u * 0.08), water);
  }
  void _bubble(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1, radius * 0.25)
        ..color = const Color(0xFFBFE3FF).withValues(alpha: 0.85),
    );
    canvas.drawCircle(center.translate(-radius * 0.35, -radius * 0.35), radius * 0.22, Paint()..color = Colors.white.withValues(alpha: 0.8));
  }

  // ------------------------------------------------------------- il cartello

  static const _signCrowd = [
    _Extra(0.05, 0.92, AvatarHead.bowler, _Kit.fork, 0.2),
    _Extra(0.16, 1.00, AvatarHead.fedora, _Kit.torch, 0.7),
    _Extra(0.27, 0.90, AvatarHead.wideBrim, _Kit.none, 0.4),
    _Extra(0.38, 1.02, AvatarHead.coppola, _Kit.none, 0.9),
  ];

  void _townLine(Canvas canvas) {
    final horizon = _h * 0.675;
    final near = _h * 0.80;
    final vanish = Offset(_w * 0.80, horizon);

    _country(canvas, horizon, vanish);
    final signX = _w * 0.60;
    _endSign(canvas, Offset(signX, near - _u * 0.02));
    final lit = 1 - _span(t, VerdictBeats.leave, VerdictBeats.road);
    _spotlight(canvas, _marchTo(signX - _u * 0.55, _u).$1, near, lit);

    final pointing = _smooth(_span(t, VerdictBeats.point, VerdictBeats.point + 0.03)) * (1 - _smooth(_span(t, 0.60, 0.63)));
    final bye = _span(t, 0.74, 0.76);
    _crowd(
      canvas,
      _signCrowd,
      near,
      arm: (i, e) {
        if (i == 3 && pointing > 0) return _mix(0.08, pi / 2, pointing);
        if (bye > 0 && !e.angry) return _mix(0.08, 2.6, bye);
        return e.angry || e.kit == _Kit.torch ? _shake(e) : 0.08;
      },
      elbow: (i, e) {
        if (i == 3 && pointing > 0) return 0.0;
        if (bye > 0 && !e.angry) return 0.5 + 0.5 * sin(t * 150 + i);
        return e.angry ? 0.3 : 0.2;
      },
    );

    // Il condannato: si ferma accanto al cartello, al dito puntato fa un
    // passo indietro e si affloscia, lo passa, e si incammina verso
    // l'orizzonte. Al clacson si gira col pollice alzato: l'auto non si
    // ferma, resta la polvere, tossisce, e riparte, sempre più piccolo.
    final stop = signX - _u * 0.55;
    final (walkX, walk, stride) = _marchTo(stop, _u);
    final pass = _smooth(_span(t, VerdictBeats.leave, VerdictBeats.road));
    final roadStart = Offset(_w * 0.76, near);
    final hitchFrom = VerdictBeats.carIn - 0.012;
    final going = _span(t, VerdictBeats.road, hitchFrom) * 0.14 + _smooth(_span(t, VerdictBeats.cough + 0.03, 0.90)) * 0.86;
    final z = 1 + 9 * going;
    final where = vanish + (roadStart - vanish) / z;
    final onRoad = t >= VerdictBeats.road;
    final x = onRoad ? where.dx : (t < VerdictBeats.leave ? walkX : _mix(stop, roadStart.dx, pass));
    final y = onRoad ? where.dy : near;
    final strolling = (pass > 0 && pass < 1) || (onRoad && t < hitchFrom) || (t > VerdictBeats.cough + 0.03 && going < 1);
    // La fase del passo segue la strada fatta: i piedi non pattinano.
    final steps = t < VerdictBeats.leave
        ? walk
        : 2 * pi * (roadStart.dx - stop) * pass / (0.84 * _u * 0.7) + 2 * pi * 2.0 * log(z);
    final flinch = sin(pi * _span(t, VerdictBeats.point, VerdictBeats.point + 0.025));
    final slump = _smooth(_span(t, VerdictBeats.point + 0.02, VerdictBeats.point + 0.04));
    final hitch = _smooth(_span(t, hitchFrom, hitchFrom + 0.012)) * (1 - _smooth(_span(t, VerdictBeats.carPass + 0.008, VerdictBeats.carPass + 0.022)));
    final dusty = t > VerdictBeats.carPass + 0.008 && t < VerdictBeats.cough + 0.03;
    final hack = dusty ? _span(t, VerdictBeats.carPass + 0.008, VerdictBeats.cough + 0.03) : 0.0;
    _person(
      canvas,
      feet: Offset(x - flinch * _u * 0.04, y),
      h: _u / z,
      walk: steps,
      stride: t < VerdictBeats.marchTo ? stride : (strolling ? 0.7 : 0),
      lean: dusty
          ? 0.18 + 0.10 * sin(hack * pi * 9).abs()
          : (t > VerdictBeats.leave ? 0.10 : -0.08 - 0.12 * flinch + 0.14 * slump) - 0.12 * hitch,
      crouch: dusty ? 0.15 : 0,
      arm: dusty ? _mix(2.4, 2.0, sin(hack * pi * 9).abs()) : 2.4,
      elbow: 1.6,
      backArm: hitch > 0 ? _mix(-0.10, -1.75, hitch) : (dusty ? 1.2 : -0.10),
      backElbow: hitch > 0 ? _mix(0.2, -0.35, hitch) : (dusty ? 1.9 : 0.2),
      hat: hat,
      kit: _Kit.bindle,
    );

    // L'auto passa, non si ferma, e si lascia dietro una scia di polvere.
    final drive = _span(t, VerdictBeats.carIn, VerdictBeats.carIn + 0.10);
    double carFront(double d) => _mix(-_w * 0.3, _w * 2.4, d);
    const carScale = 0.8;
    final carY = near + _h * 0.035;
    for (var i = 0; i < 12; i++) {
      final born = VerdictBeats.carIn + 0.007 * i;
      final rear = carFront(_span(born, VerdictBeats.carIn, VerdictBeats.carIn + 0.10)) - _u * 2.0 * carScale;
      if (rear < -_w * 0.2 || rear > _w * 1.2) continue;
      final life = _span(t, born, born + 0.16);
      _puff(canvas, Offset(rear - life * _u * 0.3, carY - _u * (0.12 + 0.35 * life)), life, size: 0.7 + 0.9 * life, color: const Color(0xFFB0916C));
    }
    if (drive > 0 && drive < 1) _sedan(canvas, carFront(drive), carY, carScale);
    _puff(canvas, where.translate(0, -_u * 0.3 / z), _span(t, VerdictBeats.carPass + 0.01, VerdictBeats.cough + 0.05), size: 1.1, color: const Color(0xFFB0916C));

    final weed = _span(t, VerdictBeats.tumbleweed, VerdictBeats.tumbleweed + 0.14);
    if (weed > 0 && weed < 1) {
      _tumbleweed(canvas, Offset(_mix(-_w * 0.2, _w * 1.2, weed), near - _u * 0.14 - (sin(weed * pi * 5)).abs() * _u * 0.28), weed * 22);
    }

    _word(canvas, strings.verdictWord(VerdictWord.getOut), VerdictBeats.point + 0.01, 0.09, Offset(_w * 0.42, near - _u * 1.45));
    _word(canvas, _vroomWord, VerdictBeats.carPass - 0.02, 0.08, Offset(_w * 0.50, near - _u * 1.25));
    _word(canvas, strings.verdictWord(VerdictWord.cough), VerdictBeats.cough, 0.07, where.translate(-_u * 0.1, -_u * 0.75), size: 0.22);
  }

  void _country(Canvas canvas, double horizon, Offset vanish) {
    canvas.drawRect(
      Rect.fromLTRB(-_w, horizon, _w * 2, _h * 1.3),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF5A3A2A), Color(0xFF2A1A13), Color(0xFF0E0907)],
        ).createShader(Rect.fromLTRB(0, horizon, _w, _h)),
    );
    // La strada sterrata, più scura della campagna, che si stringe fino
    // all'orizzonte; la riga in mezzo dice da che parte va.
    final left = Offset(-_w * 0.25, _h);
    final right = Offset(_w * 1.65, _h);
    canvas.drawPath(
      Path()
        ..moveTo(left.dx, left.dy)
        ..lineTo(vanish.dx - 1, horizon)
        ..lineTo(vanish.dx + 1, horizon)
        ..lineTo(right.dx, right.dy)
        ..close(),
      Paint()..color = const Color(0xFF1E1511),
    );
    final verge = Paint()
      ..color = const Color(0xFF8A6A4A).withValues(alpha: 0.6)
      ..strokeWidth = max(1, _u * 0.012);
    canvas.drawLine(left, vanish, verge);
    canvas.drawLine(right, vanish, verge);
    final middle = Offset(_w * 0.70, _h);
    final dash = Paint()..color = const Color(0xFFE9E4D8).withValues(alpha: 0.55);
    for (var z = 1.0; z < 12; z *= 1.45) {
      final a = vanish + (middle - vanish) / z;
      final b = vanish + (middle - vanish) / (z * 1.2);
      dash.strokeWidth = max(1, _u * 0.03 / z);
      canvas.drawLine(a, b, dash);
    }
    // I pali del telegrafo, coi fili, che si perdono lungo la strada.
    final pole = Paint()
      ..color = _ink
      ..strokeCap = StrokeCap.round;
    final base = Offset(_w * 1.20, _h * 0.80);
    final wire = Path();
    for (final (i, z) in [1.2, 1.9, 3.0, 4.8, 7.5].indexed) {
      final foot = vanish + (base - vanish) / z;
      final tall = _u * 1.8 / z;
      pole.strokeWidth = max(1, _u * 0.045 / z);
      canvas.drawLine(foot, foot.translate(0, -tall), pole);
      final arm = foot.translate(0, -tall * 0.92);
      canvas.drawLine(arm.translate(-_u * 0.16 / z, 0), arm.translate(_u * 0.16 / z, 0), pole);
      i == 0 ? wire.moveTo(arm.dx - _u * 0.16 / z, arm.dy) : wire.quadraticBezierTo(arm.dx + _u * 0.1 / z, arm.dy + _u * 0.08 / z, arm.dx - _u * 0.16 / z, arm.dy);
    }
    canvas.drawPath(wire, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _ink);
    // Qualche cespuglio sull'orizzonte.
    final rng = Random(9);
    for (var i = 0; i < 9; i++) {
      final x = rng.nextDouble() * _w;
      canvas.drawOval(Rect.fromCenter(center: Offset(x, horizon + _u * 0.01), width: _u * (0.12 + rng.nextDouble() * 0.2), height: _u * 0.06), Paint()..color = const Color(0xFF1A110C));
    }
  }

  /// Il cartello bianco di fine città, col nome sbarrato in rosso.
  void _endSign(Canvas canvas, Offset foot) {
    final board = Rect.fromCenter(center: foot.translate(0, -_u * 1.05), width: _u * 0.80, height: _u * 0.36);
    final post = Paint()
      ..color = const Color(0xFF3A3D44)
      ..strokeWidth = _u * 0.035;
    canvas.drawLine(foot.translate(-_u * 0.22, 0), board.bottomLeft.translate(_u * 0.18, 0), post);
    canvas.drawLine(foot.translate(_u * 0.22, 0), board.bottomRight.translate(-_u * 0.18, 0), post);
    canvas.drawRRect(RRect.fromRectAndRadius(board, Radius.circular(_u * 0.03)), Paint()..color = const Color(0xFFE9E4D8));
    canvas.drawRRect(
      RRect.fromRectAndRadius(board.deflate(_u * 0.025), Radius.circular(_u * 0.02)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _u * 0.014
        ..color = _ink,
    );
    final letters = TextPainter(
      text: TextSpan(
        text: town.toUpperCase(),
        style: TextStyle(fontFamily: 'Georgia', fontSize: _u * 0.15, fontWeight: FontWeight.w900, color: _ink),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final fit = min(1.0, board.width * 0.82 / max(1, letters.width));
    canvas.save();
    canvas.translate(board.center.dx, board.center.dy);
    canvas.scale(fit);
    letters.paint(canvas, Offset(-letters.width / 2, -letters.height / 2));
    canvas.restore();
    canvas.drawLine(
      board.bottomLeft.translate(_u * 0.06, -_u * 0.05),
      board.topRight.translate(-_u * 0.06, _u * 0.05),
      Paint()
        ..color = const Color(0xFFD62E36)
        ..strokeWidth = _u * 0.05
        ..strokeCap = StrokeCap.round,
    );
  }

  void _tumbleweed(Canvas canvas, Offset center, double spin) {
    final twig = Paint()
      ..color = const Color(0xFF8A6A44)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1, _u * 0.012);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(spin);
    for (var i = 0; i < 7; i++) {
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: _u * 0.30, height: _u * (0.12 + i * 0.025)), twig);
      canvas.rotate(pi / 7);
    }
    canvas.restore();
  }

  /// La berlina nera degli anni Quaranta: parafanghi tondi, il bordo di luce
  /// del tramonto, il faro acceso, le ruote che girano e la carrozzeria che
  /// sobbalza sulla strada sterrata.
  void _sedan(Canvas canvas, double front, double ground, double scale) {
    final u = _u;
    final back = -u * 2.1;
    final r = u * 0.20;
    // L'ombra resta a terra, il resto sobbalza sulle molle.
    canvas.drawOval(
      Rect.fromLTRB(front + (back - u * 0.05) * scale, ground - u * 0.03 * scale, front + u * 0.05 * scale, ground + u * 0.04 * scale),
      Paint()..color = Colors.black.withValues(alpha: 0.5),
    );
    canvas.save();
    canvas.translate(front, ground);
    canvas.scale(scale);
    final bounce = sin(front / u * 5) * u * 0.018;

    Path body() => Path()
      // Il parafango dietro, il baule, il tetto, il cofano lungo e il muso.
      ..moveTo(back + u * 0.02, -u * 0.12)
      ..quadraticBezierTo(back - u * 0.05, -u * 0.40, back + u * 0.20, -u * 0.47)
      ..quadraticBezierTo(back + u * 0.40, -u * 0.86, back + u * 0.82, -u * 0.86)
      ..quadraticBezierTo(back + u * 1.15, -u * 0.86, back + u * 1.30, -u * 0.53)
      ..quadraticBezierTo(back + u * 1.80, -u * 0.52, -u * 0.06, -u * 0.43)
      ..quadraticBezierTo(u * 0.05, -u * 0.32, u * 0.01, -u * 0.12)
      ..close();

    canvas.save();
    canvas.translate(0, bounce);
    canvas.drawPath(body().shift(Offset(-u * 0.025, -u * 0.02)), Paint()..color = _rim);
    canvas.drawPath(body(), Paint()..color = _ink);
    // I finestrini, col montante in mezzo.
    final glass = Paint()..color = const Color(0xFF3B4658);
    canvas.drawPath(
      Path()
        ..moveTo(back + u * 0.42, -u * 0.53)
        ..quadraticBezierTo(back + u * 0.52, -u * 0.79, back + u * 0.80, -u * 0.79)
        ..lineTo(back + u * 0.80, -u * 0.53)
        ..close(),
      glass,
    );
    canvas.drawPath(
      Path()
        ..moveTo(back + u * 0.86, -u * 0.53)
        ..lineTo(back + u * 0.86, -u * 0.79)
        ..quadraticBezierTo(back + u * 1.08, -u * 0.79, back + u * 1.20, -u * 0.53)
        ..close(),
      glass,
    );
    // Il filetto cromato lungo la fiancata, la maniglia, il paraurti.
    final chrome = Paint()
      ..color = _steel.withValues(alpha: 0.75)
      ..strokeWidth = u * 0.016
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(back + u * 0.10, -u * 0.40), Offset(-u * 0.10, -u * 0.36), chrome);
    canvas.drawLine(Offset(back + u * 0.92, -u * 0.47), Offset(back + u * 1.02, -u * 0.47), chrome);
    canvas.drawLine(Offset(-u * 0.02, -u * 0.13), Offset(u * 0.06, -u * 0.13), chrome..strokeWidth = u * 0.03);
    canvas.drawLine(Offset(back - u * 0.04, -u * 0.13), Offset(back + u * 0.06, -u * 0.13), chrome);
    // Il faro, col fascio di luce che spazza la strada.
    final lamp = Offset(-u * 0.04, -u * 0.36);
    canvas.drawPath(
      Path()
        ..moveTo(lamp.dx, lamp.dy - u * 0.04)
        ..lineTo(lamp.dx + u * 1.6, lamp.dy - u * 0.10)
        ..lineTo(lamp.dx + u * 1.6, lamp.dy + u * 0.36)
        ..lineTo(lamp.dx, lamp.dy + u * 0.04)
        ..close(),
      Paint()
        ..shader = LinearGradient(
          colors: [const Color(0xFFFFF3C4).withValues(alpha: 0.45), const Color(0xFFFFF3C4).withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(lamp.dx, lamp.dy - u * 0.2, u * 1.6, u * 0.6)),
    );
    canvas.drawCircle(lamp, u * 0.06, Paint()..color = const Color(0xFFFFF3C4));
    canvas.drawCircle(Offset(back + u * 0.02, -u * 0.30), u * 0.035, Paint()..color = const Color(0xFFE23A3A));
    canvas.restore();

    // Le ruote, coi raggi che girano con la strada fatta.
    final spin = front / r;
    for (final x in [back + u * 0.40, -u * 0.38]) {
      final hub = Offset(x, -r);
      canvas.drawCircle(hub, r, Paint()..color = _ink);
      canvas.drawCircle(hub, r * 0.55, Paint()..color = const Color(0xFF2A2C30));
      final spoke = Paint()
        ..color = _steel.withValues(alpha: 0.6)
        ..strokeWidth = u * 0.016;
      for (var i = 0; i < 4; i++) {
        final a = spin + i * pi / 4;
        canvas.drawLine(hub - Offset(cos(a), sin(a)) * (r * 0.5), hub + Offset(cos(a), sin(a)) * (r * 0.5), spoke);
      }
      canvas.drawCircle(hub, r * 0.16, Paint()..color = _steel);
    }
    // Le righe della velocità, dietro.
    final streak = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = u * 0.014;
    for (final (dy, len) in [(0.70, 1.0), (0.48, 1.5), (0.24, 0.8)]) {
      canvas.drawLine(Offset(back - u * 0.15, -u * dy), Offset(back - u * (0.15 + len), -u * dy), streak);
    }
    canvas.restore();
  }

  // ---------------------------------------------------------------- il treno

  static const _trainCrowd = [
    _Extra(0.04, 0.95, AvatarHead.fedora, _Kit.kerchief, 0.1),
    _Extra(0.13, 0.90, AvatarHead.wideBrim, _Kit.kerchief, 0.4),
    _Extra(0.22, 1.02, AvatarHead.bowler, _Kit.torch, 0.7),
    _Extra(0.30, 0.96, AvatarHead.coppola, _Kit.kerchief, 0.9),
  ];

  void _station(Canvas canvas) {
    final platform = _h * 0.78;
    // Prima di partire la carrozza dà uno strattone indietro, coi respingenti,
    // poi prende velocità.
    final leaving = Curves.easeInQuad.transform(_span(t, VerdictBeats.depart, 0.84));
    final tug = sin(pi * _span(t, VerdictBeats.depart - 0.012, VerdictBeats.depart + 0.01)) * _u * 0.05;
    final rear = _w * 0.40 + _w * 1.3 * leaving - tug;
    final floor = platform - _u * 0.18;
    final door = Rect.fromLTWH(rear + _u * 0.14, floor - _u * 1.15, _u * 0.34, _u * 1.15);
    final window = Rect.fromLTWH(rear + _u * 0.68, platform - _u * 1.16, _u * 0.40, _u * 0.40);
    // La porta che sbatte fa tremare la carrozza.
    final slam = _span(t, VerdictBeats.doorShuts + 0.008, VerdictBeats.doorShuts + 0.03);
    final rattle = slam > 0 && slam < 1 ? sin(slam * pi * 7) * (1 - slam) * _u * 0.015 : 0.0;

    _clock(canvas, Offset(_w * 0.20, _h * 0.24));
    canvas.save();
    canvas.translate(0, rattle);
    _carriage(canvas, rear, platform, floor, door, window, rear - _w * 0.40);
    _spotlight(canvas, _marchTo(door.center.dx, _u).$1, platform, 1 - _span(t, VerdictBeats.board, VerdictBeats.doorShuts));

    // Il condannato: sale sul predellino, entra nel buio della porta e la
    // parete se lo mangia; poi ricompare al finestrino a salutare.
    final (walkX, walk, stride) = _marchTo(door.center.dx, _u);
    final climb = _span(t, VerdictBeats.board, VerdictBeats.board + 0.05);
    if (climb < 1) {
      final up = _smooth(_span(climb, 0, 0.5));
      final inside = _smooth(_span(climb, 0.3, 1));
      final x = _mix(walkX, door.right + _u * 0.25, inside);
      final y = platform - _mix(0, _u * 0.09, up) - _mix(0, _u * 0.09, _span(climb, 0.5, 0.8));
      canvas.save();
      // Si vede solo fuori dalla carrozza o dentro il vano della porta.
      canvas.clipPath(
        Path()
          ..addRect(Rect.fromLTRB(-_w, -_h, rear, _h * 2))
          ..addRect(Rect.fromLTRB(door.left, door.top, door.right, _h * 2)),
      );
      _person(
        canvas,
        feet: Offset(x, y),
        h: _u,
        walk: climb > 0 ? walk + climb * 9 : walk,
        stride: climb > 0 ? 0.6 : stride,
        lean: climb > 0 ? 0.16 * sin(pi * up) : -0.10 * stride,
        crouch: climb > 0 ? 0.18 * sin(pi * climb * 2).abs() : 0,
        backArm: climb > 0 ? _mix(-0.1, 1.6, up) : -0.10,
        backElbow: climb > 0 ? 0.6 : 0.2,
        hat: hat,
      );
      canvas.restore();
    }
    // La porta scorre e sbatte, con un rimbalzo.
    final shut = Curves.easeOutBack.transform(_span(t, VerdictBeats.doorShuts - 0.004, VerdictBeats.doorShuts + 0.008));
    if (shut > 0) {
      final panel = Rect.fromLTRB(_mix(door.right, door.left, shut), door.top, door.right + _u * 0.02 * (1 - shut), door.bottom);
      canvas.drawRect(panel, Paint()..color = const Color(0xFF4A2226));
      canvas.drawRect(Rect.fromLTWH(panel.left, panel.top, _u * 0.02, panel.height), Paint()..color = const Color(0xFF6A3A30));
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(panel.left + _u * 0.08, door.top + _u * 0.12, _u * 0.18, _u * 0.26), Radius.circular(_u * 0.02)),
        Paint()..color = _warm.withValues(alpha: 0.55),
      );
      canvas.drawLine(
        Offset(panel.left + _u * 0.05, door.top + _u * 0.60),
        Offset(panel.left + _u * 0.05, door.top + _u * 0.75),
        Paint()
          ..color = AppColors.gold
          ..strokeWidth = _u * 0.02
          ..strokeCap = StrokeCap.round,
      );
    }
    // Le righe del colpo, ai lati della porta.
    if (slam > 0 && slam < 0.6) {
      final lines = Paint()
        ..color = Colors.white.withValues(alpha: 0.6 * (1 - slam / 0.6))
        ..strokeWidth = max(1, _u * 0.014)
        ..strokeCap = StrokeCap.round;
      for (final (dy, len) in const [(0.25, 0.14), (0.50, 0.20), (0.75, 0.14)]) {
        final y = door.top + door.height * dy;
        canvas.drawLine(Offset(door.left - _u * 0.05, y), Offset(door.left - _u * (0.05 + len), y - _u * 0.03), lines);
      }
    }
    final aboard = _span(t, VerdictBeats.doorShuts + 0.012, VerdictBeats.doorShuts + 0.03);
    if (aboard > 0) {
      final waving = _span(t, 0.39, 0.42);
      canvas.save();
      canvas.clipRect(window);
      _person(
        canvas,
        feet: Offset(window.center.dx + _u * 0.02, window.bottom + _u * 0.60 * (2 - aboard)),
        h: _u,
        facing: -1,
        hat: hat,
      );
      canvas.restore();
      // Il braccio sporge dal finestrino e sventola il fazzoletto.
      if (waving > 0) {
        final ink = Paint()..color = _ink;
        final shoulder = Offset(window.left + _u * 0.08, window.bottom - _u * 0.14);
        final elbow = shoulder + Offset(-_u * 0.16, -_u * 0.12 * waving);
        final hand = elbow + Offset(-_u * (0.04 + 0.06 * sin(t * 160)), -_u * 0.18 * waving);
        _limb(canvas, shoulder, elbow, _u * 0.040, _u * 0.034, ink);
        _limb(canvas, elbow, hand, _u * 0.034, _u * 0.028, ink);
        canvas.drawCircle(hand, _u * 0.032, ink);
        _held(canvas, hand, const Offset(0, -1), _u, _Kit.kerchief);
      }
    }
    canvas.restore();

    // La folla saluta col fazzoletto; uno si soffia il naso.
    final farewell = _span(t, VerdictBeats.whistle, VerdictBeats.whistle + 0.03) * (1 - _span(t, 0.78, 0.82));
    final sob = _smooth(_span(t, VerdictBeats.sniff - 0.02, VerdictBeats.sniff)) * (1 - _smooth(_span(t, 0.70, 0.73)));
    final blow = sob > 0.9 ? sin(t * 260).abs() : 0.0;
    _crowd(
      canvas,
      _trainCrowd,
      platform,
      arm: (i, e) => i == 1 && sob > 0 ? _mix(2.6, 2.25, sob) : (farewell > 0 ? _mix(0.08, 2.6 + 0.2 * sin(t * 90 + i), farewell) : (e.kit == _Kit.torch ? _shake(e) : 0.08)),
      elbow: (i, e) => i == 1 && sob > 0 ? _mix(0.4, 2.1, sob) : (farewell > 0 ? 0.4 + 0.5 * sin(t * 120 + i * 2) : 0.2),
      lean: (i, e) => i == 1 ? 0.10 * sob + 0.06 * blow : 0,
      kit: (i, e) => farewell > 0 || sob > 0 ? _Kit.kerchief : (e.kit == _Kit.torch ? _Kit.torch : _Kit.none),
    );
    final pushH = _u * 0.86;
    final (pushX, pushWalk, pushStride) = _marchTo(door.center.dx - _u * 0.42, pushH);
    final marching = t < VerdictBeats.marchTo - 0.02;
    // Chi spinge dà l'ultima spintarella mentre l'altro sale, poi si spolvera
    // le mani.
    final shove = sin(pi * _span(t, VerdictBeats.board, VerdictBeats.board + 0.03));
    _person(
      canvas,
      feet: Offset(pushX + shove * _u * 0.06, platform),
      h: pushH,
      walk: pushWalk,
      stride: pushStride,
      lean: marching ? 0.18 * pushStride : 0.14 * shove,
      arm: marching ? 1.45 : (shove > 0 ? _mix(0.6, 1.5, shove) : (farewell > 0 ? _mix(0.08, 2.7, farewell) : 0.1)),
      elbow: marching ? 0.1 : (shove > 0 ? 0.1 : (farewell > 0 ? 0.4 + 0.5 * sin(t * 110) : 0.2)),
      backArm: marching ? 1.3 : (shove > 0 ? 1.3 * shove : -0.1),
      hat: AvatarHead.fedora,
      kit: farewell > 0 ? _Kit.kerchief : _Kit.none,
    );

    // Il fumo della locomotiva, fuori campo, che passa sopra la carrozza.
    for (var i = 0; i < 12; i++) {
      final from = i * 0.06;
      final life = _span(t, from, from + 0.24);
      _puff(canvas, Offset(_w * 1.05 + _w * 1.4 * leaving - life * _u * 1.6, platform - _u * (1.7 + life * 0.9)), life, size: 0.9 + 0.5 * life, color: const Color(0xFF8E8A86));
    }

    _platform(canvas, platform);

    // Il vapore: al fischio esce a sbuffi da sotto la carrozza, rotola sul
    // marciapiede e sale; alla partenza un'altra nuvola fra le ruote.
    for (var i = 0; i < 9; i++) {
      final from = VerdictBeats.whistle + i * 0.008;
      final life = _span(t, from, from + 0.13);
      final x = _mix(_w * 0.50, _w * 1.05, i / 8) + _w * 1.3 * leaving * 0.4;
      _puff(canvas, Offset(x + life * _u * 0.3 * (i.isEven ? 1 : -1), platform - _u * (0.05 + 0.55 * life)), life, size: 0.8 + 0.9 * life, color: const Color(0xFFF4F1EA));
    }
    for (var i = 0; i < 6; i++) {
      final from = VerdictBeats.depart + i * 0.012;
      final life = _span(t, from, from + 0.14);
      _puff(canvas, Offset(_w * (0.45 + i * 0.09) - life * _u * 0.6, platform - _u * (0.08 + 0.4 * life)), life, size: 0.7 + 0.8 * life, color: const Color(0xFFE9E4D8));
    }

    // Resta solo un fazzoletto, che scende piano.
    final flutter = _span(t, VerdictBeats.kerchief, VerdictBeats.kerchief + 0.12);
    if (flutter > 0) {
      final at = Offset(_w * 0.62 + sin(flutter * 14) * _u * 0.18 * (1 - flutter), _mix(_h * 0.14, platform - _u * 0.02, flutter));
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(flutter < 1 ? sin(flutter * 14) * 0.6 : 0.1);
      canvas.scale(1, flutter < 1 ? 1 : 0.3);
      canvas.drawPath(
        Path()
          ..moveTo(-_u * 0.07, -_u * 0.05)
          ..lineTo(_u * 0.08, -_u * 0.06)
          ..lineTo(_u * 0.06, _u * 0.06)
          ..lineTo(-_u * 0.06, _u * 0.05)
          ..close(),
        Paint()..color = _cloth,
      );
      canvas.restore();
    }

    _word(canvas, strings.verdictWord(VerdictWord.toot), VerdictBeats.whistle, 0.10, Offset(_w * 0.68, platform - _u * 1.75));
    _word(canvas, strings.verdictWord(VerdictWord.sniff), VerdictBeats.sniff, 0.08, Offset(_w * 0.20, platform - _u * 1.30), size: 0.24);
  }

  void _platform(Canvas canvas, double top) {
    canvas.drawRect(
      Rect.fromLTRB(-_w, top, _w * 2, _h * 1.3),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2E2824), Color(0xFF0C0A09)],
        ).createShader(Rect.fromLTRB(0, top, _w, _h)),
    );
    canvas.drawRect(Rect.fromLTRB(-_w, top + _u * 0.025, _w * 2, top + _u * 0.045), Paint()..color = const Color(0xFFC9A227).withValues(alpha: 0.75));
  }

  /// La carrozza: legno scuro, il filetto d'oro, i finestrini accesi, il
  /// tetto a botte, il predellino sotto la porta e i carrelli con le ruote
  /// che girano quando parte. [travelled] è la strada fatta, per i raggi.
  void _carriage(Canvas canvas, double rear, double platform, double floor, Rect door, Rect window, double travelled) {
    final body = Rect.fromLTRB(rear, platform - _u * 1.45, rear + _w * 3, floor);
    // Sotto la cassa: il telaio scuro e le ruote, che spuntano sopra il
    // bordo del marciapiede.
    canvas.drawRect(Rect.fromLTRB(rear + _u * 0.05, floor - _u * 0.02, body.right, floor + _u * 0.08), Paint()..color = const Color(0xFF120A0B));
    final r = _u * 0.14;
    final spin = travelled / r;
    for (var x = rear + _u * 0.75; x < _w + _u; x += _u * 0.42) {
      final hub = Offset(x, platform - _u * 0.02);
      canvas.drawCircle(hub, r, Paint()..color = _ink);
      canvas.drawCircle(hub, r, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _u * 0.018
        ..color = const Color(0xFF5A4A40));
      final spoke = Paint()
        ..color = const Color(0xFF5A4A40)
        ..strokeWidth = _u * 0.014;
      for (var i = 0; i < 3; i++) {
        final a = spin + i * pi / 3;
        canvas.drawLine(hub - Offset(cos(a), sin(a)) * (r * 0.85), hub + Offset(cos(a), sin(a)) * (r * 0.85), spoke);
      }
      canvas.drawCircle(hub, r * 0.22, Paint()..color = AppColors.gold.withValues(alpha: 0.7));
    }
    // Il respingente in coda.
    canvas.drawRect(Rect.fromLTWH(rear - _u * 0.10, floor - _u * 0.10, _u * 0.10, _u * 0.05), Paint()..color = _ink);
    canvas.drawCircle(Offset(rear - _u * 0.11, floor - _u * 0.075), _u * 0.05, Paint()..color = _ink);

    canvas.drawRRect(RRect.fromRectAndCorners(body, topLeft: Radius.circular(_u * 0.10)), Paint()..color = const Color(0xFF3E1D21));
    // Il tetto a botte, con la sua ombra.
    canvas.drawRRect(
      RRect.fromRectAndCorners(Rect.fromLTRB(rear - _u * 0.03, body.top - _u * 0.10, body.right, body.top + _u * 0.04), topLeft: Radius.circular(_u * 0.10)),
      Paint()..color = const Color(0xFF1E0F11),
    );
    canvas.drawLine(Offset(rear + _u * 0.06, body.top - _u * 0.085), Offset(body.right, body.top - _u * 0.085), Paint()
      ..color = _rim
      ..strokeWidth = max(1, _u * 0.012));
    canvas.drawRect(Rect.fromLTRB(rear, platform - _u * 0.42, body.right, platform - _u * 0.39), Paint()..color = AppColors.gold.withValues(alpha: 0.8));
    for (var x = window.left; x < _w + _u; x += _u * 0.55) {
      final pane = Rect.fromLTWH(x, window.top, window.width, window.height);
      canvas.drawRRect(RRect.fromRectAndRadius(pane, Radius.circular(_u * 0.04)), Paint()..color = const Color(0xFFE9B860));
      canvas.drawLine(Offset(pane.left, pane.top + pane.height * 0.35), Offset(pane.right, pane.top + pane.height * 0.35), Paint()
        ..color = const Color(0xFF3E1D21)
        ..strokeWidth = max(1, _u * 0.012));
    }
    // Il vano della porta, il corrimano d'ottone e il predellino.
    canvas.drawRect(door, Paint()..color = const Color(0xFF0A0606));
    final brass = Paint()
      ..color = AppColors.gold
      ..strokeWidth = _u * 0.022
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(door.left - _u * 0.04, door.top + _u * 0.35), Offset(door.left - _u * 0.04, door.bottom - _u * 0.10), brass);
    canvas.drawRect(Rect.fromLTRB(door.left - _u * 0.04, platform - _u * 0.10, door.right + _u * 0.04, platform - _u * 0.08), Paint()..color = _ink);
    canvas.drawLine(Offset(door.left + _u * 0.02, floor), Offset(door.left + _u * 0.02, platform - _u * 0.09), Paint()
      ..color = _ink
      ..strokeWidth = _u * 0.02);
    canvas.drawLine(Offset(door.right - _u * 0.02, floor), Offset(door.right - _u * 0.02, platform - _u * 0.09), Paint()
      ..color = _ink
      ..strokeWidth = _u * 0.02);
    canvas.drawCircle(Offset(rear + _u * 0.06, platform - _u * 0.62), _u * 0.04, Paint()..color = const Color(0xFFE23A3A));
  }

  void _clock(Canvas canvas, Offset center) {
    final r = _u * 0.20;
    canvas.drawLine(center.translate(0, -r), Offset(center.dx, 0), Paint()
      ..color = _ink
      ..strokeWidth = _u * 0.03);
    canvas.drawCircle(center, r, Paint()..color = _ink);
    canvas.drawCircle(center, r * 0.82, Paint()..color = const Color(0xFFE9E4D8));
    final hand = Paint()
      ..color = _ink
      ..strokeWidth = r * 0.10
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, center + Offset(sin(-0.5), -cos(-0.5)) * r * 0.45, hand);
    final minute = t * 2 * pi * 0.3 - 0.2;
    canvas.drawLine(center, center + Offset(sin(minute), -cos(minute)) * r * 0.70, hand..strokeWidth = r * 0.06);
  }

  // --------------------------------------------------------------- il cannone

  static const _circusCrowd = [
    _Extra(0.04, 0.94, AvatarHead.fedora, _Kit.none, 0.9),
    _Extra(0.12, 1.00, AvatarHead.bowler, _Kit.none, 0.2),
    _Extra(0.20, 0.90, AvatarHead.wideBrim, _Kit.kerchief, 0.4),
    _Extra(0.27, 1.02, AvatarHead.coppola, _Kit.torch, 0.6),
  ];

  void _circus(Canvas canvas) {
    final ground = _h * 0.79;
    _fairground(canvas, ground);
    // Il condannato arriva un po' prima degli altri: deve prendere la rincorsa.
    const arrive = 0.225;
    final start = _w * 0.56 - _u * 0.62;
    _spotlight(canvas, _marchTo(start, _u, until: arrive).$1, ground, 1 - _span(t, VerdictBeats.jump, VerdictBeats.jump + 0.04));

    const angle = -0.95;
    final dir = Offset(cos(angle), sin(angle));
    // Prima del colpo la canna si gonfia e trema; poi il rinculo.
    final swell = t < VerdictBeats.boom ? Curves.easeIn.transform(_span(t, VerdictBeats.boom - 0.03, VerdictBeats.boom)) : 0.0;
    final jitter = Offset(sin(t * 900), cos(t * 1100)) * (_u * 0.012 * swell);
    final recoil = sin(pi * _span(t, VerdictBeats.boom, VerdictBeats.boom + 0.05)) * _u * 0.12;
    final pivot = Offset(_w * 0.56, ground - _u * 0.32) - dir * recoil + jitter;
    final muzzle = pivot + dir * (_u * 0.95);
    final breech = pivot - dir * (_u * 0.22);

    // La miccia: scende dalla culatta e fa un'ansa per terra.
    final fuse = Path()
      ..moveTo(breech.dx - _u * 0.10, breech.dy + _u * 0.10)
      ..quadraticBezierTo(breech.dx - _u * 0.22, ground + _u * 0.01, breech.dx - _u * 0.36, ground - _u * 0.015)
      ..quadraticBezierTo(breech.dx - _u * 0.48, ground - _u * 0.05, breech.dx - _u * 0.58, ground - _u * 0.02)
      // Il capo della miccia si arriccia all'insù, dove arriva la torcia.
      ..quadraticBezierTo(breech.dx - _u * 0.66, ground - _u * 0.04, breech.dx - _u * 0.62, ground - _u * 0.20);
    final metric = fuse.computeMetrics().first;
    final fuseEnd = metric.getTangentForOffset(metric.length)!.position;
    double burnAt(double time) => _span(time, VerdictBeats.fuse, VerdictBeats.boom - 0.005);
    Offset sparkAt(double time) => metric.getTangentForOffset(metric.length * (1 - burnAt(time)))!.position;

    // Il condannato: si accuccia (la carica), salta a tuffo dentro la bocca
    // del cannone e ci scivola, finché resta fuori solo la testa; quando la
    // canna si gonfia, la testa sparisce con un ultimo scivolone.
    final (walkX, walk, stride) = _marchTo(start, _u, until: arrive);
    final prep = _smooth(_span(t, VerdictBeats.jump - 0.022, VerdictBeats.jump));
    final hop = _span(t, VerdictBeats.jump, VerdictBeats.jump + 0.05);
    final slide = _smooth(_span(t, VerdictBeats.slide, VerdictBeats.slide + 0.035));
    final duck = _smooth(_span(t, VerdictBeats.boom - 0.03, VerdictBeats.boom - 0.015));
    final fired = t >= VerdictBeats.boom;
    const lean = pi / 2 + angle;
    if (!fired) {
      final feet = hop <= 0
          ? Offset(walkX, ground)
          : Offset.lerp(Offset(start, ground), muzzle, _smooth(hop))! - Offset(0, _u * 0.7 * sin(pi * hop)) - dir * (_u * (0.85 * slide + 0.14 * duck));
      final tucked = hop > 0 && hop < 1;
      _person(
        canvas,
        feet: feet,
        h: _u,
        walk: walk,
        stride: hop > 0 || prep > 0 ? 0 : stride,
        lean: hop > 0 ? 0 : -0.10 * stride + 0.30 * prep,
        tilt: lean * _smooth(hop),
        arm: hop > 0 ? (slide < 1 ? _mix(2.9, 0.0, slide) : 0.08) : _mix(0.08, -0.7, prep),
        elbow: 0.1,
        backArm: hop > 0 ? _mix(2.6, 0.0, slide) : _mix(-0.1, -0.9, prep),
        crouch: hop > 0 ? (tucked ? 0.3 * sin(pi * hop) : 0) : 0.42 * prep,
        hat: hat,
      );
    }
    _cannon(canvas, pivot, breech, muzzle, dir, ground, swell);

    // La miccia, che si consuma verso il cannone, con la scintilla che
    // sfrigola e una scia di fumo.
    if (!fired) {
      final burn = burnAt(t);
      final left = metric.extractPath(0, metric.length * (1 - burn));
      canvas.drawPath(
        left,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _u * 0.034
          ..strokeCap = StrokeCap.round
          ..color = _ink,
      );
      canvas.drawPath(
        left,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _u * 0.020
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFC9B48A),
      );
      if (burn > 0) {
        for (var k = 1; k <= 5; k++) {
          final back = t - k * 0.008;
          if (back < VerdictBeats.fuse) break;
          _puff(canvas, sparkAt(back).translate(0, -_u * 0.04 * k), k / 6, size: 0.22, color: const Color(0xFFB8B0A4));
        }
        final spark = sparkAt(t);
        canvas.drawCircle(
          spark,
          _u * 0.12,
          Paint()
            ..color = _warm.withValues(alpha: 0.45)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, _u * 0.05),
        );
        _star(canvas, spark, _u * (0.08 + 0.05 * sin(t * 500).abs()), const Color(0xFFFFF3C4));
        _spray(canvas, spark, (t * 60) % 1, seed: (t * 60).floor(), color: _warm, count: 8, bias: const Offset(0, -0.9), reach: 0.30);
      }
    }

    // La folla: il portatore di torcia va ad accendere chinandosi, poi scappa
    // a gambe levate; tutti si tappano le orecchie, poi guardano in alto.
    final ears = _span(t, VerdictBeats.boom - 0.04, VerdictBeats.boom - 0.02) * (1 - _span(t, 0.62, 0.64));
    final look = _span(t, 0.62, 0.64) * (1 - _span(t, 0.80, 0.83));
    final cheer = _span(t, VerdictBeats.ping + 0.01, VerdictBeats.ping + 0.03) * (1 - _span(t, VerdictBeats.shoe, VerdictBeats.shoe + 0.02));
    final dazed = _span(t, VerdictBeats.bonk, VerdictBeats.bonk + 0.10);
    final squash = _span(t, VerdictBeats.bonk, VerdictBeats.bonk + 0.035);
    for (final (i, e) in _circusCrowd.indexed) {
      final h = _u * e.scale * _extraSize;
      var (x, walk, stride) = _marchTo(_w * e.x, h, lag: _lagOf(e));
      var facing = 1;
      var arm = _shake(e);
      var elbow = 0.3;
      var backArm = -0.1;
      var backElbow = 0.2;
      var lean = 0.0;
      var tilt = 0.0;
      var crouch = 0.0;
      var kit = e.kit;
      if (!e.angry && e.kit != _Kit.torch) {
        arm = 0.08;
        elbow = 0.2;
      }
      if (i == 3) {
        final home = _w * e.x;
        final spot = fuseEnd.dx - _u * 0.42;
        final go = _smooth(_span(t, VerdictBeats.torch, VerdictBeats.torch + 0.04));
        final reach = _smooth(_span(t, VerdictBeats.torch + 0.04, VerdictBeats.fuse)) * (1 - _span(t, VerdictBeats.fuse + 0.004, VerdictBeats.fuse + 0.012));
        final flee = _span(t, VerdictBeats.fuse + 0.008, VerdictBeats.fuse + 0.04);
        final run = Curves.easeOut.transform(flee);
        final gone = home - _w * 0.07;
        x = flee > 0 ? _mix(spot, gone, run) : _mix(x, spot, go);
        final travelled = (spot - home).abs() * go + (spot - gone).abs() * run;
        walk = 2 * pi * travelled / (0.84 * h * 0.9);
        stride = (go > 0 && go < 1) || (flee > 0 && flee < 1) ? 0.9 : 0;
        facing = flee > 0 && flee < 1 ? -1 : 1;
        if (go > 0) {
          arm = _mix(arm, 0.55, reach);
          elbow = _mix(0.3, 0.15, reach);
          lean = 0.35 * reach + (flee > 0 && flee < 1 ? 0.25 : 0);
          crouch = 0.30 * reach;
        }
        if (flee > 0 && flee < 1) {
          arm = 2.6 + 0.4 * sin(t * 300);
          backArm = 2.4 + 0.4 * sin(t * 300 + pi);
        }
      }
      if (ears > 0) {
        arm = _mix(arm, 2.75, ears);
        elbow = _mix(elbow, 1.95, ears);
        backArm = _mix(-0.1, 2.75, ears);
        backElbow = _mix(0.2, 1.95, ears);
        crouch = max(crouch, 0.15 * ears);
        kit = _Kit.none;
      }
      if (look > 0) {
        arm = _mix(arm, 2.5, look);
        elbow = _mix(elbow, 1.6, look);
        lean = -0.12 * look;
        kit = _Kit.none;
      }
      if (cheer > 0) {
        arm = _mix(arm, 2.8 + 0.2 * sin(t * 80 + i), cheer);
        elbow = _mix(elbow, 0.3, cheer);
        backArm = _mix(backArm, 2.6, cheer);
        lean = -0.12 * look;
      }
      if (i == 1 && dazed > 0 && dazed < 1) {
        // Il colpo lo schiaccia giù, poi si rialza barcollando e si tocca la testa.
        crouch = 0.45 * sin(pi * squash) + 0.08 * (1 - dazed);
        tilt = sin(t * 110) * 0.14 * (1 - dazed);
        arm = _mix(2.7, 0.08, _span(dazed, 0.6, 1));
        elbow = _mix(2.0, 0.2, _span(dazed, 0.6, 1));
      }
      _person(
        canvas,
        feet: Offset(x, ground),
        h: h,
        facing: facing,
        walk: walk + e.phase * 3,
        stride: stride,
        lean: lean + _idle(e, stride),
        tilt: tilt,
        crouch: crouch,
        arm: arm,
        elbow: elbow,
        backArm: backArm,
        backElbow: backElbow,
        hat: e.hat,
        dame: e.dame,
        kit: kit,
      );
    }

    // Il colpo: lampo, palla di fuoco, scintille, l'anello di fumo, e il
    // condannato che vola via girando.
    _flash(canvas, _span(t, VerdictBeats.boom, VerdictBeats.boom + 0.035), strength: 0.75);
    final blast = _span(t, VerdictBeats.boom, VerdictBeats.boom + 0.06);
    final centre = muzzle + dir * (_u * 0.2);
    if (blast > 0 && blast < 1) {
      for (final (scale, color) in const [(1.0, Color(0xFFFF6A2B)), (0.65, Color(0xFFFFB13B)), (0.35, Color(0xFFFFF3C4))]) {
        canvas.drawCircle(centre, _u * 0.8 * Curves.easeOut.transform(blast) * scale, Paint()..color = color.withValues(alpha: (1 - blast) * 0.7));
      }
      final textures = sprites;
      if (textures != null) {
        final grow = Curves.easeOut.transform(blast);
        ParticleSprites.draw(
          canvas,
          textures.explosionAt(blast),
          centre,
          width: _u * 2.6 * grow,
          height: _u * 2.6 * grow,
          opacity: 0.92 * (1 - blast),
        );
        ParticleSprites.draw(
          canvas,
          textures.muzzle,
          muzzle,
          width: _u * 0.45,
          height: _u * 1.0,
          opacity: 1 - blast,
          rotation: angle + pi / 2,
          tint: const Color(0xFFFFD68A),
        );
      }
    }
    _spray(canvas, centre, _span(t, VerdictBeats.boom, VerdictBeats.boom + 0.07), seed: 21, color: _warm, count: 26, bias: dir * 0.9, reach: 1.6);
    for (var i = 0; i < 8; i++) {
      final a = i * pi / 4;
      final life = _span(t, VerdictBeats.boom + 0.01, VerdictBeats.boom + 0.16);
      _puff(canvas, centre + Offset(cos(a), sin(a) * 0.6) * (_u * (0.25 + 0.6 * Curves.easeOut.transform(life))), life, size: 0.55 + 0.4 * life);
    }
    for (var i = 0; i < 4; i++) {
      _puff(canvas, muzzle + dir * (_u * (0.2 + i * 0.25)), _span(t, VerdictBeats.boom + i * 0.01, VerdictBeats.boom + 0.20), size: 1.0 + i * 0.2);
    }
    final sky = Offset(_w * 0.80, _h * 0.22);
    final control = Offset(muzzle.dx + _w * 0.10, _h * 0.10);
    Offset flightAt(double p) => Offset(
          (1 - p) * (1 - p) * muzzle.dx + 2 * (1 - p) * p * control.dx + p * p * sky.dx,
          (1 - p) * (1 - p) * muzzle.dy + 2 * (1 - p) * p * control.dy + p * p * sky.dy,
        );
    final flight = _span(t, VerdictBeats.boom, VerdictBeats.ping);
    if (flight > 0 && flight < 1) {
      final p = Curves.easeOut.transform(flight);
      // La scia di fumo dietro al proiettile umano.
      for (var k = 1; k <= 6; k++) {
        final behind = flight - k * 0.035;
        if (behind <= 0) break;
        _puff(canvas, flightAt(Curves.easeOut.transform(behind)), k / 7, size: _mix(0.5, 0.08, p), color: const Color(0xFFB8B0A4));
      }
      final at = flightAt(p);
      final h = _u * _mix(1, 0.05, p);
      _person(canvas, feet: at + Offset(0, h * 0.5), h: h, tilt: lean + flight * 16, arm: 2.6, elbow: 0.3, backArm: -2.2, crouch: 0.3, hat: hat, hatOn: false);
    }
    final twinkle = _span(t, VerdictBeats.ping, VerdictBeats.ping + 0.12);
    if (twinkle > 0 && twinkle < 1) {
      final glow = sin(pi * twinkle) * (0.7 + 0.3 * sin(t * 300).abs());
      _star(canvas, sky, _u * 0.16 * glow, Colors.white.withValues(alpha: glow.clamp(0.0, 1.0)));
      _star(canvas, sky, _u * 0.08 * glow, _warm.withValues(alpha: glow.clamp(0.0, 1.0)));
    }

    // Dal cielo torna solo una scarpa, girando, sulla testa di uno della folla.
    final victimX = _w * _circusCrowd[1].x;
    final headTop = ground - _u * _circusCrowd[1].scale * _extraSize * 1.12;
    final fall = Curves.easeIn.transform(_span(t, VerdictBeats.shoe, VerdictBeats.bonk));
    final bounce = _span(t, VerdictBeats.bonk, VerdictBeats.bonk + 0.06);
    if (fall > 0) {
      final at = bounce <= 0
          ? Offset(victimX + _u * 0.02 + sin(fall * 9) * _u * 0.03, _mix(_h * 0.08, headTop, fall))
          : Offset(victimX + _u * 0.45 * bounce, _mix(headTop, ground, bounce) - sin(pi * bounce) * _u * 0.35);
      if (bounce <= 0 && fall > 0.15) {
        // Le righe della caduta, sopra la scarpa.
        final lines = Paint()
          ..color = Colors.white.withValues(alpha: 0.45)
          ..strokeWidth = max(1, _u * 0.010)
          ..strokeCap = StrokeCap.round;
        for (final dx in const [-0.05, 0.05]) {
          canvas.drawLine(at.translate(_u * dx, -_u * 0.12), at.translate(_u * dx, -_u * (0.12 + 0.4 * fall)), lines);
        }
      }
      _shoe(canvas, at, bounce > 0 ? 0.4 + bounce * 8 : fall * 7);
    }
    // L'urto: un lampo a raggiera sulla testa, poi le stelline che girano.
    final impact = _span(t, VerdictBeats.bonk, VerdictBeats.bonk + 0.03);
    if (impact > 0 && impact < 1) {
      final rays = Paint()
        ..color = Colors.white.withValues(alpha: 1 - impact)
        ..strokeWidth = max(1, _u * 0.018)
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 8; i++) {
        final a = -pi + i * pi / 7;
        final d = Offset(cos(a), sin(a));
        canvas.drawLine(Offset(victimX, headTop) + d * (_u * (0.10 + 0.08 * impact)), Offset(victimX, headTop) + d * (_u * (0.18 + 0.14 * impact)), rays);
      }
    }
    if (dazed > 0 && dazed < 1) {
      final dip = _u * 0.10 * sin(pi * squash);
      for (var i = 0; i < 4; i++) {
        final a = dazed * 18 + i * 2 * pi / 4;
        final depth = sin(a);
        _star(
          canvas,
          Offset(victimX + _u * 0.02 + cos(a) * _u * 0.28, headTop + dip - _u * 0.06 + depth * _u * 0.07),
          _u * (0.085 + 0.025 * depth),
          AppColors.gold.withValues(alpha: 1 - _span(dazed, 0.7, 1)),
          cartoon: true,
        );
      }
    }

    _word(canvas, _boomWord, VerdictBeats.boom, 0.10, muzzle.translate(-_u * 0.3, -_u * 0.55));
    _word(canvas, strings.verdictWord(VerdictWord.ping), VerdictBeats.ping, 0.09, sky.translate(-_u * 0.45, _u * 0.35), size: 0.26);
    _word(canvas, strings.verdictWord(VerdictWord.bonk), VerdictBeats.bonk, 0.08, Offset(victimX + _u * 0.35, headTop - _u * 0.25), size: 0.28);
  }

  void _fairground(Canvas canvas, double ground) {
    // Il tendone a strisce, sul fondo.
    final tent = Rect.fromLTRB(-_w * 0.05, ground - _u * 1.9, _w * 0.48, ground);
    final cone = Path()
      ..moveTo(tent.left, tent.bottom)
      ..lineTo(tent.left, tent.top + _u * 0.9)
      ..lineTo(tent.center.dx, tent.top)
      ..lineTo(tent.right, tent.top + _u * 0.9)
      ..lineTo(tent.right, tent.bottom)
      ..close();
    canvas.save();
    canvas.clipPath(cone);
    for (var i = 0; i < 9; i++) {
      final x = tent.left + tent.width * i / 9;
      canvas.drawRect(Rect.fromLTWH(x, tent.top, tent.width / 9, tent.height), Paint()..color = i.isEven ? const Color(0xFF6A1A20) : const Color(0xFF8E7B62));
    }
    canvas.drawRect(tent, Paint()..color = Colors.black.withValues(alpha: 0.35));
    canvas.restore();
    canvas.drawLine(Offset(tent.center.dx, tent.top), Offset(tent.center.dx, tent.top - _u * 0.25), Paint()
      ..color = _ink
      ..strokeWidth = _u * 0.02);
    canvas.drawPath(
      Path()
        ..moveTo(tent.center.dx, tent.top - _u * 0.25)
        ..lineTo(tent.center.dx + _u * 0.18, tent.top - _u * 0.20)
        ..lineTo(tent.center.dx, tent.top - _u * 0.14)
        ..close(),
      Paint()..color = _red,
    );

    canvas.drawRect(
      Rect.fromLTRB(-_w, ground, _w * 2, _h * 1.3),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A2218), Color(0xFF0B0907)],
        ).createShader(Rect.fromLTRB(0, ground, _w, _h)),
    );

    // Le bandierine.
    final line = Path()
      ..moveTo(-_w * 0.05, _h * 0.15)
      ..quadraticBezierTo(_w * 0.5, _h * 0.22, _w * 1.05, _h * 0.14);
    canvas.drawPath(line, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = _ink);
    final metric = line.computeMetrics().first;
    const colors = [Color(0xFFB3202A), Color(0xFFC9A227), Color(0xFFE9E4D8)];
    for (var i = 0; i < 14; i++) {
      final at = metric.getTangentForOffset(metric.length * (i + 0.5) / 14)!.position;
      final sway = sin(t * 30 + i) * _u * 0.015;
      canvas.drawPath(
        Path()
          ..moveTo(at.dx - _u * 0.06, at.dy)
          ..lineTo(at.dx + _u * 0.06, at.dy)
          ..lineTo(at.dx + sway, at.dy + _u * 0.14)
          ..close(),
        Paint()..color = colors[i % 3].withValues(alpha: 0.85),
      );
    }
  }

  /// Il cannone del circo: rosso, coi cerchi d'oro, sul carrello di legno.
  /// [swell] gonfia la canna subito prima del colpo.
  void _cannon(Canvas canvas, Offset pivot, Offset breech, Offset muzzle, Offset dir, double ground, double swell) {
    final ink = Paint()..color = _ink;
    // Il carrello, la coda a terra e la ruota.
    canvas.drawPath(
      Path()
        ..moveTo(pivot.dx - _u * 0.10, pivot.dy)
        ..lineTo(pivot.dx - _u * 0.70, ground)
        ..lineTo(pivot.dx - _u * 0.52, ground)
        ..lineTo(pivot.dx + _u * 0.12, pivot.dy + _u * 0.05)
        ..close(),
      Paint()..color = const Color(0xFF3A2414),
    );
    final side = Offset(-dir.dy, dir.dx);
    final fat = 1 + 0.30 * swell;
    final belly = Offset.lerp(breech, muzzle, 0.55)!;
    Offset rim(Offset at, double r) => at + side * (_u * r);
    final barrel = Path()
      ..moveTo(rim(breech, 0.19).dx, rim(breech, 0.19).dy)
      ..quadraticBezierTo(rim(belly, 0.16 * fat * fat).dx, rim(belly, 0.16 * fat * fat).dy, rim(muzzle, 0.13 * fat).dx, rim(muzzle, 0.13 * fat).dy)
      ..lineTo(rim(muzzle, -0.13 * fat).dx, rim(muzzle, -0.13 * fat).dy)
      ..quadraticBezierTo(rim(belly, -0.16 * fat * fat).dx, rim(belly, -0.16 * fat * fat).dy, rim(breech, -0.19).dx, rim(breech, -0.19).dy)
      ..close();
    canvas.drawPath(barrel, Paint()..color = Color.lerp(_red, const Color(0xFFE0453A), swell)!);
    // La luce del tramonto lungo la canna.
    canvas.drawLine(rim(breech, -0.12), rim(muzzle, -0.08 * fat), Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = _u * 0.03
      ..strokeCap = StrokeCap.round);
    canvas.drawPath(barrel, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _u * 0.02
      ..color = _ink);
    canvas.drawCircle(breech, _u * 0.19, Paint()..color = const Color(0xFF8A161E));
    canvas.drawCircle(breech - dir * (_u * 0.17), _u * 0.05, Paint()..color = const Color(0xFF8A161E));
    final band = Paint()
      ..color = AppColors.gold
      ..strokeWidth = _u * 0.05
      ..strokeCap = StrokeCap.butt;
    canvas.drawLine(rim(muzzle, 0.16 * fat), rim(muzzle, -0.16 * fat), band);
    final mid = Offset.lerp(breech, muzzle, 0.25)!;
    canvas.drawLine(rim(mid, 0.18 * fat), rim(mid, -0.18 * fat), band..strokeWidth = _u * 0.03);
    // La bocca, nera, vista un po' di sbieco.
    canvas.save();
    canvas.translate(muzzle.dx, muzzle.dy);
    canvas.rotate(atan2(dir.dy, dir.dx));
    canvas.drawOval(Rect.fromCenter(center: Offset(_u * 0.01, 0), width: _u * 0.06, height: _u * 0.22 * fat), ink);
    canvas.restore();
    for (final at in [0.48, 0.70]) {
      _star(canvas, Offset.lerp(breech, muzzle, at)!, _u * 0.06 * fat, AppColors.gold);
    }
    final wheel = Offset(pivot.dx, ground - _u * 0.24);
    canvas.drawCircle(wheel, _u * 0.24, ink);
    canvas.drawCircle(wheel, _u * 0.24, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _u * 0.03
      ..color = const Color(0xFF6B4423));
    for (var i = 0; i < 6; i++) {
      final a = i * pi / 3;
      canvas.drawLine(wheel, wheel + Offset(cos(a), sin(a)) * (_u * 0.22), Paint()
        ..color = const Color(0xFF6B4423)
        ..strokeWidth = _u * 0.02);
    }
    canvas.drawCircle(wheel, _u * 0.05, Paint()..color = AppColors.gold);
  }

  /// La scarpa del condannato: una stringata nera, col tacco e i lacci,
  /// grande abbastanza da riconoscerla mentre gira in aria.
  void _shoe(Canvas canvas, Offset at, double spin) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(spin);
    final s = _u * 1.5;
    final upper = Path()
      ..moveTo(-s * 0.085, 0)
      ..lineTo(-s * 0.085, -s * 0.05)
      ..quadraticBezierTo(-s * 0.08, -s * 0.075, -s * 0.05, -s * 0.075)
      ..lineTo(-s * 0.005, -s * 0.07)
      ..quadraticBezierTo(s * 0.03, -s * 0.045, s * 0.08, -s * 0.04)
      ..quadraticBezierTo(s * 0.115, -s * 0.035, s * 0.11, 0)
      ..close();
    canvas.drawPath(upper.shift(Offset(-s * 0.008, -s * 0.006)), Paint()..color = _rim);
    canvas.drawPath(upper, Paint()..color = _ink);
    // La suola e il tacco.
    canvas.drawRect(Rect.fromLTRB(-s * 0.09, -s * 0.004, s * 0.115, s * 0.012), Paint()..color = const Color(0xFF5A3B22));
    canvas.drawRect(Rect.fromLTRB(-s * 0.09, -s * 0.004, -s * 0.05, s * 0.026), Paint()..color = const Color(0xFF5A3B22));
    // I lacci.
    final lace = Paint()
      ..color = _cloth
      ..strokeWidth = max(1, s * 0.006);
    for (final dx in const [0.0, 0.018, 0.036]) {
      canvas.drawLine(Offset(s * (-0.01 + dx), -s * (0.066 - dx * 0.5)), Offset(s * (0.004 + dx), -s * (0.054 - dx * 0.5)), lace);
    }
    canvas.restore();
  }

  // ----------------------------------------------------------- l'assoluzione

  static const _squareCrowd = [
    _Extra(0.12, 0.95, AvatarHead.fedora, _Kit.none, 0.9),
    _Extra(0.28, 0.92, AvatarHead.wideBrim, _Kit.none, 0.2),
    _Extra(0.44, 1.02, AvatarHead.bowler, _Kit.fork, 0.6),
    _Extra(0.58, 0.90, AvatarHead.coppola, _Kit.none, 0.7),
    _Extra(0.73, 0.98, AvatarHead.fedora, _Kit.torch, 0.3),
    _Extra(0.89, 0.94, AvatarHead.bun, _Kit.none, 0.8),
  ];

  void _square(Canvas canvas) {
    final ground = _h * 0.79;
    canvas.drawRect(
      Rect.fromLTRB(-_w, ground, _w * 2, _h * 1.3),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2B2420), Color(0xFF0B0908)],
        ).createShader(Rect.fromLTRB(0, ground, _w, _h)),
    );
    final cobble = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.05);
    for (var row = 0; row < 4; row++) {
      final y = ground + _u * (0.06 + row * 0.09 * (1 + row * 0.3));
      for (var x = (row.isEven ? 0.0 : _u * 0.12); x < _w; x += _u * 0.24) {
        canvas.drawArc(Rect.fromCenter(center: Offset(x, y), width: _u * 0.22, height: _u * 0.07), pi, pi, false, cobble);
      }
    }

    final shrug = _smooth(_span(t, VerdictBeats.shrug, VerdictBeats.shrug + 0.03)) * (1 - _smooth(_span(t, VerdictBeats.disperse - 0.02, VerdictBeats.disperse)));
    for (final (i, e) in _squareCrowd.indexed) {
      final h = _u * e.scale;
      final k = 70 + e.phase * 50;
      final arguing = 1 - _span(t, VerdictBeats.shrug - 0.02, VerdictBeats.shrug);
      final order = const [3, 0, 5, 1, 4, 2][i];
      // Chi se ne va prima si gira e sbuffa (un mezzo inchino stizzito), poi
      // parte piano e allunga il passo; la fase del passo segue la strada
      // fatta, così i piedi non pattinano sui ciottoli.
      final from = VerdictBeats.disperse + order * 0.025;
      final huff = sin(pi * _span(t, from - 0.022, from));
      final leave = Curves.easeIn.transform(_span(t, from, from + 0.16));
      final outward = e.x < 0.5 ? -1 : 1;
      final travelled = _w * 0.9 * leave;
      final x = _w * e.x + outward * travelled;
      final facing = t >= from - 0.022 ? outward : (i.isEven ? 1 : -1);
      final hop = arguing * (sin(t * k * 0.5 + i)).abs() * _u * 0.03;
      final going = leave > 0 && leave < 1;
      _person(
        canvas,
        feet: Offset(x, ground - hop),
        h: h,
        facing: facing,
        walk: 2 * pi * travelled / (0.84 * h * 0.8) + i,
        stride: going ? min(0.8, 0.3 + leave * 3) : 0,
        crouch: 0.12 * huff,
        lean: arguing * 0.12 * sin(t * k * 0.5 + i) - 0.06 * shrug + 0.18 * huff + (going ? 0.08 : 0),
        arm: _mix(_mix(0.08, 1.5 + 0.9 * sin(t * k + i * 1.7), arguing), 1.15, shrug),
        elbow: _mix(_mix(0.2, 0.5 + 0.6 * sin(t * k * 1.3 + i), arguing), 1.35, shrug),
        backArm: _mix(_mix(-0.1, 0.4 + 0.6 * sin(t * k * 0.8 + i), arguing), 1.0, shrug),
        backElbow: _mix(0.2, 1.35, shrug),
        hat: e.hat,
        dame: e.dame,
        kit: arguing > 0.5 ? e.kit : _Kit.none,
      );
      // Le nuvolette delle parolacce.
      final said = 0.04 + order * 0.065;
      final balloon = _span(t, said, said + 0.09);
      if (balloon > 0 && balloon < 1) _balloon(canvas, Offset(_w * e.x, ground - h * 1.40), _curses[i], balloon);
    }

    final weed = _span(t, VerdictBeats.emptySquare, VerdictBeats.emptySquare + 0.16);
    if (weed > 0 && weed < 1) {
      _tumbleweed(canvas, Offset(_mix(-_w * 0.2, _w * 1.2, weed), ground - _u * 0.14 - (sin(weed * pi * 5)).abs() * _u * 0.25), weed * 22);
    }
    _word(canvas, strings.verdictWord(VerdictWord.shrug), VerdictBeats.shrug + 0.01, 0.12, Offset(_w * 0.5, ground - _u * 1.55));
  }

  void _balloon(Canvas canvas, Offset at, String curse, double life) {
    final pop = Curves.easeOutBack.transform(min(1, life / 0.25));
    final fade = 1 - _span(life, 0.75, 1);
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.scale(pop);
    final bubble = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: _u * 0.44, height: _u * 0.24), Radius.circular(_u * 0.12));
    final fill = Paint()..color = _cloth.withValues(alpha: fade);
    canvas.drawRRect(bubble, fill);
    canvas.drawPath(
      Path()
        ..moveTo(-_u * 0.04, _u * 0.11)
        ..lineTo(_u * 0.02, _u * 0.22)
        ..lineTo(_u * 0.06, _u * 0.11)
        ..close(),
      fill,
    );
    final text = TextPainter(
      text: TextSpan(
        text: curse,
        style: TextStyle(fontSize: _u * 0.13, fontWeight: FontWeight.w900, color: _red.withValues(alpha: fade)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, Offset(-text.width / 2, -text.height / 2));
    canvas.restore();
  }

  // ------------------------------------------------------------------ sagome

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

  /// Una persona in soprabito, di profilo, alta [h]: la stessa sagoma delle
  /// scene della notte, con in più quello che la folla si porta dietro e le
  /// scarpe di cemento.
  void _person(
    Canvas canvas, {
    required Offset feet,
    required double h,
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
    AvatarHead hat = AvatarHead.fedora,
    bool hatOn = true,
    bool dame = false,
    bool cement = false,
    _Kit kit = _Kit.none,
  }) {
    if (h < 1) return;
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
        if (stride <= 0) return Offset(rest * h, 0);
        // Mentre il passo si accorcia i piedi tornano alla posa da fermo,
        // così chi si ferma non scatta.
        final settle = rest * h * (1 - min(1.0, stride));
        final cycle = (phase / (2 * pi)) % 1;
        final reach = stride * h * 0.21;
        if (cycle < 0.5) return Offset(settle + _mix(reach, -reach, cycle * 2), 0);
        final swing = (cycle - 0.5) * 2;
        return Offset(settle + _mix(-reach, reach, _smooth(swing)), -sin(pi * swing) * h * 0.075 * stride);
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
      if (cement && details) _cementBlock(canvas, Offset(h * 0.02, 0), h);

      canvas.save();
      canvas.translate(hip.dx, hip.dy);
      canvas.rotate(lean);

      final swing = stride * sin(walk) * 0.45;
      final broad = dame ? 0.84 : 1.0;
      final coat = details && dame ? (Paint()..color = const Color(0xFF8A1622)) : paint;

      (Offset, Offset) armAt(Offset shoulder, double angle, double bend) {
        final joint = shoulder + _aim(angle) * (h * 0.185);
        final hand = joint + _aim(angle + bend) * (h * 0.175);
        _limb(canvas, shoulder, joint, h * 0.046, h * 0.038, coat);
        _limb(canvas, joint, hand, h * 0.038, h * 0.030, coat);
        canvas.drawCircle(hand, h * 0.034, paint);
        return (hand, _aim(angle + bend));
      }

      armAt(Offset(-h * 0.03 * broad, -h * 0.325), backArm - swing, backElbow);

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
      if (hatOn) _hat(canvas, head, h, dame ? AvatarHead.wideBrim : hat, paint, details: details);

      final (hand, along) = armAt(Offset(h * 0.035 * broad, -h * 0.325), arm + swing, elbow);
      if (details) _held(canvas, hand, along, h, kit);
      canvas.restore();
    }

    canvas.save();
    canvas.translate(-h * 0.016 * facing, -h * 0.010);
    body(Paint()..color = _rim, details: false);
    canvas.restore();
    body(Paint()..color = _ink, details: true);
    canvas.restore();
  }

  void _hat(Canvas canvas, Offset head, double h, AvatarHead hat, Paint paint, {required bool details}) {
    void band(double left, double right, double y) {
      if (!details) return;
      canvas.drawRect(
        Rect.fromLTRB(head.dx + h * left, head.dy + h * y, head.dx + h * right, head.dy + h * (y + 0.024)),
        Paint()..color = _rim,
      );
    }

    switch (hat) {
      case AvatarHead.fedora || AvatarHead.wideBrim || AvatarHead.borsalino || AvatarHead.panama || AvatarHead.trilby || AvatarHead.homburg:
        final wide = hat == AvatarHead.wideBrim;
        canvas.save();
        canvas.translate(head.dx + h * 0.02, head.dy - h * 0.050);
        canvas.rotate(0.10);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: h * (wide ? 0.44 : 0.33), height: h * 0.048), paint);
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
      case AvatarHead.bowler || AvatarHead.boater || AvatarHead.topHat:
        canvas.drawOval(Rect.fromCenter(center: head.translate(h * 0.01, -h * 0.052), width: h * 0.27, height: h * 0.04), paint);
        canvas.drawArc(Rect.fromCenter(center: head.translate(h * 0.005, -h * 0.052), width: h * 0.18, height: h * 0.22), pi, pi, true, paint);
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
        canvas.drawArc(Rect.fromCenter(center: head.translate(-h * 0.008, -h * 0.012), width: h * 0.165, height: h * 0.180), pi * 0.95, pi * 1.05, true, paint);
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
        canvas.drawArc(Rect.fromCenter(center: head.translate(-h * 0.008, -h * 0.010), width: h * 0.165, height: h * 0.185), pi * 0.9, pi * 1.0, true, paint);
    }
  }

  void _held(Canvas canvas, Offset hand, Offset along, double h, _Kit kit) {
    final wood = Paint()
      ..color = const Color(0xFF6B4423)
      ..strokeWidth = h * 0.028
      ..strokeCap = StrokeCap.round;
    switch (kit) {
      case _Kit.none:
        break;
      case _Kit.torch:
        final tip = hand + along * (h * 0.26);
        canvas.drawLine(hand - along * (h * 0.06), tip, wood);
        final flicker = 1 + 0.18 * sin(t * 320 + hand.dx);
        canvas.drawCircle(
          tip.translate(0, -h * 0.05),
          h * 0.20,
          Paint()
            ..color = const Color(0xFFFF9A3B).withValues(alpha: 0.35)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.08),
        );
        for (final (scale, color) in const [(1.0, Color(0xFFFF6A2B)), (0.6, Color(0xFFFFE27A))]) {
          final r = h * 0.055 * scale;
          canvas.drawPath(
            Path()
              ..moveTo(tip.dx - r, tip.dy)
              ..quadraticBezierTo(tip.dx - r, tip.dy - r * 1.4, tip.dx + sin(t * 200) * r * 0.4, tip.dy - r * 2.6 * flicker)
              ..quadraticBezierTo(tip.dx + r, tip.dy - r * 1.4, tip.dx + r, tip.dy)
              ..close(),
            Paint()..color = color,
          );
        }
      case _Kit.fork:
        final top = hand + along * (h * 0.42);
        canvas.drawLine(hand - along * (h * 0.40), top, wood);
        final across = Offset(-along.dy, along.dx);
        final steel = Paint()
          ..color = _steel
          ..strokeWidth = h * 0.016
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(top - across * (h * 0.07), top + across * (h * 0.07), steel);
        for (final s in [-0.07, 0.0, 0.07]) {
          canvas.drawLine(top + across * (h * s), top + across * (h * s) + along * (h * 0.13), steel);
        }
      case _Kit.kerchief:
        final wave = sin(t * 180 + hand.dx);
        canvas.drawPath(
          Path()
            ..moveTo(hand.dx, hand.dy)
            ..quadraticBezierTo(hand.dx + h * 0.08, hand.dy - h * 0.03 * wave, hand.dx + h * 0.14, hand.dy + h * 0.02)
            ..lineTo(hand.dx + h * 0.10 + h * 0.03 * wave, hand.dy + h * 0.14)
            ..quadraticBezierTo(hand.dx + h * 0.04, hand.dy + h * 0.10, hand.dx - h * 0.01, hand.dy + h * 0.12)
            ..close(),
          Paint()..color = _cloth,
        );
      case _Kit.bindle:
        final tip = hand + along * (h * 0.40);
        canvas.drawLine(hand - along * (h * 0.05), tip, wood..strokeWidth = h * 0.022);
        canvas.drawCircle(tip.translate(0, h * 0.05), h * 0.085, Paint()..color = const Color(0xFF9C1B26));
        for (final (dx, dy) in const [(-0.04, 0.03), (0.03, 0.07), (0.02, 0.0), (-0.02, 0.10)]) {
          canvas.drawCircle(tip.translate(h * dx, h * (0.05 + dy - 0.05)), h * 0.012, Paint()..color = _cloth);
        }
    }
  }

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

  // ------------------------------------------------------------------ effetti

  void _spray(
    Canvas canvas,
    Offset origin,
    double life, {
    required int seed,
    required Color color,
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

  void _puff(Canvas canvas, Offset center, double life, {double size = 1, Color color = const Color(0xFF8E8A86)}) {
    if (life <= 0 || life >= 1) return;
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
      ..color = color.withValues(alpha: 0.55 * (1 - life))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, _u * 0.05);
    for (final (dx, dy, r) in [(-0.22, 0.0, 0.16), (0.0, -0.08, 0.22), (0.24, 0.02, 0.15)]) {
      canvas.drawCircle(center + Offset(dx * (1 + life), dy - life * 0.25) * (_u * size), _u * r * size * (0.6 + life), paint);
    }
  }

  void _flash(Canvas canvas, double life, {double strength = 0.8}) {
    if (life <= 0 || life >= 1) return;
    canvas.drawRect(Rect.fromLTWH(-_w, -_h, _w * 3, _h * 3), Paint()..color = Colors.white.withValues(alpha: strength * (1 - life) * (1 - life)));
  }

  /// Una stella: lo sprite che brilla, o con [cartoon] la stella a punte
  /// dei fumetti, piena del suo colore.
  void _star(Canvas canvas, Offset center, double radius, Color color, {bool cartoon = false}) {
    if (radius <= 0) return;
    final textures = sprites;
    if (textures != null && !cartoon) {
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
    final points = cartoon ? 10 : 16;
    for (var i = 0; i < points; i++) {
      final r = i.isEven ? radius : radius * (cartoon ? 0.45 : 0.42);
      final a = -pi / 2 + i * 2 * pi / points;
      final point = center + Offset(cos(a), sin(a)) * r;
      i == 0 ? path.moveTo(point.dx, point.dy) : path.lineTo(point.dx, point.dy);
    }
    path.close();
    if (cartoon) {
      canvas.drawPath(path, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.35
        ..strokeJoin = StrokeJoin.round
        ..color = _ink.withValues(alpha: color.a));
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  /// La parola da fumetto, centrata su [at]. [size] è in unità di figura.
  void _word(Canvas canvas, String word, double from, double length, Offset at, {double size = 0.34, Color fill = const Color(0xFFFFE27A)}) {
    final life = _span(t, from, from + length);
    if (life <= 0 || life >= 1) return;
    final pop = Curves.easeOutBack.transform(min(1, life / 0.2));
    final fade = 1 - Curves.easeIn.transform(_span(life, 0.6, 1));
    final px = _u * size * (word.length > 7 ? 0.62 : 1.0);

    TextPainter letters({Paint? outline, Color? color}) => TextPainter(
          text: TextSpan(
            text: word,
            style: TextStyle(
              fontSize: px,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              letterSpacing: px * 0.02,
              foreground: outline,
              color: color,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

    final edge = letters(
      outline: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = px * 0.20
        ..strokeJoin = StrokeJoin.round
        ..color = _ink.withValues(alpha: fade),
    );
    // La parola non esce mai dallo schermo.
    final scale = 0.45 + 0.55 * pop + 0.10 * life;
    final half = edge.width * scale / 2 + _w * 0.03;
    final x = half * 2 >= _w ? _w / 2 : at.dx.clamp(half, _w - half);
    canvas.save();
    canvas.translate(x, at.dy);
    canvas.rotate(-0.13);
    canvas.scale(min(scale, scale * _w * 0.94 / max(1, edge.width * scale)));
    final origin = Offset(-edge.width / 2, -edge.height / 2);
    edge.paint(canvas, origin);
    letters(color: _red.withValues(alpha: fade)).paint(canvas, origin.translate(px * 0.05, px * 0.05));
    letters(color: fill.withValues(alpha: fade)).paint(canvas, origin);
    canvas.restore();
  }

  @override
  bool shouldRepaint(VerdictScenePainter old) =>
      old.t != t || old.take != take || old.hat != hat || old.town != town || old.strings != strings;
}
