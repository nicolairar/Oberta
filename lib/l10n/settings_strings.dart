import 'package:flutter/widgets.dart';

import 'app_language.dart';
import 'app_strings.dart';

/// I testi della pagina delle impostazioni e della privacy, in italiano e in
/// inglese. Stanno a parte perché vivono solo lì.
class SettingsStrings {
  final AppLanguage language;

  const SettingsStrings(this.language);

  static SettingsStrings of(BuildContext context) => SettingsStrings(AppStrings.of(context).language);

  bool get _en => language == AppLanguage.en;

  String _t(String it, String en) => _en ? en : it;

  String get audio => _t('AUDIO', 'AUDIO');
  String get languageSection => _t('LINGUA', 'LANGUAGE');
  String get game => _t('GIOCO', 'GAME');
  String get account => _t('ACCOUNT', 'ACCOUNT');
  String get privacy => _t('PRIVACY E DATI', 'PRIVACY & DATA');
  String get about => _t('INFORMAZIONI', 'ABOUT');

  String signedInAs(String handle) => _t('Sei dentro come @$handle', 'Signed in as @$handle');
  String get signedInNoHandle => _t('Sei dentro, ancora senza nome', 'Signed in, no username yet');
  String get notSignedIn => _t('Non sei entrato online.', 'You are not signed in online.');

  String get privacyPolicy => _t('Informativa sulla privacy', 'Privacy policy');
  String get terms => _t('Termini d\'uso', 'Terms of use');
  String get openOnWeb => _t('Apri sul web', 'Open on the web');

  String get exportData => _t('Scarica i miei dati', 'Download my data');
  String get exportHint =>
      _t('Tutto quello che il server sa di te, in un file JSON.', 'Everything the server keeps about you, as a JSON file.');
  String get exportFailed => _t('Non è stato possibile scaricare i dati. Riprova.', 'Could not download your data. Try again.');

  String get deleteAccount => _t('Elimina account', 'Delete account');
  String get deleteHint => _t('Per sempre: profilo, amici, armadio e monete.', 'Forever: profile, friends, wardrobe and coins.');
  String get deleteTitle => _t('Eliminare l\'account?', 'Delete your account?');
  String get deleteBody => _t(
        'Profilo, aspetto, amici, armadio, monete, stanze e messaggi: spariscono tutti, per sempre. '
            'Degli acquisti veri resta solo una ricevuta anonima, per il fisco.',
        'Profile, look, friends, wardrobe, coins, rooms and messages: all gone, for good. '
            'Real-money purchases leave only an anonymous receipt, for tax reasons.',
      );
  String get deleteContinue => _t('Continua', 'Continue');
  String get cancel => _t('Annulla', 'Cancel');
  String deleteTypePrompt(String word) => _t('Ultima parola: scrivi «$word» per confermare.', 'Last word: type "$word" to confirm.');
  String get deleteConfirmWord => _t('ELIMINA', 'DELETE');
  String get deleteForever => _t('Elimina per sempre', 'Delete forever');
  String get deleteDone => _t('Account eliminato. Addio, e grazie.', 'Account deleted. Farewell, and thank you.');
  String get deleteFailed => _t('Non è stato possibile eliminare l\'account. Riprova.', 'Could not delete the account. Try again.');

  String get version => _t('Versione', 'Version');
  String get credits => _t('Riconoscimenti', 'Credits');
  String get creditsBody => _t(
        'Suoni ed elementi grafici di Kenney (kenney.nl) e di Freesound (freesound.org), con licenza CC0. Grazie!',
        'Sounds and graphics by Kenney (kenney.nl) and Freesound (freesound.org), under the CC0 license. Thank you!',
      );

  /// La targhetta sotto il ritratto, in casa: apre lo specchio del barbiere.
  String get yourLook => _t('IL TUO LOOK', 'YOUR LOOK');
  String get barberSign => _t('BARBIERE', 'BARBER');
  String get changeLook => _t('Cambia il tuo look', 'Change your look');

  String get legalAsset => _en ? 'en' : 'it';
}
