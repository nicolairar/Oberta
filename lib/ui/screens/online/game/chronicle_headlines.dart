import '../../../../l10n/app_language.dart';
import '../../../../l10n/player_gender.dart';
import '../../../../rules/game_engine.dart';
import '../../../../rules/player.dart';
import '../../../../rules/role.dart';

/// Il titolone dell'alba e i nomi da ritrarre in prima pagina: la stessa
/// cronaca per la partita online e per la sala prove.
({String headline, List<String> dead}) dawnHeadline(
  DawnReport dawn, {
  required AppLanguage language,
  required String everyoneAlive,
}) {
  String m(String key, [Map<String, Object?> args = const {}]) => language.message('chronicle.$key', args);
  final dead = [
    for (final attack in dawn.attacks)
      if (attack.isFatal) attack.target.name,
  ];
  final names = dead.join(m('deadJoiner'));
  final risen = dawn.resurrected?.name;
  final burned = [
    for (final attack in dawn.attacks)
      if (attack.isFatal && attack.source == AttackSource.fire) attack.target.name,
  ];
  final others = [
    for (final name in dead)
      if (!burned.contains(name)) name,
  ];
  // L'italiano concorda: tutte donne «trovate morte», un uomo basta per
  // «trovati morti»; se di qualcuno non si sa, un titolo che non concorda.
  final genders = [for (final name in dead) PlayerGenders.of(name)];
  final gender = genders.contains(Gender.unknown)
      ? Gender.unknown
      : genders.every((g) => g == Gender.feminine)
      ? Gender.feminine
      : Gender.masculine;
  final otherGender = [for (final name in others) PlayerGenders.of(name)].fold<Gender?>(
    null,
    (all, g) => all == null || all == g ? g : (all == Gender.unknown || g == Gender.unknown ? Gender.unknown : Gender.masculine),
  );
  final headline = burned.isNotEmpty
      ? others.isEmpty
            ? m('fire', {'burned': burned.join(m('listJoiner'))})
            : m('fireWithOthers', {
                'burned': burned.join(m('listJoiner')),
                'others': others.join(m('listJoiner')),
                'gender': (otherGender ?? Gender.unknown).name,
                'n': others.length,
              })
      : dead.isEmpty && risen != null
      ? m('risen', {'name': risen})
      : dead.isEmpty
      ? everyoneAlive
      : m('foundDead', {'names': names, 'gender': gender.name, 'n': dead.length});
  return (headline: headline, dead: dead);
}

/// Il titolo della sera, dopo il verdetto. [tag] scrive il nome sul giornale.
String lynchHeadline(
  LynchReport report, {
  required AppLanguage language,
  required String Function(Player) tag,
  required String Function(Role) roleLabel,
}) {
  String m(String key, [Map<String, Object?> args = const {}]) => language.message('chronicle.$key', args);
  final condemned = report.condemned;
  final role = report.role;
  if (condemned == null) return m('squareUndecided');
  final name = tag(condemned);
  if (role == null) return m('lynched', {'name': name});
  if (report.personalWin) return m('lynchedFool', {'name': name});
  final hunter = report.bountyHunter;
  if (hunter != null) {
    return m('lynchedBounty', {'name': name, 'hunter': tag(hunter)});
  }
  if (role.team == Team.neutral) {
    return m('lynchedNeutral', {'name': name, 'role': roleLabel(role)});
  }
  final mafia = role.team == Team.mafia;
  return m(mafia ? 'lynchedFamily' : 'lynchedInnocent', {'name': name});
}
