import 'app_language.dart';
import 'app_strings.dart';

/// The words of the newer roles on the shared phone: the private notes at a
/// player's turn (what reached them at dawn), the cell's written question
/// and answer, and the day powers used in front of everyone.
class LocalRoleStrings {
  final AppStrings strings;

  const LocalRoleStrings(this.strings);

  bool get _en => strings.language == AppLanguage.en;

  String _t(String it, String en) => _en ? en : it;

  // ---- Notes at your turn: what reached you at dawn.
  String get wasBusy => _t('Ieri notte qualcuno ti ha tenuto occupato: la tua mossa è saltata.',
      'Last night someone kept you busy: your move was lost.');
  String get wasJailed =>
      _t('Ieri notte eri in cella: la tua mossa è saltata.', 'Last night you were in a cell: your move was lost.');
  String jailerAsked(String question) => _t('Il Carceriere chiedeva: «$question»', 'The Jailer asked: “$question”');
  String prisonerAnswered(String name, String answer) =>
      _t('Dalla cella, $name ha risposto: «$answer»', 'From the cell, $name answered: “$answer”');
  String foundFamily(String name) => _t('All\'alba: $name risulta della Famiglia.', 'At dawn: $name comes up Family.');
  String foundClean(String name) => _t('All\'alba: $name risulta pulito.', 'At dawn: $name comes up clean.');
  String foundRole(String name, String role) => _t('All\'alba: $name era $role.', 'At dawn: $name was the $role.');

  // ---- The cell, on the phone.
  String get jailedTitle => _t('Sei in cella', 'You are in a cell');
  String get jailedBody => _t('Stanotte non esci e nessuno ti tocca.', 'You are not going out tonight, and nobody can touch you.');
  String get jailerAsks => _t('Il Carceriere ti chiede:', 'The Jailer asks you:');
  String get answerHint => _t('La tua risposta (la leggerà solo lui)', 'Your answer (only the Jailer reads it)');
  String get questionHint =>
      _t('Una domanda per il prigioniero (facoltativa)', 'A question for the prisoner (optional)');
  String jailed(String name) => _t('$name è in cella.', '$name is in your cell.');

  // ---- The cult.
  String get converted => _t('Hai visto la luce: ora sei della setta, e vinci solo con lei.',
      'You have seen the light: you are in the cult now, and win only with it.');
  String sect(String names) => _t('La tua setta: $names.', 'Your cult: $names.');
  String doorClosed(String name) => _t('Ieri notte, porta chiusa: $name.', 'Last night, a shut door: $name.');
  String get sectWins => _t('Vince la setta', 'The cult wins');

  // ---- Cupid.
  String get linkSecond => _t('E chi altro? Tocca il secondo innamorato.', 'And who else? Tap the second lover.');
  String linked(String a, String b) => _t('Hai legato $a e $b.', 'You bound $a and $b.');
  String inLoveWith(String name) => _t('Il tuo cuore batte per $name: vincete solo vivi tutti e due.',
      'Your heart beats for $name: you win only if both of you live.');
  String fateCannon(int round) => _t('Cannonata, giorno $round', 'Shelled, day $round');
  String fateDay(int round) => _t('Di giorno, giorno $round', 'By day, day $round');

  // ---- The day powers, in front of everyone.
  String get truce => _t('Tregua del Pacifista', 'Pacifist\'s truce');
  String get whoAreYou => _t('Il Pacifista tocchi il proprio volto.', 'The Pacifist taps their own face.');
  String get notYou => _t('Solo il Pacifista può chiedere la tregua.', 'Only the Pacifist can call the truce.');
  String get whoToReveal => _t('Chi sveli a tutti?', 'Who do you reveal to everyone?');
  String get cannon => _t('Fuoco dell\'Artigliere', 'Gunner\'s fire');
  String get gunnerWhoAreYou => _t('L\'Artigliere tocchi il proprio volto.', 'The Gunner taps their own face.');
  String get notTheGunner => _t('Solo l\'Artigliere può sparare.', 'Only the Gunner can fire.');
  String get whoToHit => _t('Chi colpisci?', 'Who do you hit?');
  String get cancel => _t('Annulla', 'Cancel');
  String get confirm => _t('Conferma', 'Confirm');
}
