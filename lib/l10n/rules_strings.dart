import 'package:flutter/widgets.dart';

import '../rules/role.dart';
import 'app_language.dart';
import 'app_strings.dart';

/// Come si racconta il gioco: in fretta, o come una favola da recitare.
enum RulesStyle { quick, stage }

/// Un capoverso delle regole. Le indicazioni di scena ([cue]) si leggono con
/// gli occhi, non con la voce: la voce del narratore le salta.
class RulesBeat {
  final String text;
  final bool cue;

  const RulesBeat(this.text) : cue = false;
  const RulesBeat.cue(this.text) : cue = true;
}

/// Un passo numerato delle regole: un titolo e pochi capoversi.
class RulesStep {
  final String title;
  final List<RulesBeat> beats;

  const RulesStep(this.title, this.beats);
}

/// Le regole del gioco da leggere ad alta voce prima di una partita su un
/// telefono solo: sei passi, in due versioni (sbrigativa e teatrale), nelle
/// due lingue. Chi cambia una frase rilancia `tool/voice/regenerate.sh`:
/// ogni capoverso detto ha la sua clip.
class RulesStrings {
  final AppLanguage language;

  const RulesStrings(this.language);

  static RulesStrings of(BuildContext context) => RulesStrings(AppStrings.of(context).language);

  bool get _en => language == AppLanguage.en;

  String _t(String it, String en) => _en ? en : it;

  // Il cartello sul palo e la pagina.
  String get sign => _t('Regole', 'Rules');
  String get title => _t('Regole del gioco', 'How to play');
  String get banner => _t('Da leggere ad alta voce', 'To be read aloud');
  String get pitch => _t(
    'Leggi questa pagina ad alta voce: in un minuto i tuoi amici sanno giocare.',
    'Read this page out loud: in one minute your friends know how to play.',
  );
  String style(RulesStyle style) => switch (style) {
    RulesStyle.quick => _t('Sbrigativa', 'Quick'),
    RulesStyle.stage => _t('Teatrale', 'Theatrical'),
  };
  String styleHint(RulesStyle style) => switch (style) {
    RulesStyle.quick => _t('Tutto il gioco in un minuto.', 'The whole game in a minute.'),
    RulesStyle.stage => _t('Una favola nera, da recitare.', 'A dark fairy tale, to perform.'),
  };
  String get readToMe => _t('Fammela leggere', 'Read it to me');
  String get stopReading => _t('Basta così', 'That will do');
  String get commonRoles => _t('I ruoli più comuni', 'The most common roles');
  String get commonRolesHint =>
      _t('Una riga ciascuno, per chi vuole sapere di più.', 'One line each, for the curious.');
  String get playLocal => _t('Giochiamo in locale', 'Let\'s play on one phone');
  String get playLocalHint => _t('Un telefono solo, passato di mano in mano.', 'One phone, passed from hand to hand.');
  String get playFriends => _t('Gioca con amici', 'Play with friends');
  String get playFriendsHint => _t(
    'In locale si gioca col telefono: da qui, una stanza online.',
    'One-phone games live on the phone: from here, an online room.',
  );
  String get back => _t('Indietro', 'Back');

  String team(Team team) => switch (team) {
    Team.citizens => _t('Città', 'Town'),
    Team.mafia => _t('Famiglia', 'Family'),
    Team.neutral => _t('Da solo', 'On their own'),
  };

  /// I ruoli che si incontrano quasi a ogni tavolo del telefono unico: quelli
  /// che entrano già con pochi giocatori. Si leggono dall'elenco dei ruoli,
  /// così chi ne aggiunge uno non deve ricordarsi di questa pagina.
  static List<Role> get commonRoleList => [
    for (final role in Role.values)
      if (role.playableIn(PlayMode.sharedPhone) && role.rule.minPlayers <= 7) role,
  ]..sort((a, b) => a.rule.minPlayers.compareTo(b.rule.minPlayers));

