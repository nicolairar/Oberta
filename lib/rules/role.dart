enum Team { citizens, mafia }

enum Role {
  mafioso,
  padrino,
  sarto,
  cittadino,
  detective,
  medico,
  cecchino,
  giornalista,
  becchino,
  guardaspalle,
  reduce,
  pregiudicato,
}

/// Le regole di un ruolo. I nomi, i motti e le spiegazioni stanno nei
/// pacchetti di lingua (`NarrationPack.roles`): qui non c'è testo per chi gioca.
extension RoleInfo on Role {
  Team get team => switch (this) {
        Role.mafioso || Role.padrino || Role.sarto => Team.mafia,
        _ => Team.citizens,
      };

  /// La fazione che risulta a chi indaga. Quasi sempre è quella vera: ma il
  /// Padrino ha le carte in regola, e il Pregiudicato no.
  Team get apparentTeam => switch (this) {
        Role.padrino => Team.citizens,
        Role.pregiudicato => Team.mafia,
        _ => team,
      };

  /// Chi, nella famiglia, di notte vota l'agguato. Il Sarto ha altro da
  /// fare finché in casa c'è qualcuno che spara.
  bool get isKiller => this == Role.mafioso || this == Role.padrino;
}
