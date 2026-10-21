import 'app_language.dart';

/// I testi in più della partita online su PC: il menu di Esc, gli aiuti da
/// tastiera, i titoli dei pannelli.
class DesktopGameStrings {
  final AppLanguage language;

  const DesktopGameStrings(this.language);

  bool get _en => language == AppLanguage.en;

  String _t(String it, String en) => _en ? en : it;

  String get menu => _t('Menu', 'Menu');
  String get menuTitle => _t('Il tavolo non aspetta', 'The table won\'t wait');
  String get menuBody => _t(
    'La partita va avanti anche con il menu aperto: l\'orologio corre per tutti.',
    'The game goes on while this menu is open: the clock runs for everyone.',
  );
  String get resume => _t('Torna al tavolo', 'Back to the table');
  String get roles => _t('I ruoli in gioco', 'Roles in play');
  String get settings => _t('Impostazioni', 'Settings');
  String get leave => _t('Abbandona la partita', 'Leave the game');
  String get stay => _t('Resta al tavolo', 'Stay at the table');
  String get leaveConfirm => _t('Abbandona', 'Leave');

  String get keyEsc => 'Esc';
  String get keyEnter => _t('Invio', 'Enter');
  String get chatKeys => _t('INVIO per scrivere', 'ENTER to chat');
  String get rightClick =>
      _t('Tasto destro su un giocatore: segnala o blocca', 'Right-click a player: report or block');
  String get timeLeft => _t('Tempo', 'Time');
  String get table => _t('Il tavolo', 'The table');
  String get you => _t('Tu', 'You');
}
