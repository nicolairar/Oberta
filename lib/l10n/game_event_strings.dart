import '../online/game/game_backend.dart';
import '../rules/role.dart';
import 'app_language.dart';
import 'app_strings.dart';
import 'player_gender.dart';

/// The server's lines in the chat (see lib/online/game/game_events.dart),
/// in Italian and English. Names and roles come with the event.
class GameEventStrings {
  final AppStrings strings;

  const GameEventStrings(this.strings);

  bool get _en => strings.language == AppLanguage.en;

  String _t(String it, String en) => _en ? en : it;

  /// The label on a private line.
  String get onlyYou => _t('SOLO TU', 'ONLY YOU');

  String _role(Object? name) {
    final role = name is String ? Role.values.asNameMap()[name] : null;
    return role == null ? '?' : strings.role(role).label;
  }

  String _team(Object? team) => switch (team) {
        'mafia' => _t('della famiglia', 'with the family'),
        'neutral' => _t('per conto suo', 'on their own'),
        _ => _t('pulito', 'clean'),
      };

  String _names(Object? list) => [for (final name in (list as List<Object?>? ?? const [])) '$name'].join(', ');

  String _winner(Object? team) => switch (team) {
        'citizens' => _t('vince la città', 'the town wins'),
        'mafia' => _t('vince la famiglia', 'the family wins'),
        'neutral' => _t('vince chi giocava da solo', 'a lone player wins'),
        _ => _t('nessun vincitore', 'no winner'),
      };

  String text(GameEvent event) {
    final d = event.data;
    final name = '${d['name'] ?? '?'}';
    switch (event.kind) {
      case 'night':
        return _t('Cala la notte ${d['round']}. La città dorme.', 'Night ${d['round']} falls. The town sleeps.');
      case 'dawn':
        final dead = (d['dead'] as List<Object?>? ?? const []);
        final saved = (d['saved'] as num?)?.toInt() ?? 0;
        final parts = <String>[
          _t('Sorge il giorno ${d['round']}.', 'Day ${d['round']} breaks.'),
          if (dead.isEmpty) _t('Nessun morto stanotte.', 'Nobody died tonight.'),
          if (dead.length == 1)
            _t(
              agree(
                PlayerGenders.of('${dead.single}'),
                m: 'Trovato morto: ${dead.single}.',
                f: 'Trovata morta: ${dead.single}.',
                n: 'Vittima della notte: ${dead.single}.',
              ),
              'Found dead: ${dead.single}.',
            ),
          if (dead.length > 1) _t('Trovati morti: ${_names(dead)}.', 'Found dead: ${_names(dead)}.'),
          if (saved == 1) _t('Qualcuno è stato salvato.', 'Someone was saved.'),
          if (saved > 1) _t('$saved agguati sventati.', '$saved attacks foiled.'),
          if (d['resurrected'] case final String back)
            _t(
              agree(PlayerGenders.of(back), m: '$back è tornato tra i vivi.', f: '$back è tornata tra i vivi.', n: '$back torna tra i vivi.'),
              '$back is back among the living.',
            ),
        ];
        return parts.join(' ');
      case 'scoop':
        final role = d['role'];
        return role != null
            ? _t('Lo scoop del giornale: $name è ${_role(role)}.', 'The paper\'s scoop: $name is the ${_role(role)}.')
            : _t('Lo scoop del giornale: $name è ${_team(d['team'])}.', 'The paper\'s scoop: $name is ${_team(d['team'])}.');
      case 'silenced':
        return _t('Il Sarto ha cucito la bocca a $name: oggi tace.', 'The Tailor sewed $name\'s mouth shut: silent today.');
      case 'lynch':
        final votes = [
          for (final v in (d['votes'] as List<Object?>? ?? const []).cast<Map<String, Object?>>()) '${v['name']} ${v['count']}',
        ];
        final abstained = (d['abstained'] as num?)?.toInt() ?? 0;
        final tally = [
          ...votes,
          if (abstained > 0) _t('astenuti $abstained', 'abstained $abstained'),
        ].join(' · ');
        final verdict = d['name'] == null
            ? _t('La piazza non condanna nessuno.', 'The square condemns nobody.')
            : _t('La piazza condanna $name: era ${_role(d['role'])}.', 'The square condemns $name: the ${_role(d['role'])}.');
        final hunter = d['bountyHunter'] == null
            ? ''
            : _t(' ${d['bountyHunter']} incassa la taglia.', ' ${d['bountyHunter']} collects the bounty.');
        return tally.isEmpty ? '$verdict$hunter' : '$verdict$hunter ($tally)';
      case 'mayor':
        return _t('$name si rivela Sindaco: il suo voto vale doppio.', '$name reveals the Mayor: their vote counts twice.');
      case 'left':
        return _t('$name ha lasciato la città.', '$name has left town.');
      case 'end':
        if (d['abandoned'] == true) return _t('Partita chiusa: non giocava più nessuno.', 'Game closed: nobody was playing.');
        final alone = _names(d['alone']);
        return _t('Fine della partita: ${_winner(d['winner'])}.', 'Game over: ${_winner(d['winner'])}.') +
            (alone.isEmpty ? '' : _t(' Vince da solo: $alone.', ' Won alone: $alone.'));
      case 'found':
        return d['role'] != null
            ? _t('$name era ${_role(d['role'])}.', '$name was the ${_role(d['role'])}.')
            : _t('$name risulta ${_team(d['team'])}.', '$name comes up ${_team(d['team'])}.');
      case 'watch':
        return d['visited'] == true
            ? _t('Alla porta di $name è passato qualcuno.', 'Someone came to $name\'s door.')
            : _t('Alla porta di $name non è passato nessuno.', 'Nobody came to $name\'s door.');
      case 'bounty':
        return _t('La tua taglia: fai linciare $name.', 'Your bounty: get $name lynched.');
      case 'doused':
        return _t('Cosparsi di benzina: ${_names(d['names'])}.', 'Doused in petrol: ${_names(d['names'])}.');
      case 'familyTarget':
        return d['name'] == null
            ? _t('La famiglia non si è messa d\'accordo.', 'The family could not agree.')
            : _t('La famiglia ha scelto $name.', 'The family chose $name.');
      case 'protected':
        return switch (d['kind']) {
          'guard' => _t('Stanotte hai fatto da scorta a $name.', 'Tonight you stood guard for $name.'),
          'lend' => _t('Stanotte hai prestato soldi a $name.', 'Tonight you lent money to $name.'),
          _ => _t('Stanotte hai vegliato su $name.', 'Tonight you watched over $name.'),
        };
    }
    return '';
  }
}
