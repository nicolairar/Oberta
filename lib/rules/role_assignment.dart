import 'dart:math';

import 'player.dart';
import 'role.dart';

/// Numero minimo di giocatori con un ruolo (narratore escluso).
const minRolePlayers = 3;

/// Numero massimo di giocatori con un ruolo: oltre, il tavolo non si regge.
const maxRolePlayers = 12;

/// Quanti della famiglia per [count] giocatori: 1 fino a 6, 2 fino a 11,
/// 3 a 12. Con 3 a 11 giocatori la Famiglia vinceva due partite su tre
/// (simulazione, `docs/ruoli.md` 2.5).
int mafiaCountFor(int count) => count <= 6
    ? 1
    : count <= 11
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

/// Quanti neutrali almeno: nessuno sotto i 9 giocatori, uno da 9, due da 11.
/// A 8 un neutrale può uscire, ma non per forza.
int minNeutralsFor(int count) => count < 9
    ? 0
    : count < 11
    ? 1
    : 2;

/// Quanti neutrali al massimo, in assoluto: due (si gioca al massimo in 12).
const maxNeutrals = 2;

/// Quanti neutrali al massimo per [count] giocatori: sempre [maxNeutrals].
/// Il Fesso non sta mai con più di un altro neutrale.
int maxNeutralsFor(int count) => maxNeutrals;

/// Il bilancio della Città per [count] giocatori: la somma dei punti
/// ([RoleInfo.points]) dei cittadini speciali non lo supera. Con un
/// neutrale L4 al tavolo vale un punto in più ([rolesForPlayerCount]).
///
/// Tarato con la simulazione (`tool/balance/simulate.dart`): fino a 6 la
/// Città ha un potere solo (con un mafioso è già favorita), a 7 e 8 tutto
/// quello che può (due della Famiglia contro sette o otto sono tanti), a 10
/// un po' meno.
int cityBudgetFor(int count) => switch (count) {
  <= 6 => 3,
  <= 9 => 8,
  10 => 7,
  11 => 9,
  _ => 10,
};

/// Il bilancio dei poteri della Famiglia: niente fino a 8 giocatori (a 7 e
/// 8 la Famiglia è già favorita), un potere medio da 9 a 11, due a 12.
int familyBudgetFor(int count) => count <= 8
    ? 0
    : count <= 11
    ? 2
    : 4;

/// Il bilancio dei neutrali: niente sotto gli 8 giocatori, poco fino a 10,
/// da 11 anche un neutrale forte (ma uno solo, vedi [neutralFits]).
int neutralBudgetFor(int count) => count < 8
    ? 0
    : count < 11
    ? 2
    : 7;

/// Quanti cittadini forti (L3: Commissario, Carceriere) al massimo: uno
/// sotto gli 8 giocatori, due da 8.
int maxStrongCitizensFor(int count) => count < 8 ? 1 : 2;

/// Da quanti giocatori può entrare un ruolo L4: uno solo per tavolo.
const minPlayersForL4 = 11;

bool _strong(Role role) => role.rule.tier.index >= RoleTier.l3.index;

int _points(Iterable<Role> roles) => roles.fold(0, (sum, role) => sum + role.points);

