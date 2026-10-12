enum Team { citizens, mafia }

enum Role {
  mafioso,
  cittadino,
  detective,
  medico,
  cecchino,
  giornalista,
}

extension RoleInfo on Role {
  /// Il nome di scena del ruolo.
  String get label => switch (this) {
        Role.mafioso => 'Il Picciotto',
        Role.cittadino => 'L\'Onesto',
        Role.detective => 'Il Commissario',
        Role.medico => 'Il Dottore',
        Role.cecchino => 'Il Cecchino',
        Role.giornalista => 'Il Cronista',
      };

  /// La frase che il personaggio direbbe di sé.
  String get motto => switch (this) {
        Role.mafioso => '«Niente di personale.»',
        Role.cittadino => '«Io non ho visto niente. Purtroppo è vero.»',
        Role.detective => '«Mentono tutti. Qualcuno meglio.»',
        Role.medico => '«Ricucio quello che gli altri strappano.»',
        Role.cecchino => '«Un colpo. Non due.»',
        Role.giornalista => '«La verità esce in edicola alle sei.»',
      };

  String get description => switch (this) {
        Role.mafioso => 'Ogni notte, insieme alla famiglia, scegli chi non vedrà l\'alba.',
        Role.cittadino => 'Nessun potere, solo occhi e lingua. Osserva, accusa, vota.',
        Role.detective => 'Ogni notte indaghi su qualcuno e scopri da che parte sta.',
        Role.medico => 'Ogni notte proteggi qualcuno. Mai la stessa persona due notti di fila.',
        Role.cecchino => 'Hai un solo proiettile per tutta la partita. Scegli bene la notte.',
        Role.giornalista =>
          'Hai un solo scoop: all\'alba tutti sapranno da che parte sta chi hai scelto. Se all\'alba ci arrivi.',
      };

  Team get team => this == Role.mafioso ? Team.mafia : Team.citizens;
}
