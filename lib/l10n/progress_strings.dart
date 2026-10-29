import 'package:flutter/widgets.dart';

import 'app_language.dart';
import 'app_strings.dart';
import '../online/game/progress.dart' show Achievement;

/// The words of missions, achievements and the leaderboard, in Italian and
/// English. Missions and achievements are named by their stable ids.
class ProgressStrings {
  final AppLanguage language;

  const ProgressStrings(this.language);

  static ProgressStrings of(BuildContext context) => ProgressStrings(AppStrings.of(context).language);

  /// The text under `progress.<key>` in the messages of the language.
  String _m(String key, [Map<String, Object?> args = const {}]) => language.message('progress.$key', args);

  String get missions => _m('missions');
  String get achievements => _m('achievements');
  String get leaderboard => _m('leaderboard');
  String get daily => _m('daily');
  String get weekly => _m('weekly');
  String get goals => _m('goals');
  String get tabDaily => _m('tabDaily');
  String get tabWeekly => _m('tabWeekly');
  String get tabGoals => _m('tabGoals');
  String get missionsHint => _m('missionsHint');
  String get goalsHint => _m('goalsHint');
  String get claim => _m('claim');
  String get claimed => _m('claimed');
  String get late => _m('late');
  String get reputation => _m('reputation');
  String reputationGain(int n) => _m('reputationGain', {'n': n});
  String claimDone(int coins, int reputation) =>
      _m('claimDone', {'coins': coins, 'reputation': reputation});
  String itemWon(String name) => _m('itemWon', {'name': name});
  String reward(String name) => _m('reward', {'name': name});
  String toClaim(int n) => _m('toClaim', {'n': n});
  String unlocksWith(String mission) => _m('unlocksWith', {'mission': mission});
  String get missionOnly => _m('missionOnly');
  String get done => _m('done');
  String endsIn(Duration d) {
    final h = d.inHours;
    if (h >= 48) return _m('endsIn', {'inDays': d.inDays});
    if (h >= 1) return _m('endsIn.endsInH', {'h': h});
    return _m('endsIn.endsInMin', {'d': d.inMinutes.clamp(1, 59)});
  }

  String get loadFailed => _m('loadFailed');
  String get retry => _m('retry');
  String unlockedCount(int n, int of) => _m('unlockedCount', {'n': n, 'of': of});
  String get locked => _m('locked');
  String rewardTitle(String title) => _m('rewardTitle', {'title': title});
  String get rewardFrame => _m('rewardFrame');
  String get title => _m('title');

  String get leaderboardEmpty => _m('leaderboardEmpty');
  String get leaderboardHint => _m('leaderboardHint');
  String yourPlace(int rank) => _m('yourPlace', {'rank': rank});
  String get notRanked => _m('notRanked');

  String missionDone(String name) => _m('missionDone', {'name': name});
  String achievementDone(String name) => _m('achievementDone', {'name': name});

  /// A mission's text, from its id (with a generic fallback by metric).
  String mission(String id, {String metric = '', int target = 1}) => switch (id) {
        'daily_play_3' => _m('mission.daily_play_3'),
        'daily_win_1' => _m('mission.daily_win_1'),
        'daily_friends_win_2' => _m('mission.daily_friends_win_2'),
        'daily_lynch_hits_3' => _m('mission.daily_lynch_hits_3'),
        'daily_nights_2' => _m('mission.daily_nights_2'),
        'daily_ranked_1' => _m('mission.daily_ranked_1'),
        'daily_survive_1' => _m('mission.daily_survive_1'),
        'daily_town_win_1' => _m('mission.daily_town_win_1'),
        'daily_mafia_win_1' => _m('mission.daily_mafia_win_1'),
        'weekly_neutral_win_1' => _m('mission.weekly_neutral_win_1'),
        'weekly_wins_7' => _m('mission.weekly_wins_7'),
        'weekly_play_15' => _m('mission.weekly_play_15'),
        'weekly_lynch_hits_10' => _m('mission.weekly_lynch_hits_10'),
        'weekly_ranked_5' => _m('mission.weekly_ranked_5'),
        'weekly_ranked_wins_3' => _m('mission.weekly_ranked_wins_3'),
        'weekly_saves_2' => _m('mission.weekly_saves_2'),
        'weekly_finds_3' => _m('mission.weekly_finds_3'),
        'weekly_kills_5' => _m('mission.weekly_kills_5'),
        'weekly_nights_12' => _m('mission.weekly_nights_12'),
        'daily_friends_play_2' => _m('mission.daily_friends_play_2'),
        'daily_win_alive_1' => _m('mission.daily_win_alive_1'),
        'daily_survive_2' => _m('mission.daily_survive_2'),
        'weekly_play_10' => _m('mission.weekly_play_10'),
        'weekly_wins_4' => _m('mission.weekly_wins_4'),
        'weekly_town_wins_3' => _m('mission.weekly_town_wins_3'),
        'weekly_mafia_wins_2' => _m('mission.weekly_mafia_wins_2'),
        'weekly_detective_win_1' => _m('mission.weekly_detective_win_1'),
        'weekly_doctor_win_1' => _m('mission.weekly_doctor_win_1'),
        'long_nights_10' => _m('mission.long_nights_10'),
        'long_lynch_hits_3' => _m('mission.long_lynch_hits_3'),
        'long_detective_wins_5' => _m('mission.long_detective_wins_5'),
        'long_finds_5' => _m('mission.long_finds_5'),
        'long_mafia_wins_10' => _m('mission.long_mafia_wins_10'),
        'long_town_wins_10' => _m('mission.long_town_wins_10'),
        'long_wins_50' => _m('mission.long_wins_50'),
        'long_games_25' => _m('mission.long_games_25'),
        'long_friends_games_20' => _m('mission.long_friends_games_20'),
        'long_ranked_games_20' => _m('mission.long_ranked_games_20'),
        'long_saves_5' => _m('mission.long_saves_5'),
        'long_survived_25' => _m('mission.long_survived_25'),
        'long_neutral_wins_3' => _m('mission.long_neutral_wins_3'),
        _ => _m('mission', {'target': target}),
      };

