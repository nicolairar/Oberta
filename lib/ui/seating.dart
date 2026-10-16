import 'dart:math';

import '../rules/player.dart';

/// Dove sta ognuno sullo schermo. Di notte il telefono passa di mano e chi
/// siede accanto vede il dito di chi sceglie: se le facce stessero sempre
/// allo stesso posto, basterebbe ricordare il posto per sapere il bersaglio.
/// Così i tavoli segreti si rimescolano a ogni turno, e quello pubblico
/// segue un ordine che non dice niente (l'alfabeto).

/// Il tavolo pubblico, di giorno e al voto: per nome, sempre lo stesso.
List<Player> publicSeating(Iterable<Player> players) => [...players]
  ..sort((a, b) {
    final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return byName != 0 ? byName : a.id.compareTo(b.id);
  });

/// Un tavolo segreto, mescolato per chi ha il telefono adesso. Non ripete
/// l'ordine di [avoid] (il turno prima, il tavolo pubblico) se c'è modo di
/// evitarlo: due giocatori soli hanno solo due ordini.
List<Player> secretSeating(Iterable<Player> players, Random random, {List<List<Player>> avoid = const []}) {
  final seats = [...players];
  if (seats.length < 2) return seats;
  for (var attempt = 0; attempt < 12; attempt++) {
    seats.shuffle(random);
    if (!avoid.any((other) => _sameOrder(other, seats))) break;
  }
  return seats;
}

bool _sameOrder(List<Player> a, List<Player> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
