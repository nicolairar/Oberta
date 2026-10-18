import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/narration/death_story.dart';
import 'package:oberta/narration/english_pack.dart';
import 'package:oberta/narration/italian_pack.dart';
import 'package:oberta/narration/narration_pack.dart';
import 'package:oberta/narration/narrator_script.dart';
import 'package:oberta/rules/game_engine.dart';
import 'package:oberta/rules/player.dart';
import 'package:oberta/rules/role.dart';

/// I nomi di scena inglesi, come li porta il pacchetto.
final englishRoleNames = {for (final role in Role.values) role: englishPack.role(role).label};

const sara = Player(id: 'sara', name: 'Sara');
const luca = Player(id: 'luca', name: 'Luca');
const threeMinutes = Duration(minutes: 3);

NarratorScript englishIn(String cityId, int seed) => NarratorScript(
      pack: englishPack,
      city: englishPack.cities.firstWhere((city) => city.id == cityId),
      random: Random(seed),
    );

DawnReport night(
  int round,
  List<Player> victims, {
  Exposure? scoop,
  Player? silenced,
  Team? winner,
}) =>
    DawnReport(
      round: round,
      attacks: [for (final victim in victims) NightAttack(victim, AttackSource.family, AttackOutcome.killed)],
      scoop: scoop,
      silenced: silenced,
      winner: winner,
    );

DawnReport attack(Player target, AttackSource source, AttackOutcome outcome) =>
    DawnReport(round: 2, attacks: [NightAttack(target, source, outcome)]);

String textOf(List<ScriptLine> lines) => lines.map((line) => line.text).join(' ');

List<String> factsOf(List<ScriptLine> lines) => [
      for (final line in lines)
        if (line.isFact) line.text,
    ];

int words(String text) => text.split(RegExp(r'\s+')).length;

Set<String> placeholders(String text) =>
    {for (final match in RegExp(r'\{\w+\}').allMatches(text)) match.group(0)!};

/// Gli elenchi da cui il narratore pesca, col nome del campo.
Map<String, List<String>> listsOf(NarrationPack pack) => {
      for (final city in pack.cities) 'openings.${city.id}': city.openings,
      for (final city in pack.cities) 'scenes.${city.id}': [for (final scene in city.scenes) scene.text],
      'firstNights': pack.firstNights,
      'nights': pack.nights,
      'quietDawns': pack.quietDawns,
      'secondVictims': pack.secondVictims,
      'sniperShots': pack.sniperShots.allLines,
      'rescues': pack.rescues.allLines,
      'shrugs': pack.shrugs.allLines,
      'methods': [for (final piece in pack.methods) piece.text],
      'epilogues': [for (final piece in pack.epilogues) piece.text],
      'scoops': pack.scoops,
      'silences': pack.silences,
      'voteCalls': pack.voteCalls,
      'lynchScenes': pack.lynchScenes,
      'lynchedInnocent': pack.lynchedInnocent,
      'lynchedMafioso': pack.lynchedMafioso,
      'lynchedLastMafioso': pack.lynchedLastMafioso,
      'noLynch': pack.noLynch,
      'citizensWin': pack.citizensWin,
      'mafiaWins': pack.mafiaWins,
      'decoyPrompts': pack.decoyPrompts,
    };

/// Le frasi singole: fatti, istruzioni, domande e spiegazioni.
Map<String, String> singlesOf(NarrationPack pack) => {
      'howToPlay': pack.howToPlay,
      'nightInstruction': pack.nightInstruction,
      'nobodyDied': pack.nobodyDied,
      'victimFact': pack.victimFact,
      'savedFact': pack.savedFact,
      'shruggedFact': pack.shruggedFact,
      'scoopMafia': pack.scoopMafia,
      'scoopClean': pack.scoopClean,
      'silencedFact': pack.silencedFact,
      'dayInstruction': pack.dayInstruction,
      'oneMinute': pack.oneMinute,
      'manyMinutes': pack.manyMinutes,
      'voteInstruction': pack.voteInstruction,
      'cardTurns': pack.cardTurns,
      'wasMafia': pack.wasMafia,
      'wasCitizen': pack.wasCitizen,
      'noLynchFact': pack.noLynchFact,
      'citizensWinFact': pack.citizensWinFact,
      'mafiaWinsFact': pack.mafiaWinsFact,
      for (final entry in pack.taskPrompts.entries) 'taskPrompts.${entry.key.name}': entry.value,
      for (final entry in pack.taskHints.entries) 'taskHints.${entry.key.name}': entry.value,
    };

