import 'package:flutter/widgets.dart';

import '../online/voice/voice_models.dart';
import 'app_language.dart';
import 'app_strings.dart';

/// I testi della voce al tavolo.
class VoiceStrings {
  final AppLanguage language;

  const VoiceStrings(this.language);

  static VoiceStrings of(BuildContext context) => VoiceStrings(AppStrings.of(context).language);

  bool get _en => language == AppLanguage.en;

  String _t(String it, String en) => _en ? en : it;

  String get title => _t('Voce', 'Voice');
  String mode(VoiceMode mode) => switch (mode) {
    VoiceMode.off => _t('Spenta', 'Off'),
    VoiceMode.listen => _t('Ascolta soltanto', 'Listen only'),
    VoiceMode.mic => _t('Microfono', 'Microphone'),
  };

  /// Nelle impostazioni: il microfono dice anche come si usa.
  String modeFull(VoiceMode mode) =>
      mode == VoiceMode.mic ? _t('Microfono (premi per parlare)', 'Microphone (push to talk)') : this.mode(mode);
  String get pushToTalk => _t('Premi per parlare', 'Push to talk');
  String get pushToTalkPhone => _t('Tieni premuto il microfono per parlare.', 'Hold the microphone to talk.');
  String get pushToTalkDesk =>
      _t('Tieni premuto V (o il microfono) per parlare.', 'Hold V (or the microphone) to talk.');

  /// Sotto il pulsante grande, in due parole.
  String get holdToTalk => _t('Tieni premuto', 'Hold to talk');
  String get holdV => _t('Tieni premuto V', 'Hold V');
  String get offline => _t('Voce scollegata, riprovo', 'Voice offline, retrying');

  /// Perché adesso non si parla (la fase, la regola).
  String get nightFamily => _t('Di notte parla solo la famiglia', 'At night only the family talks');
  String get deadListen => _t('I morti ascoltano soltanto', 'The dead only listen');
  String get sewn => _t('Il Sarto ti ha cucito la bocca', 'The Tailor sewed your mouth shut');
  String get jailed => _t('In cella non si parla', 'No talking in the cell');
  String get voteSilence => _t('Durante il voto si tace', 'No talking during the vote');
  String get nobodyNow => _t('Adesso nessuno parla', 'Nobody talks right now');
  String get opensSoon => _t('La voce si apre fra un attimo', 'Voice opens in a moment');

  /// Silenziare qualcuno, solo su questo telefono.
  String get muteVoice => _t('Silenzia la voce', 'Mute voice');
  String get unmuteVoice => _t('Riattiva la voce', 'Unmute voice');
  String get mutedHere => _t('Silenziato: solo tu non lo senti.', "Muted: only you can't hear them.");

  /// Il microfono negato dal sistema.
  String get micDeniedTitle => _t('Microfono negato', 'Microphone denied');
  String get micDenied => _t(
    'Senza il permesso del microfono puoi solo ascoltare. Puoi darlo dalle impostazioni del sistema, poi scegli di nuovo «Microfono».',
    'Without microphone access you can only listen. You can allow it in the system settings, then choose "Microphone" again.',
  );
  String get openSettings => _t('Apri le impostazioni', 'Open settings');
  String get notNow => _t('Non ora', 'Not now');
  String get settings => _t('Voce al tavolo', 'Table voice');
  String get settingsHint => _t(
    'Nelle stanze con gli amici. Di giorno parlano i vivi, di notte solo la famiglia. Dal vivo: niente viene registrato.',
    'In friends rooms. By day the living talk, at night only the family. Live only: nothing is recorded.',
  );
  String get people => _t('Al tavolo', 'At the table');
  String get nobody => _t('Nessun altro in ascolto.', 'Nobody else is listening.');
  String get mute => _t('Silenzia', 'Mute');
  String get reportOrBlock => _t('Segnala o blocca', 'Report or block');
  String get unmute => _t('Riattiva', 'Unmute');
  String get blocked => _t('Bloccato: non vi sentite.', "Blocked: you can't hear each other.");
  String get closed => _t('Adesso la voce è chiusa.', 'Voice is closed right now.');
  String get listening => _t('Ascolti soltanto.', 'Listening only.');
  String get silencedNow => _t('Adesso non puoi parlare.', "You can't talk right now.");
  String get connecting => _t('Collegamento…', 'Connecting…');
  String get live => _t('Ti sentono', 'They can hear you');
  String get button => _t('Voce', 'Voice');
  String get micAskTitle => _t('Il microfono', 'The microphone');
  String get micAsk => _t(
    'Per parlare al tavolo Obertà usa il microfono, solo quando il gioco ti dà la parola. '
        'La voce passa dal vivo e non viene registrata né trascritta.',
    'To talk at the table Obertà uses the microphone, only when the game gives you the floor. '
        'Your voice goes out live and is never recorded or transcribed.',
  );
  String get micAllow => _t('Usa il microfono', 'Use the microphone');
  String get cancel => _t('Annulla', 'Cancel');
}
