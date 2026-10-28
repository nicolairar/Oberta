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

  bool get _en => language == AppLanguage.en;

  String _t(String it, String en) => _en ? en : it;

  // ---- The recap.
  String get open => _t('IL RESOCONTO', 'THE FULL ACCOUNT');
  String get masthead => _t('Il Resoconto', 'The Full Account');
  String get dateLine => _t('Edizione straordinaria · tutte le carte in tavola', 'Special edition · every card on the table');
  String get cast => _t('Chi era chi', 'Who was who');
  String get timeline => _t('Notte per notte, giorno per giorno', 'Night by night, day by day');
  String night(int round) => _t('Notte $round', 'Night $round');
  String day(int round) => _t('Giorno $round', 'Day $round');
  String get won => _t('VINCE', 'WON');
  String get wonAlone => _t('VINCE DA SOLO', 'WON ALONE');
  String get survived => _t('in piedi', 'standing');
  String get fell => _t('caduto', 'fallen');
  String get left => _t('se n\'è andato', 'walked out');
  String get close => _t('CHIUDI', 'CLOSE');
  String get you => _t('tu', 'you');
  String get quietNight => _t('Una notte senza mosse.', 'A night without a move.');

  String team(Team team) => switch (team) {
    Team.citizens => _t('cittadino', 'town'),
    Team.mafia => _t('famiglia', 'family'),
    Team.neutral => _t('per conto suo', 'on their own'),
  };

  String winner(Team? team) => switch (team) {
    Team.citizens => _t('Vince la città', 'The town wins'),
    Team.mafia => _t('Vince la famiglia', 'The family wins'),
    Team.neutral => _t('Vince il Piromane', 'The Arsonist wins'),
    null => _t('Nessun vincitore', 'No winner'),
  };

  String familyAimed(String target, String voters) =>
      _t('La famiglia ha puntato $target ($voters).', 'The family went for $target ($voters).');
  String get familyNobody => _t('La famiglia non si è messa d\'accordo.', 'The family could not agree.');

  String move(NightTaskKind kind, String target, {Team? seen, String? role, bool? visited}) => switch (kind) {
    NightTaskKind.silence => _t('ha cucito la bocca a $target.', 'sewed $target\'s mouth shut.'),
    NightTaskKind.protect => _t('ha vegliato su $target.', 'watched over $target.'),
    NightTaskKind.guard => _t('ha fatto da scorta a $target.', 'stood guard for $target.'),
    NightTaskKind.investigate => _t(
      'ha indagato su $target: risultava ${seen == Team.mafia ? 'della famiglia' : 'pulito'}.',
      'investigated $target: came back ${seen == Team.mafia ? 'family' : 'clean'}.',
    ),
    NightTaskKind.dig => _t('ha scavato la fossa di $target: era ${inline(role ?? '')}.', 'dug up $target: they were the $role.'),
    NightTaskKind.snipe => _t('ha sparato a $target.', 'took a shot at $target.'),
    NightTaskKind.scoop => _t('ha scritto lo scoop su $target.', 'ran the scoop on $target.'),
    NightTaskKind.douse => _t('ha cosparso di benzina $target.', 'doused $target in petrol.'),
    NightTaskKind.ignite => _t('ha acceso il fiammifero.', 'struck the match.'),
    NightTaskKind.resurrect => _t('ha richiamato in vita $target.', 'called $target back to life.'),
    NightTaskKind.lend => _t('ha prestato soldi a $target.', 'lent money to $target.'),
    NightTaskKind.stab => _t('ha colpito $target.', 'knifed $target.'),
    NightTaskKind.jail => _t('ha chiuso in cella $target.', 'locked $target up.'),
    NightTaskKind.block => _t('ha passato la notte con $target.', 'spent the night with $target.'),
    NightTaskKind.watch => _t(
      'ha sorvegliato la porta di $target: ${visited == true ? 'qualcuno è passato' : 'nessuno è passato'}.',
      'watched $target\'s door: ${visited == true ? 'someone came by' : 'nobody came by'}.',
    ),
    NightTaskKind.kill || NightTaskKind.decoy => '',
  };

  String attack(AttackOutcome outcome, AttackSource source, String target) {
    final by = switch (source) {
      AttackSource.family => _t('dalla famiglia', 'by the family'),
      AttackSource.sniper => _t('dal Cecchino', 'by the Sniper'),
      AttackSource.fire => _t('dal fuoco', 'by the fire'),
      AttackSource.assassin => _t('dal Sicario', 'by the Hitman'),
    };
    final g = PlayerGenders.of(target);
    return switch (outcome) {
      AttackOutcome.killed => _t(
        agree(g, m: '$target è stato ucciso $by.', f: '$target è stata uccisa $by.', n: '$target non ce la fa: il colpo arriva $by.'),
        '$target was killed $by.',
      ),
      AttackOutcome.healed => _t(
        agree(g, m: '$target, colpito $by, è stato salvato.', f: '$target, colpita $by, è stata salvata.', n: 'Il colpo arriva $by, ma $target si salva.'),
        '$target, hit $by, was saved.',
      ),
      AttackOutcome.shrugged => _t('$target ha incassato il colpo $by.', '$target took the blow $by and lived.'),
    };
  }

  String scoopOut(String target, Team team) => switch (team) {
    Team.mafia => _t('Il giornale esce: $target è della famiglia.', 'The paper is out: $target is family.'),
    Team.citizens => _t('Il giornale esce: $target è pulito.', 'The paper is out: $target is clean.'),
    Team.neutral => _t('Il giornale esce: $target fa per conto suo.', 'The paper is out: $target plays alone.'),
  };

  /// A role name in the middle of an Italian sentence: "era il Picciotto".
  String inline(String role) => _en || role.isEmpty ? role : role[0].toLowerCase() + role.substring(1);
  String risen(String target) => _t(
    agree(PlayerGenders.of(target), m: '$target è tornato tra i vivi.', f: '$target è tornata tra i vivi.', n: '$target torna tra i vivi.'),
    '$target is back among the living.',
  );
  String mayor(String name) => _t('$name si rivela Sindaco: il suo voto vale due.', '$name reveals the Mayor: their vote counts twice.');
  String get votes => _t('Lo scrutinio', 'The ballot');
  String get abstained => _t('si astiene', 'abstains');
  String condemned(String name, String role) =>
      _t('La piazza condanna $name. Era ${inline(role)}.', 'The square condemns $name. They were the $role.');
  String get noCondemned => _t('La piazza non condanna nessuno.', 'The square condemns nobody.');
  String foolWins(String name) => _t('$name voleva proprio questo: vince da solo.', '$name wanted exactly this: wins alone.');
  String bounty(String hunter) => _t('$hunter incassa la taglia.', '$hunter collects the bounty.');
  String exit(String name) => _t('$name ha lasciato la città.', '$name left town.');

  // ---- The notices on the table.
  String leftTown(String name) => _t('$name esce di scena.', '$name has left the scene.');
  String wentAway(String name) => _t('$name si allontana dal tavolo.', '$name stepped away from the table.');
  String cameBack(String name) => _t('$name di nuovo al tavolo.', '$name is back at the table.');
  String calledOut(String name) => _t('$name ti chiama in causa.', '$name is calling you out.');
}
