import 'package:flutter/widgets.dart';

import 'app_language.dart';
import 'app_strings.dart';
import '../online/game/progress.dart' show Achievement;

/// The words of missions, achievements and the leaderboard, in Italian and
/// English. Missions and achievements are named by their stable ids.
class ProgressStrings {
  final AppLanguage language;

  const ProgressStrings(this.language);

  static ProgressStrings of(BuildContext context) => ProgressStrings(AppStrings.of(context).language);

  bool get _en => language == AppLanguage.en;

  String _t(String it, String en) => _en ? en : it;

  String get missions => _t('Missioni', 'Missions');
  String get achievements => _t('Medaglie', 'Achievements');
  String get leaderboard => _t('Classifica', 'Leaderboard');
  String get daily => _t('DI GIORNATA', 'DAILY');
  String get weekly => _t('DELLA SETTIMANA', 'WEEKLY');
  String get goals => _t('OBIETTIVI', 'GOALS');
  String get tabDaily => _t('OGGI', 'TODAY');
  String get tabWeekly => _t('SETTIMANA', 'WEEK');
  String get tabGoals => _t('OBIETTIVI', 'GOALS');
  String get missionsHint => _t(
        'Si completano giocando, poi si riscuotono. Le monete si guadagnano solo così: niente si compra con soldi veri. Non contano le partite abbandonate o giocate da assente.',
        'They complete as you play, then you claim them. Coins are only earned this way: nothing is bought with real money. Abandoned or idle games never count.',
      );
  String get goalsHint => _t(
        'Gli obiettivi restano finché non li prendi. Alcuni regalano pezzi che in bottega non si vendono.',
        'Goals stay until you reach them. Some give pieces the shop never sells.',
      );
  String get claim => _t('RISCUOTI', 'CLAIM');
  String get claimed => _t('RISCOSSO', 'CLAIMED');
  String get late => _t('DI IERI', 'EARLIER');
  String get reputation => _t('RISPETTO', 'RESPECT');
  String reputationGain(int n) => _t('+$n rispetto', '+$n respect');
  String claimDone(int coins, int reputation) =>
      _t('Riscosso: $coins monete, +$reputation rispetto', 'Claimed: $coins coins, +$reputation respect');
  String itemWon(String name) => _t('In regalo: $name', 'Yours now: $name');
  String reward(String name) => _t('Premio: $name', 'Reward: $name');
  String toClaim(int n) => _t(n == 1 ? '1 da riscuotere' : '$n da riscuotere', '$n to claim');
  String unlocksWith(String mission) => _t('Si sblocca con: $mission', 'Unlocks with: $mission');
  String get missionOnly => _t('Solo con le missioni', 'Missions only');
  String get done => _t('FATTO', 'DONE');
  String endsIn(Duration d) {
    final h = d.inHours;
    if (h >= 48) return _t('scade fra ${d.inDays} giorni', 'ends in ${d.inDays} days');
    if (h >= 1) return _t('scade fra $h ore', 'ends in ${h}h');
    return _t('scade fra ${d.inMinutes.clamp(1, 59)} minuti', 'ends in ${d.inMinutes.clamp(1, 59)} min');
  }

  String get loadFailed => _t('Non è stato possibile caricare. Riprova.', 'Could not load. Try again.');
  String get retry => _t('Riprova', 'Retry');
  String unlockedCount(int n, int of) => _t('$n su $of', '$n of $of');
  String get locked => _t('Da conquistare', 'Locked');
  String rewardTitle(String title) => _t('Titolo: «$title»', 'Title: "$title"');
  String get rewardFrame => _t('Cornice in regalo', 'Free frame');
  String get title => _t('TITOLO', 'TITLE');

  String get leaderboardEmpty => _t('Nessuno in classifica, per ora.', 'Nobody on the board yet.');
  String get leaderboardHint => _t('I primi cento della classificata, per lingua.', 'The top hundred in ranked, by language.');
  String yourPlace(int rank) => _t('Sei al $rank° posto', 'You are #$rank');
  String get notRanked => _t('Gioca una classificata per entrare in classifica.', 'Play a ranked game to get on the board.');

