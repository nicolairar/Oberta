import 'dart:math';

/// Il piano dei lettori di una scena: ogni suono va su un lettore che, quando
/// arriva il suo fotogramma, è già pronto, col file caricato e la testina
/// dove il suono comincia davvero. Così al momento del colpo resta solo da
/// premere play.
///
/// Un lettore si può ricaricare solo quando il suono di prima è finito, e
/// ricaricarlo prende un po' ([rearm]): i suoni si danno a un lettore già
/// usato quando ha fatto in tempo a liberarsi, se no a uno nuovo, fino a
/// [maxPlayers]. Quelli che restano senza (`null`) partono a freddo, come
/// ogni altro suono.
///
/// [cues] sono in ordine di tempo: [at] quando deve sentirsi, [length]
/// quanto suona.
({List<int?> seats, int players}) planDeck(
  List<({Duration at, Duration length})> cues, {
  int maxPlayers = 12,
  Duration rearm = const Duration(milliseconds: 300),
}) {
  final freeAt = <Duration>[];
  final seats = <int?>[];
  for (final cue in cues) {
    int? seat;
    for (var p = 0; p < freeAt.length; p++) {
      if (freeAt[p] + rearm <= cue.at && (seat == null || freeAt[p] < freeAt[seat])) seat = p;
    }
    if (seat == null && freeAt.length < maxPlayers) {
      seat = freeAt.length;
      freeAt.add(Duration.zero);
    }
    if (seat != null) freeAt[seat] = cue.at + cue.length;
    seats.add(seat);
  }
  return (seats: seats, players: freeAt.length);
}

/// Il ritardo che resta anche col lettore pronto: da quando si preme play a
/// quando il suono esce davvero (il lettore che si avvia, il buffer
/// dell'altoparlante, le cuffie bluetooth). Il palco lo misura a ogni
/// suono delle scene, e le scene fanno partire i suoni con quell'anticipo.
///
/// Un fotogramma ([allowance]) non si anticipa: anche l'immagine ci mette
/// un giro di schermo ad arrivare, e un suono che arriva un filo prima di
/// quello che si vede si nota più di uno che arriva un filo dopo. Contano le
/// ultime [window] misure (la mediana, così una lettura storta non sposta
/// niente), e mai più di [most].
class LeadMeter {
  final Duration allowance;
  final Duration most;
  final int window;

  LeadMeter({
    this.allowance = const Duration(milliseconds: 16),
    this.most = const Duration(milliseconds: 150),
    this.window = 9,
  });

  final List<int> _late = [];

  /// Un suono partito [late] dopo che si è premuto play.
  void heard(Duration late) {
    // Fuori di qui non è il lettore che tarda: è una lettura sbagliata.
    if (late < const Duration(milliseconds: -20) || late > const Duration(seconds: 1)) return;
    _late.add(late.inMicroseconds);
    if (_late.length > window) _late.removeAt(0);
  }

  /// Quanto prima del loro fotogramma far partire i suoni.
  Duration get lead {
    if (_late.length < 3) return Duration.zero;
    final sorted = [..._late]..sort();
    final median = sorted[sorted.length ~/ 2];
    final ahead = median - allowance.inMicroseconds;
    return Duration(microseconds: max(0, min(ahead, most.inMicroseconds)));
  }
}
