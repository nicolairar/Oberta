/// Le fazioni. I neutrali (Fesso, Piromane) giocano per sé: non vincono con
/// la città né con la famiglia, ma ognuno ha la sua vittoria personale.
enum Team { citizens, mafia, neutral }

enum Role {
  mafioso,
  padrino,
  sarto,
  compare,
  cittadino,
  detective,
  medico,
  cecchino,
  giornalista,
  becchino,
  guardaspalle,
  reduce,
  pregiudicato,
  messia,
  sindaco,
  portinaio,
  fesso,
  piromane,
}

/// Come si gioca: un telefono passato di mano in mano, o un telefono a testa.
enum PlayMode { sharedPhone, online }

/// A che famiglia di poteri appartiene un ruolo: serve a comporre mazzi
/// equilibrati (mai tre investigatori allo stesso tavolo piccolo...).
enum RoleCategory {
  /// Picciotto: spara con la famiglia.
  family,

  /// Padrino, Sarto, Compare: la famiglia con un potere in più.
  familyPower,

  /// Commissario, Becchino, Cronista.
  investigator,

  /// Dottore, Guardaspalle.
  protector,

  /// Cecchino: un colpo in più per la città.
  extraKill,

  /// Reduce, Pregiudicato: niente da fare di notte, ma pesano.
  passive,

  /// Messia, Sindaco: un potere una volta per partita, per la piazza.
  civic,

  /// Fesso, Piromane: giocano per sé.
  neutral,

  /// L'Onesto.
  plain,
}

/// Le regole di composizione di un ruolo: da quanti giocatori entra, quante
/// copie al massimo, la categoria e in che modalità esiste.
class RoleRule {
  final int minPlayers;

  /// `null`: quante ne servono (Picciotti, Onesti).
  final int? maxCopies;
  final RoleCategory category;
  final Set<PlayMode> modes;

  const RoleRule(
    this.category, {
    this.minPlayers = 3,
    this.maxCopies = 1,
    this.modes = const {PlayMode.sharedPhone, PlayMode.online},
  });
}

/// Le regole di un ruolo. I nomi, i motti e le spiegazioni stanno nei
/// pacchetti di lingua (`NarrationPack.roles`): qui non c'è testo per chi gioca.
extension RoleInfo on Role {
  Team get team => switch (this) {
        Role.mafioso || Role.padrino || Role.sarto || Role.compare => Team.mafia,
    Role.fesso || Role.piromane => Team.neutral,
        _ => Team.citizens,
      };

  /// La fazione che risulta a chi indaga. Quasi sempre è quella vera: ma il
  /// Padrino ha le carte in regola, e il Pregiudicato no.
  Team get apparentTeam => switch (this) {
        Role.padrino => Team.citizens,
        Role.pregiudicato => Team.mafia,
    // I neutrali non sono della famiglia: alle carte risultano cittadini.
    Role.fesso || Role.piromane => Team.citizens,
        _ => team,
      };

  /// Chi, nella famiglia, di notte vota l'agguato. Il Sarto vota come un
  /// Picciotto (o, una volta per partita, cuce una bocca invece di votare);
  /// il Compare no: il suo potere è la chat di giorno.
  bool get isKiller => this == Role.mafioso || this == Role.padrino || this == Role.sarto;

  RoleRule get rule => switch (this) {
        Role.mafioso => const RoleRule(RoleCategory.family, maxCopies: null),
        Role.padrino => const RoleRule(RoleCategory.familyPower, minPlayers: 10),
        Role.sarto => const RoleRule(RoleCategory.familyPower, minPlayers: 7),
        Role.compare => const RoleRule(RoleCategory.familyPower, minPlayers: 7, modes: {PlayMode.online}),
        Role.cittadino => const RoleRule(RoleCategory.plain, maxCopies: null),
        Role.detective => const RoleRule(RoleCategory.investigator, minPlayers: 4),
        Role.medico => const RoleRule(RoleCategory.protector, minPlayers: 5),
        Role.cecchino => const RoleRule(RoleCategory.extraKill, minPlayers: 7),
        Role.giornalista => const RoleRule(RoleCategory.investigator, minPlayers: 8),
        Role.becchino => const RoleRule(RoleCategory.investigator, minPlayers: 8),
        Role.guardaspalle => const RoleRule(RoleCategory.protector, minPlayers: 9),
        Role.reduce => const RoleRule(RoleCategory.passive, minPlayers: 9),
        Role.pregiudicato => const RoleRule(RoleCategory.passive, minPlayers: 10),
    Role.messia => const RoleRule(RoleCategory.civic, minPlayers: 10),
    Role.sindaco => const RoleRule(RoleCategory.civic, minPlayers: 9),
    Role.portinaio => const RoleRule(RoleCategory.investigator, minPlayers: 9),
    Role.fesso => const RoleRule(RoleCategory.neutral, minPlayers: 8),
    Role.piromane => const RoleRule(RoleCategory.neutral, minPlayers: 13),
      };

  /// Ostile alla città: finché è vivo la città non ha vinto.
  bool get isHostileNeutral => this == Role.piromane;

  /// Esiste in questa modalità? Il Compare vive solo online, dove c'è la chat.
  bool playableIn(PlayMode mode) => rule.modes.contains(mode);
}
