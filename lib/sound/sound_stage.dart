import 'dart:async';

import '../ui/widgets/death_scene.dart';
import 'cue_sounds.dart';

/// Il palco del suono: chi mette in scena chiede, lui suona.
///
/// Di suo non fa rumore: è il palco muto dei test e di chi ha spento
/// l'audio. Quello vero ([DeviceStage]) si installa all'avvio.
class SoundStage {
  /// Il palco in uso. I test lo lasciano muto; `main` monta quello vero.
  static SoundStage instance = SoundStage();

  /// Spento, il palco non suona più niente finché non lo si riaccende.
  bool enabled = true;

  /// Avvisa che queste scene stanno per andare in onda, così la colonna
  /// sonora è pronta quando si spengono le luci.
  void prepare(Iterable<DeathAct> acts) {}

  /// Fa partire la colonna sonora di una scena.
  ///
  /// Un palco che suona davvero restituisce un `Future` che si chiude quando
  /// la musica è partita: il film aspetta quello, così immagini e suono
  /// cominciano insieme. Il palco muto risponde subito, senza attese.
  FutureOr<void> playScene(DeathAct act) {}

  /// A che punto è arrivato il nastro, se sta suonando: serve al film per
  /// rimettersi a tempo.
  Future<Duration?> position() async => null;

  /// Un suono breve per un gesto o un cambio di scena. Non ferma la musica
  /// di una scena, e più suoni brevi possono sovrapporsi.
  void cue(Cue cue) {}

  Future<void> stop() async {}
}
