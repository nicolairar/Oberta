import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_language.dart';
import '../../l10n/app_strings.dart';
import '../../network/fake_local_session.dart';
import '../widgets/home_alley.dart';
import '../widgets/home_caption.dart';
import '../widgets/home_neon_sign.dart';
import '../widgets/home_posters.dart';
import '../widgets/home_settings_plate.dart';
import 'lobby_screen.dart';
import '../../sound/fx_groups.dart';
import '../../sound/sound_stage.dart';

double _span(double t, double from, double to) => ((t - from) / (to - from)).clamp(0.0, 1.0);

/// La schermata iniziale: un vicolo di notte, sotto la pioggia. L'insegna
/// al neon fa da titolo, i manifesti sul muro fanno da menu: quello di
/// stasera apre la stanza, gli altri due annunciano le modalità che verranno.
///
/// L'angolo in alto a destra (vedi [HomeAlleyLayout.slot]) è riservato alle
/// impostazioni: la targhetta con l'ingranaggio compare solo se qualcuno
/// passa [onSettings], altrimenti lì c'è solo muro.
class HomeScreen extends StatefulWidget {
  /// Che cosa succede toccando l'ingranaggio. Senza, il pulsante non c'è.
  final VoidCallback? onSettings;

  const HomeScreen({super.key, this.onSettings});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  /// Quante volte si è passati di qui: decide da che didascalia cominciare.
  static int _visits = Random().nextInt(AppLanguage.it.strings.homeCaptions.length);

