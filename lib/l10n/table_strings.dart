import 'package:flutter/widgets.dart';

import 'app_language.dart';
import 'app_strings.dart';
import 'player_gender.dart';

/// The words of the online table's action strip and of its prompts: what
/// to do now, what is chosen, who is waiting. Plain sentences, in Italian
/// and English.
class TableStrings {
  final AppLanguage language;

  const TableStrings(this.language);

  static TableStrings of(BuildContext context) => TableStrings(AppStrings.of(context).language);

  bool get _en => language == AppLanguage.en;

  String _t(String it, String en) => _en ? en : it;

  // ---- The card.
  String get holdTheCard => _t('Tieni premuta la carta per guardarla.', 'Press and hold the card to look at it.');

  // ---- The night.
  String picked(String name) =>
      _t('Hai scelto $name. Puoi cambiare fino allo scadere.', 'You picked $name. You can change until time runs out.');
  String get passed => _t('Hai passato. Puoi ancora scegliere qualcuno.', 'You passed. You can still pick someone.');
  String familyPicks(String picks) => _t('Famiglia: $picks', 'Family: $picks');
  String get nightRunsOut => _t('La notte finisce allo scadere del tempo.', 'The night ends when time runs out.');

  /// The question before an investigation or a dig: the answer is instant.
  String investigate(String name) => _t('Indaghi su $name?', 'Investigate $name?');
  String dig(String name) => _t('Scavi la fossa di $name?', 'Dig up $name?');
  String get instantAnswer =>
      _t('La risposta arriva subito, e poi non puoi cambiare.', 'The answer comes at once, and then you cannot change it.');
  String get cancel => _t('Annulla', 'Cancel');

  /// The Jailer's question: the cell closes at once.
  String jail(String name) => _t('Chiudi $name in cella?', 'Lock $name up?');
  String get jailBody => _t(
    'La cella si chiude subito: stanotte non agisce e nessuno lo tocca. Poi non puoi cambiare.',
    'The cell shuts at once: tonight they cannot act and nobody can touch them. You cannot change it.',
  );
  String get youAreJailed => _t('Sei in cella. Stanotte non esci.', 'You are in a cell. You are not going out tonight.');
  String get jailerWantsYou => _t('Il Carceriere vuole parlarti.', 'The Jailer wants a word.');
  String inYourCell(String name) => _t('In cella: $name. Interrogalo in chat.', 'In your cell: $name. Question them in the chat.');
  String mateInCell(String name) => _t('Stanotte $name è in cella.', 'Tonight $name is in a cell.');
  String get jailChat => _t('La cella', 'The cell');
  String get jailer => _t('Il Carceriere', 'The Jailer');
  // ---- Cupid.
  String get linkFirst => _t('Tocca il primo innamorato.', 'Tap the first lover.');
  String linkSecond(String name) => _t('$name e chi? Tocca il secondo.', '$name and who? Tap the second.');
  String link(String a, String b) => _t('Fai innamorare $a e $b?', 'Make $a and $b fall in love?');
  String get linkBody => _t(
    'Si sapranno innamorati all\'alba: vincono solo se restano vivi tutti e due. Poi non puoi cambiare.',
    'They learn it at dawn and win only if both live. You cannot change it.',
  );
  String loversLine(String a, String b) => _t('Innamorati: $a e $b.', 'Lovers: $a and $b.');
  String inLoveWith(String name) => _t('Il tuo cuore batte per $name.', 'Your heart beats for $name.');
  String get loversChat => _t('Gli innamorati', 'The lovers');
  String get answerAtDawn =>
      _t('Al tavolo c\'è chi blocca: la risposta arriva all\'alba.', 'Someone at this table blocks: the answer comes at dawn.');

  // ---- The day.
  String get readTheNews => _t('Leggi la cronaca, poi Pronto.', 'Read the news, then Ready.');
  String votedFor(String name) => _t('Hai votato $name. Puoi cambiare idea.', 'You voted $name. You can change your mind.');
  String abstained([Gender me = Gender.unknown]) => _t(
    agree(me, m: 'Ti sei astenuto. Puoi ancora votare.', f: 'Ti sei astenuta. Puoi ancora votare.', n: 'Astensione registrata. Puoi ancora votare.'),
    'You abstained. You can still vote.',
  );
  String get revealMayor => _t('Rivelati', 'Reveal');
  String get revealMayorTitle => _t('Ti riveli come Sindaco?', 'Reveal yourself as the Mayor?');
  String get revealMayorBody =>
      _t('Tutti sapranno chi sei, e da oggi il tuo voto vale doppio.', 'Everyone will know who you are, and your vote counts twice from today.');
  String silenced([Gender gender = Gender.unknown]) => _t(agree(gender, m: 'zittito', f: 'zittita'), 'silenced');

  // ---- The Pacifist's truce.
  String get truce => _t('Tregua', 'Truce');
  String get truceHint => _t('Tocca chi svelare a tutti.', 'Tap who to reveal to everyone.');
  String truceTitle(String name) => _t('Fermi tutti: sveli $name?', 'Stop everything: reveal $name?');
  String get truceBody => _t(
    'Tutti vedranno il suo ruolo esatto e il tuo. Oggi non si vota. Una volta sola.',
    'Everyone will see their exact role, and yours. No vote today. Only once.',
  );
  String truceLine(String pacifist, String name, String role) =>
      _t('$pacifist ha chiesto la tregua: $name è $role.', '$pacifist called a truce: $name is the $role.');
  String get truceVerdict => _t('Tregua: oggi non si impicca nessuno.', 'Truce: nobody hangs today.');

  /// The red stamp on the lynched seat.
  String lynched([Gender gender = Gender.unknown]) => _t(agree(gender, m: 'Linciato', f: 'Linciata'), 'Lynched');

  /// The verdict, short and plain: who, and which card. In Italian it agrees
  /// with the player; when nobody said how, the square does the lynching.
  String lynchedLine(String name, String? role, {Gender gender = Gender.unknown}) {
    final who = agree(
      gender,
      m: '$name è stato linciato.',
      f: '$name è stata linciata.',
      n: 'La piazza ha linciato $name.',
    );
    if (role == null) return _t(who, '$name was lynched.');
    final card = role.isEmpty ? role : role[0].toLowerCase() + role.substring(1);
    return _t('$who Era $card.', '$name was lynched. They were the $role.');
  }

  String get noLynch => _t('Nessuno è stato linciato.', 'Nobody was lynched.');
  String abstainedVotes(int n) => _t(n == 1 ? '1 astenuto' : '$n astenuti', '$n abstained');

  // ---- The chat, when it is closed.
  String get chatOpensLater => _t('La piazza riapre per la discussione.', 'The square opens again for the discussion.');
  String get chatOver => _t('La partita è finita.', 'The game is over.');

  // ---- The connection.
  String get rejoin => _t('Rientra', 'Rejoin');

  // ---- The end.
  String get leave => _t('Esci', 'Leave');
}
