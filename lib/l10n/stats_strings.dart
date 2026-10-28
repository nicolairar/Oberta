import 'package:flutter/widgets.dart';

import 'app_language.dart';
import 'app_strings.dart';

/// The words of the dossier's stats page, in Italian and English.
class StatsStrings {
  final AppLanguage language;

  const StatsStrings(this.language);

  static StatsStrings of(BuildContext context) => StatsStrings(AppStrings.of(context).language);

  /// The text under `stats.<key>` in the messages of the language.
  String _m(String key, [Map<String, Object?> args = const {}]) => language.message('stats.$key', args);

  /// The two index tabs of the folder.
  String get tabFile => _m('tabFile');
  String get tabStats => _m('tabStats');

  String get title => _m('title');
  String get includeTests => _m('includeTests');
  String includeTestsCount(int n) => '$includeTests ($n)';

  String get games => _m('games');
  String get wins => _m('wins');
  String get losses => _m('losses');
  String get winRate => _m('winRate');

  String get atTheTable => _m('atTheTable');
  String get timePlayed => _m('timePlayed');
  String timeMeasured(int timed, int games) =>
      _m('timeMeasured', {'timed': timed, 'games': games});
  String get favouriteRole => _m('favouriteRole');
  String get longestStreak => _m('longestStreak');
  String get survived => _m('survived');

  String get byTable => _m('byTable');
  String get friends => _m('friends');
  String get ranked => _m('ranked');

  String get byFaction => _m('byFaction');
  String get family => _m('family');
  String get town => _m('town');
  String get alone => _m('alone');

  String get byRole => _m('byRole');
  String gamesWins(int games, int wins) =>
      _m('gamesWins', {'games': games, 'wins': wins});
  String get neverPlayed => _m('neverPlayed');

  String get feats => _m('feats');
  String get featsHint =>
      _m('featsHint');

  /// A lifetime counter's label, by metric id; null for those not shown.
  String? counter(String metric) => switch (metric) {
    'nights' => _m('counter.nights'),
    'lynch_hits' => _m('counter.lynch_hits'),
    'saves' => _m('counter.saves'),
    'finds' => _m('counter.finds'),
    'snipes' => _m('counter.snipes'),
    'kills' => _m('counter.kills'),
    'framed' => _m('counter.framed'),
    'godfather_lynch' => _m('counter.godfather_lynch'),
    'wins_alive' => _m('counter.wins_alive'),
    _ => null,
  };

  String get private => _m('private');
  String get privateHint => _m('privateHint');
  String get abandoned => _m('abandoned');
  String get afk => _m('afk');
  String get reserved => _m('reserved');

  String get empty => _m('empty');
  String get loadFailed => _m('loadFailed');
  String get retry => _m('retry');

  String duration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h == 0) return '$m min';
    return '$h h ${m.toString().padLeft(2, '0')} min';
  }

  String percent(double rate) => '${(rate * 100).round()}%';

  // Public profiles: another player's dossier.
  String get profile => _m('profile');
  String get publicTitle => _m('publicTitle');
  String get onRecord => _m('onRecord');
  String get featured => _m('featured');
  String get noMedals => _m('noMedals');
  String get topRoles => _m('topRoles');
  String get closedFile => _m('closedFile');
  String get unavailable => _m('unavailable');
  String get publicSwitch => _m('publicSwitch');
  String get publicSwitchHint => _m('publicSwitchHint');
}
