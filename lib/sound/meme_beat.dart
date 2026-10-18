import 'dart:math';

import 'memes.dart';
import 'sound_stage.dart';

/// I momenti della partita che meritano una battuta. Tutti pubblici: un meme
/// lo sente tutto il tavolo, quindi non dipende mai da un ruolo o da una
/// mossa segreta.
enum MemeMoment {
  gameStart([Meme.rizz, Meme.heeHee, Meme.vineBoom], big: true),
  deal([Meme.applePay, Meme.knocked, Meme.heeHee, Meme.animeAhh]),
  roleReveal([Meme.vineBoom, Meme.animeAhh, Meme.heeHee, Meme.error, Meme.rizz]),
  voteCall([Meme.dexter, Meme.vineBoom], big: true),
  voteCast([Meme.vineBoom, Meme.knocked, Meme.animeAhh, Meme.error, Meme.applePay, Meme.heeHee]),
  voteChanged([Meme.faaah, Meme.heeHee, Meme.rizz, Meme.animeAhh]),
  accused([Meme.vineBoom, Meme.faaah, Meme.knocked], big: true),
  nobodyDied([Meme.heeHee, Meme.catLaugh, Meme.rizz], big: true),
  save([Meme.applePay, Meme.rizz], big: true),
  silenced([Meme.animeAhh, Meme.knocked, Meme.heeHee]),
  scoop([Meme.vineBoom, Meme.faaah], big: true),
  timerEnd([Meme.error, Meme.faaah, Meme.knocked]),
  chatBurst([Meme.heeHee, Meme.animeAhh, Meme.rizz, Meme.error]),
  offline([Meme.error, Meme.knocked, Meme.faaah]),
  verdictMafia([Meme.vineBoom, Meme.knocked], big: true),
  verdictInnocent([Meme.catLaugh, Meme.hellNah, Meme.faaah], big: true),
  noConviction([Meme.chicken, Meme.heeHee], big: true),
  mafiaWins([Meme.catLaugh, Meme.hellNah], big: true),
  townWins([Meme.rizz, Meme.applePay, Meme.lutador], big: true);

  final List<Meme> pool;

  /// I colpi di scena: suonano sempre (in coda, mai sopra un altro meme).
  /// Gli altri rispettano la pausa tra un meme e l'altro.
  final bool big;

  const MemeMoment(this.pool, {this.big = false});
}

/// Il regista dei meme: decide *se* e *quale* meme suona, così che siano
/// tanti ma mai uno sopra l'altro, mai lo stesso due volte di fila, e i
/// lunghi (che zittiscono la musica) restino rari.
class MemeBeat {
  MemeBeat({DateTime Function()? clock, Random? dice, void Function(Meme meme, Duration after)? play})
    : _clock = clock ?? DateTime.now,
      _dice = dice ?? Random(),
      _play = play ?? ((meme, after) => SoundStage.instance.meme(meme, after: after));

  static MemeBeat instance = MemeBeat();

  /// Tra due meme qualsiasi (non colpi di scena) passa almeno questo: uno
  /// ogni 8–10 secondi fa ridere, di più stanca.
  static const smallGap = Duration(seconds: 9);

  /// Anche un colpo di scena non parte a ridosso dell'ultimo meme.
  static const bigGap = Duration(milliseconds: 2500);

  /// Una canzoncina lunga al massimo ogni tanto.
  static const longGap = Duration(seconds: 120);

  final DateTime Function() _clock;
  final Random _dice;
  final void Function(Meme meme, Duration after) _play;

  /// Se è falso nessun meme suona (si legge dalla modalità meme).
  bool Function() enabled = () => SoundStage.instance.memeMode;

  Meme? _last;
  DateTime _lastStart = DateTime(0);
  DateTime _busyUntil = DateTime(0);
  DateTime _lastLong = DateTime(0);

  Meme? get last => _last;

  /// Un meme partito per conto suo (le scene dei film hanno i loro): conta
  /// per le pause e per non ripetersi.
  void heard(Meme meme, {Duration after = Duration.zero}) {
    final start = _clock().add(after);
    _last = meme;
    _lastStart = start;
    final end = start.add(Duration(milliseconds: meme.millis));
    if (end.isAfter(_busyUntil)) _busyUntil = end;
    if (meme.isLong) _lastLong = start;
  }

  /// Il momento [moment] è arrivato: forse ci scappa un meme. Restituisce
  /// quello che suona, o `null` se stavolta si tace.
  Meme? hit(MemeMoment moment, {Duration after = Duration.zero}) {
    if (!enabled()) return null;
    final start = _clock().add(after);
    final sinceLast = start.difference(_lastStart);
    if (moment.big) {
      if (sinceLast < bigGap) return null;
    } else {
      // I meme piccoli: mai sopra un altro, e con calma.
      if (start.isBefore(_busyUntil) || sinceLast < smallGap) return null;
    }
    final longOk = !start.isBefore(_busyUntil) && start.difference(_lastLong) >= longGap;
    var choices = [
      for (final meme in moment.pool)
        if (meme != _last && (!meme.isLong || longOk)) meme,
    ];
    if (choices.isEmpty) {
      choices = [
        for (final meme in shortMemes)
          if (meme != _last) meme,
      ];
    }
    final meme = choices[_dice.nextInt(choices.length)];
    // Un colpo di scena mentre suona ancora qualcosa: aspetta la fine.
    final wait = start.isBefore(_busyUntil) ? _busyUntil.difference(start) : Duration.zero;
    heard(meme, after: after + wait);
    _play(meme, after + wait);
    return meme;
  }
}

/// Scorciatoia per gli schermi: `beat(MemeMoment.voteCast)`.
Meme? beat(MemeMoment moment, {Duration after = Duration.zero}) => MemeBeat.instance.hit(moment, after: after);
