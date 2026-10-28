import 'role.dart';

/// Tutti i ruoli in un posto solo, con le loro regole di mazzo: per la
/// pagina della collezione dei ruoli e le statistiche per ruolo. I testi per
/// chi gioca (nome, motto, spiegazione) stanno nei pacchetti di lingua:
/// `AppLanguage.pack.role(entry.role)` (vedi `lib/narration/`).
class RoleCatalogEntry {
  final Role role;

  /// La squadra vera, e quella che risulta al Commissario.
  final Team team;
  final Team apparentTeam;

  /// Il livello di potere (`docs/ruoli.md`, 2.1) e i punti nel bilancio del
  /// mazzo (il Pregiudicato vale −1).
  final RoleTier tier;
  final int points;
  final RoleCategory category;

  /// Da quanti giocatori entra nel mazzo automatico.
  final int minPlayers;

  /// Dove esiste: telefono unico, online, o tutti e due.
  final Set<PlayMode> modes;

  /// Vota l'agguato della Famiglia.
  final bool killer;

  /// Neutrale che uccide in proprio: finché vive la Città non vince.
  final bool hostile;

  const RoleCatalogEntry({
    required this.role,
    required this.team,
    required this.apparentTeam,
    required this.tier,
    required this.points,
    required this.category,
    required this.minPlayers,
    required this.modes,
    required this.killer,
    required this.hostile,
  });

  /// Un id stabile, uguale al nome dell'enum (`detective`, `carceriere`...):
  /// è anche quello dell'icona (`assets/roles/<id>.png`) e delle statistiche.
  String get id => role.name;
}

/// Il catalogo, nell'ordine delle carte ([Role.values]).
final List<RoleCatalogEntry> roleCatalog = List.unmodifiable([
  for (final role in Role.values)
    RoleCatalogEntry(
      role: role,
      team: role.team,
      apparentTeam: role.apparentTeam,
      tier: role.rule.tier,
      points: role.points,
      category: role.rule.category,
      minPlayers: role.rule.minPlayers,
      modes: role.rule.modes,
      killer: role.isKiller,
      hostile: role.isHostileNeutral,
    ),
]);

/// I ruoli di una squadra, nell'ordine delle carte.
List<RoleCatalogEntry> rolesOfTeam(Team team) => [
  for (final entry in roleCatalog)
    if (entry.team == team) entry,
];
