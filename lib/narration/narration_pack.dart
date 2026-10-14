import '../rules/game_engine.dart';
import '../rules/role.dart';

/// Un pezzo di storia con un nome stabile: il testo cambia con la lingua,
/// l'[id] no, e servirà alle animazioni per mettere in scena lo stesso pezzo.
class StoryPiece {
  final String id;
  final String text;

  const StoryPiece(this.id, this.text);
}

/// Come si presenta un ruolo in una lingua: il nome di scena, la frase che
/// il personaggio direbbe di sé, e cosa fa, in una riga o due.
class RoleText {
  final String label;
  final String motto;
  final String description;

  const RoleText(this.label, this.motto, this.description);
}

/// La città vera in cui è ambientata una partita, con i suoi luoghi veri.
class CitySetting {
  final String id;

  /// Il nome da usare dentro le frasi ("Chicago").
  final String name;

  /// Il titolo di testa, con l'anno ("Chicago, 1929").
  final String title;
  final List<String> openings;

  /// Le ambientazioni delle morti notturne: tutte posti reali della città.
  final List<StoryPiece> scenes;

  const CitySetting({
    required this.id,
    required this.name,
    required this.title,
    required this.openings,
    required this.scenes,
  });
}

/// Tutti i testi del narratore in una lingua. Il codice che compone il
/// copione non contiene frasi: aggiungere una lingua è aggiungere un pacchetto.
///
/// Segnaposto: `{name}` il giocatore, `{role}` il ruolo, `{city}` la città,
/// `{minutes}` la durata. Le liste sono battute d'atmosfera, pescate a caso;
/// i campi singoli sono le frasi chiare che dicono cosa è successo e cosa si
/// fa adesso.
///
/// Il copione si legge ad alta voce a un tavolo che vuole giocare: ogni
/// battuta sta in una riga o due. Se è più lunga, nessuno la legge.
class NarrationPack {
  /// I dodici ruoli, come li chiamano la carta, il copione e la griglia.
  final Map<Role, RoleText> roles;

  final List<CitySetting> cities;
  final String howToPlay;

  final List<String> firstNights;
  final List<String> nights;
  final String nightInstruction;

  final String nobodyDied;
  final List<String> quietDawns;
  final List<String> secondVictims;
  final String victimFact;

  /// Quello che succede quando a sparare è il Cecchino, e quando il Dottore
  /// arriva in tempo. Nominano sempre la persona presa di mira.
  final List<String> sniperShots;
  final List<String> rescues;
  final String savedFact;

  /// Il colpo che non va a segno perché chi era nel mirino ha la pelle
  /// dura: si ferma sulla fiaschetta nel taschino. Il fatto non dice perché.
  final List<String> shrugs;
  final String shruggedFact;

  /// Gli strati di una morte notturna che non dipendono dalla città:
  /// l'azione e lo stacco finale. L'ambientazione viene dalla città.
  final List<StoryPiece> methods;
  final List<StoryPiece> epilogues;

  final List<String> scoops;
  final String scoopMafia;
  final String scoopClean;

  /// La bocca cucita dal Sarto: chi viene nominato oggi non può parlare.
  final List<String> silences;
  final String silencedFact;

  final String dayInstruction;
  final String oneMinute;
  final String manyMinutes;

  final List<String> voteCalls;
  final String voteInstruction;

  final List<String> lynchScenes;
  final String cardTurns;
  final String wasMafia;
  final String wasCitizen;
  final List<String> lynchedInnocent;
  final List<String> lynchedMafioso;
  final List<String> lynchedLastMafioso;
  final List<String> noLynch;
  final String noLynchFact;

  final List<String> citizensWin;
  final String citizensWinFact;
  final List<String> mafiaWins;
  final String mafiaWinsFact;

  final Map<NightTaskKind, String> taskPrompts;
  final Map<NightTaskKind, String> taskHints;
  final List<String> decoyPrompts;

  const NarrationPack({
    required this.roles,
    required this.cities,
    required this.howToPlay,
    required this.firstNights,
    required this.nights,
    required this.nightInstruction,
    required this.nobodyDied,
    required this.quietDawns,
    required this.secondVictims,
    required this.victimFact,
    required this.sniperShots,
    required this.rescues,
    required this.savedFact,
    required this.shrugs,
    required this.shruggedFact,
    required this.methods,
    required this.epilogues,
    required this.scoops,
    required this.scoopMafia,
    required this.scoopClean,
    required this.silences,
    required this.silencedFact,
    required this.dayInstruction,
    required this.oneMinute,
    required this.manyMinutes,
    required this.voteCalls,
    required this.voteInstruction,
    required this.lynchScenes,
    required this.cardTurns,
    required this.wasMafia,
    required this.wasCitizen,
    required this.lynchedInnocent,
    required this.lynchedMafioso,
    required this.lynchedLastMafioso,
    required this.noLynch,
    required this.noLynchFact,
    required this.citizensWin,
    required this.citizensWinFact,
    required this.mafiaWins,
    required this.mafiaWinsFact,
    required this.taskPrompts,
    required this.taskHints,
    required this.decoyPrompts,
  });

  RoleText role(Role role) => roles[role]!;
}
