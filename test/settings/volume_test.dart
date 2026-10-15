import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/settings/app_settings.dart';
import 'package:oberta/settings/settings_store.dart';
import 'package:oberta/sound/sound_stage.dart';

void main() {
  test('la musica parte a metà e gli effetti più su, e si ricordano', () {
    final store = MemorySettingsStore();
    final settings = AppSettings(store);
    expect(settings.musicVolume, 0.5);
    expect(settings.effectsVolume, AppSettings.defaultEffectsVolume);

    settings.musicVolume = 0.25;
    settings.effectsVolume = 1.4;
    expect(settings.effectsVolume, 1.0, reason: 'mai oltre il massimo');
    expect(SoundStage.instance.musicVolume, 0.25);
    expect(SoundStage.instance.effectsVolume, 1.0);

    final again = AppSettings(store);
    expect(again.musicVolume, 0.25);
    expect(again.effectsVolume, 1.0);
  });

  test('la modalità meme parte spenta, e si ricorda quando la si accende', () {
    final store = MemorySettingsStore();
    final settings = AppSettings(store);
    expect(settings.memeMode, isFalse);
    expect(SoundStage.instance.memeMode, isFalse);
    settings.memeMode = true;
    expect(SoundStage.instance.memeMode, isTrue);
    expect(AppSettings(store).memeMode, isTrue);
    settings.memeMode = false;
  });
}
