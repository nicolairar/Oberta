import 'package:flutter/widgets.dart';

import 'app_language.dart';
import 'app_strings.dart';

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

  // ---- The day.
  String get readTheNews => _t('Leggi la cronaca, poi Pronto.', 'Read the news, then Ready.');
  String votedFor(String name) => _t('Hai votato $name. Puoi cambiare idea.', 'You voted $name. You can change your mind.');
  String get abstained => _t('Ti sei astenuto. Puoi ancora votare.', 'You abstained. You can still vote.');
  String get revealMayor => _t('Rivelati', 'Reveal');
  String get revealMayorTitle => _t('Ti riveli come Sindaco?', 'Reveal yourself as the Mayor?');
  String get revealMayorBody =>
      _t('Tutti sapranno chi sei, e da oggi il tuo voto vale doppio.', 'Everyone will know who you are, and your vote counts twice from today.');
  String get silenced => _t('zittito', 'silenced');
  String get lynched => _t('Linciato', 'Lynched');
  String abstainedVotes(int n) => _t(n == 1 ? '1 astenuto' : '$n astenuti', '$n abstained');

  // ---- The chat, when it is closed.
  String get chatOpensLater => _t('La piazza riapre per la discussione.', 'The square opens again for the discussion.');
  String get chatOver => _t('La partita è finita.', 'The game is over.');

  // ---- The connection.
  String get rejoin => _t('Rientra', 'Rejoin');

  // ---- The end.
  String get leave => _t('Esci', 'Leave');
}
