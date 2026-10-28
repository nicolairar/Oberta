import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/rules/game_engine.dart';
import 'package:oberta/rules/game_settings.dart';
import 'package:oberta/rules/game_setup.dart';
import 'package:oberta/rules/game_snapshot.dart';
import 'package:oberta/rules/intent.dart';
import 'package:oberta/rules/player.dart';
import 'package:oberta/rules/role.dart';

import 'player_view_test.dart' show leaksIn, wire;

/// Ogni interazione tra ruoli, una per test. Le regole che questi test
/// fissano sono scritte in docs/ruoli-analisi.md, "Regole di risoluzione".

Player _p(String id) => Player(id: id, name: id);

final mob = _p('mob');
final mob2 = _p('mob2');
final sarto = _p('tailor');
final doc = _p('doc');
final guard = _p('guard');
final vet = _p('vet');
final sniper = _p('sniper');
final hitman = _p('hitman');
final pyro = _p('pyro');
final shark = _p('shark');
final hunter = _p('hunter');
final fool = _p('fool');
final messiah = _p('messiah');
final mayor = _p('mayor');
final reporter = _p('reporter');
final digger = _p('digger');
final doorman = _p('doorman');
final cop = _p('cop');
final a = _p('a');
final b = _p('b');
final c = _p('c');
final d = _p('d');
final e = _p('e');

/// Un tavolo con questi ruoli più abbastanza Onesti da non finire per caso.
GameEngine table(Map<Player, Role> roles, {int fillers = 5, int seed = 3, GameSettings? settings}) {
  final all = {...roles};
  for (final filler in [a, b, c, d, e].take(fillers)) {
    all.putIfAbsent(filler, () => Role.cittadino);
  }
  return GameEngine(GameSetup.fromRoles(all), seed: seed, settings: settings ?? const GameSettings());
}

/// Una notte: le mosse date, tutti gli altri passano.
DawnReport night(GameEngine engine, Map<Player, Player?> moves, {Set<Player> alternative = const {}}) {
  for (final entry in moves.entries) {
    engine.submitNightChoice(entry.key, entry.value, alternative: alternative.contains(entry.key));
  }
  for (final player in engine.pendingNightPlayers) {
    engine.submitNightChoice(player, null);
  }
  return engine.resolveNight();
}

NightAttack? attackOn(DawnReport dawn, Player player) {
  for (final attack in dawn.attacks) {
    if (attack.target == player) return attack;
  }
  return null;
}

/// Fotografa, passa per il JSON, riprende: la copia deve essere identica,
/// fino alle viste di ciascun posto.
void expectRoundTrip(GameEngine engine) {
  final json = wire(engine.snapshot().toJson());
  final copy = GameEngine.fromSnapshot(GameSnapshot.fromJson(json));
  expect(wire(copy.snapshot().toJson()).toString(), json.toString());
  for (final player in engine.setup.players) {
    expect(wire(copy.viewFor(player.id).toJson()).toString(), wire(engine.viewFor(player.id).toJson()).toString());
  }
  expect(wire(copy.publicView().toJson()).toString(), wire(engine.publicView().toJson()).toString());
}

/// Nessuna vista dice più di quanto il posto abbia diritto di sapere.
void expectNoLeaks(GameEngine engine) {
  expect(leaksIn(engine, null, wire(engine.publicView().toJson())), isEmpty);
  for (final player in engine.setup.players) {
    expect(leaksIn(engine, player, wire(engine.viewFor(player.id).toJson())), isEmpty, reason: player.id);
  }
}

