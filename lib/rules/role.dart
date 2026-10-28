/// Le fazioni. I neutrali (Fesso, Piromane, Cacciatore di taglie, Strozzino,
/// Sicario) giocano per sé: non vincono con
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
  cacciatore,
  strozzino,
  sicario,
  prostituta,
  carceriere,
  pacifista,
  cupido,
  presidente,
  capoSetta,
  artigliere,
  tiratoreScelto,
}

/// Come si gioca: un telefono passato di mano in mano, o un telefono a testa.
enum PlayMode { sharedPhone, online }

/// A che famiglia di poteri appartiene un ruolo: serve a comporre mazzi
/// equilibrati (mai tre investigatori allo stesso tavolo piccolo...).
enum RoleCategory {
  /// Picciotto: spara con la famiglia.
  family,

  /// Padrino, Sarto, Compare, Prostituta: la famiglia con un potere in più.
  familyPower,

  /// Commissario, Becchino, Cronista.
  investigator,

  /// Dottore, Guardaspalle, Carceriere.
  protector,

  /// Cecchino, Artigliere, Tiratore scelto: un colpo in più per la città.
  extraKill,

  /// Reduce, Pregiudicato: niente da fare di notte, ma pesano.
  passive,

  /// Messia, Sindaco, Pacifista: un potere una volta per partita, per la piazza.
  civic,

  /// Fesso, Piromane, Cacciatore, Strozzino, Sicario: giocano per sé.
  neutral,

  /// L'Onesto.
  plain,
}

/// Quanto pesa un ruolo nel mazzo (`docs/ruoli.md`, 2.1): dal nessun potere
/// al potere che decide una partita da solo.
enum RoleTier {
  /// Nessun potere (o un malus).
  l0(0),

  /// Un potere piccolo o tardivo.
  l1(1),

  /// Un potere vero.
  l2(2),

  /// Un potere forte.
  l3(3),

  /// Un potere che vale per due.
  l4(5);

  /// I punti nel bilancio del mazzo: da L3 a L4 il salto è voluto.
  final int points;

  const RoleTier(this.points);
}

/// Le regole di composizione di un ruolo: da quanti giocatori entra, quante
/// copie al massimo, la categoria, il livello e in che modalità esiste.
class RoleRule {
  final int minPlayers;

  /// `null`: quante ne servono (Picciotti, Onesti).
  final int? maxCopies;
  final RoleCategory category;
  final RoleTier tier;
  final Set<PlayMode> modes;

  const RoleRule(
    this.category, {
    this.minPlayers = 3,
    this.maxCopies = 1,
    this.tier = RoleTier.l0,
    this.modes = const {PlayMode.sharedPhone, PlayMode.online},
  });
}

/// Le regole di un ruolo. I nomi, i motti e le spiegazioni stanno nei
/// pacchetti di lingua (`NarrationPack.roles`): qui non c'è testo per chi gioca.
extension RoleInfo on Role {
  Team get team => switch (this) {
    Role.mafioso || Role.padrino || Role.sarto || Role.compare || Role.prostituta => Team.mafia,
    Role.fesso || Role.piromane || Role.cacciatore || Role.strozzino || Role.sicario || Role.capoSetta => Team.neutral,
    _ => Team.citizens,
  };

  /// La fazione che risulta a chi indaga. Quasi sempre è quella vera: ma il
  /// Padrino ha le carte in regola, e il Pregiudicato no.
  Team get apparentTeam => switch (this) {
    Role.padrino => Team.citizens,
    Role.pregiudicato => Team.mafia,
    // Il Sicario ha la faccia del mestiere: alle carte risulta della famiglia.
    Role.sicario => Team.mafia,
    // Gli altri neutrali non sono della famiglia: alle carte risultano cittadini.
    Role.fesso || Role.piromane || Role.cacciatore || Role.strozzino || Role.capoSetta => Team.citizens,
    _ => team,
  };

  /// Chi, nella famiglia, di notte vota l'agguato: tutti tranne la
  /// Prostituta, che passa la notte altrove (vota solo se resta l'ultima
  /// della Famiglia che può farlo). Il Sarto vota come un Picciotto (o, una
  /// volta per partita, cuce una bocca invece di votare); il Compare vota e
  /// in più, finché vive, apre la chat di giorno.
  bool get isKiller => team == Team.mafia && this != Role.prostituta;

  /// I punti del ruolo nel bilancio del mazzo. Il Pregiudicato pesa meno di
  /// zero: è un guaio per la Città.
  /// Il Presidente pesa −2: è un punto debole della Città.
  int get points => switch (this) {
    Role.pregiudicato => -1,
    Role.presidente => -2,
    _ => rule.tier.points,
  };

