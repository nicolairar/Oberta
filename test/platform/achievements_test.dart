import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/platform/achievements.dart';
import 'package:oberta/steam/steam.dart';

class _FakeBackend extends AchievementBackend {
  bool signedIn = true;
  final Set<String> broken = {};
  final List<String> sent = [];
  bool prepared = false;

  @override
  void prepare() => prepared = true;

  @override
  Future<bool> ready() async => signedIn;

  @override
  Future<bool> unlock(String id) async {
    if (broken.contains(id)) throw StateError('platform said no');
    sent.add(id);
    return true;
  }
}

class _FakeSteam extends NoSteam {
  final Map<String, bool> defined;
  final List<String> unlocked = [];

  _FakeSteam(this.defined);

  @override
  bool get running => true;
  @override
  bool? achieved(String name) => defined[name];
  @override
  bool unlock(String name) {
    unlocked.add(name);
    defined[name] = true;
    return true;
  }
}

void main() {
  test('by default it reports nowhere and never throws', () async {
    final none = PlatformAchievements(null);
    await none.report(['role_medico', 'wins_10']);
    expect(none.reported, isEmpty);
  });

  test('each confirmed id goes to the platform once', () async {
    final backend = _FakeBackend();
    final a = PlatformAchievements(backend);
    await Future.wait([a.report(['role_medico', 'wins_10']), a.report(['role_medico'])]);
    await a.report(['wins_10', 'roles_town_all']);
    expect(backend.sent, ['role_medico', 'wins_10', 'roles_town_all']);
    expect(a.reported, {'role_medico', 'wins_10', 'roles_town_all'});
  });

  test('errors are swallowed and the failed id is tried again later', () async {
    final backend = _FakeBackend()..broken.add('wins_10');
    final a = PlatformAchievements(backend);
    await a.report(['wins_10', 'role_sarto']);
    expect(backend.sent, ['role_sarto']);
    backend.broken.clear();
    await a.report(['wins_10', 'role_sarto']);
    expect(backend.sent, ['role_sarto', 'wins_10']);
  });

  test('not signed in: nothing is sent or marked, it goes through after', () async {
    final backend = _FakeBackend()..signedIn = false;
    final a = PlatformAchievements(backend);
    await a.report(['role_fesso']);
    expect(backend.sent, isEmpty);
    backend.signedIn = true;
    await a.report(['role_fesso']);
    expect(backend.sent, ['role_fesso']);
  });

  test('ids that are not ours are ignored', () async {
    final backend = _FakeBackend();
    final a = PlatformAchievements(backend);
    await a.report(['', 'DROP TABLE', 'oberta.role_medico', 'ok']);
    expect(backend.sent, isEmpty);
  });

  test('Steam: API name = our id, set only when defined and not yet achieved', () async {
    final steam = _FakeSteam({'role_medico': false, 'wins_10': true});
    final a = PlatformAchievements(SteamAchievements(steam));
    await a.report(['role_medico', 'wins_10', 'role_nuovo']);
    expect(steam.unlocked, ['role_medico']);
    expect(a.reported, {'role_medico', 'wins_10'}, reason: 'role_nuovo is not in Steamworks yet');
  });

  test('Game Center ids', () {
    expect(gameCenterId('role_medico'), 'oberta.role_medico');
    expect(playGamesIds, isEmpty);
  });
}
