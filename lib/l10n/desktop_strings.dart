import 'package:flutter/widgets.dart';

import 'app_language.dart';
import 'app_strings.dart';

/// I testi del desktop (schermo, Steam) e del collegamento degli account.
class DesktopStrings {
  final AppLanguage language;

  const DesktopStrings(this.language);

  static DesktopStrings of(BuildContext context) => DesktopStrings(AppStrings.of(context).language);

  /// The text under `desktop.<key>` in the messages of the language.
  String _m(String key, [Map<String, Object?> args = const {}]) => language.message('desktop.$key', args);

  String get loginSteam => _m('loginSteam');
  String get steamWaiting =>
      _m('steamWaiting');

  String get screen => _m('screen');
  String get windowMode => _m('windowMode');
  String get windowed => _m('windowed');
  String get fullscreen => _m('fullscreen');
  String get borderless => _m('borderless');
  String get resolution => _m('resolution');
  String get resolutionHint =>
      _m('resolutionHint');
  String get orientation => _m('orientation');
  String get landscape => _m('landscape');
  String get portrait => _m('portrait');

  String get linkAccount => _m('linkAccount');
  String get linkHint => _m('linkHint');
  String get linkBody => _m('linkBody');
  String linkWith(String provider) => _m('linkWith', {'provider': provider});
  String get linkRule => _m('linkRule');
  String get linkWaiting =>
      _m('linkWaiting');
  String get linkDone => _m('linkDone');
  String get linkSwitched =>
      _m('linkSwitched');
  String get linkAlready => _m('linkAlready');
  String get close => _m('close');

  // Il vicolo su PC: la barra in alto e l'uscita.
  String get quit => _m('quit');
  String get quitTitle => _m('quitTitle');
  String get quitBody => _m('quitBody');
  String get quitConfirm => _m('quitConfirm');
  String get stay => _m('stay');
  String get enterHint => _m('enterHint');
  String get posterEnter => _m('posterEnter');
}
