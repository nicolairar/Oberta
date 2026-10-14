import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/narration/death_story.dart';
import 'package:oberta/narration/italian_pack.dart';
import 'package:oberta/narration/narrator_script.dart';
import 'package:oberta/narration/picker.dart';
import 'package:oberta/rules/game_engine.dart';
import 'package:oberta/rules/player.dart';
import 'package:oberta/rules/role.dart';

const sara = Player(id: 'sara', name: 'Sara');
const luca = Player(id: 'luca', name: 'Luca');
const threeMinutes = Duration(minutes: 3);

final chicago = italianPack.cities.firstWhere((city) => city.id == 'chicago');

NarratorScript scriptIn(String cityId, int seed) => NarratorScript(
      city: italianPack.cities.firstWhere((city) => city.id == cityId),
      random: Random(seed),
    );

/// Il rapporto di una notte in cui la famiglia ha ucciso [victims].
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

/// Una notte in cui hanno sparato a [target], e il colpo non è andato a segno.
DawnReport shrugged(Player target, {AttackSource source = AttackSource.family}) => DawnReport(
      round: 2,
      attacks: [NightAttack(target, source, AttackOutcome.shrugged)],
    );

String textOf(List<ScriptLine> lines) => lines.map((line) => line.text).join(' ');

List<String> factsOf(List<ScriptLine> lines) => [
      for (final line in lines)
        if (line.isFact) line.text,
    ];

