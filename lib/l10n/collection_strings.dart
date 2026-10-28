import 'package:flutter/widgets.dart';

import '../rules/role.dart';
import 'app_language.dart';
import 'app_strings.dart';

/// The words of the roles collection ("I ruoli"), in Italian and English.
class CollectionStrings {
  final AppLanguage language;

  const CollectionStrings(this.language);

  static CollectionStrings of(BuildContext context) => CollectionStrings(AppStrings.of(context).language);

  bool get _en => language == AppLanguage.en;

  String _t(String it, String en) => _en ? en : it;

  String get title => _t('I ruoli', 'The roles');
  String get settingsHint => _t('La collezione: ogni carta si scopre vincendo con lei.', 'The collection: win with a role to turn its card.');
  String count(int n, int of) => _t('$n carte su $of', '$n of $of cards');
  String get hint => _t(
        'Ogni carta resta coperta finché non vinci una partita con quel ruolo.',
        'Every card stays face down until you win a game with that role.',
      );
  String get signedOut => _t(
        'Accedi per scoprire le carte e tenere il conto delle tue partite.',
        'Sign in to turn the cards and keep count of your games.',
      );
  String get signIn => _t('Accedi', 'Sign in');

  String team(Team team) => switch (team) {
        Team.citizens => _t('Villaggio', 'Village'),
        Team.mafia => _t('Mafia', 'Mafia'),
        Team.neutral => _t('Solitari', 'Loners'),
      };

  String sideCount(int n, int of) => '$n/$of';
  String get locked => _t('Coperta', 'Face down');
  String get lockedBody => _t(
        'Carta coperta. Vinci una partita con questo ruolo per scoprire cosa fa e vedere le tue statistiche.',
        'Face down. Win a game with this role to learn what it does and see your numbers.',
      );
  String playedNoWin(int n) => n == 1
      ? _t('Giocata una volta, mai vinta.', 'Played once, never won.')
      : _t('Giocata $n volte, mai vinta.', 'Played $n times, never won.');
  String get neverPlayed => _t('Mai giocata.', 'Never played.');

  String get played => _t('Partite', 'Games');
  String get wins => _t('Vittorie', 'Wins');
  String get losses => _t('Sconfitte', 'Losses');
  String get winRate => _t('% vittorie', 'Win %');
  String get bestStreak => _t('Serie migliore', 'Best streak');
  String get lastPlayed => _t('Ultima partita', 'Last game');
  String short(int wins, int played) => _t('$wins V · $played P', '$wins W · $played G');

  String date(DateTime d) {
    const it = ['gen', 'feb', 'mar', 'apr', 'mag', 'giu', 'lug', 'ago', 'set', 'ott', 'nov', 'dic'];
    const en = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final l = d.toLocal();
    return _en ? '${en[l.month - 1]} ${l.day}, ${l.year}' : '${l.day} ${it[l.month - 1]} ${l.year}';
  }

  String get close => _t('Chiudi', 'Close');
  String get publicCount => _t('Ruoli scoperti', 'Roles unlocked');
}