/// [role] può entrare tra i neutrali già pescati ([neutrals])? Al massimo un
/// assassino in proprio, al massimo uno che vince col linciaggio, con il
/// Fesso al massimo un altro neutrale, al massimo un neutrale forte (L3 o
/// L4), un L4 solo da [minPlayersForL4] giocatori, e dentro
/// [neutralBudgetFor].
bool neutralFits(Role role, List<Role> neutrals, int count) {
  final all = [...neutrals, role];
  if (all.length > maxNeutralsFor(count)) return false;
  if (all.where((r) => r.isHostileNeutral).length > 1) return false;
  if (all.where((r) => r.isLynchSeeker).length > 1) return false;
  if (all.where(_strong).length > 1) return false;
  if (role.rule.tier == RoleTier.l4 && count < minPlayersForL4) return false;
  if (_points(all) > neutralBudgetFor(count)) return false;
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
/// composizione (vedi `docs/ruoli.md`, 2.2):
/// - la famiglia è proporzionale ([mafiaCountFor]), con al massimo
///   [maxFamilyPowersFor] ruoli di potere, dentro [familyBudgetFor], e
///   sempre qualcuno che vota l'agguato ([RoleInfo.isKiller]);
/// - ogni ruolo entra dalla sua soglia, in una copia, solo nelle modalità in
///   cui esiste (il Compare e i ruoli nuovi solo online), e mai se è in
///   [exclude];
/// - investigatori e protettori al massimo [maxPerCategoryFor], un solo
///   colpo extra, cittadini speciali al massimo [maxSpecialCitizensFor],
///   cittadini forti al massimo [maxStrongCitizensFor], e i loro punti
///   dentro [cityBudgetFor] (un punto in più con un neutrale L4);
/// - i neutrali entrano prima, ognuno con probabilità 1/2, al posto di un
///   cittadino speciale, almeno [minNeutralsFor], al massimo [maxNeutralsFor]
///   e dentro [neutralFits]; con un assassino in proprio niente Cecchino;
/// - si pesca prima un investigatore, poi un protettore, poi il resto a caso;
/// - il contrappeso: da 7 giocatori, se la Città spende quasi tutto il suo
///   bilancio e la Famiglia non ha poteri, un Picciotto ne riceve uno.
///
/// Con lo stesso [random] (seminato) esce sempre lo stesso mazzo.
List<Role> rolesForPlayerCount(
  int count, {
  Random? random,
  PlayMode mode = PlayMode.sharedPhone,
  Set<Role> exclude = const {},
}) {
  if (count < minRolePlayers) {
    throw ArgumentError.value(count, 'count', 'servono almeno $minRolePlayers giocatori');
  }
  if (count > maxRolePlayers) {
    throw ArgumentError.value(count, 'count', 'si gioca al massimo in $maxRolePlayers');
  }
  final rng = random ?? Random();
  bool eligible(Role role) => role.playableIn(mode) && count >= role.rule.minPlayers && !exclude.contains(role);

  // La famiglia.
  final mafia = mafiaCountFor(count);
  final powerCap = min(maxFamilyPowersFor(count), mafia);
  final allPowers = [
    for (final role in Role.values)
      if (role.rule.category == RoleCategory.familyPower && eligible(role)) role,
  ];
  bool powerFits(Role role, List<Role> chosen) {
    final all = [...chosen, role];
    if (all.length > powerCap || _points(all) > familyBudgetFor(count)) return false;
    // Chi non vota l'agguato lascia sempre il posto a qualcuno che lo vota.
    return all.length < mafia || all.any((r) => r.isKiller);
  }

  final powers = [...allPowers]..shuffle(rng);
  final family = <Role>[];
  for (final role in powers) {
    if (family.length >= powerCap) break;
    if (!rng.nextBool()) continue;
    if (powerFits(role, family)) family.add(role);
  }

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
  final budget = cityBudgetFor(count) + (specials.any((r) => r.rule.tier == RoleTier.l4) ? 1 : 0);
  List<Role> town() => [
    for (final role in specials)
      if (role.team == Team.citizens) role,
  ];
  bool fits(Role role) {
    final rule = role.rule;
    if (rule.category == RoleCategory.plain || rule.category == RoleCategory.family) return false;
    if (rule.category == RoleCategory.familyPower || rule.category == RoleCategory.neutral) return false;
    if (!eligible(role)) return false;
    // Il Piromane e il Sicario sono già un colpo in più: niente Cecchino.
    if (rule.category == RoleCategory.extraKill && specials.any((r) => r.isHostileNeutral)) return false;
    // Il Presidente mai con chi uccide in proprio: chi vincerebbe, se cade?
    if (role == Role.presidente && specials.any((r) => r.isHostileNeutral)) return false;
    if (specials.where((r) => r == role).length >= (rule.maxCopies ?? count)) return false;
    final city = town();
    if (_points([...city, role]) > budget) return false;
    if (_strong(role) && city.where(_strong).length >= maxStrongCitizensFor(count)) return false;
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

  // Il contrappeso: una Città quasi al completo contro una Famiglia senza
  // poteri non è una partita.
  if (count >= 7 && family.isEmpty && _points(town()) >= budget - 1) {
    final options = [
      for (final role in allPowers)
        if (powerFits(role, family)) role,
    ];
    if (options.isNotEmpty) family.add(options[rng.nextInt(options.length)]);
  }
  family.addAll(List.filled(mafia - family.length, Role.mafioso));
  return [...family, ...specials, ...List.filled(citizens - specials.length, Role.cittadino)];
}

/// Distribuisce a caso un mazzo bilanciato. L'ordine della mappa segue [players].
Map<Player, Role> assignRoles(List<Player> players, [Random? random, PlayMode mode = PlayMode.sharedPhone]) {
  final rng = random ?? Random();
  final deck = rolesForPlayerCount(players.length, random: rng, mode: mode)..shuffle(rng);
  return Map.fromIterables(players, deck);
}
