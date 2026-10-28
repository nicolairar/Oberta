import 'package:flutter/widgets.dart';

import 'app_language.dart';
import 'app_strings.dart';

/// The words of the dossier's stats page, in Italian and English.
class StatsStrings {
  final AppLanguage language;

  const StatsStrings(this.language);

  static StatsStrings of(BuildContext context) => StatsStrings(AppStrings.of(context).language);

  bool get _en => language == AppLanguage.en;

  String _t(String it, String en) => _en ? en : it;

  /// The two index tabs of the folder.
  String get tabFile => _t('SCHEDA', 'FILE');
  String get tabStats => _t('STATISTICHE', 'STATS');

  String get title => _t('STATISTICHE PERSONALI', 'PERSONAL STATS');
  String get includeTests => _t('Includi partite di prova', 'Include test matches');
  String includeTestsCount(int n) => '$includeTests ($n)';

  String get games => _t('Partite', 'Games');
  String get wins => _t('Vinte', 'Won');
  String get losses => _t('Perse', 'Lost');
  String get winRate => _t('Vittorie', 'Win rate');

  String get atTheTable => _t('AL TAVOLO', 'AT THE TABLE');
  String get timePlayed => _t('Tempo al tavolo', 'Time at the table');
  String timeMeasured(int timed, int games) =>
      _t('misurato su $timed partite di $games', 'measured over $timed of $games games');
  String get favouriteRole => _t('Ruolo preferito', 'Favourite role');
  String get longestStreak => _t('Serie di vittorie più lunga', 'Longest win streak');
  String get survived => _t('Vivo alla fine', 'Alive at the end');

  String get byTable => _t('PER TAVOLO', 'BY TABLE');
  String get friends => _t('Con amici', 'With friends');
  String get ranked => _t('Classificata', 'Ranked');

  String get byFaction => _t('PER FAZIONE', 'BY FACTION');
  String get family => _t('Famiglia', 'Family');
  String get town => _t('Città', 'Town');
  String get alone => _t('Da solo', 'On their own');

  String get byRole => _t('PER RUOLO', 'BY ROLE');
  String gamesWins(int games, int wins) =>
      _t('$games ${games == 1 ? 'partita' : 'partite'} · $wins vinte', '$games ${games == 1 ? 'game' : 'games'} · $wins won');
  String get neverPlayed => _t('mai giocato', 'never played');

  String get feats => _t('IMPRESE', 'FEATS');
  String get featsHint =>
      _t('Di sempre, solo dalle partite giocate fino in fondo.', 'All time, only from games played to the end.');

  /// A lifetime counter's label, by metric id; null for those not shown.
  String? counter(String metric) => switch (metric) {
    'nights' => _t('Notti sopravvissute', 'Nights survived'),
    'lynch_hits' => _t('Voti giusti al rogo', 'Right lynch votes'),
    'saves' => _t('Salvataggi del Dottore', 'Doctor saves'),
    'finds' => _t('Colpevoli scoperti', 'Culprits found'),
    'snipes' => _t('Colpi del Cecchino', 'Sniper shots'),
    'kills' => _t('Colpi della Famiglia', 'Family hits'),
    'framed' => _t('Onesti incastrati', 'Honest framed'),
    'godfather_lynch' => _t('Padrini al rogo', 'Godfathers lynched'),
    'wins_alive' => _t('Vinte da vivo', 'Won alive'),
    _ => null,
  };

  String get private => _t('SOLO PER TE', 'ONLY FOR YOU');
  String get privateHint => _t('Nessun altro vede questi numeri.', 'Nobody else sees these numbers.');
  String get abandoned => _t('Abbandonate', 'Abandoned');
  String get afk => _t('Da assente', 'Away (AFK)');
  String get reserved => _t('RISERVATO', 'RESTRICTED');

  String get empty => _t(
    'Ancora nessuna partita online. Le statistiche si scrivono giocando.',
    'No online games yet. The stats write themselves as you play.',
  );
  String get loadFailed => _t('Non è stato possibile caricare. Riprova.', 'Could not load. Try again.');
  String get retry => _t('Riprova', 'Retry');

  String duration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h == 0) return '$m min';
    return '$h h ${m.toString().padLeft(2, '0')} min';
  }

  String percent(double rate) => '${(rate * 100).round()}%';

  // Public profiles: another player's dossier.
  String get profile => _t('Profilo', 'Profile');
  String get publicTitle => _t('FASCICOLO PUBBLICO', 'PUBLIC FILE');
  String get onRecord => _t('AGLI ATTI', 'ON RECORD');
  String get featured => _t('MEDAGLIE IN VETRINA', 'SHOWCASE MEDALS');
  String get noMedals => _t('Nessuna medaglia, per ora.', 'No medals yet.');
  String get topRoles => _t('RUOLI PIÙ GIOCATI', 'MOST PLAYED ROLES');
  String get closedFile => _t(
    'Fascicolo riservato: questo giocatore tiene per sé le sue statistiche.',
    'Restricted file: this player keeps their stats to themselves.',
  );
  String get unavailable => _t('Profilo non disponibile.', 'Profile not available.');
  String get publicSwitch => _t('Profilo pubblico', 'Public profile');
  String get publicSwitchHint => _t(
    'Gli altri vedono statistiche, grado e medaglie. Spento: solo nome, livello e ritratto.',
    'Others see your stats, rank and medals. Off: only your name, level and portrait.',
  );
}
