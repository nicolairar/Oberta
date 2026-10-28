import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/rules/game_engine.dart';
import 'package:oberta/rules/game_setup.dart';
import 'package:oberta/rules/game_snapshot.dart';
import 'package:oberta/rules/intent.dart';
import 'package:oberta/rules/player.dart';
import 'package:oberta/rules/role.dart';

import 'player_view_test.dart' show leaksIn, wire;

// La Prostituta, il Carceriere e il Pacifista (docs/ruoli.md, 3.1, 3.2, 3.10).

Player _p(String id) => Player(id: id, name: id);

final mob = _p('mob');
final mob2 = _p('mob2');
final hooker = _p('hooker');
final jailer = _p('jailer');
final peace = _p('peace');
final cop = _p('cop');
final doc = _p('doc');
final guard = _p('guard');
final porter = _p('porter');
final pyro = _p('pyro');
final hitman = _p('hitman');
final mayor = _p('mayor');
final fool = _p('fool');
final a = _p('a');
final b = _p('b');
final c = _p('c');

GameEngine table(Map<Player, Role> roles, {int seed = 3}) => GameEngine(GameSetup.fromRoles(roles), seed: seed);

IntentResult act(GameEngine engine, Player actor, Player? target, {bool kill = false}) => engine.apply(
  target == null
      ? Pass(actor.id)
      : kill
      ? MafiaVote(actor.id, target.id)
      : NightAction(actor.id, target.id),
);

DawnReport endNight(GameEngine engine) {
  for (final player in engine.pendingNightPlayers) {
    engine.apply(Pass(player.id));
  }
  return engine.resolveNight();
}

