import 'dart:async';

import '../ui/widgets/death_scene.dart';
import 'cue_sounds.dart';
import 'fx_groups.dart';
import 'memes.dart';
import 'scene_cues.dart';

/// Il sottofondo di ogni momento della partita.
enum MusicMood {
  menu,
  table,
  night,
  day,
  winTown,
  winFamily;

  /// I temi della vittoria suonano una volta sola, non girano in loop.
  bool get oneShot => this == winTown || this == winFamily;
}

/// I suoni dei tasti: ogni gesto ha il suo.
enum Press { tap, confirm, back, toggle, chips, card, shuffle }

/// Il mixaggio: quanto suona ogni famiglia di suoni rispetto al volume
/// degli effetti. La musica e il gioco davanti, i rumori di fondo dietro.
const mix = (
  scene: 0.75,
  cue: 0.8,
  press: 0.35,
  atmosphere: 0.3,
  ambience: 0.2,
  voice: 1.0,
);


/// Il palco del suono: chi mette in scena chiede, lui suona.
///
/// Di suo non fa rumore: è il palco muto dei test e di chi ha spento
/// l'audio. Quello vero ([DeviceStage]) si installa all'avvio.
class SoundStage {
  /// Il palco in uso. I test lo lasciano muto; `main` monta quello vero.
  static SoundStage instance = SoundStage();

  /// Spento, il palco non suona più niente finché non lo si riaccende.
  bool enabled = true;

  /// Quanto suonano la musica e gli effetti, da 0 a 1. Separati: chi vuole
  /// la musica bassa e gli spari forti può farlo.
  double musicVolume = 0.5;
  double effectsVolume = 0.8;

  /// La modalità meme: spenta, i meme non suonano mai.
  bool memeMode = false;

  /// Un meme, se la modalità meme è accesa. [after] lo ritarda.
  void meme(Meme meme, {Duration after = Duration.zero}) {}

  /// Un campione dei pacchetti Kenney (`assets/sounds/<name>.wav`).
  void sample(String name, {double volume = 1}) {}

  /// Un suono di una scena, al suo momento.
  void sceneCue(SceneCue cue) {
    if (cue.meme != null) {
      meme(cue.meme!);
    } else if (cue.fx != null) {
      effect(cue.fx!, volume: cue.gain * mix.scene);
    } else if (cue.sample != null) {
      sample(cue.sample!, volume: cue.gain * mix.scene);
    }
  }

  /// Cambia la musica di sottofondo: dissolvenza dalla traccia di prima a
  /// quella nuova (una a caso tra quelle di [mood]). Se suona già, resta.
  void music(MusicMood? mood) {}

  /// Il loop della schermata in vista: quando un brano che suona una volta
  /// sola (la vittoria) finisce, riparte questo. Lo mettono le schermate.
  MusicMood screenLoop = MusicMood.menu;

  /// Il palco avvisa qui quando [mood] è finito da solo: un brano che non
  /// gira in loop lascia il posto al loop della schermata.
  void musicEnded(MusicMood mood) {
    if (mood.oneShot && enabled) music(screenLoop);
  }

  /// Un sottofondo che gira in loop finché non lo si cambia (pioggia, grilli,
  /// vento), in dissolvenza; `null` lo spegne.
  void ambience(FxGroup? group) {}

  /// Un rumore di fondo (il gallo, gli uccelli, un treno lontano): entra in
  /// dissolvenza, resta sotto la musica, esce in dissolvenza. Più rumori di
  /// fondo possono suonare insieme.
  void atmosphere(FxGroup group, {Duration after = Duration.zero, double volume = 1}) {}

  /// Il suono di un tasto.
  void press(Press press) {}

  /// Abbassa la musica mentre va in scena un filmato, e la rialza dopo.
  void duckMusic(bool ducked) {}

  /// Una clip del narratore automatico (`assets/<asset>`), sul suo lettore:
  /// una alla volta, la nuova ferma la vecchia. Suona col volume degli effetti.
  void voice(String asset) {}

  /// Zittisce il narratore, subito.
  void stopVoice() {}

  /// Mentre parla il narratore, la musica e il sottofondo si fanno da parte.
  void duckForVoice(bool ducked) {}

  /// Un effetto registrato di [group], una registrazione a caso (mai la
  /// stessa due volte di fila). [after] lo ritarda.
  void effect(FxGroup group, {Duration after = Duration.zero, double volume = 1}) {}

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
