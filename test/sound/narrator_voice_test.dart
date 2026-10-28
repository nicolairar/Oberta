import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/narration/italian_pack.dart';
import 'package:oberta/narration/narrator_script.dart';
import 'package:oberta/narration/voice_lines.dart';
import 'package:oberta/rules/game_engine.dart';
import 'package:oberta/rules/player.dart';
import 'package:oberta/rules/role.dart';
import 'package:oberta/sound/narrator_voice.dart';
import 'package:oberta/sound/sound_stage.dart';

const ada = Player(id: 'ada', name: 'Ada');

/// Un palco che si segna cosa dice il narratore.
class _Ear extends SoundStage {
  final said = <String>[];
  var stops = 0;
  final ducks = <bool>[];

  @override
  void voice(String asset) => said.add(asset);

  @override
  void stopVoice() => stops++;

  @override
  void duckForVoice(bool ducked) => ducks.add(ducked);
}

void main() {
  final index = File('assets/voice/index.json');
  final voice = NarratorVoice.fromJson(index.readAsStringSync());

  test('ogni frase del copione della voce ha la sua clip, in tutte e due le lingue', () {
    // Only Italian and English are recorded; the other languages narrate in text.
    for (final language in AppLanguage.values.where((l) => l.hasVoice)) {
      final missing = [
        for (final segment in voiceSegments(language.pack))
          if (voice.clip(language, segment.text) == null) segment.text,
      ];
      expect(missing, isEmpty, reason: '${language.name}: lanciare tool/voice/regenerate.sh');
      for (final segment in voiceSegments(language.pack)) {
        final file = File('assets/${NarratorVoice.assetFor(language, segment.text)}');
        expect(file.existsSync(), isTrue, reason: file.path);
      }
    }
  });

  test('le clip durano quanto la frase: niente clip vuote, niente clip infinite', () {
    for (final language in AppLanguage.values.where((l) => l.hasVoice)) {
      for (final segment in voiceSegments(language.pack)) {
        final ms = voice.clip(language, segment.text)!.inMilliseconds;
        // Le clip più corte sono un numero o una parola; poi circa un
        // secondo ogni 12-20 caratteri, più la coda della stanza.
        final chars = segment.text.length;
        expect(ms, greaterThan(250), reason: segment.text);
        expect(ms, lessThan(1500 + chars * 140), reason: segment.text);
        if (chars > 40) expect(ms, greaterThan(chars * 35), reason: segment.text);
      }
    }
  });

  test('una pagina messa in tempo: le clip in fila, il nome è un silenzio, poi una pausa', () {
    final city = italianPack.cities.firstWhere((city) => city.id == 'palermo');
    final script = NarratorScript(city: city, random: Random(2));
    final lines = script.lynch(const LynchReport(round: 1, condemned: ada, role: Role.medico));
    final plan = voice.plan(lines, AppLanguage.it, leadIn: const Duration(milliseconds: 300));

    expect(plan.steps.first.start, const Duration(milliseconds: 300));
    for (var i = 1; i < plan.steps.length; i++) {
      final previous = plan.steps[i - 1], step = plan.steps[i];
      final pause = step.line == previous.line ? Duration.zero : NarratorVoice.linePause;
      expect(step.start, previous.end + pause, reason: 'passo $i');
    }
    expect(plan.length, plan.steps.last.end);

    final card = [for (final step in plan.steps) if (step.line == 1) step];
    final parts = lines[1].voice;
    expect(parts[1].isName, isTrue);
    expect(card[1].asset, isNull, reason: 'il nome non si dice');
    expect(card[1].length, NarratorVoice.nameGap);
    expect(card[3].asset, NarratorVoice.assetFor(AppLanguage.it, 'Il Dottore'));
    expect(card[3].length, voice.clip(AppLanguage.it, 'Il Dottore'));
    expect(card[0].asset, 'voice/it/${voiceKey('it', 'La carta si gira.')}.m4a');

    final day = script.dawn(const DawnReport(round: 1), discussion: const Duration(minutes: 3)).last;
    final assets = [for (final step in voice.plan([day], AppLanguage.it).steps) step.asset];
    expect(assets, [
      NarratorVoice.assetFor(AppLanguage.it, 'Avete'),
      NarratorVoice.assetFor(AppLanguage.it, '3'),
      NarratorVoice.assetFor(AppLanguage.it, 'minuti'),
      NarratorVoice.assetFor(AppLanguage.it, 'per discutere. Poi votate chi eliminare.'),
    ]);
  });

  test('una frase senza clip scorre lo stesso, muta, a passo di voce', () {
    final plan = NarratorVoice().plan(const [ScriptLine('Una frase mai incisa.')], AppLanguage.it);
    expect(plan.steps.single.asset, isNull);
    expect(plan.length, NarratorVoice.perCharacter * 'Una frase mai incisa.'.length);
    expect(NarratorVoice().speaks(AppLanguage.it), isFalse);
    expect(voice.speaks(AppLanguage.it), isTrue);
    expect(voice.speaks(AppLanguage.en), isTrue);
  });

  test('chi prende la parola zittisce chi parlava, e la musica torna su solo alla fine', () {
    final ear = _Ear();
    SoundStage.instance = ear;
    addTearDown(() => SoundStage.instance = SoundStage());
    final first = Object(), second = Object();
    var hushed = false;
    const step = VoiceStep(line: 0, part: 0, start: Duration.zero, length: Duration(seconds: 1), asset: 'voice/it/x.m4a');

    voice.claim(first, () => hushed = true);
    voice.say(first, step);
    expect(ear.said, ['voice/it/x.m4a']);
    expect(ear.ducks, [true]);

    voice.claim(second, () {});
    expect(hushed, isTrue);
    expect(ear.stops, 1);
    voice.say(first, step);
    expect(ear.said, hasLength(1), reason: 'chi non ha la parola non parla');

    voice.release(first);
    expect(ear.ducks.last, isTrue, reason: 'chi non ha la parola non rialza la musica');
    voice.release(second);
    expect(ear.ducks.last, isFalse);
    voice.hush();
    expect(ear.stops, 1, reason: 'se nessuno parla non c\'è niente da zittire');
  });
}
