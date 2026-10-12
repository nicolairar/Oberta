import '../rules/game_engine.dart';

/// Un pezzo di storia con un nome stabile: il testo cambia con la lingua,
/// l'[id] no, e servirà alle animazioni per mettere in scena lo stesso pezzo.
class StoryPiece {
  final String id;
  final String text;

  const StoryPiece(this.id, this.text);
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
class NarrationPack {
  final List<CitySetting> cities;
  final List<String> premises;
  final String howToPlay;

  final List<String> firstNights;
  final List<String> nights;
  final String nightInstruction;

  final List<String> dawns;
  final String nobodyDied;
  final List<String> quietDawns;
  final List<String> secondVictims;
  final String victimFact;

  /// Gli strati di una morte notturna che non dipendono dalla città:
  /// inquadratura, azione, stacco finale. L'ambientazione viene dalla città.
  final List<StoryPiece> shots;
  final List<StoryPiece> methods;
  final List<StoryPiece> epilogues;

  final List<String> scoops;
  final String scoopMafia;
  final String scoopClean;

  final List<String> days;
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
    required this.cities,
    required this.premises,
    required this.howToPlay,
    required this.firstNights,
    required this.nights,
    required this.nightInstruction,
    required this.dawns,
    required this.nobodyDied,
    required this.quietDawns,
    required this.secondVictims,
    required this.victimFact,
    required this.shots,
    required this.methods,
    required this.epilogues,
    required this.scoops,
    required this.scoopMafia,
    required this.scoopClean,
    required this.days,
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
}
