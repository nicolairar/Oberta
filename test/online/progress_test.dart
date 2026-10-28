import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/online/game/match_rewards.dart';
import 'package:oberta/online/game/progress.dart';
import 'package:oberta/rules/role.dart';

import 'afk_test.dart' show play, seatOf;

MissionSlot _mission(String id, String metric, int target, {int progress = 0, int coins = 40, int xp = 80}) =>
    MissionSlot(
      id: id,
      cadence: id.startsWith('weekly') ? 'weekly' : 'daily',
      period: '2026-10-21',
      metric: metric,
      target: target,
      progress: progress,
      xp: xp,
      coins: coins,
    );

SettleSeat _seat({
  String team = 'citizens',
  String role = 'cittadino',
  bool won = true,
  bool survived = true,
  bool abandoned = false,
  bool afk = false,
  bool leftDead = false,
  bool short = false,
  Map<String, int> feats = const {},
  List<MissionSlot> missions = const [],
  Map<String, int> stats = const {},
  Set<String> achieved = const {},
}) =>
    SettleSeat(
      profile: 'p',
      seat: 's1',
      team: team,
      role: role,
      won: won,
      survived: survived,
      abandoned: abandoned,
      afk: afk,
      leftDead: leftDead,
      short: short,
      wonToday: true,
      feats: feats,
      missions: missions,
      stats: stats,
      achieved: achieved,
    );

