import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/narration/italian_pack.dart';
import 'package:oberta/narration/narration_pack.dart';
import 'package:oberta/narration/narrator_script.dart';
import 'package:oberta/narration/voice_lines.dart';
import 'package:oberta/rules/game_engine.dart';
import 'package:oberta/rules/player.dart';
import 'package:oberta/rules/role.dart';

const ada = Player(id: 'ada', name: 'Ada');
const bruno = Player(id: 'bruno', name: 'Bruno');

/// Tutte le battute che il copione può comporre in una città: ogni alba,
/// ogni verdetto, ogni finale, con abbastanza semi da pescare tutto.
List<ScriptLine> everything(NarrationPack pack, CitySetting city, int seed) {
  final script = NarratorScript(pack: pack, city: city, random: Random(seed));
  NightAttack attack(Player who, AttackSource source, AttackOutcome outcome) => NightAttack(who, source, outcome);
  return [
    ...script.opening(),
    for (var round = 1; round <= 3; round++) ...script.nightFalls(round),
    ...script.dawn(const DawnReport(round: 1), discussion: const Duration(minutes: 3)),
    ...script.dawn(const DawnReport(round: 1), discussion: const Duration(minutes: 1)),
    ...script.dawn(
      DawnReport(
        round: 2,
        attacks: [
          attack(ada, AttackSource.family, AttackOutcome.killed),
          attack(bruno, AttackSource.sniper, AttackOutcome.killed),
        ],
        scoop: const Exposure(bruno, Team.mafia),
        silenced: ada,
      ),
      discussion: const Duration(minutes: 5),
    ),
    ...script.dawn(
      DawnReport(
        round: 2,
        attacks: [
          attack(ada, AttackSource.family, AttackOutcome.healed),
          attack(bruno, AttackSource.family, AttackOutcome.shrugged),
        ],
        scoop: const Exposure(ada, Team.citizens),
      ),
      discussion: const Duration(minutes: 3),
    ),
    ...script.voteCall(),
    for (final role in Role.values)
      ...script.lynch(LynchReport(round: 1, condemned: ada, role: role, winner: seed.isEven ? null : Team.citizens)),
    ...script.lynch(const LynchReport(round: 1, condemned: bruno, role: Role.mafioso, winner: Team.citizens)),
    ...script.lynch(const LynchReport(round: 1)),
    ...script.ending(Team.mafia),
    ...script.ending(Team.citizens),
  ];
}

void main() {
  test('la chiave è FNV-1a a 64 bit di lingua e testo, e non sente gli spazi in più', () {
    // Lo stesso conto fatto a mano in Python, sui byte UTF-8 di "it|Cambio di scena.".
    expect(voiceKey('it', 'Cambio di scena.'), '1105f0424118262c');
    expect(voiceKey('it', '  Cambio   di scena. '), voiceKey('it', 'Cambio di scena.'));
    expect(voiceKey('en', 'Cambio di scena.'), isNot(voiceKey('it', 'Cambio di scena.')));
    expect(voiceKey('it', 'È notte.'), matches(RegExp(r'^[0-9a-f]{16}$')));
  });

  test('una battuta si spezza dove cambia da una partita all\'altra', () {
    expect(splitTemplate('La carta si gira. {name} era… {role}.'), ['La carta si gira. ', '{name}', ' era… ', '{role}', '.']);
    expect(splitTemplate('{name} cade.'), ['{name}', ' cade.']);
    expect(splitTemplate('Su {city} scende il buio.'), ['Su {city} scende il buio.']);
  });

  test('il nome tace, il ruolo e i minuti hanno la loro clip, "qualcuno" si dice', () {
    final city = italianPack.cities.firstWhere((city) => city.id == 'chicago');
    final script = NarratorScript(city: city, random: Random(1));

    final verdict = script.lynch(const LynchReport(round: 1, condemned: ada, role: Role.padrino));
    final card = verdict[1];
    expect(card.text, 'La carta si gira. Ada era… IL PADRINO. Stava con la famiglia.');
    expect([for (final part in card.voice) part.say], ['La carta si gira.', null, 'era…', 'Il Padrino', null, 'Stava con la famiglia.']);
    expect([for (final part in card.voice) part.isName], [false, true, false, false, false, false]);
    expect(card.voice[3].display, 'IL PADRINO', reason: 'sullo schermo il ruolo è in maiuscolo, la voce lo dice normale');

    final dawn = script.dawn(const DawnReport(round: 1), discussion: const Duration(minutes: 3));
    final day = dawn.last;
    expect(day.text, 'Avete 3 minuti per discutere. Poi votate chi eliminare.');
    expect([for (final part in day.voice) part.say], ['Avete', '3', 'minuti', 'per discutere. Poi votate chi eliminare.']);
    final oneMinute = script.dawn(const DawnReport(round: 1), discussion: const Duration(minutes: 1)).last;
    expect([for (final part in oneMinute.voice) part.say], ['Avete', 'un minuto', 'per discutere. Poi votate chi eliminare.']);

    final rescue = script.dawn(
      const DawnReport(round: 2, attacks: [NightAttack(bruno, AttackSource.family, AttackOutcome.healed)]),
      discussion: const Duration(minutes: 3),
    );
    final saved = [for (final line in rescue) ...line.voice].where((part) => part.display.toLowerCase() == 'qualcuno');
    expect(saved, isNotEmpty, reason: 'chi si è salvato è "qualcuno"');
    expect(saved.every((part) => !part.isName && part.say == 'qualcuno'), isTrue);
    expect(textOfAll(rescue), isNot(contains('Bruno')));
  });

  test('il copione della voce copre ogni battuta che il narratore può dire, in ogni lingua e città', () {
    for (final language in AppLanguage.values) {
      final pack = language.pack;
      final dumped = {for (final segment in voiceSegments(pack)) segment.text};
      for (final city in pack.cities) {
        for (var seed = 0; seed < 40; seed++) {
          for (final line in everything(pack, city, seed)) {
            expect(line.voice, isNotEmpty, reason: line.text);
            expect(line.voice.map((part) => part.display).join(), line.text, reason: 'i pezzi ridanno la battuta');
            for (final part in line.voice) {
              final say = part.say;
              if (say != null) expect(dumped, contains(say), reason: '${language.name}: "$say" in "${line.text}"');
            }
          }
        }
      }
    }
  });

  test('ogni campo del copione finisce nel copione della voce', () {
    for (final language in AppLanguage.values) {
      final pack = language.pack;
      final dumped = {for (final segment in voiceSegments(pack)) segment.text};
      bool covered(String template, CitySetting city) => splitTemplate(template.replaceAll('{city}', city.name))
          .where((piece) => !dynamicPlaceholders.contains(piece) && isSpeakable(piece))
          .every((piece) => dumped.contains(normalizeVoiceText(piece)));
      for (final city in pack.cities) {
        for (final text in [...city.openings, for (final scene in city.scenes) scene.text, ...spokenTemplates(pack)]) {
          expect(covered(text, city), isTrue, reason: '${language.name}/${city.id}: $text');
        }
        expect(dumped, contains(city.title));
      }
      for (final role in Role.values) {
        expect(dumped, contains(pack.role(role).label));
      }
      for (var n = 1; n <= maxSpokenMinutes; n++) {
        expect(dumped, contains('$n'));
      }
      expect(dumped, contains(pack.someone));
    }
  });
}

String textOfAll(List<ScriptLine> lines) => lines.map((line) => line.text).join(' ');
