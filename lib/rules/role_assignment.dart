import 'dart:math';

import 'player.dart';
import 'role.dart';

/// Numero minimo di giocatori con un ruolo (narratore escluso).
const minRolePlayers = 3;

/// Numero massimo di giocatori con un ruolo: oltre, il tavolo non si regge.
const maxRolePlayers = 12;

/// Quanti della famiglia per [count] giocatori: 1 fino a 6, 2 fino a 10,
/// 3 a 11 e 12.
int mafiaCountFor(int count) => count <= 6
    ? 1
    : count <= 10
        ? 2
        : 3;

/// Quanti ruoli di famiglia con un potere (Padrino, Sarto, Compare) al
/// massimo: uno sotto gli 11 giocatori, due da 11. Mai tutti e tre.
int maxFamilyPowersFor(int count) => count < 11 ? 1 : 2;

/// Quanti investigatori, e quanti protettori, al massimo: uno sotto i 12
/// giocatori, due da 12.
int maxPerCategoryFor(int count) => count < 12 ? 1 : 2;

/// Quanti cittadini speciali al massimo: circa due terzi dei cittadini, così
/// gli Onesti restano una minoranza.
int maxSpecialCitizensFor(int citizens) => (citizens * 2) ~/ 3;

/// Quanti neutrali almeno: nessuno sotto gli 8 giocatori, uno da 8, due da 11.
int minNeutralsFor(int count) => count < 8 ? 0 : count < 11 ? 1 : 2;

/// Quanti neutrali al massimo, in assoluto: due (si gioca al massimo in 12).
const maxNeutrals = 2;

/// Quanti neutrali al massimo per [count] giocatori: sempre [maxNeutrals].
/// Il Fesso non sta mai con più di un altro neutrale.
int maxNeutralsFor(int count) => maxNeutrals;

/// [role] può entrare tra i neutrali già pescati ([neutrals])? Al massimo un
/// assassino in proprio, al massimo uno che vince col linciaggio, e con il
/// Fesso al massimo un altro neutrale.
bool neutralFits(Role role, List<Role> neutrals, int count) {
  final all = [...neutrals, role];
  if (all.length > maxNeutralsFor(count)) return false;
  if (all.where((r) => r.isHostileNeutral).length > 1) return false;
  if (all.where((r) => r.isLynchSeeker).length > 1) return false;
  return !all.contains(Role.fesso) || all.length <= 2;
}

int _categoryCap(RoleCategory category, int count) => switch (category) {
      RoleCategory.investigator || RoleCategory.protector => maxPerCategoryFor(count),
      RoleCategory.extraKill => 1,
      RoleCategory.familyPower => maxFamilyPowersFor(count),
      RoleCategory.family || RoleCategory.passive || RoleCategory.civic || RoleCategory.plain => count,
      RoleCategory.neutral => maxNeutralsFor(count),
    };

/// Un mazzo per [count] giocatori, pescato a caso dentro le regole di
/// composizione (vedi `docs/ruoli-analisi.md`):
/// - la famiglia è proporzionale ([mafiaCountFor]), con al massimo
///   [maxFamilyPowersFor] ruoli di potere e sempre qualcuno che spara;
/// - ogni ruolo entra dalla sua soglia, in una copia, solo nelle modalità in
///   cui esiste (il Compare solo online);
/// - investigatori e protettori al massimo [maxPerCategoryFor], un solo
///   colpo extra, cittadini speciali al massimo [maxSpecialCitizensFor];
/// - i neutrali entrano prima, ognuno con probabilità 1/2, al posto di un
///   cittadino speciale, almeno [minNeutralsFor], al massimo [maxNeutralsFor]
///   e dentro [neutralFits]; con un assassino in proprio niente Cecchino;
/// - si pesca prima un investigatore, poi un protettore, poi il resto a caso.
///
/// Con lo stesso [random] (seminato) esce sempre lo stesso mazzo.
List<Role> rolesForPlayerCount(int count, {Random? random, PlayMode mode = PlayMode.sharedPhone}) {
  if (count < minRolePlayers) {
    throw ArgumentError.value(count, 'count', 'servono almeno $minRolePlayers giocatori');
  }
  if (count > maxRolePlayers) {
    throw ArgumentError.value(count, 'count', 'si gioca al massimo in $maxRolePlayers');
  }
  final rng = random ?? Random();
  bool eligible(Role role) => role.playableIn(mode) && count >= role.rule.minPlayers;

  // La famiglia.
  final mafia = mafiaCountFor(count);
  final powers = [
    for (final role in Role.values)
      if (role.rule.category == RoleCategory.familyPower && eligible(role)) role,
  ]..shuffle(rng);
  final family = <Role>[];
  for (final role in powers) {
    if (family.length >= min(maxFamilyPowersFor(count), mafia)) break;
    if (!rng.nextBool()) continue;
    family.add(role);
  }
  family.addAll(List.filled(mafia - family.length, Role.mafioso));

  // I cittadini, e i neutrali che prendono il posto di qualcuno di loro.
  final citizens = count - mafia;
  final cap = maxSpecialCitizensFor(citizens);
  final specials = <Role>[];
  final neutrals = [
    for (final role in Role.values)
      if (role.rule.category == RoleCategory.neutral && eligible(role)) role,
  ]..shuffle(rng);
  final most = min(cap, maxNeutralsFor(count));
  final wanted = min(minNeutralsFor(count), most);
  for (final role in neutrals) {
    if (specials.length >= most) break;
    if (!neutralFits(role, specials, count)) continue;
    if (specials.length < wanted || rng.nextBool()) specials.add(role);
  }
  bool fits(Role role) {
    final rule = role.rule;
    if (rule.category == RoleCategory.plain || rule.category == RoleCategory.family) return false;
    if (rule.category == RoleCategory.familyPower || rule.category == RoleCategory.neutral) return false;
    if (!eligible(role)) return false;
    // Il Piromane e il Sicario sono già un colpo in più: niente Cecchino.
    if (rule.category == RoleCategory.extraKill && specials.any((r) => r.isHostileNeutral)) return false;
    if (specials.where((r) => r == role).length >= (rule.maxCopies ?? count)) return false;
    return specials.where((r) => r.rule.category == rule.category).length < _categoryCap(rule.category, count);
  }

  void pick(bool Function(Role) filter) {
    if (specials.length >= cap) return;
    final options = [
      for (final role in Role.values)
        if (filter(role) && fits(role)) role,
    ];
    if (options.isNotEmpty) specials.add(options[rng.nextInt(options.length)]);
  }

  pick((role) => role.rule.category == RoleCategory.investigator);
  pick((role) => role.rule.category == RoleCategory.protector);
  while (specials.length < cap) {
    final before = specials.length;
    pick((_) => true);
    if (specials.length == before) break;
  }
  return [...family, ...specials, ...List.filled(citizens - specials.length, Role.cittadino)];
}

/// Distribuisce a caso un mazzo bilanciato. L'ordine della mappa segue [players].
Map<Player, Role> assignRoles(List<Player> players, [Random? random, PlayMode mode = PlayMode.sharedPhone]) {
  final rng = random ?? Random();
  final deck = rolesForPlayerCount(players.length, random: rng, mode: mode)..shuffle(rng);
  return Map.fromIterables(players, deck);
}
