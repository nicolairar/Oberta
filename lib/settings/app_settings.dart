import 'package:flutter/widgets.dart';

import '../l10n/app_language.dart';
import '../sound/sound_stage.dart';
import 'settings_store.dart';

/// Le preferenze di chi gioca, ricordate da una sera all'altra: la lingua e
/// l'audio. Chi le cambia avvisa chi ascolta, e l'app si ridisegna subito.
class AppSettings extends ChangeNotifier {
  static const languageKey = 'language';
  static const soundKey = 'sound';
  static const keys = {languageKey, soundKey};

  /// Le preferenze in uso. I test le tengono in memoria; `main` le apre dal
  /// telefono con [open].
  static AppSettings instance = AppSettings(MemorySettingsStore());

  final SettingsStore _store;
  AppLanguage? _language;
  bool _soundOn;

  AppSettings(this._store)
      : _language = AppLanguage.values.asNameMap()[_store.getString(languageKey)],
        _soundOn = _store.getBool(soundKey) ?? true;

  /// Legge le preferenze salvate sul telefono e rimette l'audio com'era
  /// rimasto. Il palco del suono va montato prima.
  static Future<AppSettings> open() async {
    final settings = AppSettings(await DeviceSettingsStore.open(keys));
    SoundStage.instance.enabled = settings.soundOn;
    return settings;
  }

  /// La lingua scelta a mano; `null` segue quella del telefono.
  AppLanguage? get language => _language;

  set language(AppLanguage? language) {
    if (language == _language) return;
    _language = language;
    language == null ? _store.remove(languageKey) : _store.setString(languageKey, language.name);
    notifyListeners();
  }

  /// La lingua in cui si gioca: quella scelta, o quella del telefono.
  AppLanguage languageFor(List<Locale>? device) => _language ?? AppLanguage.forDevice(device);

  bool get soundOn => _soundOn;

  set soundOn(bool on) {
    if (on == _soundOn) return;
    _soundOn = on;
    SoundStage.instance.enabled = on;
    if (!on) SoundStage.instance.stop();
    _store.setBool(soundKey, on);
    notifyListeners();
  }
}