/// Tutto quello che un giocatore può leggere o sentirsi leggere.
List<String> everyLineOf(NarrationPack pack) => [
      for (final city in pack.cities) ...[city.name, city.title],
      for (final list in listsOf(pack).values) ...list,
      ...singlesOf(pack).values,
    ];

/// Le battute d'atmosfera: quelle che il test italiano tiene sotto le 16 parole.
List<String> storyLinesOf(NarrationPack pack) {
  final lists = listsOf(pack);
  return [
    for (final entry in lists.entries)
      if (entry.key != 'decoyPrompts') ...entry.value,
  ];
}

/// Parole che in un copione inglese non hanno motivo di esserci. Solo
/// minuscole: "La Cala" è un posto vero, e resta com'è.
final italianWords = RegExp(
  r"(?<![A-Za-zÀ-ÿ'])"
  r'(il|lo|la|gli|le|che|è|e|non|un|una|di|del|della|con|per|su|sono|ha|chi|stanotte|notte|oggi)'
  r"(?![A-Za-zÀ-ÿ'])",
);

/// Un giocatore non è mai "he" o "she": si usa il nome, o "they".
final genderedWords = RegExp(
  r"\b(he|she|him|her|his|hers|himself|herself|he's|she's|guy|guys|sir|madam|mister|lady|gentleman)\b",
  caseSensitive: false,
);