  String missionDone(String name) => _t('Missione compiuta: $name. Riscuotila!', 'Mission complete: $name. Claim it!');
  String achievementDone(String name) => _t('Medaglia: $name', 'Achievement: $name');

  /// A mission's text, from its id (with a generic fallback by metric).
  String mission(String id, {String metric = '', int target = 1}) => switch (id) {
        'daily_play_3' => _t('Gioca 3 partite', 'Play 3 games'),
        'daily_win_1' => _t('Vinci una partita', 'Win a game'),
        'daily_friends_win_2' => _t('Vinci 2 partite con amici', 'Win 2 games with friends'),
        'daily_lynch_hits_3' => _t('Vota il mafioso giusto 3 volte', 'Vote for the right mafioso 3 times'),
        'daily_nights_2' => _t('Sopravvivi a 2 notti', 'Survive 2 nights'),
        'daily_ranked_1' => _t('Gioca 1 partita classificata', 'Play 1 ranked game'),
        'daily_survive_1' => _t('Arriva vivo alla fine di una partita', 'Be alive at the end of a game'),
        'daily_town_win_1' => _t('Vinci con la città', 'Win with the town'),
        'daily_mafia_win_1' => _t('Vinci con la famiglia', 'Win with the family'),
        'weekly_neutral_win_1' => _t('Vinci da neutrale', 'Win as a neutral'),
        'weekly_wins_7' => _t('Vinci 7 partite', 'Win 7 games'),
        'weekly_play_15' => _t('Gioca 15 partite', 'Play 15 games'),
        'weekly_lynch_hits_10' => _t('Vota il mafioso giusto 10 volte', 'Vote for the right mafioso 10 times'),
        'weekly_ranked_5' => _t('Gioca 5 partite classificate', 'Play 5 ranked games'),
        'weekly_ranked_wins_3' => _t('Vinci 3 partite classificate', 'Win 3 ranked games'),
        'weekly_saves_2' => _t('Salva 2 vite da Dottore', 'Save 2 lives as the Doctor'),
        'weekly_finds_3' => _t('Smaschera 3 mafiosi da Commissario', 'Unmask 3 mafiosi as the Detective'),
        'weekly_kills_5' => _t('Porta a segno 5 agguati con la famiglia', 'Pull off 5 hits with the family'),
        'weekly_nights_12' => _t('Sopravvivi a 12 notti', 'Survive 12 nights'),
        'daily_friends_play_2' => _t('Gioca 2 partite con amici', 'Play 2 games with friends'),
        'daily_win_alive_1' => _t('Vinci e arriva vivo alla fine', 'Win and live to the end'),
        'daily_survive_2' => _t('Arriva vivo alla fine di 2 partite', 'Be alive at the end of 2 games'),
        'weekly_play_10' => _t('Gioca 10 partite', 'Play 10 games'),
        'weekly_wins_4' => _t('Vinci 4 partite', 'Win 4 games'),
        'weekly_town_wins_3' => _t('Vinci 3 volte con la città', 'Win 3 times with the town'),
        'weekly_mafia_wins_2' => _t('Vinci 2 volte con la famiglia', 'Win 2 times with the family'),
        'weekly_detective_win_1' => _t('Vinci una partita da Commissario', 'Win a game as the Detective'),
        'weekly_doctor_win_1' => _t('Vinci una partita da Dottore', 'Win a game as the Doctor'),
        'long_nights_10' => _t('Sopravvivi a 10 notti', 'Survive 10 nights'),
        'long_lynch_hits_3' => _t('Manda al patibolo 3 picciotti', 'Send 3 mobsters to the gallows'),
        'long_detective_wins_5' => _t('Vinci 5 partite da Commissario', 'Win 5 games as the Detective'),
        'long_finds_5' => _t('Smaschera 5 mafiosi da Commissario', 'Unmask 5 mafiosi as the Detective'),
        'long_mafia_wins_10' => _t('Vinci 10 volte con la famiglia', 'Win 10 times with the family'),
        'long_town_wins_10' => _t('Vinci 10 volte con la città', 'Win 10 times with the town'),
        'long_wins_50' => _t('Vinci 50 partite', 'Win 50 games'),
        'long_games_25' => _t('Gioca 25 partite', 'Play 25 games'),
        'long_friends_games_20' => _t('Gioca 20 partite con amici', 'Play 20 games with friends'),
        'long_ranked_games_20' => _t('Gioca 20 partite classificate', 'Play 20 ranked games'),
        'long_saves_5' => _t('Salva 5 vite da Dottore', 'Save 5 lives as the Doctor'),
        'long_survived_25' => _t('Arriva vivo alla fine di 25 partite', 'Be alive at the end of 25 games'),
        'long_neutral_wins_3' => _t('Vinci 3 volte da neutrale', 'Win 3 times as a neutral'),
        _ => _t('Obiettivo: $target', 'Goal: $target'),
      };