  /// An achievement's name and what it asks.
  (String, String) achievement(String id) => switch (id) {
        'wins_10' => (_m('achievement.wins_10'), _m('achievement')),
        'wins_50' => (_m('achievement.wins_50'), _m('achievement.winGames')),
        'wins_200' => (_m('achievement.wins_200'), _m('achievement.winGames.2')),
        'games_25' => (_m('achievement.games_25'), _m('achievement.playGames')),
        'games_100' => (_m('achievement.games_100'), _m('achievement.playGames.2')),
        'games_500' => (_m('achievement.games_500'), _m('achievement.playGames.3')),
        'ranked_wins_10' => (_m('achievement.ranked_wins_10'), _m('achievement.winRankedGames')),
        'ranked_wins_50' => (_m('achievement.ranked_wins_50'), _m('achievement.winRankedGames.2')),
        'friends_wins_25' => (_m('achievement.friends_wins_25'), _m('achievement.winGamesWith')),
        'town_wins_25' => (_m('achievement.town_wins_25'), _m('achievement.winTimesWith')),
        'mafia_wins_25' => (_m('achievement.mafia_wins_25'), _m('achievement.winTimesWith.2')),
        'neutral_wins_1' => (_m('achievement.neutral_wins_1'), _m('achievement.winAsA')),
        'neutral_wins_10' => (_m('achievement.neutral_wins_10'), _m('achievement.winTimesAs')),
        'roles_won_5' => (_m('achievement.roles_won_5'), _m('achievement.winWithDifferent')),
        'roles_won_12' => (_m('achievement.roles_won_12'), _m('achievement.winWithDifferent.2')),
        'roles_won_all' => (_m('achievement.roles_won_all'), _m('achievement.winWithEvery')),
        'roles_town_all' => (_m('achievement.roles_town_all'), _m('achievement.winWithEvery.2')),
        'roles_mafia_all' => (_m('achievement.roles_mafia_all'), _m('achievement.winWithEvery.3')),
        'roles_lone_all' => (_m('achievement.roles_lone_all'), _m('achievement.winWithEvery.4')),
        'wins_alive_25' => (_m('achievement.wins_alive_25'), _m('achievement.winTimesStill')),
        'lynch_hits_10' => (_m('achievement.lynch_hits_10'), _m('achievement.voteCondemnedMafiosi')),
        'lynch_hits_50' => (_m('achievement.lynch_hits_50'), _m('achievement.voteCondemnedMafiosi.2')),
        'lynch_hits_200' => (_m('achievement.lynch_hits_200'), _m('achievement.voteCondemnedMafiosi.3')),
        'nights_25' => (_m('achievement.nights_25'), _m('achievement.surviveNights')),
        'nights_100' => (_m('achievement.nights_100'), _m('achievement.surviveNights.2')),
        'saves_1' => (_m('achievement.saves_1'), _m('achievement.saveALife')),
        'saves_10' => (_m('achievement.saves_10'), _m('achievement.saveLivesAs')),
        'doctor_save_survive' => (
            _m('achievement.countryDoctor'),
            _m('achievement.asTheDoctor'),
          ),
        'finds_10' => (_m('achievement.finds_10'), _m('achievement.unmaskMafiosiAs')),
        'godfather_lynch' => (
            _m('achievement.theInspector'),
            _m('achievement.asTheDetective'),
          ),
        'snipes_1' => (_m('achievement.snipes_1'), _m('achievement.asTheSniper')),
        'kills_25' => (_m('achievement.kills_25'), _m('achievement.successfulHitsWith')),
        'framed_5' => (_m('achievement.framed_5'), _m('achievement.asAMafioso')),
        'fool_win' => (_m('achievement.fool_win'), _m('achievement.winAsThe')),
        _ => switch (Achievement.roleOf(id)) {
            final role? => (
                language.strings.role(role).label,
                _m('achievement.winAGame'),
              ),
            null => (id, ''),
          },
      };

  /// A title from an achievement, as shown in the dossier.
  String titleName(String id) => switch (id) {
        'man_of_honor' => _m('titleName.man_of_honor'),
        'legend' => _m('titleName.legend'),
        'veteran' => _m('titleName.veteran'),
        'boss' => _m('titleName.boss'),
        'model_citizen' => _m('titleName.model_citizen'),
        'made_man' => _m('titleName.made_man'),
        'lone_wolf' => _m('titleName.lone_wolf'),
        'chameleon' => _m('titleName.chameleon'),
        'bloodhound' => _m('titleName.bloodhound'),
        'night_owl' => _m('titleName.night_owl'),
        'guardian_angel' => _m('titleName.guardian_angel'),
        'inspector' => _m('titleName.inspector'),
        'schemer' => _m('titleName.schemer'),
        _ => id,
      };
}
