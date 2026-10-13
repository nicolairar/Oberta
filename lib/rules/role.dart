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

extension RoleInfo on Role {
  /// Il nome di scena del ruolo.
  String get label => switch (this) {
        Role.mafioso => 'Il Picciotto',
        Role.padrino => 'Il Padrino',
        Role.sarto => 'Il Sarto',
        Role.cittadino => 'L\'Onesto',
        Role.detective => 'Il Commissario',
        Role.medico => 'Il Dottore',
        Role.cecchino => 'Il Cecchino',
        Role.giornalista => 'Il Cronista',
        Role.becchino => 'Il Becchino',
        Role.guardaspalle => 'Il Guardaspalle',
        Role.reduce => 'Il Reduce',
        Role.pregiudicato => 'Il Pregiudicato',
      };

  /// La frase che il personaggio direbbe di sé.
  String get motto => switch (this) {
        Role.mafioso => '«Niente di personale.»',
        Role.padrino => '«Io faccio solo favori. Chiedete in giro.»',
        Role.sarto => '«Cucio abiti di giorno e bocche di notte.»',
        Role.cittadino => '«Io non ho visto niente. Purtroppo è vero.»',
        Role.detective => '«Mentono tutti. Qualcuno meglio.»',
        Role.medico => '«Ricucio quello che gli altri strappano.»',
        Role.cecchino => '«Un colpo. Non due.»',
        Role.giornalista => '«La verità esce in edicola alle sei.»',
        Role.becchino => '«I miei clienti non mentono mai.»',
        Role.guardaspalle => '«Prima devono passare da me.»',
        Role.reduce => '«Mi hanno già sparato. Gente migliore di voi.»',
        Role.pregiudicato => '«Ho pagato tutto. La fedina non lo sa.»',
      };

  String get description => switch (this) {
        Role.mafioso => 'Ogni notte, insieme alla famiglia, scegli chi non vedrà l\'alba.',
        Role.padrino =>
          'Scegli con la famiglia chi non vedrà l\'alba. Al Commissario risulti innocente.',
        Role.sarto =>
          'Ogni notte togli la parola a qualcuno per un giorno. Se la famiglia resta senza sicari, uccidi tu.',
        Role.cittadino => 'Nessun potere, solo occhi e lingua. Osserva, accusa, vota.',
        Role.detective => 'Ogni notte indaghi su qualcuno e scopri da che parte sta.',
        Role.medico => 'Ogni notte proteggi qualcuno. Mai la stessa persona due notti di fila.',
        Role.cecchino => 'Hai un solo proiettile per tutta la partita. Scegli bene la notte.',
        Role.giornalista =>
          'Hai un solo scoop: all\'alba tutti sapranno da che parte sta chi hai scelto. Se all\'alba ci arrivi.',
        Role.becchino =>
          'Ogni notte puoi scavare nella fossa di chi è morto di notte: scopri, solo tu, che ruolo aveva.',
        Role.guardaspalle =>
          'Ogni notte fai da scudo a qualcuno. Se quella notte finisce nel mirino, muori tu al suo posto.',
        Role.reduce =>
          'Hai la pelle dura: il primo agguato notturno contro di te va a vuoto. Il secondo no.',
        Role.pregiudicato =>
          'Stai con gli onesti, ma la fedina è sporca: al Commissario risulti della famiglia.',
      };

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
