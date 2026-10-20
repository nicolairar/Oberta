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
  String get linkMake => _t('Crea un codice', 'Make a code');
  String get linkEnter => _t('Inserisci un codice', 'Enter a code');
  String linkCodeBody(int minutes) => _t(
        'Sull\'altro dispositivo, entrato con l\'altro account, apri Impostazioni → Collega account e scrivi '
            'questo codice. Vale $minutes minuti.',
        'On the other device, signed in with the other account, open Settings → Link account and type this '
            'code. It is valid for $minutes minutes.',
      );
  String get linkRule => _t(
        'Resta il profilo più vecchio, con nome, monete, esperienza, armadio e classifica. Quello più nuovo '
            'non si potrà più usare.',
        'The older profile stays, with its name, coins, experience, wardrobe and rating. The newer one can no '
            'longer be used.',
      );
  String get linkSubmit => _t('Collega', 'Link');
  String get linkDone => _t('Account collegati.', 'Accounts linked.');
  String get linkSignInAgain =>
      _t('Account collegati. Entra di nuovo per continuare.', 'Accounts linked. Sign in again to continue.');
  String get close => _t('Chiudi', 'Close');
}