  /// An achievement's name and what it asks.
  (String, String) achievement(String id) => switch (id) {
        'wins_10' => (_t('Fortunato', 'Lucky'), _t('Vinci 10 partite', 'Win 10 games')),
        'wins_50' => (_t('Uomo d\'onore', 'Man of honor'), _t('Vinci 50 partite', 'Win 50 games')),
        'wins_200' => (_t('Leggenda', 'Legend'), _t('Vinci 200 partite', 'Win 200 games')),
        'games_25' => (_t('Habitué', 'Regular'), _t('Gioca 25 partite', 'Play 25 games')),
        'games_100' => (_t('Di casa', 'Part of the furniture'), _t('Gioca 100 partite', 'Play 100 games')),
        'games_500' => (_t('Veterano', 'Veteran'), _t('Gioca 500 partite', 'Play 500 games')),
        'ranked_wins_10' => (_t('Sul tavolo verde', 'On the green felt'), _t('Vinci 10 classificate', 'Win 10 ranked games')),
        'ranked_wins_50' => (_t('Capobastone', 'Boss'), _t('Vinci 50 classificate', 'Win 50 ranked games')),
        'friends_wins_25' => (_t('Fra amici', 'Among friends'), _t('Vinci 25 partite con amici', 'Win 25 games with friends')),
        'town_wins_25' => (_t('Cittadino modello', 'Model citizen'), _t('Vinci 25 volte con la città', 'Win 25 times with the town')),
        'mafia_wins_25' => (_t('Uomo di panza', 'Made man'), _t('Vinci 25 volte con la famiglia', 'Win 25 times with the family')),
        'neutral_wins_1' => (_t('Per conto mio', 'On my own'), _t('Vinci da neutrale', 'Win as a neutral')),
        'neutral_wins_10' => (_t('Cane sciolto', 'Lone wolf'), _t('Vinci 10 volte da neutrale', 'Win 10 times as a neutral')),
        'roles_won_5' => (_t('Mille facce', 'Many faces'), _t('Vinci con 5 ruoli diversi', 'Win with 5 different roles')),
        'roles_won_12' => (_t('Attore consumato', 'Seasoned actor'), _t('Vinci con 12 ruoli diversi', 'Win with 12 different roles')),
        'roles_won_all' => (_t('Trasformista', 'Chameleon'), _t('Vinci con ogni ruolo', 'Win with every role')),
        'roles_town_all' => (_t('Tutto il villaggio', 'The whole village'), _t('Vinci con ogni ruolo del villaggio', 'Win with every village role')),
        'roles_mafia_all' => (_t('Tutta la famiglia', 'The whole family'), _t('Vinci con ogni ruolo della mafia', 'Win with every mafia role')),
        'roles_lone_all' => (_t('Tutti i solitari', 'Every loner'), _t('Vinci con ogni ruolo solitario', 'Win with every loner role')),
        'wins_alive_25' => (_t('Pelle dura', 'Thick skin'), _t('Vinci 25 volte da vivo', 'Win 25 times still alive')),
        'lynch_hits_10' => (_t('Buon fiuto', 'Good nose'), _t('Vota 10 mafiosi condannati', 'Vote 10 condemned mafiosi')),
        'lynch_hits_50' => (_t('Segugio', 'Bloodhound'), _t('Vota 50 mafiosi condannati', 'Vote 50 condemned mafiosi')),
        'lynch_hits_200' => (_t('Giustiziere', 'Avenger'), _t('Vota 200 mafiosi condannati', 'Vote 200 condemned mafiosi')),
        'nights_25' => (_t('Insonne', 'Sleepless'), _t('Sopravvivi a 25 notti', 'Survive 25 nights')),
        'nights_100' => (_t('Nottambulo', 'Night owl'), _t('Sopravvivi a 100 notti', 'Survive 100 nights')),
        'saves_1' => (_t('Primo soccorso', 'First aid'), _t('Salva una vita da Dottore', 'Save a life as the Doctor')),
        'saves_10' => (_t('Angelo custode', 'Guardian angel'), _t('Salva 10 vite da Dottore', 'Save 10 lives as the Doctor')),
        'doctor_save_survive' => (
            _t('Medico condotto', 'Country doctor'),
            _t('Da Dottore, salva qualcuno e arriva vivo alla fine', 'As the Doctor, save someone and live to the end'),
          ),
        'finds_10' => (_t('Fiuto da sbirro', 'Cop instinct'), _t('Smaschera 10 mafiosi da Commissario', 'Unmask 10 mafiosi as the Detective')),
        'godfather_lynch' => (
            _t('Il Commissario', 'The Inspector'),
            _t('Da Commissario, manda il Padrino al patibolo', 'As the Detective, send the Godfather to the gallows'),
          ),
        'snipes_1' => (_t('Colpo secco', 'Clean shot'), _t('Da Cecchino, abbatti un mafioso', 'As the Sniper, take down a mafioso')),
        'kills_25' => (_t('Mano pesante', 'Heavy hand'), _t('25 agguati riusciti con la famiglia', '25 successful hits with the family')),
        'framed_5' => (_t('Tragediatore', 'Schemer'), _t('Da mafioso, fai condannare 5 innocenti', 'As a mafioso, get 5 innocents condemned')),
        'fool_win' => (_t('Ride bene chi ride ultimo', 'Last laugh'), _t('Vinci da Fesso', 'Win as the Fool')),
        _ => switch (Achievement.roleOf(id)) {
            final role? => (
                language.strings.role(role).label,
                _t('Vinci una partita con questo ruolo', 'Win a game with this role'),
              ),
            null => (id, ''),
          },
      };

  /// A title from an achievement, as shown in the dossier.
  String titleName(String id) => switch (id) {
        'man_of_honor' => _t('Uomo d\'onore', 'Man of honor'),
        'legend' => _t('Leggenda', 'Legend'),
        'veteran' => _t('Veterano', 'Veteran'),
        'boss' => _t('Capobastone', 'Boss'),
        'model_citizen' => _t('Cittadino modello', 'Model citizen'),
        'made_man' => _t('Uomo di panza', 'Made man'),
        'lone_wolf' => _t('Cane sciolto', 'Lone wolf'),
        'chameleon' => _t('Trasformista', 'Chameleon'),
        'bloodhound' => _t('Segugio', 'Bloodhound'),
        'night_owl' => _t('Nottambulo', 'Night owl'),
        'guardian_angel' => _t('Angelo custode', 'Guardian angel'),
        'inspector' => _t('Il Commissario', 'The Inspector'),
        'schemer' => _t('Tragediatore', 'Schemer'),
        _ => id,
      };
}
