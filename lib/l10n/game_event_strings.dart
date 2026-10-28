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
          if (d['escorted'] == true) _t('La scorta ha respinto un attentato al Presidente.', 'The escort fended off an attack on the President.'),
          if (saved == 1) _t('Qualcuno è stato salvato.', 'Someone was saved.'),
          if (saved > 1) _t('$saved agguati sventati.', '$saved attacks foiled.'),
          if (d['resurrected'] case final String back)
            _t(
              agree(PlayerGenders.of(back), m: '$back è tornato tra i vivi.', f: '$back è tornata tra i vivi.', n: '$back torna tra i vivi.'),
              '$back is back among the living.',
            ),
          for (final broken in (d['heartbroken'] as List<Object?>? ?? const []))
            _t('Il cuore di $broken si è spezzato.', '$broken died of a broken heart.'),
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
        final broken = d['heartbroken'] == null
            ? ''
            : _t(' Il cuore di ${d['heartbroken']} si è spezzato.', ' ${d['heartbroken']} died of a broken heart.');
        return tally.isEmpty ? '$verdict$hunter$broken' : '$verdict$hunter$broken ($tally)';
      case 'mayor':
        return _t('$name si rivela Sindaco: il suo voto vale doppio.', '$name reveals the Mayor: their vote counts twice.');
      case 'truce':
        return _t(
          '$name, il Pacifista, chiede la tregua: ${d['target']} è ${_role(d['role'])}. Oggi non si vota.',
          '$name, the Pacifist, calls a truce: ${d['target']} is the ${_role(d['role'])}. No vote today.',
        );
      case 'cannon':
        final broken = d['heartbroken'] == null
            ? ''
            : _t(' Il cuore di ${d['heartbroken']} si è spezzato.', ' ${d['heartbroken']} died of a broken heart.');
        return _t(
              'Un boato in piazza: $name, l\'Artigliere, ha colpito ${d['target']}, che era ${_role(d['role'])}.',
              'A roar in the square: $name, the Gunner, hit ${d['target']}, who was the ${_role(d['role'])}.',
            ) +
            broken;
      case 'shot':
        final brokenShot = d['heartbroken'] == null
            ? ''
            : _t(' Il cuore di ${d['heartbroken']} si è spezzato.', ' ${d['heartbroken']} died of a broken heart.');
        return (d['backfired'] == true
                ? _t('Un colpo dal campanile torna indietro: $name, ${_role(d['role'])}, mirava a uno della Città.',
                    'A shot from the bell tower comes back: $name, the ${_role(d['role'])}, was aiming at the town.')
                : _t('Un colpo dal campanile: $name è a terra. Era ${_role(d['role'])}.',
                    'A shot from the bell tower: $name is down. The ${_role(d['role'])}.')) +
            brokenShot;
      case 'aim':
        return _t('Hai $name nel mirino.', 'You have $name in your sights.');
      case 'cell':
        return d['self'] == true
            ? _t('Sei in cella. Stanotte non esci.', 'You are in a cell. You are not going out tonight.')
            : _t('Stanotte $name è in cella.', 'Tonight $name is in a cell.');
      case 'lovers':
        final names = [for (final n in (d['names'] as List<Object?>? ?? const [])) '$n'];
        if (d['self'] != true) return _t('Hai legato ${names.join(' e ')}.', 'You bound ${names.join(' and ')}.');
        return _t('Il cuore ha scelto: ${names.join(' e ')} si amano. Vincete solo se restate vivi tutti e due.',
            'The heart has chosen: ${names.join(' and ')} are in love. You win only if both of you live.');
      case 'converted':
        return _t('Hai visto la luce: ora sei della setta, e vinci solo con lei.',
            'You have seen the light: you are in the cult now, and win only with it.');
      case 'door':
        return d['converted'] == true
            ? _t('$name è dei tuoi, ora.', '$name is one of yours now.')
            : _t('Porta chiusa: $name non si è convertito.', 'Door shut: $name did not convert.');
      case 'busy':
        return _t('Stanotte qualcuno ti ha tenuto occupato.', 'Last night someone kept you busy.');
      case 'left':
        return _t('$name ha lasciato la città.', '$name has left town.');
      case 'end':
        if (d['abandoned'] == true) return _t('Partita chiusa: non giocava più nessuno.', 'Game closed: nobody was playing.');
        final alone = _names(d['alone']);
        final fell = d['presidentFell'] == true ? _t(' Il Presidente è caduto.', ' The President has fallen.') : '';
        return _t('Fine della partita: ${_winner(d['winner'])}.', 'Game over: ${_winner(d['winner'])}.') + fell +
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