  RoleRule get rule => switch (this) {
    Role.mafioso => const RoleRule(RoleCategory.family, maxCopies: null),
    Role.padrino => const RoleRule(RoleCategory.familyPower, minPlayers: 10, tier: RoleTier.l2),
    Role.sarto => const RoleRule(RoleCategory.familyPower, minPlayers: 7, tier: RoleTier.l2),
    Role.compare => const RoleRule(
      RoleCategory.familyPower,
      minPlayers: 7,
      tier: RoleTier.l1,
      modes: {PlayMode.online},
    ),
    Role.cittadino => const RoleRule(RoleCategory.plain, maxCopies: null),
    Role.detective => const RoleRule(RoleCategory.investigator, minPlayers: 4, tier: RoleTier.l3),
    Role.medico => const RoleRule(RoleCategory.protector, minPlayers: 5, tier: RoleTier.l2),
    Role.cecchino => const RoleRule(RoleCategory.extraKill, minPlayers: 7, tier: RoleTier.l2),
    Role.giornalista => const RoleRule(RoleCategory.investigator, minPlayers: 8, tier: RoleTier.l2),
    Role.becchino => const RoleRule(RoleCategory.investigator, minPlayers: 8, tier: RoleTier.l1),
    Role.guardaspalle => const RoleRule(RoleCategory.protector, minPlayers: 9, tier: RoleTier.l2),
    Role.reduce => const RoleRule(RoleCategory.passive, minPlayers: 9, tier: RoleTier.l1),
    Role.pregiudicato => const RoleRule(RoleCategory.passive, minPlayers: 10),
    Role.messia => const RoleRule(RoleCategory.civic, minPlayers: 10, tier: RoleTier.l2),
    Role.sindaco => const RoleRule(RoleCategory.civic, minPlayers: 9, tier: RoleTier.l1),
    Role.portinaio => const RoleRule(RoleCategory.investigator, minPlayers: 9, tier: RoleTier.l1),
    Role.fesso => const RoleRule(RoleCategory.neutral, minPlayers: 8, tier: RoleTier.l1),
    Role.piromane => const RoleRule(RoleCategory.neutral, minPlayers: 11, tier: RoleTier.l4),
    Role.cacciatore => const RoleRule(RoleCategory.neutral, minPlayers: 9, tier: RoleTier.l2),
    Role.strozzino => const RoleRule(RoleCategory.neutral, minPlayers: 10, tier: RoleTier.l1),
    Role.sicario => const RoleRule(RoleCategory.neutral, minPlayers: 12, tier: RoleTier.l3),
    // Sul telefono unico la cella non ha chat (una domanda e una risposta
    // scritte, al proprio turno) e le risposte che arrivano all'alba si
    // leggono al turno della notte dopo (docs/ruoli.md, 3.1).
    Role.prostituta => const RoleRule(RoleCategory.familyPower, minPlayers: 9, tier: RoleTier.l2),
    Role.carceriere => const RoleRule(RoleCategory.protector, minPlayers: 8, tier: RoleTier.l3),
    Role.pacifista => const RoleRule(RoleCategory.civic, minPlayers: 9, tier: RoleTier.l2),
    // Cupido lega due innamorati la prima notte, e poi non fa più niente.
    Role.cupido => const RoleRule(RoleCategory.civic, minPlayers: 9, tier: RoleTier.l1),
    // Il Presidente: pubblico dall'inizio, con la scorta; se muore la Città
    // perde. Mai con un neutrale che uccide in proprio.
    Role.presidente => const RoleRule(RoleCategory.passive, minPlayers: 10),
    // Il Capo della setta: ogni notte converte; vince quando tutti i vivi
    // sono della setta. Uno solo per tavolo, da 11.
    Role.capoSetta => const RoleRule(RoleCategory.neutral, minPlayers: 11, tier: RoleTier.l4),
    // L'Artigliere: due colpi di giorno, dal secondo giorno, che tutti
    // sentono. Un colpo extra: mai con Cecchino, Piromane o Sicario.
    Role.artigliere => const RoleRule(RoleCategory.extraKill, minPlayers: 10, tier: RoleTier.l3),
    // Il Tiratore scelto: di notte mira, di giorno spara (due colpi); se
    // colpisce uno della Città muore lui. Prende il posto del Cecchino ai
    // tavoli grandi ([rolesForPlayerCount]).
    Role.tiratoreScelto => const RoleRule(RoleCategory.extraKill, minPlayers: 9, tier: RoleTier.l3),
  };

  /// Ostile alla città, un assassino in proprio (Piromane, Sicario): finché
  /// è vivo la città non ha vinto. Al tavolo ce n'è al massimo uno.
  ///
  /// Il Capo della setta non uccide, ma conta come loro: finché vive la Città
  /// non vince, e non sta mai con il Piromane, il Sicario o il Presidente.
  bool get isHostileNeutral => this == Role.piromane || this == Role.sicario || this == Role.capoSetta;

  /// Non si converte alla setta: la Famiglia, chi uccide in proprio, il
  /// Presidente. Il Capo legge «Porta chiusa».
  bool get resistsConversion => team == Team.mafia || isHostileNeutral || this == Role.presidente;

  /// Vince con un linciaggio (Fesso, Cacciatore di taglie): al tavolo ce n'è
  /// al massimo uno, o la piazza diventa una lotteria.
  bool get isLynchSeeker => this == Role.fesso || this == Role.cacciatore;

  /// Chi tiene fermo qualcuno di notte (Prostituta, Carceriere): con uno di
  /// loro al tavolo le indagini rispondono all'alba, non subito.
  bool get isBlocker => this == Role.prostituta || this == Role.carceriere;

  /// Esiste in questa modalità? Il Compare vive solo online, dove c'è la chat.
  bool playableIn(PlayMode mode) => rule.modes.contains(mode);
}
