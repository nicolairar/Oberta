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
  String get pushToTalk => _t('Premi per parlare', 'Push to talk');
  String get pushToTalkPhone => _t('Tieni premuto il microfono per parlare.', 'Hold the microphone to talk.');
  String get pushToTalkDesk =>
      _t('Tieni premuto V (o il microfono) per parlare.', 'Hold V (or the microphone) to talk.');
  String get openMic => _t('Microfono aperto: tocca per zittirti.', 'Open mic: tap to mute yourself.');
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
