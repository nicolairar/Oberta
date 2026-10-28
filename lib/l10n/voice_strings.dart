import 'package:flutter/widgets.dart';

import '../online/voice/voice_models.dart';
import 'app_language.dart';
import 'app_strings.dart';

/// I testi della voce al tavolo.
class VoiceStrings {
  final AppLanguage language;

  const VoiceStrings(this.language);

  static VoiceStrings of(BuildContext context) => VoiceStrings(AppStrings.of(context).language);

  /// The text under `voice.<key>` in the messages of the language.
  String _m(String key, [Map<String, Object?> args = const {}]) => language.message('voice.$key', args);

  String get title => _m('title');
  String mode(VoiceMode mode) => switch (mode) {
    VoiceMode.off => _m('mode.off'),
    VoiceMode.listen => _m('mode.listen'),
    VoiceMode.mic => _m('mode.mic'),
  };

  /// Nelle impostazioni: il microfono dice anche come si usa.
  String modeFull(VoiceMode mode) =>
      mode == VoiceMode.mic ? _m('modeFull') : this.mode(mode);
  String get pushToTalk => _m('pushToTalk');
  String get pushToTalkPhone => _m('pushToTalkPhone');
  String get pushToTalkDesk =>
      _m('pushToTalkDesk');

  /// Sotto il pulsante grande, in due parole.
  String get holdToTalk => _m('holdToTalk');
  String get holdV => _m('holdV');
  String get offline => _m('offline');

  /// Perché adesso non si parla (la fase, la regola).
  String get nightFamily => _m('nightFamily');
  String get deadListen => _m('deadListen');
  String get sewn => _m('sewn');
  String get jailed => _m('jailed');
  String get voteSilence => _m('voteSilence');
  String get nobodyNow => _m('nobodyNow');
  String get opensSoon => _m('opensSoon');

  /// Silenziare qualcuno, solo su questo telefono.
  String get muteVoice => _m('muteVoice');
  String get unmuteVoice => _m('unmuteVoice');
  String get mutedHere => _m('mutedHere');

  /// Il microfono negato dal sistema.
  String get micDeniedTitle => _m('micDeniedTitle');
  String get micDenied => _m('micDenied');
  String get openSettings => _m('openSettings');
  String get notNow => _m('notNow');
  String get settings => _m('settings');
  String get settingsHint => _m('settingsHint');
  String get people => _m('people');
  String get nobody => _m('nobody');
  String get mute => _m('mute');
  String get reportOrBlock => _m('reportOrBlock');
  String get unmute => _m('unmute');
  String get blocked => _m('blocked');
  String get closed => _m('closed');
  String get listening => _m('listening');
  String get silencedNow => _m('silencedNow');
  String get connecting => _m('connecting');
  String get live => _m('live');
  String get button => _m('button');
  String get micAskTitle => _m('micAskTitle');
  String get micAsk => _m('micAsk');
  String get micAllow => _m('micAllow');
  String get cancel => _m('cancel');
}
