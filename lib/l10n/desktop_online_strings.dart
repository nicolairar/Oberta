import 'package:flutter/widgets.dart';

import 'app_language.dart';
import 'app_strings.dart';

/// I testi in più delle schermate online su PC: le didascalie delle porte
/// della sala e gli aiuti da tastiera.
class DesktopOnlineStrings {
  final AppLanguage language;

  const DesktopOnlineStrings(this.language);

  static DesktopOnlineStrings of(BuildContext context) => DesktopOnlineStrings(AppStrings.of(context).language);

  /// The text under `desktopOnline.<key>` in the messages of the language.
  String _m(String key, [Map<String, Object?> args = const {}]) => language.message('desktopOnline.$key', args);

  String get hubCreateBody =>
      _m('hubCreateBody');
  String get hubJoinBody =>
      _m('hubJoinBody');
  String get hubFriendsBody =>
      _m('hubFriendsBody');
  String get hubDoors => _m('hubDoors');
  String get profile => _m('profile');
  String get joinHint => _m('joinHint');
  String get invite => _m('invite');
  String get table => _m('table');
  String get search => _m('search');
  String get results => _m('results');
  String get searchEmpty =>
      _m('searchEmpty');
  String get rankedHow => _m('rankedHow');
  String get freeSeat => _m('freeSeat');
}
