import 'package:flutter/widgets.dart';

import 'fx_groups.dart';
import 'sound_stage.dart';

/// Chi guarda le pagine che vanno e vengono: serve a [ScreenMusic] per
/// sapere quando una schermata torna davanti. Va montato nel `MaterialApp`.
final RouteObserver<ModalRoute<void>> screenMusicRoutes = RouteObserver<ModalRoute<void>>();

/// Una schermata con la sua musica: la rimette quando entra e ogni volta che
/// torna davanti (chi stava sopra se n'è andato). Così la musica della
/// vittoria non resta accesa nel menu, e quando un brano che non gira in
/// loop finisce riparte quello della schermata in vista.
mixin ScreenMusic<T extends StatefulWidget> on State<T> implements RouteAware {
  /// La musica di questa schermata.
  MusicMood get screenMood;

  /// Il sottofondo di questa schermata: di solito nessuno.
  FxGroup? get screenAmbience => null;

  /// Vero mentre la schermata tiene a bada la musica da sé (per esempio
  /// mentre aspetta i risultati di una partita appena finita): al ritorno
  /// davanti non la cambia, ci pensa lei con [playScreenMusic].
  bool get musicHeld => false;

  ModalRoute<void>? _musicRoute;

  /// Rimette la musica (e il sottofondo) di questa schermata.
  void playScreenMusic() {
    final stage = SoundStage.instance;
    stage.screenLoop = screenMood;
    stage.music(screenMood);
    stage.ambience(screenAmbience);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == _musicRoute) return;
    if (_musicRoute != null) screenMusicRoutes.unsubscribe(this);
    _musicRoute = route;
    if (route != null) screenMusicRoutes.subscribe(this, route);
  }

  @override
  void dispose() {
    screenMusicRoutes.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPush() => playScreenMusic();

  @override
  void didPopNext() {
    if (!musicHeld) playScreenMusic();
  }

  @override
  void didPushNext() {}

  @override
  void didPop() {}
}
