import 'player.dart';

class VoteTally {
  final Map<Player, int> counts;

  const VoteTally(this.counts);

  /// I più votati, nell'ordine in cui hanno ricevuto il primo voto.
  /// Vuoto se si sono astenuti tutti; più di uno in caso di parità.
  List<Player> get leaders {
    if (counts.isEmpty) return const [];
    final top = counts.values.reduce((a, b) => a > b ? a : b);
    return [
      for (final entry in counts.entries)
        if (entry.value == top) entry.key,
    ];
  }
}

/// Conta i voti. Un voto `null` è un'astensione. [weights] dà a certi
/// votanti un peso diverso da uno (es. il capo mafia che vale doppio).
VoteTally tallyVotes(Map<Player, Player?> votes, {Map<Player, int> weights = const {}}) {
  final counts = <Player, int>{};
  votes.forEach((voter, choice) {
    if (choice == null) return;
    counts[choice] = (counts[choice] ?? 0) + (weights[voter] ?? 1);
  });
  return VoteTally(counts);
}