void main() {
  group('Il Carceriere', () {
    Map<Player, Role> roles() => {
      mob: Role.mafioso,
      mob2: Role.mafioso,
      jailer: Role.carceriere,
      cop: Role.detective,
      doc: Role.medico,
      a: Role.cittadino,
      b: Role.cittadino,
      c: Role.cittadino,
    };

    test('la cella si chiude subito: la mossa del prigioniero salta e non ne fa altre', () {
      final engine = table(roles());
      expect(act(engine, doc, a).accepted, isTrue);
      expect(act(engine, jailer, doc).accepted, isTrue);
      expect(engine.jailedTonight, doc);
      expect(engine.nightChoices[doc]?.target, isNull, reason: 'la protezione è saltata');
      expect(engine.viewFor(doc.id).action, isNull);
      expect(act(engine, doc, b), isA<IntentRejected>());
      // La cella non si cambia.
      expect(engine.viewFor(jailer.id).action, isNull);
      expect(act(engine, jailer, a), isA<IntentRejected>());
      expect(engine.pendingNightPlayers, isNot(contains(doc)));
    });

    test('chi sa della cella: il Carceriere, il prigioniero, la Famiglia se è dei suoi; mai chi l\'ha chiusa', () {
      final engine = table(roles());
      act(engine, jailer, mob2);
      expect(engine.viewFor(jailer.id).cell, mob2);
      expect(engine.viewFor(mob2.id).cell, mob2);
      expect(engine.viewFor(mob.id).cell, mob2, reason: 'la Famiglia sa che uno dei suoi è dentro');
      for (final other in [cop, doc, a, b, c]) {
        expect(engine.viewFor(other.id).cell, isNull, reason: other.id);
      }
      // Il prigioniero non sa chi è il Carceriere.
      expect(engine.knowledgeOf(mob2, jailer).isEmpty, isTrue);
      expect(leaksIn(engine, mob2, wire(engine.viewFor(mob2.id).toJson())), isEmpty);
      // In cella niente chat della Famiglia, e il suo voto non conta.
      expect(engine.canUseFamilyChat(mob2), isFalse);
      expect(engine.canUseFamilyChat(mob), isTrue);
      expect(engine.viewFor(mob2.id).familyVotes, isEmpty);
      // Un cittadino in cella: la Famiglia non lo sa.
      final other = table(roles());
      act(other, jailer, a);
      expect(other.viewFor(mob.id).cell, isNull);
    });

    test('in cella non muore nessuno, e all\'alba non si annuncia niente', () {
      final engine = table(roles());
      act(engine, jailer, a);
      act(engine, mob, a, kill: true);
      act(engine, mob2, a, kill: true);
      final dawn = endNight(engine);
      expect(dawn.attacks, isEmpty);
      expect(engine.isAlive(a), isTrue);
    });

    test('il prigioniero unico killer: niente agguato', () {
      final engine = table({...roles(), mob2: Role.cittadino});
      act(engine, mob, b, kill: true);
      act(engine, jailer, mob);
      final dawn = endNight(engine);
      expect(dawn.attacks, isEmpty);
    });

    test('mai la stessa persona due notti di fila', () {
      final engine = table(roles());
      act(engine, jailer, a);
      endNight(engine);
      engine.lynch(null);
      expect(engine.taskFor(jailer).targets, isNot(contains(a)));
      expect(act(engine, jailer, a), isA<IntentRejected>());
      expect(act(engine, jailer, b).accepted, isTrue);
    });

    test('ferma anche il fuoco: chi è in cella non brucia e resta cosparso', () {
      final engine = table({pyro: Role.piromane, jailer: Role.carceriere, mob: Role.mafioso, a: Role.cittadino, b: Role.cittadino});
      act(engine, pyro, a);
      endNight(engine);
      engine.lynch(null);
      act(engine, jailer, a);
      engine.apply(NightAction(pyro.id, pyro.id));
      final dawn = endNight(engine);
      expect(dawn.attacks.where((attack) => attack.target == a), isEmpty);
      expect(engine.isAlive(a), isTrue);
      expect(engine.doused, contains(a));
    });

    test('il Guardaspalle sul prigioniero non muore al suo posto', () {
      final engine = table({...roles(), guard: Role.guardaspalle, c: Role.cittadino});
      act(engine, guard, a);
      act(engine, jailer, a);
      act(engine, mob, a, kill: true);
      act(engine, mob2, a, kill: true);
      endNight(engine);
      expect(engine.isAlive(guard), isTrue);
      expect(engine.isAlive(a), isTrue);
    });

    test('con chi blocca al tavolo l\'indagine risponde all\'alba, e in cella non risponde', () {
      final engine = table(roles());
      expect(engine.findingsAtDawn, isTrue);
      final result = act(engine, cop, mob);
      expect((result as IntentAccepted).finding, isNull, reason: 'niente risposta subito');
      expect(engine.nightChoiceLocked(cop), isFalse, reason: 'si può ancora cambiare');
      endNight(engine);
      expect(engine.knowledgeOf(cop, mob).team, Team.mafia);

      final jailed = table(roles());
      act(jailed, cop, mob);
      act(jailed, jailer, cop);
      endNight(jailed);
      expect(jailed.knowledgeOf(cop, mob).isEmpty, isTrue);
    });

    test('senza chi blocca, l\'indagine risponde subito come prima', () {
      final engine = table({mob: Role.mafioso, cop: Role.detective, a: Role.cittadino, b: Role.cittadino});
      expect(engine.findingsAtDawn, isFalse);
      expect((act(engine, cop, mob) as IntentAccepted).finding?.team, Team.mafia);
    });

    test('il Portinaio vede passare il Carceriere', () {
      final engine = table({...roles(), porter: Role.portinaio});
      act(engine, porter, a);
      act(engine, jailer, a);
      endNight(engine);
      expect(engine.watchesOf(porter).single.visited, isTrue);
    });

    test('se il Carceriere se ne va, il prigioniero esce e sceglie di nuovo', () {
      final engine = table(roles());
      act(engine, jailer, doc);
      engine.leaveTown(jailer);
      expect(engine.jailedTonight, isNull);
      expect(engine.pendingNightPlayers, contains(doc));
      expect(act(engine, doc, a).accepted, isTrue);
    });
  });

  group('La Prostituta', () {
    Map<Player, Role> roles() => {
      mob: Role.mafioso,
      hooker: Role.prostituta,
      cop: Role.detective,
      doc: Role.medico,
      jailer: Role.carceriere,
      a: Role.cittadino,
      b: Role.cittadino,
      c: Role.cittadino,
    };

    test('non vota l\'agguato finché c\'è un altro della Famiglia che lo vota', () {
      final engine = table(roles());
      expect(Role.prostituta.isKiller, isFalse);
      expect(engine.taskFor(hooker).kind, NightTaskKind.block);
      expect(act(engine, hooker, a, kill: true), isA<IntentRejected>());
    });

    test('blocca la mossa: il Dottore bloccato non salva, e all\'alba lo sa solo lui', () {
      final engine = table(roles());
      act(engine, doc, a);
      act(engine, hooker, doc);
      act(engine, mob, a, kill: true);
      final dawn = endNight(engine);
      expect(dawn.victims, [a]);
      expect(engine.viewFor(doc.id).busy, isTrue);
      for (final other in [mob, hooker, cop, b, c]) {
        expect(engine.viewFor(other.id).busy, isFalse, reason: other.id);
      }
      expect(engine.publicView().toJson().toString(), isNot(contains('busy')));
    });

    test('blocca il Commissario: niente risposta all\'alba', () {
      final engine = table(roles());
      act(engine, cop, mob);
      act(engine, hooker, cop);
      endNight(engine);
      expect(engine.knowledgeOf(cop, mob).isEmpty, isTrue);
    });

    test('mai la stessa persona due notti di fila', () {
      final engine = table(roles());
      act(engine, hooker, cop);
      endNight(engine);
      engine.lynch(null);
      expect(engine.taskFor(hooker).targets, isNot(contains(cop)));
    });

    test('bloccare il Carceriere non apre la cella', () {
      final engine = table(roles());
      act(engine, jailer, a);
      act(engine, hooker, jailer);
      act(engine, mob, a, kill: true);
      endNight(engine);
      expect(engine.isAlive(a), isTrue);
    });

    test('in cella non blocca nessuno', () {
      final engine = table(roles());
      act(engine, hooker, doc);
      act(engine, jailer, hooker);
      act(engine, doc, a);
      act(engine, mob, a, kill: true);
      endNight(engine);
      expect(engine.isAlive(a), isTrue, reason: 'il Dottore ha salvato');
      expect(engine.viewFor(doc.id).busy, isFalse);
    });

    test('rimasta sola nella Famiglia vota l\'agguato, e può ancora passare la notte fuori', () {
      final engine = table(roles());
      endNight(engine);
      engine.lynch(mob);
      final task = engine.taskFor(hooker);
      expect(task.kind, NightTaskKind.kill);
      expect(task.alternative, NightTaskKind.block);
      expect(act(engine, hooker, a, kill: true).accepted, isTrue);
      final dawn = endNight(engine);
      expect(dawn.victims, [a]);
    });

    test('una mossa bloccata si spende lo stesso: lo scoop del Cronista', () {
      final engine = table({...roles(), c: Role.giornalista});
      act(engine, c, mob);
      act(engine, hooker, c);
      final dawn = endNight(engine);
      expect(dawn.scoop, isNull);
      engine.lynch(null);
      expect(engine.taskFor(c).kind, NightTaskKind.decoy);
    });
  });

  group('Il Pacifista', () {
    Map<Player, Role> roles() => {
      mob: Role.padrino,
      mob2: Role.mafioso,
      peace: Role.pacifista,
      mayor: Role.sindaco,
      fool: Role.fesso,
      a: Role.cittadino,
      b: Role.cittadino,
      c: Role.cittadino,
    };

    test('di notte non si chiede la tregua, e non la chiede chi non è il Pacifista', () {
      final engine = table(roles());
      expect(engine.apply(Pacify(peace.id, mob.id)), isA<IntentRejected>());
      endNight(engine);
      expect(engine.apply(Pacify(a.id, mob.id)), isA<IntentRejected>());
      expect(engine.apply(Pacify(peace.id, peace.id)), isA<IntentRejected>());
    });

    test('la tregua: tutti vedono il ruolo esatto (anche il Padrino) e il Pacifista, e oggi non si vota', () {
      final engine = table(roles());
      endNight(engine);
      engine.apply(DayVote(a.id, b.id));
      expect(engine.viewFor(peace.id).action!.canPacify, isTrue);
      expect(engine.viewFor(a.id).action!.canPacify, isFalse);
      expect(engine.apply(Pacify(peace.id, mob.id)).accepted, isTrue);
      expect(engine.truceToday, isTrue);
      expect(engine.knowledgeOf(null, mob).role, Role.padrino);
      expect(engine.knowledgeOf(null, mob).team, Team.mafia);
      expect(engine.knowledgeOf(null, peace).role, Role.pacifista);
      final board = engine.publicView();
      expect(board.pacifist, peace);
      expect(board.pacified, mob);
      expect(board.dayVotes, isEmpty, reason: 'i voti di oggi sono cancellati');
      expect(engine.viewFor(a.id).action, isNull);
      expect(engine.apply(DayVote(b.id, a.id)), isA<IntentRejected>());
      expect(engine.apply(RevealMayor(mayor.id)), isA<IntentRejected>());
      final verdict = engine.closeDayVote();
      expect(verdict.truce, isTrue);
      expect(verdict.condemned, isNull);
      expect(engine.isAlive(mob), isTrue);
      expect(engine.phase, GamePhase.night);
    });

    test('una volta per partita', () {
      final engine = table(roles());
      endNight(engine);
      engine.apply(Pacify(peace.id, a.id));
      engine.closeDayVote();
      endNight(engine);
      expect(engine.viewFor(peace.id).action!.canPacify, isFalse);
      expect(engine.apply(Pacify(peace.id, mob.id)), isA<IntentRejected>());
      expect(engine.truceToday, isFalse);
    });

    test('il Fesso svelato quel giorno non si può linciare', () {
      final engine = table(roles());
      endNight(engine);
      engine.apply(Pacify(peace.id, fool.id));
      expect(engine.knowledgeOf(null, fool).role, Role.fesso);
      expect(() => engine.lynch(fool), throwsStateError);
      engine.closeDayVote();
      expect(engine.isAlive(fool), isTrue);
      expect(engine.personalWins, isEmpty);
    });
  });

  test('il Sicario vince solo se resta l\'ultimo vivo', () {
    final engine = table({hitman: Role.sicario, a: Role.cittadino, b: Role.cittadino, c: Role.cittadino});
    act(engine, hitman, a);
    endNight(engine);
    engine.lynch(b);
    expect(engine.winner, isNull, reason: 'in due la partita va avanti');
    act(engine, hitman, c);
    expect(endNight(engine).winner, Team.neutral);
    expect(engine.personalWins, [hitman]);
  });

  test('cella, blocco, tregua: la fotografia riprende la partita identica', () {
    final engine = table({
      mob: Role.mafioso,
      hooker: Role.prostituta,
      jailer: Role.carceriere,
      peace: Role.pacifista,
      doc: Role.medico,
      a: Role.cittadino,
      b: Role.cittadino,
      c: Role.cittadino,
    });
    act(engine, jailer, a);
    act(engine, hooker, doc);
    endNight(engine);
    engine.apply(Pacify(peace.id, mob.id));
    final json = wire(engine.snapshot().toJson());
    final again = GameEngine.fromSnapshot(GameSnapshot.fromJson(json));
    expect(jsonEncode(again.snapshot().toJson()), jsonEncode(engine.snapshot().toJson()));
    expect(again.truceToday, isTrue);
    expect(again.isBusy(again.setup.players.firstWhere((p) => p.id == doc.id)), isTrue);
    again.closeDayVote();
    expect(again.taskFor(again.setup.players.firstWhere((p) => p.id == jailer.id)).targets.map((p) => p.id), isNot(contains(a.id)));
    final replayed = GameEngine.replay(engine.setup, seed: engine.seed!, log: engine.log);
    expect(jsonEncode(replayed.snapshot().toJson()), jsonEncode(engine.snapshot().toJson()));
  });
}