  /// La spiegazione del ruolo accorciata a una riga: le prime frasi, finché
  /// dicono qualcosa.
  static String oneLine(String description) {
    final sentences = RegExp(r'[^.!?]+[.!?]+').allMatches(description).map((m) => m.group(0)!.trim()).toList();
    if (sentences.isEmpty) return description;
    final out = StringBuffer(sentences.first);
    for (final sentence in sentences.skip(1)) {
      if (out.length >= 40) break;
      out.write(' $sentence');
    }
    return out.toString();
  }

  List<RulesStep> steps(RulesStyle style) => switch ((style, _en)) {
    (RulesStyle.quick, false) => _quickIt,
    (RulesStyle.quick, true) => _quickEn,
    (RulesStyle.stage, false) => _stageIt,
    (RulesStyle.stage, true) => _stageEn,
  };

  /// Tutto quello che la voce dice, nelle due versioni: il copione delle clip.
  List<String> get spoken => [
    for (final style in RulesStyle.values)
      for (final step in steps(style)) ...[
        step.title,
        for (final beat in step.beats)
          if (!beat.cue) beat.text,
      ],
  ];
}

const _quickIt = [
  RulesStep('Due squadre', [
    RulesBeat('Siamo in una città degli anni Quaranta. Quasi tutti sono gente perbene: la Città.'),
    RulesBeat('Qualcuno no. È la Famiglia, e stasera ha da fare.'),
    RulesBeat('I mafiosi si conoscono tra loro. Gli onesti non conoscono nessuno. Ed è questo il problema.'),
  ]),
  RulesStep('La carta è segreta', [
    RulesBeat('Il telefono fa il giro. Ognuno guarda il suo ruolo, da solo, e non lo dice a nessuno.'),
    RulesBeat('Di giorno puoi dire quello che vuoi su chi sei. Anche bugie. Soprattutto bugie.'),
  ]),
  RulesStep('La notte', [
    RulesBeat(
      'Di notte il telefono passa di mano in mano. Chi lo tiene fa la sua mossa in segreto; gli altri guardano altrove.',
    ),
    RulesBeat('La Famiglia sceglie chi far fuori. Il Commissario indaga, il Dottore salva.'),
    RulesBeat(
      'Chi non ha poteri tocca PASSO, con la stessa faccia degli altri. Nessuno deve capire chi ha fatto cosa.',
    ),
  ]),
  RulesStep('Il giorno', [
    RulesBeat('All\'alba si scopre chi non ce l\'ha fatta. Chi muore di notte si porta il ruolo nella tomba.'),
    RulesBeat('Poi si discute: accuse, alibi, facce strane.'),
    RulesBeat(
      'Alla fine si vota. Il più votato viene linciato, e si gira la sua carta. Pareggio? Oggi non si condanna nessuno.',
    ),
  ]),
  RulesStep('Chi vince', [
    RulesBeat('La Città vince quando la Famiglia è tutta fuori.'),
    RulesBeat('La Famiglia vince quando è tanta quanto tutti gli altri.'),
    RulesBeat('Qualche tipo strano gioca per sé: la sua carta gli dice come si vince.'),
  ]),
  RulesStep('Le regole d\'oro', [
    RulesBeat('Non sbirciare il telefono degli altri.'),
    RulesBeat('Non mostrare il tuo schermo a nessuno.'),
    RulesBeat('I morti non parlano. Nemmeno con gli occhi.'),
    RulesBeat('E nessuno si offende: è solo un gioco. Più o meno.'),
  ]),
];

