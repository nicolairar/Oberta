import '../rules/game_engine.dart';
import '../rules/role.dart';

/// Un pezzo di storia con un nome stabile: il testo cambia con la lingua,
/// l'[id] no, e servirà alle animazioni per mettere in scena lo stesso pezzo.
class StoryPiece {
  final String id;
  final String text;

  const StoryPiece(this.id, this.text);
}

/// Le battute di una scena divise per variante: l'id della variante, e le
/// frasi che la raccontano.
extension VariantLines on Map<String, List<String>> {
  /// Tutte le battute, di qualunque variante.
  List<String> get allLines => [for (final lines in values) ...lines];
}

/// Come si presenta un ruolo in una lingua: il nome di scena, la frase che
/// il personaggio direbbe di sé, e le regole in righe secche: cosa fa di
/// notte, quando vince, e al massimo un'avvertenza. Niente metafore qui: il
/// colore sta nel motto.
class RoleText {
  final String label;
  final String motto;

  /// Cosa fa il ruolo e quando vince, in poche frasi semplici.
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
  /// arriva in tempo. Nominano sempre la persona presa di mira. Ogni scena
  /// ha più varianti (il campanile, la cabina, l'ambulanza...), ognuna col
  /// suo filmato: le battute stanno sotto l'id della variante, così il
  /// racconto dice sempre quello che si vede.
  final Map<String, List<String>> sniperShots;
  final Map<String, List<String>> rescues;

  /// Come si chiama, nel racconto, chi si è salvato: nessuno deve sapere chi
  /// fosse, quindi è solo "qualcuno".
  final String someone;
  final String savedFact;

  /// Il colpo che non va a segno perché chi era nel mirino ha la pelle
  /// dura: si ferma sulla fiaschetta nel taschino, la pistola s'inceppa, il
  /// killer scivola. Anche qui, battute per variante. Il fatto non dice perché.
  final Map<String, List<String>> shrugs;
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

  /// Lo stesso, per la partita online: lì non si parla, si scrive in chat.
  final String silencedFactOnline;

  final String dayInstruction;
  final String oneMinute;
  final String manyMinutes;

  final List<String> voteCalls;
  final String voteInstruction;

  /// Il telefono che passa di mano: chi lo prende ({name}), e che gli altri
  /// guardino altrove; per la carta, che nessun altro la veda.
  final String passPhone;
  final String curtainHint;
  final String cardCurtainHint;

  /// La mossa della notte è fatta: il telefono va posato.
  final String putPhoneDown;

  /// Il voto a turno, col telefono in mezzo: tocca a {name}.
  final String voterTurn;

  final List<String> lynchScenes;
  final String cardTurns;
  final String wasMafia;
  final String wasCitizen;

  /// Il condannato non stava con nessuno: Fesso o Piromane.
  final String wasNeutral;
  final List<String> lynchedInnocent;
  final List<String> lynchedMafioso;
  final List<String> lynchedLastMafioso;
  final List<String> noLynch;
  final String noLynchFact;

  /// La tregua del Pacifista: oggi non si vota, nessuno sale sul patibolo.
  final List<String> truces;
  final String truceFact;

  /// Il crepacuore: muore un innamorato, l'altro lo segue ({name}).
  final List<String> heartbreaks;
  final String heartbreakFact;

  /// Gli innamorati di Cupido sono vivi tutti e due a fine partita.
  final String loversWinFact;

  /// La scorta del Presidente respinge un attentato; e il Presidente cade.
  final List<String> escorts;
  final String escortFact;
  final String presidentFallsFact;

  final List<String> citizensWin;
  final String citizensWinFact;
  final List<String> mafiaWins;
  final String mafiaWinsFact;

  /// Il Piromane accende il fiammifero: chi era cosparso brucia.
  final List<String> fires;
  final String burnedFact;

  /// Il Messia riporta in vita un linciato: torna con il suo ruolo.
  final List<String> resurrections;
  final String resurrectedFact;

  /// Il Fesso linciato: vince da solo, e la partita va avanti.
  final List<String> foolWins;
  final String foolWinsFact;

  /// Il Piromane resta in piedi: vince da solo.
  final List<String> arsonistWins;
  final String arsonistWinsFact;

  /// La taglia sale sul patibolo: il Cacciatore incassa, e la partita va
  /// avanti. Il fatto nomina il Cacciatore.
  final List<String> bountyWins;
  final String bountyWinsFact;

  /// Lo Strozzino vivo a fine partita, con {name}: vince insieme a chiunque.
  final String loanSharkWinsFact;

  /// Il Sicario resta in piedi: vince da solo.
  final List<String> assassinWins;
  final String assassinWinsFact;

  /// Il Sindaco si rivela (solo online, nella chat della piazza).
  final String mayorRevealed;

  /// Quello che il Portinaio ha visto dalla guardiola, la notte prima.
  final String watchVisited;
  final String watchQuiet;

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
    required this.someone,
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
    required this.silencedFactOnline,
    required this.dayInstruction,
    required this.oneMinute,
    required this.manyMinutes,
    required this.voteCalls,
    required this.voteInstruction,
    required this.passPhone,
    required this.curtainHint,
    required this.cardCurtainHint,
    required this.putPhoneDown,
    required this.voterTurn,
    required this.lynchScenes,
    required this.cardTurns,
    required this.wasMafia,
    required this.wasCitizen,
    required this.wasNeutral,
    required this.lynchedInnocent,
    required this.lynchedMafioso,
    required this.lynchedLastMafioso,
    required this.noLynch,
    required this.noLynchFact,
    required this.truces,
    required this.truceFact,
    required this.heartbreaks,
    required this.heartbreakFact,
    required this.loversWinFact,
    required this.escorts,
    required this.escortFact,
    required this.presidentFallsFact,
    required this.citizensWin,
    required this.citizensWinFact,
    required this.mafiaWins,
    required this.mafiaWinsFact,
    required this.fires,
    required this.burnedFact,
    required this.resurrections,
    required this.resurrectedFact,
    required this.foolWins,
    required this.foolWinsFact,
    required this.arsonistWins,
    required this.arsonistWinsFact,
    required this.bountyWins,
    required this.bountyWinsFact,
    required this.loanSharkWinsFact,
    required this.assassinWins,
    required this.assassinWinsFact,
    required this.mayorRevealed,
    required this.watchVisited,
    required this.watchQuiet,
    required this.taskPrompts,
    required this.taskHints,
    required this.decoyPrompts,
  });

  RoleText role(Role role) => roles[role]!;
}
