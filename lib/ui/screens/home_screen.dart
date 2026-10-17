import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_language.dart';
import '../../l10n/app_strings.dart';
import '../../network/fake_local_session.dart';
import '../../online/incoming_links.dart';
import '../../online/join_code.dart';
import '../../online/online_account.dart';
import '../../online/online_services.dart';
import '../widgets/home_account.dart';
import '../widgets/home_alley.dart';
import '../widgets/home_caption.dart';
import '../widgets/home_neon_sign.dart';
import '../widgets/home_posters.dart';
import '../widgets/home_settings_plate.dart';
import 'lobby_screen.dart';
import 'online/online_room_screen.dart';
import 'online/online_screen.dart';
import 'online/online_widgets.dart';
import 'online/profile_sheet.dart';
import 'online/sign_in_sheet.dart';
import '../../sound/fx_groups.dart';
import '../../sound/sound_stage.dart';

double _span(double t, double from, double to) => ((t - from) / (to - from)).clamp(0.0, 1.0);

/// La schermata iniziale: un vicolo di notte, sotto la pioggia. L'insegna
/// al neon fa da titolo, i manifesti sul muro fanno da menu: quello di
/// stasera apre la stanza, quello blu porta al gioco online con gli amici,
/// quello rosso annuncia la classificata.
///
/// L'angolo in alto a destra (vedi [HomeAlleyLayout.slot]) è riservato alle
/// impostazioni: la targhetta con l'ingranaggio compare solo se qualcuno
/// passa [onSettings], altrimenti lì c'è solo muro.
///
/// Se l'app ha l'online, l'angolo in alto a sinistra è dell'account: chi è
/// entrato ci trova il suo cartellino (ritratto, nome, livello, monete);
/// chi non è entrato trova accanto all'ingranaggio la targhetta «Accedi».
/// Il vicolo raccoglie anche i link delle stanze aperti da fuori (il QR
/// inquadrato con la fotocamera) e porta dritti al tavolo.
class HomeScreen extends StatefulWidget {
  /// Che cosa succede toccando l'ingranaggio. Senza, il pulsante non c'è.
  final VoidCallback? onSettings;

  /// Il server da usare. Senza, quello aperto da `main` (se c'è).
  final OnlineServices? services;

  /// Da dove arrivano i link delle stanze. Senza, quelli del telefono.
  final IncomingLinks? links;

  const HomeScreen({super.key, this.onSettings, this.services, this.links});

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

  late final OnlineServices? _online = widget.services ?? OnlineServices.instance;
  late final OnlineAccount? _account = switch (_online) {
    final online? => OnlineAccount(online)..addListener(_accountChanged),
    null => null,
  };
  late final IncomingLinks _links = widget.links ?? IncomingLinks.instance;

  /// Il suggerimento sulla targhetta «Accedi» è acceso.
  bool _coach = false;

  /// La stanza di un link, in attesa che chi l'ha aperto entri e abbia il profilo.
  String? _pendingRoom;
  bool _joining = false;
  bool _settingUp = false;

  /// L'account per cui si è già chiesto di finire il profilo: si chiede una volta.
  String? _setupAskedFor;

  @override
  void initState() {
    super.initState();
    _account;
    _links.addListener(_linkArrived);
    // Un link arrivato prima del vicolo (l'app aperta proprio dal QR).
    WidgetsBinding.instance.addPostFrameCallback((_) => _linkArrived());
  }

  void _accountChanged() {
    if (!mounted) return;
    final account = _account!;
    setState(() {
      if (account.signedIn) _coach = false;
    });
    if (account.error case final error? when _pendingRoom != null) {
      _pendingRoom = null;
      showFailure(context, error);
      return;
    }
    _continue();
  }

  /// Dopo l'accesso: prima il profilo, se è da finire, poi la stanza del
  /// link, se c'era. Non si apre niente sopra un'altra pagina.
  void _continue() {
    final account = _account;
    final profile = account?.profile;
    if (!mounted || account == null || profile == null) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    if (!profile.isComplete) {
      final userId = profile.id;
      if (_pendingRoom != null || _setupAskedFor != userId) {
        _setupAskedFor = userId;
        _openSetup(profile);
      }
      return;
    }
    if (_pendingRoom case final code?) {
      _pendingRoom = null;
      _joinRoom(code, profile);
    }
  }

  /// Il nome unico e il nome da mostrare, su una pagina a parte.
  Future<void> _openSetup(Profile profile) async {
    if (_settingUp) return;
    _settingUp = true;
    final saved = await Navigator.of(context).push<Profile>(
      MaterialPageRoute(builder: (_) => ProfileSetupScreen(services: _online!, profile: profile)),
    );
    _settingUp = false;
    if (!mounted) return;
    if (saved == null) {
      _pendingRoom = null;
      return;
    }
    _account!.saved(saved);
  }