const _quickEn = [
  RulesStep('Two sides', [
    RulesBeat('Picture a big city in the forties. Almost everyone is decent folk: the Town.'),
    RulesBeat('Some aren\'t. They\'re the Family, and tonight they\'ve got work to do.'),
    RulesBeat('The mobsters know each other. Honest folk know nobody. That\'s the problem.'),
  ]),
  RulesStep('Your card is secret', [
    RulesBeat('The phone goes round. Everyone looks at their role, alone, and tells no one.'),
    RulesBeat('By day you can say anything you like about who you are. Even lies. Especially lies.'),
  ]),
  RulesStep('The night', [
    RulesBeat(
      'At night the phone passes from hand to hand. Whoever holds it makes a secret move; everyone else looks away.',
    ),
    RulesBeat('The Family picks someone to rub out. The Detective investigates, the Doctor saves.'),
    RulesBeat('No powers? Tap PASS, with the same poker face as everyone else. Nobody should know who did what.'),
  ]),
  RulesStep('The day', [
    RulesBeat('At dawn you find out who didn\'t make it. Whoever dies at night takes their role to the grave.'),
    RulesBeat('Then you talk: accusations, alibis, funny looks.'),
    RulesBeat(
      'Finally, you vote. The most voted is lynched, and their card is turned over. A tie? Nobody hangs today.',
    ),
  ]),
  RulesStep('Who wins', [
    RulesBeat('The Town wins when the whole Family is out.'),
    RulesBeat('The Family wins when they are as many as everyone else.'),
    RulesBeat('A few odd types play for themselves: their card tells them how to win.'),
  ]),
  RulesStep('The golden rules', [
    RulesBeat('Don\'t peek at anyone else\'s phone.'),
    RulesBeat('Never show your screen to anyone.'),
    RulesBeat('Dead men don\'t talk. Not even with their eyes.'),
    RulesBeat('And nobody takes it personally: it\'s only a game. More or less.'),
  ]),
];

const _stageIt = [
  RulesStep('C\'era una volta', [
    RulesBeat.cue('Abbassa le luci. Aspetta il silenzio.'),
    RulesBeat(
      'C\'era una volta, in una città che non dorme mai, una piazza piena di brava gente. La chiamavano la Città.',
    ),
    RulesBeat(
      'Ma tra quella brava gente si nascondeva la Famiglia. Pochi, eleganti, armati. Si conoscevano tutti tra loro… e nessuno conosceva loro.',
    ),
    RulesBeat.cue('Guarda in faccia ognuno, lentamente.'),
    RulesBeat('Forse uno di loro è seduto a questo tavolo. Forse due.'),
  ]),
  RulesStep('La busta sigillata', [
    RulesBeat('A ciascuno di voi toccherà una busta sigillata: dentro c\'è chi siete davvero.'),
    RulesBeat.cue('Passa il telefono a chi hai a destra, come fosse una busta.'),
    RulesBeat('Leggetela da soli. Poi chiudetela nel cuore, e non ditela a nessuno.'),
    RulesBeat('Da domani potrete raccontare di voi tutto quello che volete. La verità… oppure no.'),
  ]),
  RulesStep('Quando cala la notte', [
    RulesBeat.cue('Abbassa la voce.'),
    RulesBeat('Quando cala la notte, il telefono passa di mano in mano, come un segreto che scotta.'),
    RulesBeat(
      'Chi lo stringe fa la sua mossa senza farsi vedere. Gli altri guardano il muro, il soffitto, le proprie scarpe.',
    ),
    RulesBeat(
      'La Famiglia sceglie chi non vedrà l\'alba. Il Commissario fruga negli affari altrui. Il Dottore veglia su qualcuno.',
    ),
    RulesBeat(
      'E chi non ha poteri? Recita. Tocca lo schermo con l\'aria di chi trama, perché nessuno sospetti di nessuno.',
    ),
  ]),
  RulesStep('All\'alba, la piazza', [
    RulesBeat.cue('Alza la voce, come un banditore.'),
    RulesBeat('All\'alba la città si sveglia e conta i suoi morti. Chi cade di notte se ne va col suo segreto.'),
    RulesBeat('Allora la piazza si riunisce: si accusa, si giura, si mente.'),
    RulesBeat.cue('Indica qualcuno, all\'improvviso.'),
    RulesBeat('Tu! Dov\'eri stanotte?'),
    RulesBeat(
      'Quando le voci tacciono, si vota. Chi prende più voti viene condannato, e la sua carta si gira davanti a tutti.',
    ),
    RulesBeat('Se i voti sono pari, la piazza si ferma: oggi nessuna condanna.'),
  ]),
  RulesStep('Come finisce la storia', [
    RulesBeat('La storia finisce bene per la Città quando l\'ultimo della Famiglia ha lasciato la piazza.'),
    RulesBeat(
      'Finisce bene per la Famiglia quando i suoi uomini sono tanti quanti tutti gli altri: da quel momento, la città è loro.',
    ),
    RulesBeat('E qualche anima solitaria gioca una partita tutta sua: la sua busta le dirà come si vince.'),
  ]),
  RulesStep('Le tre leggi della strada', [
    RulesBeat.cue('Lentamente, contando sulle dita.'),
    RulesBeat('Prima legge: non si sbircia nel telefono degli altri.'),
    RulesBeat('Seconda legge: il proprio schermo non si mostra a nessuno.'),
    RulesBeat('Terza legge: i morti non parlano. Né con la bocca, né con gli occhi.'),
    RulesBeat.cue('Pausa. Poi, sottovoce.'),
    RulesBeat('E adesso… che la notte cominci.'),
  ]),
];

