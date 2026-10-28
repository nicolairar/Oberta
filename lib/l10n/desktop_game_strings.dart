import 'app_language.dart';

/// I testi in più della partita online su PC: il menu di Esc, gli aiuti da
/// tastiera, i titoli dei pannelli.
class DesktopGameStrings {
  final AppLanguage language;

  const DesktopGameStrings(this.language);

  /// The text under `desktopGame.<key>` in the messages of the language.
  String _m(String key, [Map<String, Object?> args = const {}]) => language.message('desktopGame.$key', args);

  String get menu => _m('menu');
  String get menuTitle => _m('menuTitle');
  String get menuBody => _m('menuBody');
  String get resume => _m('resume');
  String get roles => _m('roles');
  String get settings => _m('settings');
  String get leave => _m('leave');
  String get stay => _m('stay');
  String get leaveConfirm => _m('leaveConfirm');

  String get keyEsc => 'Esc';
  String get keyEnter => _m('keyEnter');
  String get chatKeys => _m('chatKeys');
  String get rightClick =>
      _m('rightClick');
  String get timeLeft => _m('timeLeft');
  String get table => _m('table');
  String get you => _m('you');
}