  Future<void> _joinRoom(String code, Profile me) async {
    if (_joining) return;
    _joining = true;
    final navigator = Navigator.of(context);
    try {
      final room = await _online!.rooms.join(code);
      if (!mounted) return;
      await navigator.push(MaterialPageRoute<void>(
        builder: (_) => OnlineRoomScreen(services: _online, room: room, me: me),
      ));
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      _joining = false;
    }
  }

  void _linkArrived() {
    if (!mounted) return;
    if (_links.take() case final uri?) _openLink(uri);
  }

  /// Un link di stanza aperto da fuori: chi è dentro va al tavolo, chi non
  /// è entrato prima entra (e si fa il profilo), poi ci va.
  Future<void> _openLink(Uri uri) async {
    if (!JoinCode.isRoomLink(uri)) return;
    final t = AppStrings.of(context).online;
    final code = JoinCode.fromLink(uri);
    if (code == null) return showNote(context, t.roomLinkInvalid);
    final online = _online;
    if (online == null) return showNote(context, t.unavailableBody);
    _pendingRoom = code;
    if (_coach) setState(() => _coach = false);
    if (online.auth.signedIn) return _continue();
    final signedIn = await showSignInSheet(context, services: online, note: t.roomLinkSignIn(code));
    if (!signedIn) {
      _pendingRoom = null;
      return;
    }
    _continue();
  }

  /// Il foglio dell'accesso; con [test], l'account di prova.
  Future<void> _signIn({bool test = false}) async {
    if (_coach) setState(() => _coach = false);
    final signedIn = await showSignInSheet(context, services: _online!, test: test);
    if (signedIn) _continue();
  }

  void _openProfile() {
    final account = _account!;
    if (account.profile case final profile? when !profile.isComplete) {
      _openSetup(profile);
      return;
    }
    showProfileSheet(context, account: account);
  }

  /// Porta la corrente all'insegna: chi si accende, chi sfarfalla.
  void _wire() {
    final jolt = _short.isAnimating ? HomeNeonSign.shortAt(_short.value) : 1.0;
    final seconds = _ambient.value * HomeStreetPainter.loop;
    final intro = _intro.value * HomeStreetPainter.opening;
    _neon.set(
      [
        for (final power in HomeNeonSign.powerAt(seconds, intro)) power * jolt,
      ],
      ghost: HomeNeonSign.ghostAt(seconds, intro, jolt: jolt),
    );
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
    _links.removeListener(_linkArrived);
    _account?.dispose();
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

  /// Il gioco online: le stanze e gli amici. Chi non è entrato non ci va:
  /// il vicolo si spegne e la luce gli indica la targhetta «Accedi».
  void _playWithFriends() {
    HapticFeedback.selectionClick();
    SoundStage.instance.press(Press.tap);
    final account = _account;
    if (account != null && !account.signedIn) {
      setState(() => _coach = true);
      return;
    }
    if (account?.profile case final profile? when !profile.isComplete) {
      _openSetup(profile);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => OnlineScreen(services: _online)));
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
    final account = _account;
    final signedIn = account?.signedIn ?? false;
    final signInPlate = account != null && !signedIn;
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
                    child: CustomPaint(
                      painter: HomeWallPainter(layout, plaque: signedIn ? null : t.alleyPlaque, signIn: signInPlate),
                    ),
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
                  if (signInPlate)
                    Positioned.fromRect(
                      rect: layout.signIn,
                      child: HomeSignInPlate(
                        key: const Key('home.signIn'),
                        label: t.online.signIn,
                        onTap: _signIn,
                        onLongPress: () => _signIn(test: true),
                      ),
                    ),
                  if (signedIn)
                    Positioned.fromRect(
                      rect: layout.badge,
                      child: HomeProfileBadge(
                        key: const Key('home.badge'),
                        profile: account!.profile,
                        pickHandle: t.online.pickHandle,
                        levelLabel: t.online.levelShort,
                        coinsLabel: t.online.coins,
                        onTap: _openProfile,
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
                      title: t.online.posterTitle,
                      blurb: t.online.posterBlurb,
                      emblem: HomeSoonEmblem.phones,
                      paper: const Color(0xFF1C3148),
                      seed: 8,
                      onTap: _playWithFriends,
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
                  if (_coach && signInPlate)
                    Positioned.fill(
                      child: HomeCoachMark(
                        target: layout.signIn,
                        caption: t.online.coachSignIn,
                        still: _still,
                        onTarget: _signIn,
                        onDismiss: () => setState(() => _coach = false),
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