void main() {
  group('Picker', () {
    test('non ripete mai la stessa battuta due volte di fila', () {
      final picker = Picker(Random(3));
      const options = ['a', 'b', 'c', 'd', 'e', 'f'];
      var previous = picker.pick('pool', options);
      for (var i = 0; i < 300; i++) {
        final current = picker.pick('pool', options);
        expect(current, isNot(previous));
        previous = current;
      }
    });

    test('prima di ripetersi lascia passare metà dell\'elenco', () {
      final picker = Picker(Random(5));
      final options = [for (var i = 0; i < 10; i++) i];
      final picks = [for (var i = 0; i < 200; i++) picker.pick('pool', options)];
      for (var i = 5; i < picks.length; i++) {
        expect(picks.sublist(i - 5, i), isNot(contains(picks[i])), reason: 'pescata $i');
      }
    });

    test('alla lunga usa tutto l\'elenco', () {
      final picker = Picker(Random(1));
      const options = ['a', 'b', 'c', 'd'];
      expect({for (var i = 0; i < 100; i++) picker.pick('pool', options)}, options.toSet());
    });

    test('ogni elenco ha la sua memoria', () {
      final picker = Picker(Random(1));
      expect(picker.pick('uno', ['solo']), 'solo');
      expect(picker.pick('due', ['solo']), 'solo');
      expect(picker.pick('uno', ['solo']), 'solo');
    });
  });

  group('il pacchetto italiano', () {
    test('ogni città ha un titolo con l\'anno, aperture e abbastanza luoghi', () {
      expect(italianPack.cities.length, greaterThanOrEqualTo(5));
      for (final city in italianPack.cities) {
        expect(city.title, startsWith(city.name), reason: city.id);
        expect(city.title, matches(RegExp(r', 19\d\d$')), reason: city.id);
        expect(city.openings, isNotEmpty, reason: city.id);
        expect(city.scenes.length, greaterThanOrEqualTo(8), reason: city.id);
        for (final opening in city.openings) {
          expect(opening, startsWith(city.title), reason: 'il film si apre dicendo dove siamo');
        }
      }
    });

    test('i pezzi di storia hanno nomi unici, pronti per le animazioni', () {
      final ids = [
        for (final city in italianPack.cities) ...city.scenes,
        ...italianPack.methods,
        ...italianPack.epilogues,
      ].map((piece) => piece.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('ogni azione nomina la vittima', () {
      for (final piece in italianPack.methods) {
        expect(piece.text, contains('{name}'), reason: piece.id);
      }
    });

    test('ogni città offre centinaia di morti diverse', () {
      for (final city in italianPack.cities) {
        final combinations =
            city.scenes.length * italianPack.methods.length * italianPack.epilogues.length;
        expect(combinations, greaterThan(900), reason: city.id);
      }
    });

    test('nessuna battuta è lunga: al tavolo si legge in fretta', () {
      int words(String text) => text.split(RegExp(r'\s+')).length;
      final story = <String>[
        for (final city in italianPack.cities) ...[
          ...city.openings,
          for (final scene in city.scenes) scene.text,
        ],
        ...italianPack.firstNights,
        ...italianPack.nights,
        ...italianPack.quietDawns,
        ...italianPack.secondVictims,
        ...italianPack.sniperShots,
        ...italianPack.rescues,
        ...italianPack.shrugs,
        for (final piece in italianPack.methods) piece.text,
        for (final piece in italianPack.epilogues) piece.text,
        ...italianPack.scoops,
        ...italianPack.silences,
        ...italianPack.voteCalls,
        ...italianPack.lynchScenes,
        ...italianPack.lynchedInnocent,
        ...italianPack.lynchedMafioso,
        ...italianPack.lynchedLastMafioso,
        ...italianPack.noLynch,
        ...italianPack.citizensWin,
        ...italianPack.mafiaWins,
      ];
      for (final line in story) {
        expect(words(line), lessThanOrEqualTo(16), reason: line);
      }
      expect(words(italianPack.howToPlay), lessThanOrEqualTo(32));
      expect(words(italianPack.nightInstruction), lessThanOrEqualTo(16));
      for (final fact in [italianPack.savedFact, italianPack.shruggedFact, italianPack.silencedFact]) {
        expect(words(fact), lessThanOrEqualTo(18), reason: fact);
      }
      for (final kind in NightTaskKind.values) {
        expect(words(italianPack.taskHints[kind]!), lessThanOrEqualTo(16), reason: kind.name);
      }
    });

    test('le battute nuove nominano sempre di chi parlano', () {
      expect(italianPack.shrugs.length, greaterThanOrEqualTo(3));
      expect(italianPack.silences.length, greaterThanOrEqualTo(3));
      final lines = [
        ...italianPack.shrugs,
        italianPack.shruggedFact,
        ...italianPack.silences,
        italianPack.silencedFact,
      ];
      for (final line in lines) {
        expect(line, contains('{name}'), reason: line);
      }
    });

    test('il colpo andato a vuoto è una fiaschetta, e non dice chi ha la pelle dura', () {
      for (final line in italianPack.shrugs) {
        expect(line, contains('fiaschetta'), reason: 'in scena si vede quella');
      }
      final text = [...italianPack.shrugs, italianPack.shruggedFact].join(' ').toUpperCase();
      expect(text, isNot(contains('REDUCE')));
      expect(text, isNot(contains('DOTTORE')), reason: 'stavolta il Dottore non c\'entra');
      expect(italianPack.shruggedFact, contains('resta in gioco'));
    });

    test('nessuna battuta d\'atmosfera ruba il nome a un ruolo', () {
      // "Il becchino ha dormito" suonerebbe come un indizio, ora che c'è Il Becchino.
      final labels = [for (final role in Role.values) italianPack.role(role).label.toUpperCase()];
      final atmosphere = [
        ...italianPack.firstNights,
        ...italianPack.nights,
        ...italianPack.quietDawns,
        ...italianPack.secondVictims,
        ...italianPack.sniperShots,
        ...italianPack.shrugs,
        ...italianPack.silences,
        ...italianPack.voteCalls,
        ...italianPack.noLynch,
        for (final piece in italianPack.methods) piece.text,
        for (final piece in italianPack.epilogues) piece.text,
      ].join(' ').toUpperCase();
      for (final label in labels) {
        expect(atmosphere, isNot(contains(label)), reason: label);
      }
      expect(italianPack.rescues.join(' ').toLowerCase(), isNot(contains('becchino')));
    });

    test('chi deve tacere lo sa in modo chiaro: niente parole, ma resta in gioco', () {
      expect(italianPack.silencedFact, contains('non può parlare'));
      expect(italianPack.silencedFact.toLowerCase(), contains('vota'));
      expect(italianPack.silencedFact, contains('eliminare'));
    });

    test('nessuno chiude gli occhi: ci si passa il telefono', () {
      final everything = [
        italianPack.howToPlay,
        italianPack.nightInstruction,
        italianPack.nobodyDied,
        italianPack.victimFact,
        italianPack.shruggedFact,
        italianPack.silencedFact,
        ...italianPack.firstNights,
        ...italianPack.nights,
        ...italianPack.shrugs,
        ...italianPack.silences,
        ...italianPack.taskPrompts.values,
        ...italianPack.taskHints.values,
      ].join(' ').toLowerCase();
      expect(everything, isNot(contains('occhi')));
      expect(italianPack.nightInstruction, contains('telefono'));
    });

    test('c\'è una domanda e una spiegazione per ogni compito notturno', () {
      for (final kind in NightTaskKind.values) {
        expect(italianPack.taskHints[kind], isNotNull, reason: kind.name);
        if (kind != NightTaskKind.decoy) {
          expect(italianPack.taskPrompts[kind], isNotNull, reason: kind.name);
        }
      }
    });
  });

  group('DeathStory', () {
    test('due morti di fila non si somigliano in nessuno strato', () {
      final picker = Picker(Random(4));
      var previous = DeathStory.compose(picker, italianPack, chicago);
      for (var i = 0; i < 200; i++) {
        final current = DeathStory.compose(picker, italianPack, chicago);
        expect(current.scene.id, isNot(previous.scene.id));
        expect(current.method.id, isNot(previous.method.id));
        expect(current.epilogue!.id, isNot(previous.epilogue!.id));
        previous = current;
      }
    });

    test('il Cecchino e il Dottore hanno una scena loro, fuori dal mazzo', () {
      final picker = Picker(Random(6));
      final shot = DeathStory.sniper(picker, italianPack, chicago);
      expect(shot.method.id, DeathStory.sniperId);
      expect(shot.survived, isFalse);
      expect(shot.fact, italianPack.victimFact);
      expect(shot.paragraphs, hasLength(3));

      final saved = DeathStory.rescue(picker, italianPack, chicago);
      expect(saved.method.id, DeathStory.rescueId);
      expect(saved.survived, isTrue);
      expect(saved.fact, italianPack.savedFact);
      expect(saved.paragraphs, hasLength(2), reason: 'niente stacco finale: chiude il fatto');

      final lucky = DeathStory.lucky(picker, italianPack, chicago);
      expect(lucky.method.id, DeathStory.luckyId);
      expect(lucky.survived, isTrue);
      expect(lucky.fact, italianPack.shruggedFact);
      expect(italianPack.shrugs, contains(lucky.method.text));
      expect(chicago.scenes, contains(lucky.scene));
      expect(lucky.paragraphs, hasLength(2), reason: 'niente stacco finale: chiude il fatto');

      final ids = italianPack.methods.map((piece) => piece.id);
      expect(ids, isNot(contains(DeathStory.sniperId)));
      expect(ids, isNot(contains(DeathStory.rescueId)));
      expect(ids, isNot(contains(DeathStory.luckyId)));
      expect({DeathStory.sniperId, DeathStory.rescueId, DeathStory.luckyId}, hasLength(3));
      for (final line in [...italianPack.sniperShots, ...italianPack.rescues, italianPack.savedFact]) {
        expect(line, contains('{name}'), reason: line);
      }
    });

    test('le scene sono solo quelle della città della partita', () {
      final picker = Picker(Random(2));
      for (var i = 0; i < 100; i++) {
        final story = DeathStory.compose(picker, italianPack, chicago);
        expect(chicago.scenes, contains(story.scene));
      }
    });
  });

  group('NarratorScript', () {
    test('senza indicazioni sorteggia la città, e alla lunga le usa tutte', () {
      final cities = {for (var seed = 0; seed < 100; seed++) NarratorScript(random: Random(seed)).city.id};
      expect(cities, hasLength(italianPack.cities.length));
    });

    test('nessun testo, in nessuna città, lascia segnaposto vuoti', () {
      for (final city in italianPack.cities) {
        final script = scriptIn(city.id, 7);
        for (var i = 0; i < 60; i++) {
          final everything = [
            ...script.opening(),
            ...script.nightFalls(1),
            ...script.nightFalls(2),
            ...script.dawn(night(1, []), discussion: threeMinutes),
            ...script.dawn(
              night(1, [sara, luca], scoop: Exposure(luca, Team.mafia)),
              discussion: threeMinutes,
            ),
            ...script.dawn(night(2, [sara], silenced: luca), discussion: threeMinutes),
            ...script.dawn(shrugged(sara), discussion: threeMinutes),
            ...script.dawn(shrugged(sara, source: AttackSource.sniper), discussion: threeMinutes),
            ...script.voteCall(),
            ...script.lynch(const LynchReport(round: 1)),
            ...script.lynch(const LynchReport(round: 1, condemned: sara, role: Role.medico)),
            ...script.lynch(const LynchReport(round: 1, condemned: sara, role: Role.mafioso)),
            for (final role in Role.values)
              ...script.lynch(LynchReport(round: 1, condemned: sara, role: role)),
            ...script.ending(Team.mafia),
            ...script.ending(Team.citizens),
          ];
          expect(textOf(everything), isNot(contains('{')), reason: city.id);
        }
      }
    });

    test('nessuna pagina del copione supera le poche righe', () {
      int words(List<ScriptLine> lines) => textOf(lines).split(RegExp(r'\s+')).length;
      for (final city in italianPack.cities) {
        final script = scriptIn(city.id, 3);
        for (var i = 0; i < 40; i++) {
          expect(words([...script.opening(), ...script.nightFalls(1)]), lessThanOrEqualTo(75));
          expect(words(script.nightFalls(2)), lessThanOrEqualTo(30));
          expect(
            words(script.dawn(night(1, [sara]), discussion: threeMinutes)),
            lessThanOrEqualTo(60),
          );
          expect(
            words(script.dawn(night(1, [sara], silenced: luca), discussion: threeMinutes)),
            lessThanOrEqualTo(95),
            reason: 'una morte e una bocca cucita: la pagina più lunga di un\'alba normale',
          );
          expect(words(script.dawn(shrugged(sara), discussion: threeMinutes)), lessThanOrEqualTo(60));
          expect(words(script.voteCall()), lessThanOrEqualTo(25));
          expect(
            words(script.lynch(const LynchReport(round: 1, condemned: sara, role: Role.medico))),
            lessThanOrEqualTo(40),
          );
          expect(words(script.ending(Team.mafia)), lessThanOrEqualTo(30));
        }
      }
    });

    test('la partita si apre dicendo dove siamo e come si gioca', () {
      final lines = scriptIn('palermo', 1).opening();
      expect(lines, hasLength(2));
      expect(lines.first.text, startsWith('Palermo, 1955.'));
      expect(factsOf(lines), [italianPack.howToPlay]);
    });

    test('la notte dice a tutti di passarsi il telefono', () {
      final script = scriptIn('napoli', 1);
      for (final round in [1, 2, 3]) {
        final lines = script.nightFalls(round);
        expect(lines, hasLength(2));
        expect(factsOf(lines), ['Passatevi il telefono. Ognuno fa la sua mossa in segreto, poi lo passa.']);
      }
    });

    test('l\'alba senza morti lo dice chiaro e apre la discussione', () {
      final script = scriptIn('chicago', 2);
      for (var i = 0; i < 30; i++) {
        final lines = script.dawn(night(1, []), discussion: threeMinutes);
        expect(lines, hasLength(3));
        expect(factsOf(lines), [
          'Stanotte non è morto nessuno.',
          'Avete 3 minuti per discutere. Poi votate chi eliminare.',
        ]);
      }
    });

    test('ogni morte è una scena di tre battute, chiusa da un fatto chiaro', () {
      final script = scriptIn('new-york', 3);
      for (var i = 0; i < 50; i++) {
        final lines = script.dawn(night(2, [sara]), discussion: threeMinutes);

        expect(lines, hasLength(5), reason: 'luogo, azione, stacco, fatto, istruzione');
        expect(lines[0].text, matches(RegExp('^(Esterno|Interno), notte')));
        expect(lines.sublist(0, 3).where((line) => line.isFact), isEmpty);
        expect(lines[1].text, contains('Sara'), reason: 'l\'azione ha un protagonista');
        expect(lines[3].isFact, isTrue);
        expect(lines[3].text, 'Stanotte è morta una persona: Sara. Il suo ruolo resta segreto.');
        expect(lines[4].isFact, isTrue);
      }
    });

    test('la scena è ambientata in un luogo della città della partita', () {
      final script = scriptIn('las-vegas', 4);
      final vegas = script.city.scenes.map((scene) => scene.text).toSet();
      for (var i = 0; i < 40; i++) {
        final lines = script.dawn(night(1, [sara]), discussion: threeMinutes);
        expect(vegas, contains(lines[0].text));
      }
    });

    test('di notte il ruolo di chi muore non viene mai detto', () {
      final script = scriptIn('napoli', 3);
      final roleNames = [for (final role in Role.values) italianPack.role(role).label.toUpperCase()];
      for (var i = 0; i < 100; i++) {
        final text = textOf(
          script.dawn(night(2, [sara, luca]), discussion: threeMinutes),
        ).toUpperCase();
        expect(text, contains('SARA'));
        expect(text, contains('LUCA'));
        for (final name in roleNames) {
          expect(text, isNot(contains(name)));
        }
      }
    });

    test('due morti nella stessa notte hanno due scene e due fatti', () {
      final lines = scriptIn('chicago', 5)
          .dawn(night(2, [sara, luca]), discussion: threeMinutes);
      final facts = factsOf(lines);
      expect(facts[0], contains('Sara'));
      expect(facts[1], contains('Luca'));
      expect(facts, hasLength(3));
    });

    test('lo scoop dice chiaro da che parte sta', () {
      final script = scriptIn('palermo', 4);
      final mafia = script.dawn(
        night(1, [], scoop: Exposure(luca, Team.mafia)),
        discussion: threeMinutes,
      );
      final clean = script.dawn(
        night(1, [], scoop: Exposure(luca, Team.citizens)),
        discussion: threeMinutes,
      );
      expect(factsOf(mafia), contains('Il giornale lo scrive chiaro: Luca sta con la famiglia.'));
      expect(factsOf(clean), contains('Il giornale lo scrive chiaro: Luca è innocente.'));
    });

    test('se la partita finisce all\'alba non si apre nessuna discussione', () {
      final lines = scriptIn('chicago', 5).dawn(
        night(3, [sara], winner: Team.mafia),
        discussion: threeMinutes,
      );
      expect(textOf(lines), isNot(contains('minuti')));
      expect(factsOf(lines), hasLength(1));
    });

    test('un minuto solo si dice "un minuto"', () {
      final lines = scriptIn('chicago', 6).dawn(
        night(1, []),
        discussion: const Duration(minutes: 1),
      );
      expect(factsOf(lines).last, 'Avete un minuto per discutere. Poi votate chi eliminare.');
    });

    test('il voto spiega che si può anche non eliminare nessuno', () {
      expect(factsOf(scriptIn('napoli', 1).voteCall()), [italianPack.voteInstruction]);
    });

    test('il linciaggio: prima la scena, poi la carta con ruolo e squadra', () {
      final script = scriptIn('new-york', 7);
      for (var i = 0; i < 40; i++) {
        final lines = script.lynch(const LynchReport(round: 1, condemned: sara, role: Role.medico));
        expect(lines, hasLength(3));
        expect(lines[0].isFact, isFalse);
        expect(lines[0].text, contains('Sara'));
        expect(lines[0].text, isNot(contains('DOTTORE')), reason: 'la prima battuta non svela niente');
        expect(lines[1].isFact, isTrue);
        expect(lines[1].text, 'La carta si gira. Sara era… IL DOTTORE. Stava con gli onesti.');
      }
      final mafioso = script.lynch(const LynchReport(round: 1, condemned: luca, role: Role.mafioso));
      expect(mafioso[1].text, 'La carta si gira. Luca era… IL PICCIOTTO. Stava con la famiglia.');
    });

    test('il tono cambia tra innocente, mafioso e ultimo mafioso', () {
      final script = scriptIn('chicago', 8);
      String reaction(LynchReport report) => script.lynch(report).last.text;

      final innocent = {
        for (var i = 0; i < 40; i++)
          reaction(const LynchReport(round: 1, condemned: sara, role: Role.cittadino)),
      };
      final mafioso = {
        for (var i = 0; i < 40; i++)
          reaction(const LynchReport(round: 1, condemned: sara, role: Role.mafioso)),
      };
      final last = {
        for (var i = 0; i < 40; i++)
          reaction(const LynchReport(
            round: 1,
            condemned: sara,
            role: Role.mafioso,
            winner: Team.citizens,
          )),
      };
      expect(innocent.intersection(mafioso), isEmpty);
      expect(mafioso.intersection(last), isEmpty);
      expect(innocent.length, greaterThan(1));
    });

    test('senza condanna lo dice chiaro', () {
      final lines = scriptIn('palermo', 9).lynch(const LynchReport(round: 1));
      expect(factsOf(lines), ['Oggi non viene eliminato nessuno.']);
    });

    test('il finale dice chi ha vinto e perché', () {
      final script = scriptIn('las-vegas', 10);
      expect(factsOf(script.ending(Team.mafia)), [italianPack.mafiaWinsFact]);
      expect(factsOf(script.ending(Team.citizens)), [italianPack.citizensWinFact]);
    });

    test('il compito di copertura cambia domanda ogni notte', () {
      final script = scriptIn('chicago', 1);
      const task = NightTask(NightTaskKind.decoy, []);
      final prompts = {for (var round = 1; round <= 5; round++) script.taskPrompt(task, round)};
      expect(prompts, hasLength(5));
    });

    test('ogni tipo di compito ha la sua domanda', () {
      final script = scriptIn('chicago', 1);
      final prompts = {
        for (final kind in NightTaskKind.values) script.taskPrompt(NightTask(kind, const []), 1),
      };
      expect(prompts, hasLength(NightTaskKind.values.length));
    });

    test('l\'alba racconta ogni agguato per quello che è stato', () {
      final script = scriptIn('chicago', 8);
      const report = DawnReport(round: 2, attacks: [
        NightAttack(sara, AttackSource.family, AttackOutcome.healed),
        NightAttack(luca, AttackSource.sniper, AttackOutcome.killed),
      ]);
      final stories = script.stage(report);
      expect(stories.map((story) => story.method.id), [DeathStory.rescueId, DeathStory.sniperId]);

      final lines = script.dawn(report, discussion: threeMinutes, stories: stories);
      final facts = factsOf(lines);
      expect(facts[0], 'Stanotte hanno sparato a Sara, ma il Dottore ha fatto in tempo. Sara resta in gioco.');
      expect(facts[1], 'Stanotte è morta una persona: Luca. Il suo ruolo resta segreto.');
      expect(textOf(lines), isNot(contains('{name}')));
      expect(textOf(lines), isNot(contains(italianPack.nobodyDied)));
    });

    test('il colpo andato a vuoto: luogo, fiaschetta, e un fatto che non fa nomi di ruolo', () {
      final script = scriptIn('palermo', 6);
      final roleNames = [for (final role in Role.values) italianPack.role(role).label.toUpperCase()];
      for (final source in AttackSource.values) {
        for (var i = 0; i < 30; i++) {
          final report = shrugged(sara, source: source);
          final stories = script.stage(report);
          expect(stories.single.method.id, DeathStory.luckyId, reason: source.name);

          final lines = script.dawn(report, discussion: threeMinutes, stories: stories);
          expect(lines, hasLength(4), reason: 'luogo, azione, fatto, istruzione');
          expect(lines[0].text, matches(RegExp('^(Esterno|Interno), notte')));
          expect(lines[1].text, contains('Sara'));
          expect(lines[1].text, contains('fiaschetta'));
          expect(factsOf(lines).first,
              'Stanotte hanno sparato a Sara, ma il colpo non è andato a segno. Sara resta in gioco.');
          final text = textOf(lines).toUpperCase();
          expect(text, isNot(contains('{')));
          expect(text, isNot(contains(italianPack.nobodyDied.toUpperCase())));
          for (final name in roleNames) {
            expect(text, isNot(contains(name)), reason: name);
          }
        }
      }
    });

    test('una notte può avere un morto, un salvataggio e un colpo a vuoto: tre scene diverse', () {
      final script = scriptIn('new-york', 2);
      const mario = Player(id: 'mario', name: 'Mario');
      const report = DawnReport(round: 3, attacks: [
        NightAttack(sara, AttackSource.family, AttackOutcome.shrugged),
        NightAttack(luca, AttackSource.sniper, AttackOutcome.killed),
      ]);
      expect(script.stage(report).map((story) => story.method.id), [DeathStory.luckyId, DeathStory.sniperId]);

      const other = DawnReport(round: 3, attacks: [
        NightAttack(sara, AttackSource.sniper, AttackOutcome.healed),
        NightAttack(mario, AttackSource.family, AttackOutcome.killed),
      ]);
      final stories = script.stage(other);
      expect(stories.first.method.id, DeathStory.rescueId);
      expect(italianPack.methods.map((piece) => piece.id), contains(stories.last.method.id));
    });

    test('la bocca cucita si annuncia all\'alba, prima di aprire la discussione', () {
      final script = scriptIn('napoli', 5);
      for (var i = 0; i < 20; i++) {
        final lines = script.dawn(night(2, [sara], silenced: luca), discussion: threeMinutes);
        final facts = factsOf(lines);
        expect(facts, [
          'Stanotte è morta una persona: Sara. Il suo ruolo resta segreto.',
          'Oggi Luca non può parlare durante la discussione. Vota a gesti, e resta tra chi potete eliminare.',
          'Avete 3 minuti per discutere. Poi votate chi eliminare.',
        ]);
        final announcement = lines[lines.length - 3];
        expect(announcement.isFact, isFalse);
        expect(announcement.text, contains('Luca'));
        expect(italianPack.silences.map((line) => line.replaceAll('{name}', 'Luca')), contains(announcement.text));
      }
    });

    test('anche in una notte tranquilla qualcuno può svegliarsi con la bocca cucita', () {
      final lines = scriptIn('chicago', 4).dawn(night(1, [], silenced: luca), discussion: threeMinutes);
      final facts = factsOf(lines);
      expect(facts.first, 'Stanotte non è morto nessuno.');
      expect(facts[1], startsWith('Oggi Luca non può parlare'));
      expect(facts, hasLength(3));
    });

    test('lo scoop viene prima del silenzio: prima le notizie, poi le regole del giorno', () {
      final lines = scriptIn('chicago', 4).dawn(
        night(1, [], scoop: Exposure(sara, Team.mafia), silenced: luca),
        discussion: threeMinutes,
      );
      final facts = factsOf(lines);
      expect(facts[1], contains('Sara sta con la famiglia'));
      expect(facts[2], startsWith('Oggi Luca non può parlare'));
    });

    test('se la partita finisce all\'alba, il silenzio non si annuncia: non c\'è discussione', () {
      final lines = scriptIn('chicago', 5).dawn(
        night(3, [sara], silenced: luca, winner: Team.mafia),
        discussion: threeMinutes,
      );
      expect(textOf(lines), isNot(contains('Luca')));
      expect(factsOf(lines), hasLength(1));
    });

    test('il patibolo chiama ogni ruolo col suo nome e la sua squadra', () {
      final script = scriptIn('palermo', 2);
      String card(Role role) => script.lynch(LynchReport(round: 1, condemned: sara, role: role))[1].text;

      expect(card(Role.padrino), 'La carta si gira. Sara era… IL PADRINO. Stava con la famiglia.');
      expect(card(Role.sarto), 'La carta si gira. Sara era… IL SARTO. Stava con la famiglia.');
      expect(card(Role.becchino), 'La carta si gira. Sara era… IL BECCHINO. Stava con gli onesti.');
      expect(card(Role.guardaspalle), 'La carta si gira. Sara era… IL GUARDASPALLE. Stava con gli onesti.');
      expect(card(Role.reduce), 'La carta si gira. Sara era… IL REDUCE. Stava con gli onesti.');
      expect(card(Role.pregiudicato), 'La carta si gira. Sara era… IL PREGIUDICATO. Stava con gli onesti.',
          reason: 'la carta dice la verità, non la fedina');
    });

    test('condannare Padrino o Sarto fa reagire come per un mafioso; il Pregiudicato no', () {
      final script = scriptIn('chicago', 8);
      String reaction(Role role) => script.lynch(LynchReport(round: 1, condemned: sara, role: role)).last.text;
      for (var i = 0; i < 20; i++) {
        expect(italianPack.lynchedMafioso, contains(reaction(Role.padrino)));
        expect(italianPack.lynchedMafioso, contains(reaction(Role.sarto)));
        expect(italianPack.lynchedInnocent, contains(reaction(Role.pregiudicato)));
      }
    });

    test('ogni mossa nuova ha domanda e spiegazione sue', () {
      final script = scriptIn('chicago', 1);
      String prompt(NightTaskKind kind) => script.taskPrompt(NightTask(kind, const []), 1);
      String hint(NightTaskKind kind) => script.taskHint(NightTask(kind, const []));

      expect(prompt(NightTaskKind.silence), 'A chi cuci la bocca stanotte?');
      expect(prompt(NightTaskKind.dig), 'Quale fossa scavi stanotte?');
      expect(prompt(NightTaskKind.guard), 'A chi fai da scudo stanotte?');
      expect(hint(NightTaskKind.silence), contains('due notti di fila'));
      expect(hint(NightTaskKind.dig), contains('solo tu'));
      expect(hint(NightTaskKind.guard), contains('muori tu'));
      final hints = {for (final kind in NightTaskKind.values) hint(kind)};
      expect(hints, hasLength(NightTaskKind.values.length));
    });

    test('gli agguati della famiglia pescano dal mazzo: mai due uguali di fila', () {
      final script = scriptIn('napoli', 3);
      final seen = <String>[];
      for (var round = 0; round < 60; round++) {
        final story = script.stage(night(round, [sara])).single;
        if (seen.isNotEmpty) expect(story.method.id, isNot(seen.last));
        seen.add(story.method.id);
      }
      final deck = italianPack.methods.length;
      expect(seen.take(deck).toSet(), hasLength(deck), reason: 'tutte le azioni escono prima che una si ripeta');
    });
  });
}
