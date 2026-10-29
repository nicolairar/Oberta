import 'package:flutter/widgets.dart';

import '../rules/game_engine.dart';
import '../rules/role.dart';
import 'app_language.dart';
import 'app_strings.dart';
import 'player_gender.dart';

/// The words of the end-of-game recap ("Il resoconto") and of the table
/// notices, in Italian and English.
class RecapStrings {
  final AppLanguage language;

  const RecapStrings(this.language);

  static RecapStrings of(BuildContext context) => RecapStrings(AppStrings.of(context).language);

  /// The text under `recap.<key>` in the messages of the language.
  String _m(String key, [Map<String, Object?> args = const {}]) => language.message('recap.$key', args);

  // ---- The recap.
  String get open => _m('open');
  String get masthead => _m('masthead');
  String get dateLine => _m('dateLine');
  String get cast => _m('cast');
  String get timeline => _m('timeline');
  String night(int round) => _m('night', {'round': round});
  String day(int round) => _m('day', {'round': round});
  String get won => _m('won');
  String get wonAlone => _m('wonAlone');
  String get survived => _m('survived');
  String get fell => _m('fell');
  String get left => _m('left');
  String get close => _m('close');
  String get you => _m('you');
  String get quietNight => _m('quietNight');

  String team(Team team) => switch (team) {
    Team.citizens => _m('team.citizens'),
    Team.mafia => _m('team.mafia'),
    Team.neutral => _m('team.neutral'),
  };

  String winner(Team? team) => switch (team) {
    Team.citizens => _m('winner.citizens'),
    Team.mafia => _m('winner.mafia'),
    Team.neutral => _m('winner.neutral'),
    null => _m('winner.null'),
  };

  String familyAimed(String target, String voters) =>
      _m('familyAimed', {'target': target, 'voters': voters});
  String get familyNobody => _m('familyNobody');

  String move(NightTaskKind kind, String target, {Team? seen, String? role, bool? visited}) => switch (kind) {
    NightTaskKind.silence => _m('move.silence', {'target': target}),
    NightTaskKind.protect => _m('move.protect', {'target': target}),
    NightTaskKind.guard => _m('move.guard', {'target': target}),
    NightTaskKind.investigate => _m('move.investigate', {'target': target, 'seen': seen == Team.mafia ? 'mafia' : 'clean'}),
    NightTaskKind.dig => _m('move.dig', {'target': target, 'role': inline(role ?? '')}),
    NightTaskKind.snipe => _m('move.snipe', {'target': target}),
    NightTaskKind.scoop => _m('move.scoop', {'target': target}),
    NightTaskKind.douse => _m('move.douse', {'target': target}),
    NightTaskKind.ignite => _m('move.ignite'),
    NightTaskKind.resurrect => _m('move.resurrect', {'target': target}),
    NightTaskKind.lend => _m('move.lend', {'target': target}),
    NightTaskKind.stab => _m('move.stab', {'target': target}),
    NightTaskKind.jail => _m('move.jail', {'target': target}),
    NightTaskKind.block => _m('move.block', {'target': target}),
    NightTaskKind.link => _m('move.link', {'target': target}),
    NightTaskKind.convert => _m('move.convert', {'target': target}),
    NightTaskKind.aim => _m('move.aim', {'target': target}),
    NightTaskKind.watch => _m('move.watch', {'target': target, 'visited': visited == true ? 'yes' : 'no'}),
    NightTaskKind.kill || NightTaskKind.decoy => '',
  };

  String attack(AttackOutcome outcome, AttackSource source, String target) {
    final by = switch (source) {
      AttackSource.family => _m('attack.family'),
      AttackSource.sniper => _m('attack.sniper'),
      AttackSource.fire => _m('attack.fire'),
      AttackSource.assassin => _m('attack.assassin'),
    };
    final g = PlayerGenders.of(target);
    return switch (outcome) {
      AttackOutcome.killed => _m('attack.killed', {'target': target, 'by': by, 'gender': g.name}),
      AttackOutcome.healed => _m('attack.healed', {'target': target, 'by': by, 'gender': g.name}),
      AttackOutcome.shrugged => _m('attack.shrugged', {'target': target, 'by': by}),
      AttackOutcome.escorted => _m('attack.escorted', {'by': by, 'target': target}),
    };
  }

  String scoopOut(String target, Team team) => switch (team) {
    Team.mafia => _m('scoopOut.mafia', {'target': target}),
    Team.citizens => _m('scoopOut.citizens', {'target': target}),
    Team.neutral => _m('scoopOut.neutral', {'target': target}),
  };

  /// A role name in the middle of an Italian sentence: "era il Picciotto".
  String inline(String role) =>
      language.capitalizesRoles || role.isEmpty ? role : role[0].toLowerCase() + role.substring(1);
  String risen(String target) => _m('risen', {'target': target, 'gender': PlayerGenders.of(target).name});
  String mayor(String name) => _m('mayor', {'name': name});
  String get votes => _m('votes');
  String get abstained => _m('abstained');
  String condemned(String name, String role) =>
      _m('condemned', {'name': name, 'role': inline(role)});
  String get noCondemned => _m('noCondemned');
  String foolWins(String name) => _m('foolWins', {'name': name});
  String bounty(String hunter) => _m('bounty', {'hunter': hunter});
  String exit(String name) => _m('exit', {'name': name});

  // ---- The notices on the table.
  String leftTown(String name) => _m('leftTown', {'name': name});
  String wentAway(String name) => _m('wentAway', {'name': name});
  String cameBack(String name) => _m('cameBack', {'name': name});
  String calledOut(String name) => _m('calledOut', {'name': name});
}
