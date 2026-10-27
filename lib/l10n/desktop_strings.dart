import 'package:flutter/widgets.dart';

import 'app_language.dart';
import 'app_strings.dart';

/// I testi del desktop (schermo, Steam) e del collegamento degli account.
class DesktopStrings {
  final AppLanguage language;

  const DesktopStrings(this.language);

  static DesktopStrings of(BuildContext context) => DesktopStrings(AppStrings.of(context).language);

  bool get _en => language == AppLanguage.en;

  String _t(String it, String en) => _en ? en : it;

  String get loginSteam => _t('Accedi con Steam', 'Sign in with Steam');
  String get steamWaiting =>
      _t('Completa l\'accesso nel browser, poi torna qui.', 'Finish signing in in your browser, then come back here.');

  String get screen => _t('SCHERMO', 'DISPLAY');
  String get windowMode => _t('Finestra', 'Window');
  String get windowed => _t('In finestra', 'Windowed');
  String get fullscreen => _t('Schermo intero', 'Fullscreen');
  String get borderless => _t('Senza bordi', 'Borderless');
  String get resolution => _t('Risoluzione', 'Resolution');
  String get resolutionHint =>
      _t('Gli schermi più larghi giocano a 16:9, con le bande ai lati.', 'Wider screens play at 16:9, with bars at the sides.');
  String get orientation => _t('Orientamento', 'Orientation');
  String get landscape => _t('Orizzontale', 'Landscape');
  String get portrait => _t('Verticale', 'Portrait');

  String get linkAccount => _t('Collega account', 'Link account');
  String get linkHint => _t(
        'Gioca con lo stesso profilo su telefono e su PC.',
        'Play with the same profile on your phone and on PC.',
      );
  String get linkBody => _t(
        'Entra con l\'altro account nel browser: i due profili diventano uno.',
        'Sign in with the other account in your browser: the two profiles become one.',
      );
  String linkWith(String provider) => _t('Collega $provider', 'Link $provider');
  String get linkRule => _t(
        'Resta il profilo più vecchio, con nome, monete, esperienza, armadio e classifica. Quello più nuovo '
            'non si potrà più usare.',
        'The older profile stays, with its name, coins, experience, wardrobe and rating. The newer one can no '
            'longer be used.',
      );
  String get linkWaiting =>
      _t('Completa l\'accesso nel browser, poi torna qui.', 'Finish signing in in your browser, then come back here.');
  String get linkDone => _t('Account collegati.', 'Accounts linked.');
  String get linkSwitched =>
      _t('Account collegati: ora sei nel profilo più vecchio.', 'Accounts linked: you are now in the older profile.');
  String get linkAlready => _t('Questo account è già collegato.', 'This account is already linked.');
  String get close => _t('Chiudi', 'Close');

  // Il vicolo su PC: la barra in alto e l'uscita.
  String get quit => _t('Esci', 'Quit');
  String get quitTitle => _t('Lasci il vicolo?', 'Leaving the alley?');
  String get quitBody => _t('Il gioco si chiude. Nessuno ha visto niente.', 'The game will close. Nobody saw a thing.');
  String get quitConfirm => _t('Esci dal gioco', 'Quit game');
  String get stay => _t('Resta', 'Stay');
  String get enterHint => _t('INVIO per confermare', 'ENTER to confirm');
  String get posterEnter => _t('Entra', 'Enter');
}
