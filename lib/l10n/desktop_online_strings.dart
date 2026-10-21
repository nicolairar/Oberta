import 'package:flutter/widgets.dart';

import 'app_language.dart';
import 'app_strings.dart';

/// I testi in più delle schermate online su PC: le didascalie delle porte
/// della sala e gli aiuti da tastiera.
class DesktopOnlineStrings {
  final AppLanguage language;

  const DesktopOnlineStrings(this.language);

  static DesktopOnlineStrings of(BuildContext context) => DesktopOnlineStrings(AppStrings.of(context).language);

  bool get _en => language == AppLanguage.en;

  String _t(String it, String en) => _en ? en : it;

  String get hubCreateBody =>
      _t('Apri un tavolo tuo e fai sedere gli amici con il codice.', 'Open your own table and seat your friends with the code.');
  String get hubJoinBody =>
      _t('Ti hanno dato un codice? Scrivilo e sei dentro.', 'Got a code from someone? Type it in and you\'re in.');
  String get hubFriendsBody =>
      _t('Cerca per nome unico, rispondi alle richieste.', 'Search by handle, answer friend requests.');
  String get hubDoors => _t('Dove si va', 'Where to');
  String get profile => _t('Il tuo profilo', 'Your profile');
  String get joinHint => _t('Scrivi il codice e premi INVIO.', 'Type the code and press ENTER.');
  String get invite => _t('Invita al tavolo', 'Invite to the table');
  String get table => _t('Al tavolo', 'At the table');
  String get search => _t('Cerca', 'Search');
  String get results => _t('Trovati', 'Found');
  String get searchEmpty =>
      _t('Scrivi un nome unico per trovare qualcuno.', 'Type a handle to find someone.');
  String get rankedHow => _t('Come funziona', 'How it works');
  String get freeSeat => _t('Posto libero', 'Empty seat');
}