void main() {
  group('protezioni contro la famiglia', () {
    test('il Dottore ferma l\'agguato', () {
      final engine = table({mob: Role.mafioso, doc: Role.medico});
      final dawn = night(engine, {mob: a, doc: a});
      expect(attackOn(dawn, a)!.outcome, AttackOutcome.healed);
      expect(engine.isAlive(a), isTrue);
      expectNoLeaks(engine);
      expectRoundTrip(engine);
    });

    test('il Dottore può proteggere se stesso, ma non due notti di fila', () {
      final engine = table({mob: Role.mafioso, doc: Role.medico});
      final dawn = night(engine, {mob: doc, doc: doc});
      expect(attackOn(dawn, doc)!.outcome, AttackOutcome.healed);
      engine.lynch(null);
      expect(engine.taskFor(doc).targets, isNot(contains(doc)));
    });

    test('lo Strozzino ferma l\'agguato come il Dottore', () {
      final engine = table({mob: Role.mafioso, shark: Role.strozzino});
      final dawn = night(engine, {mob: a, shark: a});
      expect(attackOn(dawn, a)!.outcome, AttackOutcome.healed);
      engine.lynch(null);
      expect(engine.taskFor(shark).targets, isNot(contains(a)));
      expectRoundTrip(engine);
    });

    test('il Guardaspalle muore al posto del protetto', () {
      final engine = table({mob: Role.mafioso, guard: Role.guardaspalle});
      final dawn = night(engine, {mob: a, guard: a});
      expect(dawn.victims, [guard]);
      expect(attackOn(dawn, a), isNull);
    });

    test('Guardaspalle: due assassini sullo stesso protetto, muore solo lui', () {
      final engine = table({mob: Role.mafioso, guard: Role.guardaspalle, hitman: Role.sicario});
      final dawn = night(engine, {mob: a, hitman: a, guard: a});
      expect(dawn.victims, [guard]);
      expect(dawn.attacks.length, 1);
      expect(engine.isAlive(a), isTrue);
    });

    test('Guardaspalle colpito lui stesso: muore, il protetto non c\'entra', () {
      final engine = table({mob: Role.mafioso, guard: Role.guardaspalle});
      final dawn = night(engine, {mob: guard, guard: a});
      expect(dawn.victims, [guard]);
    });

    test('Guardaspalle protetto dal Dottore: vivono tutti e due', () {
      final engine = table({mob: Role.mafioso, guard: Role.guardaspalle, doc: Role.medico});
      final dawn = night(engine, {mob: a, guard: a, doc: guard});
      expect(dawn.victims, isEmpty);
      expect(attackOn(dawn, guard)!.outcome, AttackOutcome.healed);
    });

    test('Dottore e Guardaspalle sulla stessa persona: basta il Dottore', () {
      final engine = table({mob: Role.mafioso, guard: Role.guardaspalle, doc: Role.medico});
      final dawn = night(engine, {mob: a, guard: a, doc: a});
      expect(dawn.victims, isEmpty);
      expect(attackOn(dawn, a)!.outcome, AttackOutcome.healed);
      expect(attackOn(dawn, guard), isNull);
    });

    test('il Reduce incassa il primo colpo, il secondo lo uccide', () {
      final engine = table({mob: Role.mafioso, vet: Role.reduce});
      expect(attackOn(night(engine, {mob: vet}), vet)!.outcome, AttackOutcome.shrugged);
      expectRoundTrip(engine);
      engine.lynch(null);
      expect(night(engine, {mob: vet}).victims, [vet]);
    });

    test('Reduce curato dal Dottore: la pelle dura resta intatta', () {
      final engine = table({mob: Role.mafioso, vet: Role.reduce, doc: Role.medico});
      expect(attackOn(night(engine, {mob: vet, doc: vet}), vet)!.outcome, AttackOutcome.healed);
      engine.lynch(null);
      expect(attackOn(night(engine, {mob: vet}), vet)!.outcome, AttackOutcome.shrugged);
    });
  });

  group('più assassini', () {
    test('famiglia e Cecchino sullo stesso bersaglio: un agguato solo, della famiglia', () {
      final engine = table({mob: Role.mafioso, sniper: Role.cecchino});
      final dawn = night(engine, {mob: a, sniper: a});
      expect(dawn.attacks.single.source, AttackSource.family);
      expect(dawn.victims, [a]);
    });

    test('famiglia, Cecchino e Sicario su tre persone: tre morti', () {
      final engine = table({mob: Role.mafioso, mob2: Role.mafioso, sniper: Role.cecchino, hitman: Role.sicario});
      final dawn = night(engine, {mob: a, mob2: a, sniper: b, hitman: c});
      expect(dawn.victims, [a, b, c]);
      expect(attackOn(dawn, b)!.source, AttackSource.sniper);
      expect(attackOn(dawn, c)!.source, AttackSource.assassin);
    });

    test('il Dottore salva uno solo: gli altri colpi vanno a segno', () {
      final engine = table({mob: Role.mafioso, hitman: Role.sicario, doc: Role.medico});
      final dawn = night(engine, {mob: a, hitman: b, doc: a});
      expect(dawn.victims, [b]);
    });

    test('il Cecchino spara una volta sola, anche se muore quella notte', () {
      final engine = table({mob: Role.mafioso, mob2: Role.mafioso, sniper: Role.cecchino});
      final dawn = night(engine, {mob: sniper, mob2: sniper, sniper: a});
      expect(dawn.victims, [sniper, a]);
      expect(engine.snapshot().sniperSpent, isTrue);
    });

    test('Sicario e Sicario-bersaglio protetto dallo Strozzino', () {
      final engine = table({mob: Role.mafioso, hitman: Role.sicario, shark: Role.strozzino});
      final dawn = night(engine, {hitman: a, shark: a});
      expect(attackOn(dawn, a)!.outcome, AttackOutcome.healed);
    });
  });

  group('il fuoco', () {
    GameEngine pyroTable([Map<Player, Role> more = const {}]) =>
        table({mob: Role.mafioso, mob2: Role.mafioso, pyro: Role.piromane, ...more});

    test('cosparge e poi accende: bruciano tutti i cosparsi vivi', () {
      final engine = pyroTable();
      night(engine, {pyro: a});
      engine.lynch(null);
      night(engine, {pyro: b});
      engine.lynch(null);
      expect(engine.viewFor(pyro.id).doused, [a, b]);
      expect(engine.viewFor(a.id).doused, isEmpty);
      expectNoLeaks(engine);
      expectRoundTrip(engine);
      final dawn = night(engine, {pyro: pyro}, alternative: {pyro});
      expect(dawn.victims, [a, b]);
      expect(dawn.attacks.every((attack) => attack.source == AttackSource.fire), isTrue);
      expect(engine.doused, isEmpty);
    });

    test('il fuoco non lo ferma nessuno: Dottore, Strozzino, Guardaspalle e Reduce non servono', () {
      final engine = pyroTable({doc: Role.medico, shark: Role.strozzino, guard: Role.guardaspalle, vet: Role.reduce});
      for (final target in [a, b, c, vet]) {
        night(engine, {pyro: target});
        engine.lynch(null);
      }
      final dawn = night(engine, {pyro: pyro, doc: a, shark: b, guard: c}, alternative: {pyro});
      for (final burned in [a, b, c, vet]) {
        expect(attackOn(dawn, burned)!.outcome, AttackOutcome.killed, reason: burned.id);
        expect(attackOn(dawn, burned)!.source, AttackSource.fire, reason: burned.id);
      }
      expect(attackOn(dawn, guard), isNull, reason: 'il Guardaspalle non entra nel rogo');
      expect(engine.isAlive(guard), isTrue);
    });

    test('il cosparso ucciso dalla famiglia non brucia due volte', () {
      final engine = pyroTable();
      night(engine, {pyro: a});
      engine.lynch(null);
      final dawn = night(engine, {mob: a, mob2: a, pyro: pyro}, alternative: {pyro});
      expect(dawn.attacks.single.source, AttackSource.family);
    });

    test('il cosparso linciato esce dalla lista del Piromane', () {
      final engine = pyroTable();
      night(engine, {pyro: a});
      engine.lynch(a);
      expect(engine.viewFor(pyro.id).doused, isEmpty);
      expect(engine.taskFor(pyro).alternative, isNull);
    });

    test('il cosparso linciato e riportato in vita torna pulito', () {
      final engine = pyroTable({messiah: Role.messia});
      night(engine, {pyro: a});
      engine.lynch(a);
      final dawn = night(engine, {messiah: a});
      expect(dawn.resurrected, a);
      expect(engine.doused, isEmpty);
      expectRoundTrip(engine);
    });

    test('accendere senza nessuno cosparso non si può', () {
      final engine = pyroTable();
      expect(engine.taskFor(pyro).alternative, isNull);
      expect(engine.taskFor(pyro).targets, isNot(contains(pyro)));
    });
  });

  group('Messia', () {
    test('resuscita qualsiasi morto: linciato o ucciso di notte, anche della Famiglia', () {
      final engine = table({mob: Role.mafioso, mob2: Role.mafioso, messiah: Role.messia, fool: Role.fesso});
      expect(engine.taskFor(messiah).kind, NightTaskKind.decoy);
      night(engine, {mob: b, mob2: b});
      engine.lynch(a);
      expect(engine.taskFor(messiah).targets.toSet(), {a, b});
      night(engine, {});
      engine.lynch(mob2);
      expect(engine.taskFor(messiah).targets.toSet(), {a, b, mob2});
    });

    test('una volta sola: chi passa la tiene per le notti dopo, chi la usa non la rivede', () {
      final engine = table({mob: Role.mafioso, mob2: Role.mafioso, messiah: Role.messia});
      // Prima notte: nessun morto, nessuna resurrezione da offrire.
      expect(engine.taskFor(messiah).kind, NightTaskKind.decoy);
      night(engine, {});
      engine.lynch(a);
      // Seconda notte passa: la resurrezione resta.
      expect(engine.taskFor(messiah).kind, NightTaskKind.resurrect);
      night(engine, {});
      engine.lynch(null);
      // Terza notte: ancora sua, la usa.
      expect(engine.taskFor(messiah).kind, NightTaskKind.resurrect);
      expect(engine.viewFor(messiah.id).action!.kind, NightTaskKind.resurrect);
      expect(night(engine, {messiah: a}).resurrected, a);
      engine.lynch(null);
      // Da qui in poi solo la copertura, anche con dei morti in giro.
      expect(engine.taskFor(messiah).kind, NightTaskKind.decoy);
      expect(engine.viewFor(messiah.id).action!.kind, NightTaskKind.decoy);
      expectRoundTrip(engine);
    });

    test('il Messia ucciso stanotte: la resurrezione fallisce ed è spesa', () {
      final engine = table({mob: Role.mafioso, mob2: Role.mafioso, messiah: Role.messia});
      night(engine, {});
      engine.lynch(a);
      final dawn = night(engine, {mob: messiah, mob2: messiah, messiah: a});
      expect(dawn.resurrected, isNull);
      expect(engine.isAlive(a), isFalse);
      expect(engine.snapshot().resurrectionSpent, isTrue);
    });

    test('la resurrezione conta prima dei vincitori: può salvare la città dalla parità', () {
      final engine = GameEngine(
        GameSetup.fromRoles({mob: Role.mafioso, messiah: Role.messia, a: Role.cittadino, b: Role.cittadino}),
        seed: 1,
      );
      night(engine, {});
      engine.lynch(a);
      // Senza il Messia: la famiglia uccide b, restano mob e messiah, parità.
      final dawn = night(engine, {mob: b, messiah: a});
      expect(dawn.resurrected, a);
      expect(dawn.winner, isNull);
      expect(engine.alivePlayers, [mob, messiah, a]);
      // Il ruolo scoperto al linciaggio resta scoperto anche da vivo.
      expect(engine.publicView().revealed.where((known) => known.seat == a).single.knowledge.role, Role.cittadino);
      expectNoLeaks(engine);
      expectRoundTrip(engine);
    });
  });

  group('informazioni', () {
    test('il Cronista ucciso stanotte non pubblica, ma lo scoop è speso', () {
      final engine = table({mob: Role.mafioso, reporter: Role.giornalista});
      final dawn = night(engine, {mob: reporter, reporter: mob});
      expect(dawn.scoop, isNull);
      expect(engine.knowledgeOf(null, mob).team, isNull);
      expect(engine.snapshot().scoopSpent, isTrue);
    });

    test('il Cronista vivo pubblica la fazione vera, anche dei neutrali', () {
      final engine = table({mob: Role.mafioso, reporter: Role.giornalista, hitman: Role.sicario});
      final dawn = night(engine, {reporter: hitman});
      expect(dawn.scoop!.team, Team.neutral);
      expect(engine.knowledgeOf(null, hitman).team, Team.neutral);
      expectNoLeaks(engine);
    });

    test('il Sarto cuce uno che muore: nessun silenzio, l\'ago è speso', () {
      final engine = table({mob: Role.mafioso, sarto: Role.sarto});
      final dawn = night(engine, {mob: a, sarto: a}, alternative: {sarto});
      expect(dawn.silenced, isNull);
      expect(engine.silenceSpent, isTrue);
      for (final player in engine.alivePlayers) {
        expect(engine.isSilenced(player), isFalse);
      }
    });

    test('il silenziato vivo tace solo quel giorno', () {
      final engine = table({mob: Role.mafioso, sarto: Role.sarto});
      night(engine, {sarto: a}, alternative: {sarto});
      expect(engine.isSilenced(a), isTrue);
      expect(engine.viewFor(a.id).silenced, isTrue);
      expectRoundTrip(engine);
      engine.lynch(null);
      night(engine, {});
      expect(engine.isSilenced(a), isFalse);
    });

    test('il Commissario: Padrino onesto, Pregiudicato e Sicario mafia, altri neutrali onesti', () {
      final engine = table({
        mob: Role.padrino,
        mob2: Role.mafioso,
        cop: Role.detective,
        vet: Role.pregiudicato,
        hitman: Role.sicario,
        pyro: Role.piromane,
        fool: Role.fesso,
        shark: Role.strozzino,
        hunter: Role.cacciatore,
      });
      final expected = {
        mob: Team.citizens,
        mob2: Team.mafia,
        vet: Team.mafia,
        hitman: Team.mafia,
        pyro: Team.citizens,
        fool: Team.citizens,
        shark: Team.citizens,
        hunter: Team.citizens,
        a: Team.citizens,
      };
      for (final MapEntry(key: subject, value: team) in expected.entries) {
        final copy = GameEngine.fromSnapshot(engine.snapshot());
        expect(copy.submitNightChoice(cop, subject)!.team, team, reason: subject.id);
        expect(copy.knowledgeOf(cop, subject).team, team);
        expect(copy.knowledgeOf(cop, subject).role, isNull);
        expectNoLeaks(copy);
      }
    });

    test('il Becchino trova il ruolo esatto di chi è bruciato, sparato o accoltellato', () {
      final engine = table({
        mob: Role.mafioso,
        mob2: Role.mafioso,
        digger: Role.becchino,
        sniper: Role.cecchino,
        hitman: Role.sicario,
        doc: Role.medico,
      }, fillers: 5);
      night(engine, {sniper: doc, hitman: a});
      engine.lynch(null);
      expect(engine.taskFor(digger).kind, NightTaskKind.dig);
      expect(engine.taskFor(digger).targets, [doc, a]);
      final found = engine.submitNightChoice(digger, doc)!;
      expect(found.role, Role.medico);
      expect(engine.knowledgeOf(digger, doc).role, Role.medico);
      expect(engine.knowledgeOf(null, doc).role, isNull);
      expectNoLeaks(engine);
      expectRoundTrip(engine);
    });

    test('il Becchino non scava chi è già pubblico (linciato)', () {
      final engine = table({mob: Role.mafioso, digger: Role.becchino});
      night(engine, {});
      engine.lynch(a);
      expect(engine.taskFor(digger).kind, NightTaskKind.decoy);
    });

    group('il Portinaio', () {
      Map<Player, Role> roles() => {
        mob: Role.mafioso,
        sarto: Role.sarto,
        doorman: Role.portinaio,
        doc: Role.medico,
        guard: Role.guardaspalle,
        cop: Role.detective,
        sniper: Role.cecchino,
        reporter: Role.giornalista,
        shark: Role.strozzino,
        hitman: Role.sicario,
        messiah: Role.messia,
        digger: Role.becchino,
      };

      bool watch(Map<Player, Player?> moves, {Set<Player> alternative = const {}, Player? target}) {
        final engine = table(roles());
        night(engine, {doorman: target ?? a, ...moves}, alternative: alternative);
        return engine.viewFor(doorman.id).watches.single.visited;
      }

      test('vede chi passa davvero', () {
        expect(watch({}), isFalse);
        expect(watch({mob: a, sarto: a}), isTrue);
        expect(watch({doc: a}), isTrue);
        expect(watch({guard: a}), isTrue);
        expect(watch({cop: a}), isTrue);
        expect(watch({sniper: a}), isTrue);
        expect(watch({reporter: a}), isTrue);
        expect(watch({shark: a}), isTrue);
        expect(watch({hitman: a}), isTrue);
        expect(watch({sarto: a}, alternative: {sarto}), isTrue);
      });

      test('non vede i compiti di copertura', () {
        expect(watch({b: a, c: a}), isFalse);
      });

      test('un voto della famiglia finito su un\'altra porta non è una visita', () {
        // mob vota a, il Sarto vota b: spareggio a sorte, una porta sola.
        final engine = table(roles(), seed: 11);
        night(engine, {doorman: a, mob: a, sarto: b});
        final family = engine.history.last.nightVictims;
        final visited = engine.viewFor(doorman.id).watches.single.visited;
        expect(visited, family.contains(a));
        expectRoundTrip(engine);
      });

      test('lo vede solo lui', () {
        final engine = table(roles());
        night(engine, {doorman: a, doc: a});
        expect(engine.viewFor(a.id).watches, isEmpty);
        expectNoLeaks(engine);
        expectRoundTrip(engine);
      });
    });
  });

  group('Sindaco', () {
    test('rivelato, il suo voto vale due solo quel giorno', () {
      final engine = table({mob: Role.mafioso, mayor: Role.sindaco});
      night(engine, {});
      engine.revealMayor(mayor);
      expect(engine.knowledgeOf(null, mayor).role, Role.sindaco);
      engine.apply(DayVote(mayor.id, a.id));
      engine.apply(DayVote(b.id, c.id));
      expect(engine.closeDayVote().condemned, a);
      night(engine, {});
      expect(engine.mayor, isNull);
      engine.apply(DayVote(mayor.id, b.id));
      engine.apply(DayVote(c.id, d.id));
      expect(engine.closeDayVote().condemned, isNull, reason: 'parità: nessuno');
    });

    test('rivelato e poi ucciso di notte: niente voto doppio, ruolo resta pubblico', () {
      final engine = table({mob: Role.mafioso, mayor: Role.sindaco});
      night(engine, {});
      engine.revealMayor(mayor);
      engine.lynch(null);
      night(engine, {mob: mayor});
      expect(engine.mayor, isNull);
      expect(engine.knowledgeOf(null, mayor).role, Role.sindaco);
      expectRoundTrip(engine);
    });

    test('rivelato e linciato lo stesso giorno', () {
      final engine = table({mob: Role.mafioso, mayor: Role.sindaco});
      night(engine, {});
      engine.revealMayor(mayor);
      expect(engine.lynch(mayor).role, Role.sindaco);
      expect(engine.mayor, isNull);
    });
  });

  group('voti', () {
    test('parità in piazza: nessun condannato', () {
      final engine = table({mob: Role.mafioso});
      night(engine, {});
      engine.apply(DayVote(a.id, b.id));
      engine.apply(DayVote(b.id, a.id));
      expect(engine.closeDayVote().condemned, isNull);
    });

    test('parità della famiglia: con TieBreak.nobody nessun agguato', () {
      final engine = table(
        {mob: Role.mafioso, mob2: Role.mafioso},
        settings: const GameSettings(mafiaTieBreak: TieBreak.nobody),
      );
      expect(night(engine, {mob: a, mob2: b}).attacks, isEmpty);
    });

    test('parità della famiglia: col sorteggio colpisce uno dei due, ripetibile', () {
      final engine = table({mob: Role.mafioso, mob2: Role.mafioso});
      final copy = GameEngine.fromSnapshot(engine.snapshot());
      final dawn = night(engine, {mob: a, mob2: b});
      expect(dawn.victims.single, anyOf(a, b));
      expect(night(copy, {mob: a, mob2: b}).victims, dawn.victims);
    });
  });

  group('neutrali e fine partita', () {
    test('Cacciatore: la taglia muore di notte, passa con la città', () {
      final engine = table({mob: Role.mafioso, hunter: Role.cacciatore});
      final mark = engine.bountyOf(hunter)!;
      night(engine, {mob: mark});
      expect(engine.bountyLapsed(hunter), isTrue);
      engine.lynch(mob);
      expect(engine.winner, Team.citizens);
      expect(engine.hasWon(hunter), isTrue);
    });

    test('Cacciatore morto: la taglia linciata non lo fa vincere', () {
      final engine = table({mob: Role.mafioso, mob2: Role.mafioso, hunter: Role.cacciatore});
      final mark = engine.bountyOf(hunter)!;
      night(engine, {mob: hunter, mob2: hunter});
      final report = engine.lynch(mark);
      expect(report.bountyHunter, isNull);
      expect(engine.personalWins, isNot(contains(hunter)));
    });

    test('Cacciatore: la taglia scaduta resta scaduta anche se il Messia la riporta in vita', () {
      final engine = table({mob: Role.mafioso, mob2: Role.mafioso, hunter: Role.cacciatore, messiah: Role.messia});
      final mark = engine.bountyOf(hunter)!;
      night(engine, {mob: hunter, mob2: hunter});
      engine.lynch(mark);
      expect(engine.bountyLapsed(hunter), isTrue);
      expect(night(engine, {messiah: mark}).resurrected, mark);
      expect(engine.bountyLapsed(hunter), isTrue);
      expectRoundTrip(engine);
    });

    test('Cacciatore incassa: finisce la partita, e lo Strozzino vivo vince con lui', () {
      final engine = table({mob: Role.mafioso, hunter: Role.cacciatore, shark: Role.strozzino});
      final mark = engine.bountyOf(hunter)!;
      night(engine, {});
      final report = engine.lynch(mark);
      expect(report.winner, Team.neutral);
      expect(engine.phase, GamePhase.ended);
      expect(engine.personalWins, containsAll([hunter, shark]));
      expectNoLeaks(engine);
    });

    test('il Fesso linciato vince anche se il linciaggio chiude la partita', () {
      final engine = GameEngine(
        GameSetup.fromRoles({mob: Role.mafioso, fool: Role.fesso, a: Role.cittadino, b: Role.cittadino}),
        seed: 1,
      );
      night(engine, {mob: a});
      final report = engine.lynch(fool);
      expect(report.personalWin, isTrue);
      expect(report.winner, Team.mafia);
      expect(engine.hasWon(fool), isTrue);
      expect(engine.hasWon(mob), isTrue);
      expect(engine.hasWon(b), isFalse);
    });

    test('il Fesso ucciso di notte non vince', () {
      final engine = table({mob: Role.mafioso, fool: Role.fesso});
      night(engine, {mob: fool});
      expect(engine.personalWins, isEmpty);
    });

    for (final (name, ending) in [
      ('città', (GameEngine engine) => engine.lynch(mob)),
      ('mafia', (GameEngine engine) => engine.lynch(a)),
    ]) {
      test('lo Strozzino vivo vince con la $name', () {
        final engine = GameEngine(
          GameSetup.fromRoles({mob: Role.mafioso, shark: Role.strozzino, a: Role.cittadino, b: Role.cittadino}),
          seed: 1,
        );
        night(engine, {mob: b});
        ending(engine);
        expect(engine.phase, GamePhase.ended);
        expect(engine.hasWon(shark), isTrue);
      });
    }

    test('lo Strozzino morto non vince', () {
      final engine = GameEngine(
        GameSetup.fromRoles({mob: Role.mafioso, shark: Role.strozzino, a: Role.cittadino, b: Role.cittadino}),
        seed: 1,
      );
      night(engine, {mob: shark});
      engine.lynch(mob);
      expect(engine.winner, Team.citizens);
      expect(engine.hasWon(shark), isFalse);
    });

    test('Sicario in due con lo Strozzino: vincono tutti e due', () {
      final engine = GameEngine(
        GameSetup.fromRoles({mob: Role.mafioso, hitman: Role.sicario, shark: Role.strozzino, a: Role.cittadino}),
        seed: 1,
      );
      night(engine, {hitman: a});
      engine.lynch(mob);
      expect(engine.winner, Team.neutral);
      expect(engine.personalWins, containsAll([hitman, shark]));
    });

    test('Piromane in due col mafioso: vince la famiglia (parità)', () {
      final engine = GameEngine(
        GameSetup.fromRoles({mob: Role.mafioso, pyro: Role.piromane, a: Role.cittadino}),
        seed: 1,
      );
      final dawn = night(engine, {mob: a});
      expect(dawn.winner, Team.mafia);
      expect(engine.hasWon(pyro), isFalse);
    });

    test('Piromane in due con un cittadino: si va avanti finché resta l\'ultimo', () {
      final engine = GameEngine(
        GameSetup.fromRoles({mob: Role.mafioso, pyro: Role.piromane, a: Role.cittadino, b: Role.cittadino}),
        seed: 1,
      );
      night(engine, {mob: b, pyro: a});
      engine.lynch(mob);
      expect(engine.winner, isNull);
      expect(engine.phase, GamePhase.night);
      expectRoundTrip(engine);
      // La piazza in due pareggia: nessuno; poi il fiammifero.
      final dawn = night(engine, {pyro: pyro}, alternative: {pyro});
      expect(dawn.victims, [a]);
      expect(dawn.winner, Team.neutral);
      expect(engine.hasWon(pyro), isTrue);
    });

    test('Piromane in due: un pareggio in piazza non blocca la partita', () {
      final engine = GameEngine(
        GameSetup.fromRoles({pyro: Role.piromane, a: Role.cittadino, b: Role.cittadino}),
        seed: 1,
      );
      night(engine, {pyro: a});
      engine.lynch(b);
      expect(night(engine, {}).winner, isNull);
      engine.apply(DayVote(pyro.id, a.id));
      engine.apply(DayVote(a.id, pyro.id));
      expect(engine.closeDayVote().condemned, isNull);
      expect(night(engine, {pyro: pyro}, alternative: {pyro}).winner, Team.neutral);
    });

    test('il Piromane linciato: vince la città', () {
      final engine = GameEngine(
        GameSetup.fromRoles({pyro: Role.piromane, a: Role.cittadino, b: Role.cittadino}),
        seed: 1,
      );
      night(engine, {});
      expect(engine.lynch(pyro).winner, Team.citizens);
    });

    test('Piromane e Sicario ultimi due (mai nel mazzo): vince il Sicario', () {
      final engine = GameEngine(
        GameSetup.fromRoles({pyro: Role.piromane, hitman: Role.sicario, a: Role.cittadino}),
        seed: 1,
      );
      final dawn = night(engine, {hitman: a});
      expect(dawn.winner, Team.neutral);
      expect(engine.personalWins, [hitman]);
      expect(engine.hasWon(pyro), isFalse);
    });

    test('il Messia che passa non spende la resurrezione', () {
      final engine = table({mob: Role.mafioso, messiah: Role.messia});
      night(engine, {});
      engine.lynch(a);
      night(engine, {});
      engine.lynch(null);
      expect(engine.taskFor(messiah).kind, NightTaskKind.resurrect);
    });

    test('finché il Sicario è vivo la città non vince', () {
      final engine = table({mob: Role.mafioso, hitman: Role.sicario});
      night(engine, {});
      engine.lynch(mob);
      expect(engine.winner, isNull);
    });

    test('l\'ultimo mafioso ucciso dal Cecchino: la città vince all\'alba', () {
      final engine = table({mob: Role.mafioso, sniper: Role.cecchino});
      final dawn = night(engine, {mob: a, sniper: mob});
      expect(dawn.winner, Team.citizens);
      expect(engine.phase, GamePhase.ended);
    });

    test('famiglia e città muoiono insieme: tutti morti vince la città', () {
      final engine = GameEngine(
        GameSetup.fromRoles({mob: Role.mafioso, sniper: Role.cecchino}),
        seed: 1,
      );
      final dawn = night(engine, {mob: sniper, sniper: mob});
      expect(engine.alivePlayers, isEmpty);
      expect(dawn.winner, Team.citizens);
    });

    test('la vista finale scopre i ruoli, mai prima', () {
      final engine = table({mob: Role.mafioso, sniper: Role.cecchino});
      expect(engine.publicView().finalRoles, isEmpty);
      night(engine, {sniper: mob});
      expect(engine.publicView().finalRoles, isNotEmpty);
      expectNoLeaks(engine);
      expectRoundTrip(engine);
    });
  });
}
