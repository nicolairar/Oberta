import 'package:flutter/widgets.dart';

import 'app_language.dart';
import 'app_strings.dart';

/// I testi del tutorial, in italiano e in inglese: una frase per ogni
/// momento, con il tono del narratore.
class TutorialStrings {
  final AppLanguage language;

  const TutorialStrings(this.language);

  static TutorialStrings of(BuildContext context) => TutorialStrings(AppStrings.of(context).language);

  bool get _en => language == AppLanguage.en;

  String _t(String it, String en) => _en ? en : it;

  String get you => _t('Tu', 'You');
  String get skip => _t('Salta', 'Skip');
  String get next => _t('Avanti', 'Next');
  String get title => _t('Prima mano', 'First hand');

  // L'offerta al primo avvio, e le voci per rifarlo.
  String get offerTitle => _t('Prima volta in città?', 'First time in town?');
  String get offerBody => _t(
    'Una mano di prova contro cinque bot, due minuti. Impari tutto giocando.',
    'A practice hand against five bots, two minutes. Learn by playing.',
  );
  String get offerLater => _t('Più tardi', 'Later');
  String get offerStart => _t('Gioca il tutorial', 'Play the tutorial');
  String get replay => _t('Rifai il tutorial', 'Replay the tutorial');
  String get replayHint => _t('La mano di prova contro i bot.', 'The practice hand against the bots.');
  String get deskButton => _t('Tutorial', 'Tutorial');

  // I titoli dei momenti.
  String night(int round) => _t('NOTTE $round', 'NIGHT $round');
  String day(int round) => _t('GIORNO $round', 'DAY $round');

  // Le frasi del narratore, una per momento.
  String get coachWelcome =>
      _t('Stanotte la città dorme, la Famiglia no. Gioca con me.', 'Tonight the city sleeps. The Family does not. Play along.');
  String get coachCard => _t('Tieni premuta la carta: è il tuo ruolo segreto.', 'Hold the card down: it is your secret role.');
  String coachNight(String name) =>
      _t('Di notte indaghi. Tocca $name: qualcosa non torna.', 'At night you investigate. Tap $name: something is off.');
  String coachFinding(String name) =>
      _t('$name è della Famiglia. Solo tu lo sai, per ora.', '$name is Family. Only you know it, for now.');
  String get coachDawn => _t('All\'alba il giornale dice chi non ce l\'ha fatta.', 'At dawn the paper says who did not make it.');
  String get coachTalk => _t('In piazza si parla. Di\' quello che sai.', 'The square talks. Say what you know.');
  String coachVote(String name) =>
      _t('Ora si vota: punta il dito su $name.', 'Now the vote: point your finger at $name.');
  String get coachVerdict =>
      _t('Il linciato scopre la carta. La piazza ha visto giusto.', 'The lynched shows the card. The square got it right.');
  String get coachSaved =>
      _t('Stanotte cercavano te. Il Dottore ti ha salvato.', 'Tonight they came for you. The Doctor saved you.');
  String get coachWin => _t('Niente più Famiglia: la città ha vinto.', 'No Family left: the city wins.');

  // Il giornale.
  String get paper => _t('LA GAZZETTA DELLA NOTTE', 'THE NIGHT GAZETTE');
  String found(String name) => _t('$name trovato senza vita', '$name found dead');
  String get quiet => _t('Notte tranquilla: nessun morto', 'A quiet night: nobody died');
  String get quietSub => _t('Un agguato è andato a vuoto.', 'An ambush came to nothing.');
  String get foundSub => _t('Il suo ruolo resta un mistero.', 'Their role stays a mystery.');

  // L'indagine e il verdetto.
  String get family => _t('FAMIGLIA', 'FAMILY');
  String investigated(String name) => _t('Hai indagato su $name', 'You investigated $name');
  String condemned(String name) => _t('La carta di $name', '$name\'s card');
  String votesFor(int n) => _t('$n voti', '$n votes');

  // La piazza: i bot parlano, tu rispondi.
  List<(String, String)> chat(int round) => round == 1
      ? [
          ('Dora', _t('Bruno non faceva male a nessuno. Chi lo voleva morto?', 'Bruno never hurt anyone. Who wanted him dead?')),
          ('Vito', _t('Io ero al bar tutta la sera. Chiedete a Carmela.', 'I was at the bar all night. Ask Carmela.')),
          ('Carmela', _t('Confermo. Guardate Enzo, piuttosto: troppo calmo.', 'True. Look at Enzo instead: far too calm.')),
          ('Enzo', _t('Io? Commissario, tu cosa sai?', 'Me? Detective, what do you know?')),
        ]
      : [
          ('Dora', _t('Stanotte ho vegliato sul Commissario. Ci hanno provato.', 'I watched over the Detective tonight. They tried.')),
          ('Carmela', _t('Che fortuna... Vito però agiva da solo.', 'Lucky you... but Vito acted alone.')),
          ('Enzo', _t('Commissario, su chi hai indagato stanotte?', 'Detective, who did you check tonight?')),
        ];
  String accuse(String name) =>
      _t('Ho indagato su $name: è della Famiglia.', 'I investigated $name: Family.');

  // La fine.
  String get cityWins => _t('LA CITTÀ HA VINTO', 'THE CITY WINS');
  String get ready => _t('Ora sei pronto', 'Now you are ready');
  String get readyBody => _t(
    'Ogni sera i ruoli cambiano: a volte sarai tu a mentire. Il tavolo ti aspetta.',
    'Roles change every night: sometimes you will be the liar. The table is waiting.',
  );
  String get toTheTable => _t('Al tavolo', 'To the table');
}
