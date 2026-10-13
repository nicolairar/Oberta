import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../network/fake_local_session.dart';
import '../widgets/home_alley.dart';
import '../widgets/home_caption.dart';
import '../widgets/home_neon_sign.dart';
import '../widgets/home_posters.dart';
import 'lobby_screen.dart';

/// Tutti i testi della schermata, in un posto solo: quando arriva la
/// traduzione basta sostituire questi.
abstract final class _Texts {
  static const title = 'OMERTÀ';

  /// La targa di marmo all'angolo del vicolo.
  static const alley = 'VICOLO DEL SILENZIO';

  // Il manifesto di stasera: un telefono solo, che ci si passa.
  static const tonight = 'STASERA SI GIOCA';
  static const sharedTitle = 'UN TELEFONO PER TUTTI';
  static const sharedBlurb = 'Si passa di mano in mano. Niente rete, niente testimoni.';
  static const createRoom = 'CREA STANZA';

  /// Il nome di chi apre la stanza, finché non lo si può scegliere.
  static const hostName = 'Tu';

  // I due manifesti di quello che arriverà.
  static const soon = 'PROSSIMAMENTE';
  static const ownTitle = 'UN TELEFONO\nA TESTA';
  static const ownBlurb = 'Ognuno col suo, e un codice di quattro lettere.';
  static const ownTeaser = 'Un telefono a testa: arriva con la rete. Pazienza.';
  static const rankedTitle = 'CLASSIFICATA';
  static const rankedBlurb = 'Sconosciuti, punti e una classifica da scalare.';
  static const rankedTeaser = 'La classificata apre presto. Intanto fatti un nome.';

  /// Le didascalie battute a macchina in fondo al vicolo: a ogni visita si
  /// comincia da una diversa.
  static const captions = [
    'Nessuno ha visto niente.',
    'Nessuno parla. Qualcuno muore.',
    'Tu non c\'eri. E se c\'eri, dormivi.',
    'In questa città anche i muri stanno zitti.',
    'Fidarsi è bene. Tacere è meglio.',
    'Chi sa, tace. Chi parla non vede l\'alba.',
    'Stanotte qualcuno non torna a casa.',
  ];
}

double _span(double t, double from, double to) => ((t - from) / (to - from)).clamp(0.0, 1.0);

/// La schermata iniziale: un vicolo di notte, sotto la pioggia. L'insegna
/// al neon fa da titolo, i manifesti sul muro fanno da menu: quello di
/// stasera apre la stanza, gli altri due annunciano le modalità che verranno.
///
/// L'angolo in alto a destra resta vuoto apposta (vedi
/// [HomeAlleyLayout.slot]): ci andrà il pulsante di impostazioni e lingua.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  /// Quante volte si è passati di qui: decide da che didascalia cominciare.
  static int _visits = Random().nextInt(_Texts.captions.length);

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
  /// alla fine di una scena; al ritorno si riapre.
  Future<void> _createRoom() async {
    if (_leaving) return;
    HapticFeedback.mediumImpact();
    final navigator = Navigator.of(context);
    if (!_still) {
      setState(() => _leaving = true);
      await _iris.forward();
    }
    final session = FakeLocalSession(hostName: _Texts.hostName);
    await navigator.push(PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, _, _) => LobbyScreen(session: session),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
    ));
    if (!mounted) return;
    setState(() => _leaving = false);
    _iris.reverse();
  }

  /// Le modalità che non ci sono ancora: il manifesto dondola e la
  /// didascalia risponde.
  void _notYet(String teaser) {
    HapticFeedback.selectionClick();
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
    return Scaffold(
      backgroundColor: const Color(0xFF07070B),
      // I manifesti sono oggetti del vicolo, non testo dell'interfaccia: si
      // ingrandiscono con lo schermo, non con le preferenze di lettura.
      body: MediaQuery.withNoTextScaling(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final layout = HomeAlleyLayout(constraints.biggest, MediaQuery.paddingOf(context));
            return Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: CustomPaint(painter: HomeWallPainter(layout, plaque: _Texts.alley)),
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
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(_Texts.title, style: TextStyle(color: Color(0x00000000))),
                      ),
                    ),
                  ),
                ),
                _posted(
                  rect: layout.mainPoster,
                  tilt: -0.016,
                  at: 1.75,
                  child: HomeTonightPoster(
                    banner: _Texts.tonight,
                    title: _Texts.sharedTitle,
                    blurb: _Texts.sharedBlurb,
                    action: _Texts.createRoom,
                    onTap: _createRoom,
                    ambient: _ambient,
                  ),
                ),
                _posted(
                  rect: layout.leftPoster,
                  tilt: 0.030,
                  at: 2.05,
                  child: HomeSoonPoster(
                    title: _Texts.ownTitle,
                    blurb: _Texts.ownBlurb,
                    strip: _Texts.soon,
                    emblem: HomeSoonEmblem.phones,
                    paper: const Color(0xFF1C3148),
                    seed: 8,
                    onTap: () => _notYet(_Texts.ownTeaser),
                  ),
                ),
                _posted(
                  rect: layout.rightPoster,
                  tilt: -0.038,
                  at: 2.25,
                  child: HomeSoonPoster(
                    title: _Texts.rankedTitle,
                    blurb: _Texts.rankedBlurb,
                    strip: _Texts.soon,
                    emblem: HomeSoonEmblem.laurel,
                    paper: const Color(0xFF581019),
                    seed: 21,
                    onTap: () => _notYet(_Texts.rankedTeaser),
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
                      lines: _Texts.captions,
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
            );
          },
        ),
      ),
    );
  }
}