void main() {
  group('il pacchetto inglese ha la stessa forma di quello italiano', () {
    test('stesse città nello stesso ordine, con le stesse aperture e gli stessi luoghi', () {
      expect(
        [for (final city in englishPack.cities) city.id],
        [for (final city in italianPack.cities) city.id],
      );
      for (var i = 0; i < italianPack.cities.length; i++) {
        final italian = italianPack.cities[i];
        final english = englishPack.cities[i];
        expect(english.openings, hasLength(italian.openings.length), reason: italian.id);
        expect(
          [for (final scene in english.scenes) scene.id],
          [for (final scene in italian.scenes) scene.id],
          reason: 'i fondali vanno per nome: ${italian.id}',
        );
      }
    });

    test('ogni città ha un titolo con lo stesso anno, e il film si apre dicendo dove siamo', () {
      for (var i = 0; i < italianPack.cities.length; i++) {
        final italian = italianPack.cities[i];
        final english = englishPack.cities[i];
        final year = RegExp(r', 19\d\d$');
        expect(english.title, startsWith(english.name), reason: english.id);
        expect(year.stringMatch(english.title), year.stringMatch(italian.title), reason: english.id);
        for (final opening in english.openings) {
          expect(opening, startsWith('${english.title}.'), reason: english.id);
        }
        for (final scene in english.scenes) {
          expect(scene.text, matches(RegExp('^(Exterior|Interior), night')), reason: scene.id);
        }
      }
    });

    test('interni ed esterni sono gli stessi: la scena è una sola', () {
      for (var i = 0; i < italianPack.cities.length; i++) {
        final italian = italianPack.cities[i].scenes;
        final english = englishPack.cities[i].scenes;
        for (var j = 0; j < italian.length; j++) {
          expect(
            english[j].text.startsWith('Interior'),
            italian[j].text.startsWith('Interno'),
            reason: italian[j].id,
          );
        }
      }
    });

    test('stesse azioni e stessi stacchi, nello stesso ordine: le animazioni vanno per nome', () {
      expect(
        [for (final piece in englishPack.methods) piece.id],
        [for (final piece in italianPack.methods) piece.id],
      );
      expect(
        [for (final piece in englishPack.epilogues) piece.id],
        [for (final piece in italianPack.epilogues) piece.id],
      );
    });

    test('ogni elenco è lungo almeno quanto quello italiano', () {
      final italian = listsOf(italianPack);
      final english = listsOf(englishPack);
      expect(english.keys, italian.keys);
      for (final name in italian.keys) {
        expect(english[name]!.length, greaterThanOrEqualTo(italian[name]!.length), reason: name);
      }
    });

    test('nessun elenco ripete una battuta', () {
      for (final entry in listsOf(englishPack).entries) {
        expect(entry.value.toSet(), hasLength(entry.value.length), reason: entry.key);
      }
    });

    test('le mappe dei compiti notturni hanno le stesse chiavi', () {
      expect(englishPack.taskPrompts.keys.toSet(), italianPack.taskPrompts.keys.toSet());
      expect(englishPack.taskHints.keys.toSet(), italianPack.taskHints.keys.toSet());
      for (final kind in NightTaskKind.values) {
        expect(englishPack.taskHints[kind], isNotNull, reason: kind.name);
        if (kind != NightTaskKind.decoy) {
          expect(englishPack.taskPrompts[kind], isNotNull, reason: kind.name);
        }
      }
    });

    test('ogni frase singola tiene gli stessi segnaposto della gemella italiana', () {
      final italian = singlesOf(italianPack);
      final english = singlesOf(englishPack);
      expect(english.keys, italian.keys);
      for (final name in italian.keys) {
        expect(placeholders(english[name]!), placeholders(italian[name]!), reason: name);
      }
    });

    test('ogni battuta degli elenchi tiene gli stessi segnaposto, posto per posto', () {
      final italian = listsOf(italianPack);
      final english = listsOf(englishPack);
      for (final name in italian.keys) {
        for (var i = 0; i < italian[name]!.length; i++) {
          expect(
            placeholders(english[name]![i]),
            placeholders(italian[name]![i]),
            reason: '$name[$i]: ${english[name]![i]}',
          );
        }
      }
    });

    test('nessun segnaposto inventato o scritto male', () {
      const known = {'{name}', '{role}', '{city}', '{minutes}'};
      for (final line in everyLineOf(englishPack)) {
        expect(known, containsAll(placeholders(line)), reason: line);
        expect(line.replaceAll(RegExp(r'\{\w+\}'), ''), isNot(anyOf(contains('{'), contains('}'))), reason: line);
      }
    });

    test('ogni città offre centinaia di morti diverse', () {
      for (final city in englishPack.cities) {
        final combinations = city.scenes.length * englishPack.methods.length * englishPack.epilogues.length;
        expect(combinations, greaterThan(900), reason: city.id);
      }
    });
  });

  group('il pacchetto inglese: la voce', () {
    test('nessuna battuta è lunga: al tavolo si legge in fretta', () {
      for (final line in storyLinesOf(englishPack)) {
        expect(words(line), lessThanOrEqualTo(16), reason: line);
      }
      expect(words(englishPack.howToPlay), lessThanOrEqualTo(32));
      expect(words(englishPack.nightInstruction), lessThanOrEqualTo(16));
      for (final fact in [englishPack.savedFact, englishPack.shruggedFact, englishPack.silencedFact]) {
        expect(words(fact), lessThanOrEqualTo(18), reason: fact);
      }
      for (final kind in NightTaskKind.values) {
        expect(words(englishPack.taskHints[kind]!), lessThanOrEqualTo(16), reason: kind.name);
      }
    });

    test('nessuno chiude gli occhi: ci si passa il telefono', () {
      for (final line in everyLineOf(englishPack)) {
        final lower = line.toLowerCase();
        expect(lower, isNot(contains('close your eyes')), reason: line);
        expect(lower, isNot(contains('closed eyes')), reason: line);
        expect(lower, isNot(contains('eyes closed')), reason: line);
        expect(lower, isNot(contains('eyes shut')), reason: line);
        expect(lower, isNot(contains('wake up')), reason: line);
      }
      final instructions = [
        englishPack.howToPlay,
        englishPack.nightInstruction,
        englishPack.nobodyDied,
        englishPack.victimFact,
        englishPack.shruggedFact,
        englishPack.silencedFact,
        ...englishPack.firstNights,
        ...englishPack.nights,
        ...englishPack.shrugs.allLines,
        ...englishPack.silences,
        ...englishPack.taskPrompts.values,
        ...englishPack.taskHints.values,
      ].join(' ').toLowerCase();
      expect(instructions, isNot(contains('eye')));
      expect(englishPack.nightInstruction, contains('phone'));
    });

    test('nessun pronome di genere: il gioco non sa chi è un uomo e chi una donna', () {
      for (final line in everyLineOf(englishPack)) {
        expect(genderedWords.hasMatch(line), isFalse, reason: line);
      }
    });

    test('ogni azione nomina la vittima, e le battute nuove dicono sempre di chi parlano', () {
      final lines = [
        for (final piece in englishPack.methods) piece.text,
        ...englishPack.sniperShots.allLines,
        ...englishPack.rescues.allLines,
        ...englishPack.shrugs.allLines,
        ...englishPack.silences,
        englishPack.silencedFact,
        ...englishPack.scoops,
      ];
      for (final line in lines) {
        expect(line, contains('{name}'), reason: line);
      }
    });

    test('i nomi inglesi dei ruoli ci sono tutti, e sono tutti diversi', () {
      expect(englishRoleNames.keys.toSet(), Role.values.toSet());
      expect(englishRoleNames.values.toSet(), hasLength(Role.values.length));
      for (final name in englishRoleNames.values) {
        expect(name, startsWith('The '), reason: 'come "Il Dottore": un nome di scena');
      }
    });

    test('nessuna battuta d\'atmosfera ruba il nome a un ruolo', () {
      // "The gravedigger slept in" suonerebbe come un indizio su The Gravedigger.
      final atmosphere = [
        ...englishPack.firstNights,
        ...englishPack.nights,
        ...englishPack.quietDawns,
        ...englishPack.secondVictims,
        ...englishPack.sniperShots.allLines,
        ...englishPack.shrugs.allLines,
        ...englishPack.scoops,
        ...englishPack.silences,
        ...englishPack.voteCalls,
        ...englishPack.noLynch,
        for (final city in englishPack.cities) ...[
          ...city.openings,
          for (final scene in city.scenes) scene.text,
        ],
        for (final piece in englishPack.methods) piece.text,
        for (final piece in englishPack.epilogues) piece.text,
      ].join(' ');
      for (final name in englishRoleNames.values) {
        final noun = RegExp('\\b${RegExp.escape(name.substring(4))}\\b', caseSensitive: false);
        expect(noun.hasMatch(atmosphere), isFalse, reason: name);
      }
      expect(englishPack.rescues.allLines.join(' ').toLowerCase(), isNot(contains('gravedigger')));
    });

    test('il Dottore si chiama sempre "the Doc", le fazioni "the Family" e "the town"', () {
      final all = everyLineOf(englishPack).join(' ');
      expect(all.toLowerCase(), isNot(contains('doctor')));
      expect(all, isNot(contains(RegExp(r'\bfamily\b'))), reason: 'la Famiglia ha la maiuscola');
      expect(all.toLowerCase(), isNot(contains('mafia')));
      expect(all.toLowerCase(), isNot(contains('citizen')));
      expect(all.toLowerCase(), isNot(contains('villager')));
      expect(englishPack.savedFact, contains('the Doc'));
      expect(englishPack.rescues.allLines.where((line) => line.contains(RegExp(r'\b[Tt]he Doc\b'))), isNotEmpty);
      for (final line in [englishPack.howToPlay, englishPack.citizensWinFact, englishPack.mafiaWinsFact]) {
        expect(line, contains('Family'), reason: line);
        expect(line, contains('town'), reason: line);
      }
      expect(englishPack.wasMafia, contains('the Family'));
      expect(englishPack.wasCitizen, contains('the town'));
      expect(englishPack.scoopMafia, contains('the Family'));
      expect(englishPack.taskHints[NightTaskKind.investigate], allOf(contains('the Family'), contains('the town')));
    });

    test('il colpo andato a vuoto dice quello che si vede, e non dice chi ha la pelle dura', () {
      final props = {
        DeathStory.luckyId: RegExp('flask'),
        DeathStory.bibleId: RegExp('Bible'),
        DeathStory.jamId: RegExp('click|jammed', caseSensitive: false),
        DeathStory.bananaId: RegExp('banana'),
        DeathStory.blackCatId: RegExp('black cat'),
      };
      expect(englishPack.shrugs.keys.toSet(), props.keys.toSet());
      for (final MapEntry(key: id, value: lines) in englishPack.shrugs.entries) {
        for (final line in lines) {
          expect(line, contains(props[id]!), reason: 'in scena si vede quello: $line');
        }
      }
      final text = [...englishPack.shrugs.allLines, englishPack.shruggedFact].join(' ').toLowerCase();
      expect(text, isNot(contains('veteran')));
      expect(text, isNot(contains('doc')), reason: 'stavolta il Dottore non c\'entra');
      // Chi si salva resta anonimo: il fatto non fa nomi.
      for (final fact in [englishPack.shruggedFact, englishPack.savedFact]) {
        expect(fact, isNot(contains('{name}')));
        expect(fact, contains('stays a secret'));
      }
    });

    test('i fatti sono chiari: chi è morto, chi tace, chi ha vinto', () {
      expect(englishPack.victimFact, 'Last night one person died: {name}. Their role stays secret.');
      expect(englishPack.nobodyDied, 'Nobody died last night.');
      expect(englishPack.silencedFact, contains('can\'t talk'));
      expect(englishPack.silencedFact, contains('votes'));
      expect(englishPack.silencedFact, contains('eliminated'));
      expect(englishPack.voteInstruction, contains('nobody'));
      expect(englishPack.citizensWinFact, startsWith('The town wins'));
      expect(englishPack.mafiaWinsFact, startsWith('The Family wins'));
    });

    test('le spiegazioni dei compiti dicono la regola che conta', () {
      expect(englishPack.taskHints[NightTaskKind.silence], contains('Only once'));
      expect(englishPack.taskHints[NightTaskKind.protect], contains('two nights in a row'));
      expect(englishPack.taskHints[NightTaskKind.guard], contains('you die'));
      expect(englishPack.taskHints[NightTaskKind.dig], contains('only you'));
      expect(englishPack.taskHints[NightTaskKind.snipe], contains('one bullet'));
      expect(englishPack.taskHints[NightTaskKind.scoop], contains('one scoop'));
      expect(englishPack.taskHints.values.toSet(), hasLength(NightTaskKind.values.length));
    });

    test('nel pacchetto non resta una parola d\'italiano', () {
      for (final line in everyLineOf(englishPack)) {
        expect(italianWords.stringMatch(line), isNull, reason: line);
        expect(line, isNot(anyOf(contains('«'), contains('»'))), reason: line);
      }
      final italian = everyLineOf(italianPack).toSet();
      for (final entry in listsOf(englishPack).entries) {
        for (final line in entry.value) {
          expect(italian, isNot(contains(line)), reason: 'non tradotta: $line');
        }
      }
    });

    test('il filtro dell\'italiano funziona: sul pacchetto italiano scatta', () {
      final caught = everyLineOf(italianPack).where(italianWords.hasMatch).length;
      expect(caught, greaterThan(everyLineOf(italianPack).length * 0.8));
    });
  });

  group('NarratorScript in inglese', () {
    List<String> everyPage(NarratorScript script) => [
          textOf(script.opening()),
          textOf(script.nightFalls(1)),
          textOf(script.nightFalls(2)),
          textOf(script.dawn(night(1, []), discussion: threeMinutes)),
          textOf(script.dawn(night(1, []), discussion: const Duration(minutes: 1))),
          textOf(script.dawn(
            night(1, [sara, luca], scoop: Exposure(luca, Team.mafia)),
            discussion: threeMinutes,
          )),
          textOf(script.dawn(
            night(1, [], scoop: Exposure(luca, Team.citizens), silenced: sara),
            discussion: threeMinutes,
          )),
          textOf(script.dawn(night(2, [sara], silenced: luca), discussion: threeMinutes)),
          textOf(script.dawn(night(3, [sara], winner: Team.mafia), discussion: threeMinutes)),
          for (final source in AttackSource.values)
            for (final outcome in AttackOutcome.values)
              textOf(script.dawn(attack(sara, source, outcome), discussion: threeMinutes)),
          textOf(script.voteCall()),
          textOf(script.lynch(const LynchReport(round: 1))),
          for (final role in Role.values) ...[
            textOf(script.lynch(LynchReport(round: 1, condemned: sara, role: role))),
            textOf(script.lynch(LynchReport(round: 1, condemned: sara, role: role, winner: role.team.opponent))),
          ],
          textOf(script.ending(Team.mafia)),
          textOf(script.ending(Team.citizens)),
          for (final kind in NightTaskKind.values) ...[
            script.taskPrompt(NightTask(kind, const []), 1),
            script.taskHint(NightTask(kind, const [])),
          ],
          for (var round = 1; round <= 6; round++)
            script.taskPrompt(const NightTask(NightTaskKind.decoy, []), round),
        ];

    test('nessun testo, in nessuna città, lascia segnaposto vuoti o italiano in giro', () {
      for (final city in englishPack.cities) {
        final script = englishIn(city.id, 7);
        for (var i = 0; i < 60; i++) {
          for (final page in everyPage(script)) {
            expect(page, isNot(anyOf(contains('{'), contains('}'))), reason: '${city.id}: $page');
            expect(italianWords.stringMatch(page), isNull, reason: '${city.id}: $page');
            expect(genderedWords.hasMatch(page), isFalse, reason: '${city.id}: $page');
          }
        }
      }
    });

    test('nessuna pagina del copione supera le poche righe', () {
      int length(List<ScriptLine> lines) => words(textOf(lines));
      for (final city in englishPack.cities) {
        final script = englishIn(city.id, 3);
        for (var i = 0; i < 60; i++) {
          expect(length([...script.opening(), ...script.nightFalls(1)]), lessThanOrEqualTo(75));
          expect(length(script.nightFalls(2)), lessThanOrEqualTo(30));
          expect(length(script.dawn(night(1, [sara]), discussion: threeMinutes)), lessThanOrEqualTo(60));
          expect(
            length(script.dawn(night(1, [sara], silenced: luca), discussion: threeMinutes)),
            lessThanOrEqualTo(95),
          );
          for (final outcome in [AttackOutcome.healed, AttackOutcome.shrugged]) {
            expect(
              length(script.dawn(attack(sara, AttackSource.family, outcome), discussion: threeMinutes)),
              lessThanOrEqualTo(60),
            );
          }
          expect(length(script.voteCall()), lessThanOrEqualTo(25));
          expect(
            length(script.lynch(const LynchReport(round: 1, condemned: sara, role: Role.medico))),
            lessThanOrEqualTo(40),
          );
          expect(length(script.ending(Team.mafia)), lessThanOrEqualTo(30));
          expect(length(script.ending(Team.citizens)), lessThanOrEqualTo(30));
        }
      }
    });

    test('la partita si apre dicendo dove siamo e come si gioca', () {
      final lines = englishIn('napoli', 1).opening();
      expect(lines, hasLength(2));
      expect(lines.first.text, startsWith('Naples, 1950.'));
      expect(factsOf(lines), [englishPack.howToPlay]);
    });

    test('la notte dice a tutti di passarsi il telefono', () {
      final script = englishIn('chicago', 1);
      for (final round in [1, 2, 3]) {
        final lines = script.nightFalls(round);
        expect(lines, hasLength(2));
        expect(factsOf(lines), ['Pass the phone around. Everyone makes their move in secret, then passes it on.']);
      }
    });

    test('l\'alba senza morti lo dice chiaro e apre la discussione', () {
      final script = englishIn('chicago', 2);
      for (var i = 0; i < 30; i++) {
        final lines = script.dawn(night(1, []), discussion: threeMinutes);
        expect(lines, hasLength(3));
        expect(factsOf(lines), [
          'Nobody died last night.',
          'You have 3 minutes to discuss. Then vote on who to eliminate.',
        ]);
      }
    });

    test('un minuto solo si dice "one minute"', () {
      final lines = englishIn('chicago', 6).dawn(night(1, []), discussion: const Duration(minutes: 1));
      expect(factsOf(lines).last, 'You have one minute to discuss. Then vote on who to eliminate.');
    });

    test('ogni morte è una scena di tre battute, chiusa da un fatto chiaro', () {
      final script = englishIn('new-york', 3);
      for (var i = 0; i < 50; i++) {
        final lines = script.dawn(night(2, [sara]), discussion: threeMinutes);
        expect(lines, hasLength(5), reason: 'luogo, azione, stacco, fatto, istruzione');
        expect(lines[0].text, matches(RegExp('^(Exterior|Interior), night')));
        expect(lines[1].text, contains('Sara'), reason: 'l\'azione ha un protagonista');
        expect(lines[3].isFact, isTrue);
        expect(lines[3].text, 'Last night one person died: Sara. Their role stays secret.');
      }
    });

    test('l\'alba racconta ogni agguato per quello che è stato', () {
      final script = englishIn('chicago', 8);
      const report = DawnReport(round: 2, attacks: [
        NightAttack(sara, AttackSource.family, AttackOutcome.healed),
        NightAttack(luca, AttackSource.sniper, AttackOutcome.killed),
      ]);
      final lines = script.dawn(report, discussion: threeMinutes);
      final facts = factsOf(lines);
      expect(facts[0], 'Last night someone nearly died, but the Doc made it in time. Who it was stays a secret.');
      expect(textOf(lines), isNot(contains('Sara')), reason: 'chi si salva resta anonimo');
      expect(facts[1], 'Last night one person died: Luca. Their role stays secret.');
      expect(
        englishPack.sniperShots.allLines.map((line) => line.replaceAll('{name}', 'Luca')),
        contains(lines[lines.length - 4].text),
      );
      expect(textOf(lines), isNot(contains(englishPack.nobodyDied)));
    });

    test('il colpo andato a vuoto: luogo, la variante, e un fatto che non fa nomi di ruolo', () {
      final script = englishIn('palermo', 6);
      for (final source in AttackSource.values) {
        for (var i = 0; i < 30; i++) {
          final lines = script.dawn(attack(sara, source, AttackOutcome.shrugged), discussion: threeMinutes);
          expect(lines, hasLength(4), reason: 'luogo, azione, fatto, istruzione');
          expect(lines[1].text, isNot(contains('Sara')));
          expect(
            englishPack.shrugs.allLines.map((line) => line.replaceAll('{name}', englishPack.someone).toLowerCase()),
            contains(lines[1].text.toLowerCase()),
          );
          expect(
            factsOf(lines).first,
            'Last night someone nearly died, but the blow missed. Who it was stays a secret.',
          );
          final text = textOf(lines).toLowerCase();
          for (final name in englishRoleNames.values) {
            expect(text, isNot(contains(name.toLowerCase())), reason: name);
          }
        }
      }
    });

    test('di notte il ruolo di chi muore non viene mai detto', () {
      final script = englishIn('napoli', 3);
      for (var i = 0; i < 100; i++) {
        final text = textOf(script.dawn(night(2, [sara, luca]), discussion: threeMinutes)).toLowerCase();
        expect(text, allOf(contains('sara'), contains('luca')));
        for (final name in englishRoleNames.values) {
          expect(text, isNot(contains(name.toLowerCase())), reason: name);
        }
      }
    });

    test('lo scoop dice chiaro da che parte sta, poi la bocca cucita, poi la discussione', () {
      final lines = englishIn('palermo', 4).dawn(
        night(1, [], scoop: Exposure(sara, Team.mafia), silenced: luca),
        discussion: threeMinutes,
      );
      expect(factsOf(lines), [
        'Nobody died last night.',
        'The paper spells it out: Sara is with the Family.',
        'Today Luca can\'t talk during the discussion. Luca votes with gestures and can still be eliminated.',
        'You have 3 minutes to discuss. Then vote on who to eliminate.',
      ]);
      final clean = englishIn('palermo', 4).dawn(
        night(1, [], scoop: Exposure(sara, Team.citizens)),
        discussion: threeMinutes,
      );
      expect(factsOf(clean), contains('The paper spells it out: Sara is innocent.'));
    });

    test('il voto spiega che si può anche non eliminare nessuno', () {
      expect(factsOf(englishIn('napoli', 1).voteCall()), [englishPack.voteInstruction]);
      expect(factsOf(englishIn('palermo', 9).lynch(const LynchReport(round: 1))), ['Nobody is eliminated today.']);
    });

    test('il patibolo: prima la scena, poi la carta con ruolo e squadra, poi il commento', () {
      final script = englishIn('new-york', 7);
      for (final role in Role.values) {
        final lines = script.lynch(LynchReport(round: 1, condemned: sara, role: role));
        final side = role.team == Team.mafia ? 'On the Family\'s side.' : 'On the town\'s side.';
        expect(lines, hasLength(3));
        expect(lines[0].isFact, isFalse);
        expect(lines[0].text, contains('Sara'));
        expect(lines[1].isFact, isTrue);
        expect(lines[1].text, 'The card flips. Sara was… ${englishRoleNames[role]!.toUpperCase()}. $side');
        expect(
          role.team == Team.mafia ? englishPack.lynchedMafioso : englishPack.lynchedInnocent,
          contains(lines[2].text),
          reason: role.name,
        );
      }
      final last = script.lynch(
        const LynchReport(round: 1, condemned: sara, role: Role.padrino, winner: Team.citizens),
      );
      expect(
        englishPack.lynchedLastMafioso.map((line) => line.replaceAll('{city}', 'New York')),
        contains(last[2].text),
      );
    });

    test('la carta chiama il ruolo col suo nome inglese', () {
      final script = englishIn('palermo', 2);
      String card(Role role) => script.lynch(LynchReport(round: 1, condemned: sara, role: role))[1].text;
      expect(card(Role.medico), 'The card flips. Sara was… THE DOC. On the town\'s side.');
      expect(card(Role.sarto), 'The card flips. Sara was… THE TAILOR. On the Family\'s side.');
      for (final role in Role.values) {
        expect(card(role), contains(englishRoleNames[role]!.toUpperCase()), reason: role.name);
      }
    });

    test('il finale dice chi ha vinto e perché', () {
      final script = englishIn('las-vegas', 10);
      expect(factsOf(script.ending(Team.mafia)), ['The Family wins: the town no longer outnumbers them.']);
      expect(factsOf(script.ending(Team.citizens)), ['The town wins: the whole Family has been eliminated.']);
    });

    test('ogni compito ha la sua domanda, e quello di copertura la cambia ogni notte', () {
      final script = englishIn('chicago', 1);
      final prompts = {
        for (final kind in NightTaskKind.values) script.taskPrompt(NightTask(kind, const []), 1),
      };
      expect(prompts, hasLength(NightTaskKind.values.length));
      const decoy = NightTask(NightTaskKind.decoy, []);
      expect({for (var round = 1; round <= 5; round++) script.taskPrompt(decoy, round)}, hasLength(5));
      expect(englishPack.taskPrompts.values.toSet().intersection(englishPack.decoyPrompts.toSet()), isEmpty);
      for (final prompt in [...englishPack.taskPrompts.values, ...englishPack.decoyPrompts]) {
        expect(prompt, endsWith('?'), reason: prompt);
      }
    });

    test('gli agguati della famiglia pescano dal mazzo: tutte le azioni escono prima che una si ripeta', () {
      final script = englishIn('napoli', 3);
      final seen = [for (var round = 0; round < 60; round++) script.stage(night(round, [sara])).single.method.id];
      final deck = englishPack.methods.length;
      expect(seen.take(deck).toSet(), hasLength(deck));
    });
  });
}

extension on Team {
  Team get opponent => this == Team.mafia ? Team.citizens : Team.mafia;
}
