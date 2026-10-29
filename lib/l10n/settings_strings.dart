import 'package:flutter/widgets.dart';

import 'app_language.dart';
import 'app_strings.dart';

/// I testi della pagina delle impostazioni e della privacy, in italiano e in
/// inglese. Stanno a parte perché vivono solo lì.
class SettingsStrings {
  final AppLanguage language;

  const SettingsStrings(this.language);

  static SettingsStrings of(BuildContext context) => SettingsStrings(AppStrings.of(context).language);

  /// The text under `settings.<key>` in the messages of the language.
  String _m(String key, [Map<String, Object?> args = const {}]) => language.message('settings.$key', args);

  String get audio => _m('audio');
  String get languageSection => _m('languageSection');
  String get game => _m('game');
  String get account => _m('account');
  String get privacy => _m('privacy');
  String get about => _m('about');

  String signedInAs(String handle) => _m('signedInAs', {'handle': handle});
  String get signedInNoHandle => _m('signedInNoHandle');
  String get notSignedIn => _m('notSignedIn');

  String get privacyPolicy => _m('privacyPolicy');
  String get terms => _m('terms');
  String get openOnWeb => _m('openOnWeb');

  String get exportData => _m('exportData');
  String get exportHint =>
      _m('exportHint');
  String get exportFailed => _m('exportFailed');

  String get deleteAccount => _m('deleteAccount');
  String get deleteHint => _m('deleteHint');
  String get deleteTitle => _m('deleteTitle');
  String get deleteBody => _m('deleteBody');
  String get deleteContinue => _m('deleteContinue');
  String get cancel => _m('cancel');
  String deleteTypePrompt(String word) => _m('deleteTypePrompt', {'word': word});
  String get deleteConfirmWord => _m('deleteConfirmWord');
  String get deleteForever => _m('deleteForever');
  String get deleteDone => _m('deleteDone');
  String get deleteFailed => _m('deleteFailed');

  String get version => _m('version');
  String get credits => _m('credits');
  String get creditsBody => _m('creditsBody');

  /// La targhetta sotto il ritratto, in casa: apre lo specchio del barbiere.
  String get yourLook => _m('yourLook');
  String get barberSign => _m('barberSign');
  String get changeLook => _m('changeLook');

  /// The privacy policy and terms exist in Italian and English only.
  String get legalAsset => language == AppLanguage.it ? 'it' : 'en';
}
