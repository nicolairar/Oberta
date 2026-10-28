import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../l10n/app_language.dart';
import '../online/voice/voice_models.dart';
import '../sound/sound_stage.dart';
import 'display_settings.dart';
import 'settings_store.dart';

/// Le preferenze di chi gioca, ricordate da una sera all'altra: la lingua e
/// l'audio. Chi le cambia avvisa chi ascolta, e l'app si ridisegna subito.
class AppSettings extends ChangeNotifier {
  static const languageKey = 'language';
  static const soundKey = 'sound';
  static const musicVolumeKey = 'musicVolume';
  static const effectsVolumeKey = 'effectsVolume';
  static const memeKey = 'meme';
  static const windowModeKey = 'windowMode';
  static const resolutionKey = 'resolution';
  static const orientationKey = 'orientation';
  static const tutorialKey = 'tutorialSeen';
  static const tutorialsDoneKey = 'tutorialsDone';
  static const voiceModeKey = 'voiceMode';
  static const voicePushToTalkKey = 'voicePushToTalk';
  static const keys = {
    voiceModeKey,
    voicePushToTalkKey,
    tutorialsDoneKey,
    languageKey,
    soundKey,
    musicVolumeKey,
    effectsVolumeKey,
    memeKey,
    windowModeKey,
    resolutionKey,
    orientationKey,
    tutorialKey,
  };

  /// Le preferenze in uso. I test le tengono in memoria; `main` le apre dal
  /// telefono con [open].
  static AppSettings instance = AppSettings(MemorySettingsStore());

  final SettingsStore _store;
  AppLanguage? _language;
  bool _soundOn;
  double _musicVolume;
  double _effectsVolume;

  AppSettings(this._store)
      : _language = AppLanguage.values.asNameMap()[_store.getString(languageKey)],
        _soundOn = _store.getBool(soundKey) ?? true,
        _musicVolume = _readVolume(_store, musicVolumeKey, defaultMusicVolume),
        _effectsVolume = _readVolume(_store, effectsVolumeKey, defaultEffectsVolume),
        _memeMode = _store.getBool(memeKey) ?? false,
        _windowMode = DesktopWindowMode.values.asNameMap()[_store.getString(windowModeKey)] ?? DesktopWindowMode.windowed,
        _resolution = DesktopResolutions.parse(_store.getString(resolutionKey)) ?? DesktopResolutions.fallback,
        _orientation =
            DesktopOrientation.values.asNameMap()[_store.getString(orientationKey)] ?? DesktopOrientation.landscape;

  // Lo schermo del desktop: per dispositivo, mai nel profilo (un PC e un
  // telefono vogliono cose diverse).
  DesktopWindowMode _windowMode;
  Size _resolution;
  DesktopOrientation _orientation;

  DesktopWindowMode get windowMode => _windowMode;

  set windowMode(DesktopWindowMode mode) {
    if (mode == _windowMode) return;
    _windowMode = mode;
    _store.setString(windowModeKey, mode.name);
    notifyListeners();
  }

  /// La risoluzione della finestra, una della lista fissa.
  Size get resolution => _resolution;

  set resolution(Size size) {
    if (size == _resolution || !DesktopResolutions.all.contains(size)) return;
    _resolution = size;
    _store.setString(resolutionKey, DesktopResolutions.label(size));
    notifyListeners();
  }

  DesktopOrientation get orientation => _orientation;

  set orientation(DesktopOrientation orientation) {
    if (orientation == _orientation) return;
    _orientation = orientation;
    _store.setString(orientationKey, orientation.name);
    notifyListeners();
  }

  /// Il tutorial è già stato proposto (giocato o rimandato): al primo
  /// avvio si offre una volta sola.
  bool get tutorialSeen => _store.getBool(tutorialKey) ?? false;

  /// Le mani di prova finite davvero (non saltate), per id: anche offline.
  Set<String> get tutorialsDone =>
      {...?_store.getString(tutorialsDoneKey)?.split(',').where((id) => id.isNotEmpty)};

  void markTutorialDone(String id) {
    final done = tutorialsDone;
    if (!done.add(id)) return;
    _store.setString(tutorialsDoneKey, (done.toList()..sort()).join(','));
    notifyListeners();
  }

  set tutorialSeen(bool seen) {
    if (seen == tutorialSeen) return;
    _store.setBool(tutorialKey, seen);
    notifyListeners();
  }

  bool _memeMode;

  /// La modalità meme, spenta finché qualcuno non la accende.
  bool get memeMode => _memeMode;

  set memeMode(bool on) {
    if (on == _memeMode) return;
    _memeMode = on;
    SoundStage.instance.memeMode = on;
    _store.setBool(memeKey, on);
    notifyListeners();
  }

  /// La musica parte a metà: è un sottofondo, non deve coprire il tavolo.
  static const defaultMusicVolume = 0.5;
  static const defaultEffectsVolume = 0.8;

  static double _readVolume(SettingsStore store, String key, double fallback) =>
      (double.tryParse(store.getString(key) ?? '') ?? fallback).clamp(0.0, 1.0);

  void _applyVolumes() {
    SoundStage.instance
      ..musicVolume = _musicVolume
      ..effectsVolume = _effectsVolume;
  }

  /// Legge le preferenze salvate sul telefono e rimette l'audio com'era
  /// rimasto. Il palco del suono va montato prima.
  static Future<AppSettings> open() async {
    final settings = AppSettings(await DeviceSettingsStore.open(keys));
    SoundStage.instance.enabled = settings.soundOn;
    settings._applyVolumes();
    SoundStage.instance.memeMode = settings.memeMode;
    return settings;
  }

  /// La voce al tavolo: spenta, solo ascolto, o col microfono. Si parte
  /// ascoltando: il microfono si accende solo per scelta.
  VoiceMode get voiceMode => VoiceMode.values.asNameMap()[_store.getString(voiceModeKey)] ?? VoiceMode.listen;

  set voiceMode(VoiceMode mode) {
    if (mode == voiceMode) return;
    _store.setString(voiceModeKey, mode.name);
    notifyListeners();
  }

  /// Premi per parlare (sul PC il tasto V) invece del microfono aperto. Di
  /// solito sul PC sì, sul telefono no.
  bool get voicePushToTalk => _store.getBool(voicePushToTalkKey) ?? _desktop;

  set voicePushToTalk(bool on) {
    if (on == voicePushToTalk) return;
    _store.setBool(voicePushToTalkKey, on);
    notifyListeners();
  }

  static bool get _desktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

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

  /// Il volume della musica di sottofondo, da 0 a 1.
  double get musicVolume => _musicVolume;

  set musicVolume(double volume) {
    volume = volume.clamp(0.0, 1.0);
    if (volume == _musicVolume) return;
    _musicVolume = volume;
    _store.setString(musicVolumeKey, volume.toStringAsFixed(2));
    _applyVolumes();
    SoundStage.instance.duckMusic(false);
    notifyListeners();
  }

  /// Il volume degli effetti e delle scene, da 0 a 1.
  double get effectsVolume => _effectsVolume;

  set effectsVolume(double volume) {
    volume = volume.clamp(0.0, 1.0);
    if (volume == _effectsVolume) return;
    _effectsVolume = volume;
    _store.setString(effectsVolumeKey, volume.toStringAsFixed(2));
    _applyVolumes();
    notifyListeners();
  }

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