void main() {
  group('the tally of a game', () {
    test('a friends win as Doctor who saved someone and survived', () {
      final tally = progressTally(
        counts: true,
        ranked: false,
        team: 'citizens',
        role: 'medico',
        won: true,
        survived: true,
        feats: {Feats.nights: 3, Feats.saves: 1, Feats.lynchHits: 2},
      );
      expect(tally, {
        Metric.games: 1,
        Metric.friendsGames: 1,
        Metric.survived: 1,
        Metric.wins: 1,
        Metric.friendsWins: 1,
        Metric.winsAlive: 1,
        Metric.townWins: 1,
        Metric.roleWin(Role.medico): 1,
        Metric.nights: 3,
        Metric.saves: 1,
        Metric.lynchHits: 2,
        Metric.doctorSaveSurvive: 1,
      });
    });

    test('a ranked loss counts the game, not the win', () {
      final tally = progressTally(counts: true, ranked: true, team: 'mafia', role: 'mafioso', won: false, survived: false);
      expect(tally, {Metric.games: 1, Metric.rankedGames: 1});
    });

    test('the Godfather lynch counts only for the Detective', () {
      Map<String, int> as(String role) => progressTally(
            counts: true,
            ranked: true,
            team: 'citizens',
            role: role,
            won: true,
            survived: true,
            feats: {Feats.godfather: 1},
          );
      expect(as('detective')[Metric.godfatherLynch], 1);
      expect(as('cittadino')[Metric.godfatherLynch], isNull);
    });

    test('a neutral win and the Fool', () {
      final tally = progressTally(counts: true, ranked: false, team: 'neutral', role: 'fesso', won: true, survived: false);
      expect(tally[Metric.neutralWins], 1);
      expect(tally[Metric.foolWin], 1);
      expect(tally[Metric.winsAlive], isNull);
    });

    test('a game that does not count moves nothing', () {
      expect(progressTally(counts: false, ranked: true, team: 'mafia', role: 'mafioso', won: true, survived: true), isEmpty);
    });
  });

  group('missions and achievements', () {
    test('a mission moves, completes once and is capped at its target', () {
      final update = applyProgress(
        tally: {Metric.wins: 1, Metric.games: 1, Metric.lynchHits: 4},
        missions: [
          _mission('daily_win_1', Metric.wins, 1),
          _mission('daily_play_3', Metric.games, 3),
          _mission('daily_lynch_hits_3', Metric.lynchHits, 3, progress: 1, coins: 50, xp: 100),
          _mission('daily_ranked_1', Metric.rankedGames, 1),
        ],
      );
      final moved = {for (final m in update.missions) m.mission.id: (m.progress, m.completed)};
      expect(moved, {
        'daily_win_1': (1, true),
        'daily_play_3': (1, false),
        'daily_lynch_hits_3': (3, true),
      });
      expect(update.missionCoins, 90);
      expect(update.xp, 180);
    });

    test('achievements unlock at their target, only once, and roles won are counted', () {
      final update = applyProgress(
        tally: {Metric.wins: 1, Metric.roleWin(Role.medico): 1},
        stats: {
          Metric.wins: 9,
          for (final role in [Role.cittadino, Role.detective, Role.mafioso, Role.sarto]) Metric.roleWin(role): 2,
        },
        achieved: {
          'neutral_wins_1',
          for (final role in [Role.cittadino, Role.detective, Role.mafioso, Role.sarto]) Achievement.roleId(role),
        },
      );
      expect([for (final a in update.unlocked) a.id], ['wins_10', 'roles_won_5', 'role_medico']);
      expect(update.achievementCoins, 50 + 75, reason: 'the card medals pay nothing');
      final again = applyProgress(tally: {Metric.wins: 1}, stats: {Metric.wins: 10}, achieved: {'wins_10'});
      expect(again.unlocked, isEmpty);
    });

    test('the catalog: about thirty, plus one card per role; stable snake_case ids, unique, rewards from the shop', () {
      expect(achievements.length - roleAchievements.length, inInclusiveRange(28, 40));
      expect([for (final a in roleAchievements) a.role], Role.values, reason: 'every role, new ones too');
      for (final a in roleAchievements) {
        expect(achievements, contains(a));
        expect((a.xp, a.coins, a.target), (0, 0, 1));
      }
      final ids = {for (final a in achievements) a.id};
      expect(ids.length, achievements.length);
      for (final a in achievements) {
        expect(RegExp(r'^[a-z0-9_]{3,40}$').hasMatch(a.id), isTrue, reason: a.id);
        expect(a.item == null || a.item!.startsWith('border.'), isTrue);
      }
      expect(Achievement.byId('roles_won_all')!.target, Role.values.length);
      for (final (id, team) in [('roles_town_all', Team.citizens), ('roles_mafia_all', Team.mafia), ('roles_lone_all', Team.neutral)]) {
        expect(Achievement.byId(id)!.target, Role.values.where((r) => r.team == team).length);
      }
    });

    test('a side is complete when every role of it won once', () {
      final mafia = Role.values.where((r) => r.team == Team.mafia).toList();
      final stats = {for (final r in mafia.skip(1)) Metric.roleWin(r): 1};
      final update = applyProgress(
        tally: {Metric.games: 1, Metric.wins: 1, Metric.roleWin(mafia.first): 1},
        stats: stats,
        achieved: {for (final r in mafia.skip(1)) Achievement.roleId(r)},
      );
      expect([for (final a in update.unlocked) a.id], containsAll([Achievement.roleId(mafia.first), 'roles_mafia_all']));
      expect(update.unlocked.map((a) => a.id), isNot(contains('roles_town_all')));
      expect(withRolesWon(stats)[Metric.rolesWonMafia], mafia.length - 1);
    });
  });

  group('settle', () {
    test('a completed mission pays XP and coins on top of the game', () {
      final out = settle(
        ranked: false,
        humans: 2,
        seats: [
          _seat(missions: [_mission('daily_win_1', Metric.wins, 1)]),
        ],
      ).single;
      expect(out.xpGained, 100 + 80);
      expect(out.coins, out.levelCoins + 40);
      expect(out.toJson()['missions'], [
        {'id': 'daily_win_1', 'cadence': 'daily', 'period': '2026-10-21', 'progress': 1, 'completed': true, 'coins': 40, 'xp': 80},
      ]);
    });

    test('AFK, abandoned, left after dying, short and bots-only games never count', () {
      final open = [_mission('daily_play_3', Metric.games, 3)];
      for (final seat in [
        _seat(afk: true, missions: open),
        _seat(abandoned: true, missions: open),
        _seat(leftDead: true, missions: open),
        _seat(short: true, missions: open),
      ]) {
        final out = settle(ranked: true, seats: [seat, _seat(won: false)]).first;
        expect(out.tally, isEmpty);
        expect(out.progress.missions, isEmpty);
        expect(out.toJson()['missions'], isEmpty);
      }
      final alone = settle(ranked: false, humans: 1, seats: [_seat(missions: open)]).single;
      expect(alone.tally, isEmpty);
    });

    test('the settle JSON reads missions, stats and achievements from the server', () {
      final out = settleJson({
        'ranked': true,
        'seats': [
          {
            'profile': 'a', 'seat': 's1', 'team': 'neutral', 'role': 'piromane', 'won': true, 'survived': true,
            'feats': {'nights': 2},
            'missions': [
              {'id': 'weekly_neutral_win_1', 'cadence': 'weekly', 'period': '2026-10-19', 'metric': 'neutral_wins',
               'target': 1, 'progress': 0, 'xp': 300, 'coins': 250},
            ],
            'stats': {'neutral_wins': 0},
            'achieved': <String>[],
          },
          {'profile': 'b', 'seat': 's2', 'team': 'citizens', 'role': 'cittadino', 'won': false, 'survived': false},
        ],
      });
      final a = (out['players'] as List).first as Map<String, Object?>;
      expect((a['tally'] as Map)['nights'], 2);
      expect((a['missions'] as List).single, containsPair('completed', true));
      expect([for (final u in a['unlocked'] as List) (u as Map)['id']], contains('neutral_wins_1'));
      expect(a['coins'], (a['levelCoins'] as int) + 250 + 50);
    });
  });

  test('the game server counts the feats of a real game', () {
    final totals = <String, int>{};
    for (var seed = 1; seed <= 6; seed++) {
      final result = play(seed, const {}, humans: 4, bots: 4);
      for (final seat in (result['seats'] as Map).keys.cast<String>()) {
        final feats = (seatOf(result, seat)['feats'] as Map).cast<String, int>();
        final role = seatOf(result, seat)['role'];
        if (feats.containsKey(Feats.godfather)) expect(role, 'detective');
        if (feats.containsKey(Feats.saves)) expect(role, 'medico');
        if (feats.containsKey(Feats.finds)) expect(role, 'detective');
        for (final MapEntry(:key, :value) in feats.entries) {
          totals[key] = (totals[key] ?? 0) + value;
        }
      }
    }
    expect(totals[Feats.nights], greaterThan(0));
  });
}
