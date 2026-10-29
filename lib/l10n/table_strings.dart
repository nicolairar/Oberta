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

  /// The text under `table.<key>` in the messages of the language.
  String _m(String key, [Map<String, Object?> args = const {}]) => language.message('table.$key', args);

  // ---- The card.
  String get holdTheCard => _m('holdTheCard');

  // ---- The night.
  String picked(String name) =>
      _m('picked', {'name': name});
  String get passed => _m('passed');
  String familyPicks(String picks) => _m('familyPicks', {'picks': picks});
  String get nightRunsOut => _m('nightRunsOut');

  /// The question before an investigation or a dig: the answer is instant.
  String investigate(String name) => _m('investigate', {'name': name});
  String dig(String name) => _m('dig', {'name': name});
  String get instantAnswer =>
      _m('instantAnswer');
  String get cancel => _m('cancel');

  /// The Jailer's question: the cell closes at once.
  String jail(String name) => _m('jail', {'name': name});
  String get jailBody => _m('jailBody');
  String get youAreJailed => _m('youAreJailed');
  String get jailerWantsYou => _m('jailerWantsYou');
  String inYourCell(String name) => _m('inYourCell', {'name': name});
  String get lastOfFamily => _m('lastOfFamily');
  String mateInCell(String name) => _m('mateInCell', {'name': name});
  String get jailChat => _m('jailChat');
  String get jailer => _m('jailer');
  // ---- The cult.
  String get converted =>
      _m('converted');
  String sectLine(String names) => _m('sectLine', {'names': names});
  String doorClosed(String name) => _m('doorClosed', {'name': name});

  // ---- Cupid.
  String get linkFirst => _m('linkFirst');
  String linkSecond(String name) => _m('linkSecond', {'name': name});
  String link(String a, String b) => _m('link', {'a': a, 'b': b});
  String get linkBody => _m('linkBody');
  String loversLine(String a, String b) => _m('loversLine', {'a': a, 'b': b});
  String inLoveWith(String name) => _m('inLoveWith', {'name': name});
  String get loversChat => _m('loversChat');
  String get answerAtDawn =>
      _m('answerAtDawn');

  // ---- The day.
  String get readTheNews => _m('readTheNews');
  String votedFor(String name) => _m('votedFor', {'name': name});
  String abstained([Gender me = Gender.unknown]) => _m('abstained', {'gender': me.name});
  String get revealMayor => _m('revealMayor');
  String get revealMayorTitle => _m('revealMayorTitle');
  String get revealMayorBody =>
      _m('revealMayorBody');
  String silenced([Gender gender = Gender.unknown]) => _m('silenced', {'gender': gender.name});

  // ---- The Marksman's day shot.
  String shootTitle(String name) => _m('shootTitle', {'name': name});
  String shootBody(int left) => _m('shootBody', {'left': left});
  String shotLine(String name, String role, {required bool backfired}) => backfired
      ? _m('shotLine', {'name': name, 'role': role})
      : _m('shotLine.aShotFrom', {'name': name, 'role': role});
  String aimLine(String name, int left) =>
      _m('aimLine', {'name': name, 'left': left});

  // ---- The Pacifist's truce.
  String get truce => _m('truce');
  String get truceHint => _m('truceHint');
  String truceTitle(String name) => _m('truceTitle', {'name': name});
  String get truceBody => _m('truceBody');
  String truceLine(String pacifist, String name, String role) =>
      _m('truceLine', {'pacifist': pacifist, 'name': name, 'role': role});
  String get truceVerdict => _m('truceVerdict');

  // ---- The Gunner's shots.
  String get fire => _m('fire');
  String get fireHint => _m('fireHint');
  String fireTitle(String name) => _m('fireTitle', {'name': name});
  String get fireBody => _m('fireBody');
  String shotsLeft(int count) => count == 1
      ? _m('shotsLeft')
      : _m('shotsLeft.youHaveShots', {'count': count});
  String gunnerShotsLeft(int count) => switch (count) {
        0 => _m('gunnerShotsLeft'),
        1 => _m('gunnerShotsLeft.theGunnerHas'),
        _ => _m('gunnerShotsLeft.theGunnerHas.2', {'count': count}),
      };
  String cannonLine(String name, String role) =>
      _m('cannonLine', {'name': name, 'role': role});

  /// The red stamp on the lynched seat.
  String lynched([Gender gender = Gender.unknown]) => _m('lynched', {'gender': gender.name});

  /// The verdict, short and plain: who, and which card. In Italian it agrees
  /// with the player; when nobody said how, the square does the lynching.
  String lynchedLine(String name, String? role, {Gender gender = Gender.unknown}) {
    if (role == null) return _m('lynchedLine', {'name': name, 'gender': gender.name});
    final card = language.capitalizesRoles || role.isEmpty ? role : role[0].toLowerCase() + role.substring(1);
    return _m('lynchedLine.role', {'name': name, 'role': card, 'gender': gender.name});
  }


  String get noLynch => _m('noLynch');
  String abstainedVotes(int n) => _m('abstainedVotes', {'n': n});

  // ---- The chat, when it is closed.
  String get chatOpensLater => _m('chatOpensLater');
  String get chatOver => _m('chatOver');

  // ---- The connection.
  String get rejoin => _m('rejoin');

  // ---- The end.
  String get leave => _m('leave');
}