  /// Un momento tranquillo del giro, per chi vuole la scena ferma: nessuna
  /// lettera in corto, nessun gatto, la sigaretta accesa.
  static const _quietMoment = 0.105;

  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (HomeStreetPainter.loop * 1000).round()),
  )..addListener(_wire);
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (HomeStreetPainter.opening * 1000).round()),
  )..addListener(_wire);
  late final AnimationController _iris =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final AnimationController _short =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 620))..addListener(_wire);

  final _neon = HomeNeonState();
  final _caption = GlobalKey<HomeCaptionState>();
  final int _firstCaption = _visits++;

  bool _still = false;
  bool _leaving = false;

  /// Porta la corrente all'insegna: chi si accende, chi sfarfalla.
  void _wire() {
    final jolt = _short.isAnimating ? HomeNeonSign.shortAt(_short.value) : 1.0;
    _neon.set([
      for (final power in HomeNeonSign.powerAt(
        _ambient.value * HomeStreetPainter.loop,
        _intro.value * HomeStreetPainter.opening,
      ))
        power * jolt,
    ]);
  }

  /// Chi tocca l'insegna prende la scossa: i tubi saltano tutti insieme.
  void _touchSign() {
    HapticFeedback.heavyImpact();
    if (!_still) _short.forward(from: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    if (_still) {
      _ambient
        ..stop()
        ..value = _quietMoment;
      _intro
        ..stop()
        ..value = 1;
    } else {
      if (!_ambient.isAnimating) _ambient.repeat();
      if (!_intro.isAnimating && !_intro.isCompleted) _intro.forward();
    }
    _wire();
  }

  @override
  void dispose() {
    _ambient.dispose();
    _intro.dispose();
    _iris.dispose();
    _short.dispose();
    _neon.dispose();
    super.dispose();
  }

  /// Apre la stanza. Prima il nero si chiude a iride sul manifesto, come
  /// alla fine di una scena; al ritorno si riapre. Chi torna trascinando
  /// la lobby dal bordo non deve trovarci sotto il nero: l'iride si riapre
  /// appena il dito comincia a tirare.
  Future<void> _createRoom() async {
    if (_leaving) return;
    HapticFeedback.mediumImpact();
    // Si entra nella stanza sul retro: la porta, le fiches, e la musica del tavolo.
    final sound = SoundStage.instance;
    sound.effect(FxGroup.door, volume: 0.45);
    sound.press(Press.chips);
    sound.music(MusicMood.table);
    // Sotto la musica, il brusio della sala: bicchieri, voci lontane.
    sound.ambience(FxGroup.bar);
    sound.atmosphere(FxGroup.chips, after: const Duration(seconds: 4), volume: 0.6);
    final navigator = Navigator.of(context);
    final host = AppStrings.of(context).hostName;
    if (!_still) {
      setState(() => _leaving = true);
      await _iris.forward();
    }
    final session = FakeLocalSession(hostName: host);
    final dragging = navigator.userGestureInProgressNotifier;
    void reopen() {
      if (dragging.value && mounted) _iris.reverse();
    }

    dragging.addListener(reopen);
    await navigator.push(_OutOfTheDarkRoute(builder: (_) => LobbyScreen(session: session)));
    dragging.removeListener(reopen);
    // Fuori dalla stanza si torna nel vicolo, con la sua musica.
    SoundStage.instance
      ..music(MusicMood.menu)
      ..ambience(null);
    if (!mounted) return;
    setState(() => _leaving = false);
    _iris.reverse();
  }

  /// Le modalità che non ci sono ancora: il manifesto dondola e la
  /// didascalia risponde.
  void _notYet(String teaser) {
    HapticFeedback.selectionClick();
    SoundStage.instance.press(Press.tap);
    _caption.currentState?.say(teaser);
  }

  /// Un manifesto che all'apertura viene sbattuto sul muro: arriva grande e
  /// storto, e si assesta.
  Widget _posted({required Rect rect, required double tilt, required double at, required Widget child}) {
    return Positioned.fromRect(
      rect: rect,
      child: AnimatedBuilder(
        animation: _intro,
        child: RepaintBoundary(child: child),
        builder: (context, child) {
          final t = Curves.easeOutCubic.transform(_span(_intro.value * HomeStreetPainter.opening, at, at + 0.42));
          return IgnorePointer(
            ignoring: t < 0.9,
            child: Opacity(
              opacity: min(1, t * 2.5),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.rotationZ(tilt + (1 - t) * 0.12)
                  ..scaleByDouble(1 + (1 - t) * 0.4, 1 + (1 - t) * 0.4, 1, 1),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF07070B),
      // I manifesti sono oggetti del vicolo, non testo dell'interfaccia: si
      // ingrandiscono con lo schermo, non con le preferenze di lettura.
      body: MediaQuery.withNoTextScaling(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final layout = HomeAlleyLayout(constraints.biggest, MediaQuery.paddingOf(context));
            // I pittori sbordano di qualche mattone oltre lo schermo: va
            // tagliato, o si vede quando la pagina scorre via su iPhone.
            return ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(
                    child: CustomPaint(painter: HomeWallPainter(layout, plaque: t.alleyPlaque)),
                  ),
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: HomeNeonPainter(sign: layout.sign, cap: layout.cap, state: _neon),
                    ),
                  ),
                  // Il titolo vero: i tubi li disegna il pittore, ma chi usa
                  // VoiceOver deve poterlo leggere. E chi tocca l'insegna la
                  // manda in corto.
                  Positioned.fromRect(
                    rect: layout.sign,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _touchSign,
                      child: Semantics(
                        header: true,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(t.homeTitle, style: const TextStyle(color: Color(0x00000000))),
                        ),
                      ),
                    ),
                  ),
                  if (widget.onSettings case final onSettings?)
                    Positioned.fromRect(
                      rect: layout.slot,
                      child: HomeSettingsPlate(
                        label: t.settings,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onSettings();
                        },
                      ),
                    ),
                  _posted(
                    rect: layout.mainPoster,
                    tilt: -0.016,
                    at: 1.75,
                    child: HomeTonightPoster(
                      banner: t.tonight,
                      title: t.sharedTitle,
                      blurb: t.sharedBlurb,
                      action: t.createRoom,
                      onTap: _createRoom,
                      ambient: _ambient,
                    ),
                  ),
                  _posted(
                    rect: layout.leftPoster,
                    tilt: 0.030,
                    at: 2.05,
                    child: HomeSoonPoster(
                      title: t.ownTitle,
                      blurb: t.ownBlurb,
                      strip: t.soon,
                      emblem: HomeSoonEmblem.phones,
                      paper: const Color(0xFF1C3148),
                      seed: 8,
                      onTap: () => _notYet(t.ownTeaser),
                    ),
                  ),
                  _posted(
                    rect: layout.rightPoster,
                    tilt: -0.038,
                    at: 2.25,
                    child: HomeSoonPoster(
                      title: t.rankedTitle,
                      blurb: t.rankedBlurb,
                      strip: t.soon,
                      emblem: HomeSoonEmblem.laurel,
                      paper: const Color(0xFF581019),
                      seed: 21,
                      onTap: () => _notYet(t.rankedTeaser),
                    ),
                  ),
                  IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: HomeStreetPainter(layout: layout, ambient: _ambient, intro: _intro, neon: _neon),
                      ),
                    ),
                  ),
                  Positioned.fromRect(
                    rect: layout.caption,
                    child: IgnorePointer(
                      child: HomeCaption(
                        key: _caption,
                        lines: t.homeCaptions,
                        first: _firstCaption,
                        delay: HomeStreetPainter.opening - 0.3,
                      ),
                    ),
                  ),
                  IgnorePointer(
                    ignoring: !_leaving,
                    child: CustomPaint(
                      painter: HomeIrisPainter(
                        closing: _iris,
                        focus: Offset(
                          layout.mainPoster.center.dx,
                          layout.mainPoster.bottom - layout.mainPoster.height * 0.14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// La strada verso la lobby. All'andata la pagina affiora dal nero in cui
/// l'iride ha appena chiuso il vicolo; una volta arrivata si comporta come
/// ogni altra pagina, e su iPhone si torna indietro trascinando dal bordo.
class _OutOfTheDarkRoute extends MaterialPageRoute<void> {
  _OutOfTheDarkRoute({required super.builder});

  bool _arrived = false;

  @override
  TickerFuture didPush() => super.didPush()..whenCompleteOrCancel(() => _arrived = true);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // La transizione di sistema c'è sempre, perché è lei a portare il gesto
    // del ritorno: all'andata però la si tiene ferma a fine corsa, e a
    // muoversi è solo la dissolvenza.
    return FadeTransition(
      opacity: _arrived ? kAlwaysCompleteAnimation : animation,
      child: super.buildTransitions(
        context,
        _arrived ? animation : kAlwaysCompleteAnimation,
        secondaryAnimation,
        child,
      ),
    );
  }
}
