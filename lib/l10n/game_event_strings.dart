import '../online/game/game_backend.dart';
import '../rules/role.dart';
import 'app_strings.dart';
import 'player_gender.dart';

/// The server's lines in the chat (see lib/online/game/game_events.dart),
/// in Italian and English. Names and roles come with the event.
class GameEventStrings {
  final AppStrings strings;

  const GameEventStrings(this.strings);

  /// The text under `gameEvent.<key>` in the messages of the language.
  String _m(String key, [Map<String, Object?> args = const {}]) => strings.language.message('gameEvent.$key', args);

  /// The label on a private line.
  String get onlyYou => _m('onlyYou');

  String _role(Object? name) {
    final role = name is String ? Role.values.asNameMap()[name] : null;
    return role == null ? '?' : strings.role(role).label;
  }

  String _team(Object? team) => switch (team) {
        'mafia' => _m('_team.mafia'),
        'neutral' => _m('_team.neutral'),
        _ => _m('_team'),
      };

  String _names(Object? list) => [for (final name in (list as List<Object?>? ?? const [])) '$name'].join(', ');

  String _winner(Object? team) => switch (team) {
        'citizens' => _m('_winner.citizens'),
        'mafia' => _m('_winner.mafia'),
        'neutral' => _m('_winner.neutral'),
        _ => _m('_winner'),
      };

  String text(GameEvent event) {
    final d = event.data;
    final name = '${d['name'] ?? '?'}';
    switch (event.kind) {
      case 'night':
        return _m('text.night', {'round': d['round']});
      case 'dawn':
        final dead = (d['dead'] as List<Object?>? ?? const []);
        final saved = (d['saved'] as num?)?.toInt() ?? 0;
        final parts = <String>[
          _m('text.dawn', {'round': d['round']}),
          if (dead.isEmpty) _m('text.dawn.nobodyDiedTonight'),
          if (dead.length == 1)
            _m('text.dawn.foundOne', {'name': '${dead.single}', 'gender': PlayerGenders.of('${dead.single}').name}),
          if (dead.length > 1) _m('text.dawn.foundDead', {'names': _names(dead)}),
          if (d['escorted'] == true) _m('text.dawn.theEscortFended'),
          if (saved == 1) _m('text.dawn.someoneWasSaved'),
          if (saved > 1) _m('text.dawn.attacksFoiled', {'saved': saved}),
          if (d['resurrected'] case final String back)
            _m('text.dawn.backAmongLiving', {'name': back, 'gender': PlayerGenders.of(back).name}),
          for (final broken in (d['heartbroken'] as List<Object?>? ?? const []))
            _m('text.dawn.diedOfA', {'broken': broken}),
        ];
        return parts.join(' ');
      case 'scoop':
        final role = d['role'];
        return role != null
            ? _m('text.scoop', {'name': name, 'role': _role(role)})
            : _m('text.scoop.thePaperS', {'name': name, 'team': _team(d['team'])});
      case 'silenced':
        return _m('text.silenced', {'name': name});
      case 'lynch':
        final votes = [
          for (final v in (d['votes'] as List<Object?>? ?? const []).cast<Map<String, Object?>>()) '${v['name']} ${v['count']}',
        ];
        final abstained = (d['abstained'] as num?)?.toInt() ?? 0;
        final tally = [
          ...votes,
          if (abstained > 0) _m('text.lynch', {'abstained': abstained}),
        ].join(' · ');
        final verdict = d['name'] == null
            ? _m('text.lynch.theSquareCondemns')
            : _m('text.lynch.theSquareCondemns.2', {'name': name, 'role': _role(d['role'])});
        final hunter = d['bountyHunter'] == null
            ? ''
            : _m('text.lynch.collectsTheBounty', {'bountyHunter': d['bountyHunter']});
        final broken = d['heartbroken'] == null
            ? ''
            : _m('text.lynch.diedOfA', {'heartbroken': d['heartbroken']});
        return tally.isEmpty ? '$verdict$hunter$broken' : '$verdict$hunter$broken ($tally)';
      case 'mayor':
        return _m('text.mayor', {'name': name});
      case 'truce':
        return _m('text.truce', {'name': name, 'target': d['target'], 'role': _role(d['role'])});
      case 'cannon':
        final broken = d['heartbroken'] == null
            ? ''
            : _m('text.cannon', {'heartbroken': d['heartbroken']});
        return _m('text.cannon.aRoarIn', {'name': name, 'target': d['target'], 'role': _role(d['role'])}) +
            broken;
      case 'shot':
        final brokenShot = d['heartbroken'] == null
            ? ''
            : _m('text.shot', {'heartbroken': d['heartbroken']});
        return (d['backfired'] == true
                ? _m('text.shot.aShotFrom', {'name': name, 'role': _role(d['role'])})
                : _m('text.shot.aShotFrom.2', {'name': name, 'role': _role(d['role'])})) +
            brokenShot;
      case 'aim':
        return _m('text.aim', {'name': name});
      case 'cell':
        return d['self'] == true
            ? _m('text.cell')
            : _m('text.cell.tonightIsIn', {'name': name});
      case 'lovers':
        final names = [for (final n in (d['names'] as List<Object?>? ?? const [])) '$n'];
        final first = names.isEmpty ? '?' : names.first;
        final second = names.length < 2 ? '?' : names[1];
        if (d['self'] != true) return _m('text.lovers.bound', {'first': first, 'second': second});
        return _m('text.lovers.self', {'first': first, 'second': second});
      case 'converted':
        return _m('text.converted');
      case 'door':
        return d['converted'] == true
            ? _m('text.door', {'name': name})
            : _m('text.door.doorShutDid', {'name': name});
      case 'busy':
        return _m('text.busy');
      case 'left':
        return _m('text.left', {'name': name});
      case 'end':
        if (d['abandoned'] == true) return _m('text.end');
        final alone = _names(d['alone']);
        final fell = d['presidentFell'] == true ? _m('text.end.thePresidentHas') : '';
        return _m('text.end.gameOver', {'winner': _winner(d['winner'])}) + fell +
            (alone.isEmpty ? '' : _m('text.end.wonAlone', {'alone': alone}));
      case 'found':
        return d['role'] != null
            ? _m('text.found', {'name': name, 'role': _role(d['role'])})
            : _m('text.found.comesUp', {'name': name, 'team': _team(d['team'])});
      case 'watch':
        return d['visited'] == true
            ? _m('text.watch', {'name': name})
            : _m('text.watch.nobodyCameTo', {'name': name});
      case 'bounty':
        return _m('text.bounty', {'name': name});
      case 'doused':
        return _m('text.doused', {'names': _names(d['names'])});
      case 'familyTarget':
        return d['name'] == null
            ? _m('text.familyTarget')
            : _m('text.familyTarget.theFamilyChose', {'name': name});
      case 'protected':
        return switch (d['kind']) {
          'guard' => _m('text.guard', {'name': name}),
          'lend' => _m('text.lend', {'name': name}),
          _ => _m('text.protected', {'name': name}),
        };
    }
    return '';
  }
}
