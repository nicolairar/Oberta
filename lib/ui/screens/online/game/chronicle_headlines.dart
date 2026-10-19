import '../../../../rules/game_engine.dart';
import '../../../../rules/player.dart';
import '../../../../rules/role.dart';

/// Il titolone dell'alba e i nomi da ritrarre in prima pagina: la stessa
/// cronaca per la partita online e per la sala prove.
({String headline, List<String> dead}) dawnHeadline(
  DawnReport dawn, {
  required bool italian,
  required String everyoneAlive,
}) {
  final dead = [
    for (final attack in dawn.attacks)
      if (attack.isFatal) attack.target.name,
  ];
  final names = dead.join(italian ? ' E ' : ' AND ');
  final risen = dawn.resurrected?.name;
  final burned = [
    for (final attack in dawn.attacks)
      if (attack.isFatal && attack.source == AttackSource.fire) attack.target.name,
  ];
  final others = [
    for (final name in dead)
      if (!burned.contains(name)) name,
  ];
  final headline = burned.isNotEmpty
      ? (italian
            ? 'Rogo nella notte: ${burned.join(' e ')}${others.isEmpty ? '' : '. Morto anche ${others.join(' e ')}'}'
            : 'Night fire: ${burned.join(' and ')} burned${others.isEmpty ? '' : ', ${others.join(' and ')} also dead'}')
      : dead.isEmpty && risen != null
      ? (italian ? '$risen torna dalla tomba' : '$risen back from the grave')
      : dead.isEmpty
      ? everyoneAlive
      : italian
      ? (dead.length > 1 ? 'Trovati morti $names' : 'Trovato morto $names')
      : '$names found dead';
  return (headline: headline, dead: dead);
}

/// Il titolo della sera, dopo il verdetto. [tag] scrive il nome sul giornale.
String lynchHeadline(
  LynchReport report, {
  required bool italian,
  required String Function(Player) tag,
  required String Function(Role) roleLabel,
}) {
  final condemned = report.condemned;
  final role = report.role;
  if (condemned == null) return italian ? 'La piazza non si decide' : 'The square cannot decide';
  final name = tag(condemned);
  if (role == null) return italian ? 'Linciato $name' : '$name lynched';
  if (report.personalWin) return italian ? 'Linciato $name: il Fesso ha vinto' : '$name lynched: the Fool wins';
  final hunter = report.bountyHunter;
  if (hunter != null) {
    return italian
        ? 'Linciato $name: ${tag(hunter)} incassa la taglia'
        : '$name lynched: ${tag(hunter)} collects the bounty';
  }
  if (role.team == Team.neutral) {
    return italian ? 'Linciato $name: era ${roleLabel(role)}' : '$name lynched: ${roleLabel(role)}';
  }
  final mafia = role.team == Team.mafia;
  return italian
      ? 'Linciato $name: ${mafia ? 'era della Famiglia' : 'era innocente'}'
      : '$name lynched: ${mafia ? 'one of the Family' : 'an innocent man'}';
}