const _stageEn = [
  RulesStep('Once upon a time', [
    RulesBeat.cue('Dim the lights. Wait for silence.'),
    RulesBeat(
      'Once upon a time, in a city that never sleeps, there was a square full of good people. They called it the Town.',
    ),
    RulesBeat(
      'But hiding among those good people was the Family. Few, elegant, armed. They all knew each other… and nobody knew them.',
    ),
    RulesBeat.cue('Look at each face, slowly.'),
    RulesBeat('Maybe one of them is sitting at this table. Maybe two.'),
  ]),
  RulesStep('The sealed envelope', [
    RulesBeat('Each of you will get a sealed envelope: inside is who you really are.'),
    RulesBeat.cue('Pass the phone to your right, as if it were an envelope.'),
    RulesBeat('Read it alone. Then lock it in your heart, and tell no one.'),
    RulesBeat('From tomorrow you may say anything you like about yourselves. The truth… or not.'),
  ]),
  RulesStep('When night falls', [
    RulesBeat.cue('Lower your voice.'),
    RulesBeat('When night falls, the phone passes from hand to hand, like a secret too hot to hold.'),
    RulesBeat('Whoever holds it makes their move unseen. The others stare at the wall, the ceiling, their own shoes.'),
    RulesBeat(
      'The Family chooses who won\'t see the dawn. The Detective pokes into other people\'s business. The Doctor watches over someone.',
    ),
    RulesBeat(
      'And those with no powers? They act. They tap the screen like schemers, so that nobody suspects anybody.',
    ),
  ]),
  RulesStep('At dawn, the square', [
    RulesBeat.cue('Raise your voice, like a town crier.'),
    RulesBeat('At dawn the city wakes up and counts its dead. Whoever falls at night leaves with their secret.'),
    RulesBeat('Then the square gathers: people accuse, swear, lie.'),
    RulesBeat.cue('Point at someone, suddenly.'),
    RulesBeat('You! Where were you last night?'),
    RulesBeat(
      'When the voices fall silent, you vote. Whoever gets the most votes is condemned, and their card is turned over for all to see.',
    ),
    RulesBeat('If the votes are tied, the square stands still: nobody is condemned today.'),
  ]),
  RulesStep('How the story ends', [
    RulesBeat('The story ends well for the Town when the last of the Family has left the square.'),
    RulesBeat(
      'It ends well for the Family when its men are as many as everyone else: from that moment, the city is theirs.',
    ),
    RulesBeat('And a few lonely souls play a game all their own: their envelope will tell them how to win.'),
  ]),
  RulesStep('The three laws of the street', [
    RulesBeat.cue('Slowly, counting on your fingers.'),
    RulesBeat('First law: you don\'t peek at anyone else\'s phone.'),
    RulesBeat('Second law: you show your screen to no one.'),
    RulesBeat('Third law: the dead don\'t talk. Not with their mouths, not with their eyes.'),
    RulesBeat.cue('A pause. Then, in a whisper.'),
    RulesBeat('And now… let the night begin.'),
  ]),
];
