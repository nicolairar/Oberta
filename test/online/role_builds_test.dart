import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/online/game/game_server.dart';
import 'package:oberta/online/game/role_builds.dart';
import 'package:oberta/rules/role.dart';

// A phone that does not know a role cannot read a table where it is dealt:
// build 65 got stuck on "connecting" when the server dealt the Jailer.

void main() {
  test('every role is either known to every build or has the first build that knows it', () {
    for (final role in Role.values) {
      expect(baselineRoles.contains(role) || roleSinceBuild.containsKey(role), isTrue,
          reason: '$role: add it to roleSinceBuild (lib/online/game/role_builds.dart) with its first build');
    }
  });

  test('build 65 is never dealt the Prostitute, the Jailer or the Pacifist; build 66 may be', () {
    expect(rolesTooNewFor(65), roleSinceBuild.keys.toSet());
    expect(rolesTooNewFor(66), isEmpty);
    expect(rolesTooNewFor(null), isEmpty);
    final seats = [
      for (var i = 1; i <= 12; i++) {'seat': 's$i', 'profile_id': i <= 2 ? 'p$i' : null, 'name': 'n$i'},
    ];
    final now = DateTime.utc(2026, 10, 28).millisecondsSinceEpoch;
    List<String> deck(int seed, int build) {
      final out = serverStep({'state': null, 'seats': seats, 'language': 'it', 'now': now, 'intents': const [], 'seed': seed, 'minBuild': build});
      final board = (out['board'] as Map)['board'] as Map;
      return [for (final row in board['deck'] as List) (row as Map)['role'] as String];
    }

    var newer = false;
    for (var seed = 1; seed <= 60; seed++) {
      expect(deck(seed, 65).where((r) => const ['prostituta', 'carceriere', 'pacifista'].contains(r)), isEmpty);
      if (deck(seed, 66).any((r) => const ['prostituta', 'carceriere', 'pacifista'].contains(r))) newer = true;
    }
    expect(newer, isTrue);
  });
}
