import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omerta/l10n/app_language.dart';
import 'package:omerta/settings/app_settings.dart';
import 'package:omerta/settings/settings_store.dart';
import 'package:omerta/sound/sound_stage.dart';

void main() {
  tearDown(() => SoundStage.instance.enabled = true);

  test('senza preferenze si segue il telefono, con l\'audio acceso', () {
    final settings = AppSettings(MemorySettingsStore());
    expect(settings.language, isNull);
    expect(settings.soundOn, isTrue);
    expect(settings.languageFor(const [Locale('it', 'IT')]), AppLanguage.it);
    expect(settings.languageFor(const [Locale('de', 'DE')]), AppLanguage.en);
  });

  test('la lingua scelta a mano vince su quella del telefono', () {
    final settings = AppSettings(MemorySettingsStore())..language = AppLanguage.en;
    expect(settings.languageFor(const [Locale('it', 'IT')]), AppLanguage.en);
    settings.language = AppLanguage.it;
    expect(settings.languageFor(const [Locale('fr')]), AppLanguage.it);
  });

  test('la lingua scelta resta dopo un riavvio, e "automatica" si dimentica', () {
    final store = MemorySettingsStore();
    AppSettings(store).language = AppLanguage.en;
    expect(store.values[AppSettings.languageKey], 'en');
    expect(AppSettings(store).language, AppLanguage.en, reason: 'riaperta, se la ricorda');

    AppSettings(store).language = null;
    expect(store.values.containsKey(AppSettings.languageKey), isFalse);
    expect(AppSettings(store).language, isNull);
  });

  test('un valore sconosciuto nel cassetto vale come "automatica"', () {
    final store = MemorySettingsStore({AppSettings.languageKey: 'klingon'});
    expect(AppSettings(store).language, isNull);
  });

  test('l\'audio spento resta spento dopo un riavvio, e il palco tace', () {
    final store = MemorySettingsStore();
    final settings = AppSettings(store)..soundOn = false;
    expect(SoundStage.instance.enabled, isFalse);
    expect(store.values[AppSettings.soundKey], false);
    expect(AppSettings(store).soundOn, isFalse);

    settings.soundOn = true;
    expect(SoundStage.instance.enabled, isTrue);
    expect(AppSettings(store).soundOn, isTrue);
  });

  test('chi cambia un\'impostazione avvisa chi ascolta, una volta sola', () {
    final settings = AppSettings(MemorySettingsStore());
    var changes = 0;
    settings.addListener(() => changes++);
    settings.language = AppLanguage.en;
    settings.language = AppLanguage.en;
    settings.soundOn = false;
    settings.soundOn = false;
    expect(changes, 2);
  });
}
