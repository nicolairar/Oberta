import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../rules/role.dart';
import 'app_language.dart';
import 'app_strings.dart';

/// The words of the roles collection ("I ruoli"), in Italian and English.
class CollectionStrings {
  final AppLanguage language;

  const CollectionStrings(this.language);

  static CollectionStrings of(BuildContext context) => CollectionStrings(AppStrings.of(context).language);

  /// The text under `collection.<key>` in the messages of the language.
  String _m(String key, [Map<String, Object?> args = const {}]) => language.message('collection.$key', args);

  String get title => _m('title');
  String get settingsHint => _m('settingsHint');
  String count(int n, int of) => _m('count', {'n': n, 'of': of});
  String get hint => _m('hint');
  String get signedOut => _m('signedOut');
  String get signIn => _m('signIn');

  String team(Team team) => switch (team) {
        Team.citizens => _m('team.citizens'),
        Team.mafia => _m('team.mafia'),
        Team.neutral => _m('team.neutral'),
      };

  String sideCount(int n, int of) => '$n/$of';
  String get locked => _m('locked');
  String get lockedBody => _m('lockedBody');
  String playedNoWin(int n) => n == 1
      ? _m('playedNoWin')
      : _m('playedNoWin.playedTimesNever', {'n': n});
  String get neverPlayed => _m('neverPlayed');

  String get played => _m('played');
  String get wins => _m('wins');
  String get losses => _m('losses');
  String get winRate => _m('winRate');
  String get bestStreak => _m('bestStreak');
  String get lastPlayed => _m('lastPlayed');
  String short(int wins, int played) => _m('short', {'wins': wins, 'played': played});

  String date(DateTime d) {
    const it = ['gen', 'feb', 'mar', 'apr', 'mag', 'giu', 'lug', 'ago', 'set', 'ott', 'nov', 'dic'];
    const en = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final l = d.toLocal();
    if (language == AppLanguage.it) return '${l.day} ${it[l.month - 1]} ${l.year}';
    if (language != AppLanguage.en) {
      // Month names of the other languages come from intl, loaded with the
      // Material localizations; until then, the English date.
      try {
        return DateFormat.yMMMd(language.locale.toLanguageTag()).format(l);
      } catch (_) {}
    }
    return '${en[l.month - 1]} ${l.day}, ${l.year}';
  }


  String get close => _m('close');
  String get publicCount => _m('publicCount');
}
