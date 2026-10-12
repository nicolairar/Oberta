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
  String get label => switch (this) {
        Role.mafioso => 'Mafioso',
        Role.cittadino => 'Cittadino',
        Role.detective => 'Detective',
        Role.medico => 'Medico',
        Role.cecchino => 'Cecchino',
        Role.giornalista => 'Giornalista',
      };

  String get description => switch (this) {
        Role.mafioso => 'Ogni notte scegli una vittima insieme agli altri mafiosi.',
        Role.cittadino => 'Nessun potere speciale. Osserva, parla, vota con saggezza.',
        Role.detective => 'Ogni notte puoi indagare su un giocatore a tua scelta.',
        Role.medico => 'Ogni notte puoi proteggere un giocatore dalla morte.',
        Role.cecchino => 'Una sola volta nella partita puoi eliminare un giocatore.',
        Role.giornalista => 'Di tanto in tanto puoi rivelare un indizio a tutti.',
      };

  Team get team => this == Role.mafioso ? Team.mafia : Team.citizens;
}
