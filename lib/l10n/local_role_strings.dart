import 'app_strings.dart';

/// The words of the newer roles on the shared phone: the private notes at a
/// player's turn (what reached them at dawn), the cell's written question
/// and answer, and the day powers used in front of everyone.
class LocalRoleStrings {
  final AppStrings strings;

  const LocalRoleStrings(this.strings);

  /// The text under `localRole.<key>` in the messages of the language.
  String _m(String key, [Map<String, Object?> args = const {}]) => strings.language.message('localRole.$key', args);

  // ---- Notes at your turn: what reached you at dawn.
  String get wasBusy => _m('wasBusy');
  String get wasJailed =>
      _m('wasJailed');
  String jailerAsked(String question) => _m('jailerAsked', {'question': question});
  String prisonerAnswered(String name, String answer) =>
      _m('prisonerAnswered', {'name': name, 'answer': answer});
  String foundFamily(String name) => _m('foundFamily', {'name': name});
  String foundClean(String name) => _m('foundClean', {'name': name});
  String foundRole(String name, String role) => _m('foundRole', {'name': name, 'role': role});

  // ---- The cell, on the phone.
  String get jailedTitle => _m('jailedTitle');
  String get jailedBody => _m('jailedBody');
  String get jailerAsks => _m('jailerAsks');
  String get answerHint => _m('answerHint');
  String get questionHint =>
      _m('questionHint');
  String jailed(String name) => _m('jailed', {'name': name});

  // ---- The cult.
  String get converted => _m('converted');
  String sect(String names) => _m('sect', {'names': names});
  String doorClosed(String name) => _m('doorClosed', {'name': name});
  String get sectWins => _m('sectWins');

  // ---- Cupid.
  String get linkSecond => _m('linkSecond');
  String linked(String a, String b) => _m('linked', {'a': a, 'b': b});
  String inLoveWith(String name) => _m('inLoveWith', {'name': name});
  String fateCannon(int round) => _m('fateCannon', {'round': round});
  String fateDay(int round) => _m('fateDay', {'round': round});

  // ---- The day powers, in front of everyone.
  String get truce => _m('truce');
  String get whoAreYou => _m('whoAreYou');
  String get notYou => _m('notYou');
  String get whoToReveal => _m('whoToReveal');
  String get cannon => _m('cannon');
  String get gunnerWhoAreYou => _m('gunnerWhoAreYou');
  String get notTheGunner => _m('notTheGunner');
  String get whoToHit => _m('whoToHit');
  String get marksman => _m('marksman');
  String get whoIsMarksman => _m('whoIsMarksman');
  String get notMarksman => _m('notMarksman');
  String aimed(String name, int left) =>
      _m('aimed', {'name': name, 'left': left});
  String get noAim => _m('noAim');
  String get fire => _m('fire');
  String get carryOn => _m('carryOn');
  String get cancel => _m('cancel');
  String get confirm => _m('confirm');
}
