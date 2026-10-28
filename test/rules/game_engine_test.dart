import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/rules/game_engine.dart';
import 'package:oberta/rules/game_settings.dart';
import 'package:oberta/rules/game_setup.dart';
import 'package:oberta/rules/game_snapshot.dart';
import 'package:oberta/rules/intent.dart';
import 'package:oberta/rules/player_view.dart';
import 'package:oberta/rules/player.dart';
import 'package:oberta/rules/role.dart';
import 'package:oberta/rules/rules_json.dart';

const boss = Player(id: 'boss', name: 'Boss');
const picciotto = Player(id: 'picciotto', name: 'Picciotto');
const detective = Player(id: 'detective', name: 'Commissario');
const doctor = Player(id: 'doctor', name: 'Dottore');
const sniper = Player(id: 'sniper', name: 'Cecchino');
const reporter = Player(id: 'reporter', name: 'Cronista');
const anna = Player(id: 'anna', name: 'Anna');
const bruno = Player(id: 'bruno', name: 'Bruno');
const don = Player(id: 'don', name: 'Padrino');
const tailor = Player(id: 'tailor', name: 'Sarto');
const digger = Player(id: 'digger', name: 'Becchino');
const guard = Player(id: 'guard', name: 'Guardaspalle');
const veteran = Player(id: 'veteran', name: 'Reduce');
const convict = Player(id: 'convict', name: 'Pregiudicato');

/// Un tavolo da otto con tutti i ruoli, in ordine di posto.
GameEngine fullTable({TieBreak tieBreak = TieBreak.random, int seed = 1}) {
  return GameEngine(
    GameSetup.fromRoles({
      boss: Role.mafioso,
      picciotto: Role.mafioso,
      detective: Role.detective,
      doctor: Role.medico,
      sniper: Role.cecchino,
      reporter: Role.giornalista,
      anna: Role.cittadino,
      bruno: Role.cittadino,
    }),
    settings: GameSettings(mafiaTieBreak: tieBreak),
    random: Random(seed),
  );
}

/// Un tavolo da tredici con tutti e dodici i ruoli, in ordine di posto.
GameEngine grandTable({TieBreak tieBreak = TieBreak.random, int seed = 1}) {
  return GameEngine(
    GameSetup.fromRoles({
      don: Role.padrino,
      tailor: Role.sarto,
      picciotto: Role.mafioso,
      detective: Role.detective,
      doctor: Role.medico,
      sniper: Role.cecchino,
      reporter: Role.giornalista,
      digger: Role.becchino,
      guard: Role.guardaspalle,
      veteran: Role.reduce,
      convict: Role.pregiudicato,
      anna: Role.cittadino,
      bruno: Role.cittadino,
    }),
    settings: GameSettings(mafiaTieBreak: tieBreak),
    random: Random(seed),
  );
}

GameEngine smallTable() {
  return GameEngine(GameSetup.fromRoles({
    boss: Role.mafioso,
    detective: Role.detective,
    anna: Role.cittadino,
    bruno: Role.cittadino,
  }));
}

/// Gioca una notte: chi non compare in [choices] passa.
/// [sew]: chi fa il compito alternativo (il Sarto che cuce invece di votare).
DawnReport playNight(GameEngine engine, [Map<Player, Player?> choices = const {}, Set<Player> sew = const {}]) {
  for (final player in engine.alivePlayers) {
    engine.submitNightChoice(player, choices[player], alternative: sew.contains(player));
  }
  return engine.resolveNight();
}

void main() {
  group('notte', () {
    test('la vittima della mafia muore e il suo ruolo resta segreto', () {
      final engine = fullTable();
      final report = playNight(engine, {boss: anna, picciotto: anna});

      expect(report.victims, [anna]);
      expect(engine.isAlive(anna), isFalse);
      expect(engine.phase, GamePhase.day);
      expect(engine.knowledgeOf(null, anna).isEmpty, isTrue);
      expect(engine.knowledgeOf(bruno, anna).isEmpty, isTrue);
    });

    test('se tutti passano non muore nessuno', () {
      final engine = fullTable();
      expect(playNight(engine).victims, isEmpty);
      expect(engine.alivePlayers, hasLength(8));
    });

    test('il Dottore salva chi protegge', () {
      final engine = fullTable();
      final report = playNight(engine, {boss: anna, picciotto: anna, doctor: anna});
      expect(report.victims, isEmpty);
      expect(engine.isAlive(anna), isTrue);
    });

    test('il Dottore può proteggere se stesso', () {
      final engine = fullTable();
      final report = playNight(engine, {boss: doctor, picciotto: doctor, doctor: doctor});
      expect(report.victims, isEmpty);
    });

    test('il Dottore non può proteggere la stessa persona due notti di fila', () {
      final engine = fullTable();
      playNight(engine, {doctor: anna});
      engine.lynch(null);

      expect(engine.taskFor(doctor).targets, isNot(contains(anna)));
      expect(() => engine.submitNightChoice(doctor, anna), throwsArgumentError);

      playNight(engine, {doctor: bruno});
      engine.lynch(null);
      expect(engine.taskFor(doctor).targets, contains(anna));
    });

    test('la famiglia può colpire anche uno dei suoi, ma nessuno sé stesso', () {
      final engine = fullTable();
      expect(engine.taskFor(boss).targets, contains(picciotto));
      expect(engine.taskFor(boss).targets, isNot(contains(boss)));
      expect(() => engine.submitNightChoice(boss, boss), throwsArgumentError);

      final report = playNight(engine, {boss: picciotto});
      expect(report.victims, [picciotto]);
      expect(engine.isAlive(picciotto), isFalse);
    });

    test('ogni agguato finisce nel rapporto così com\'è andato', () {
      final engine = fullTable();
      final report = playNight(engine, {boss: anna, picciotto: anna, doctor: anna, sniper: bruno});

      expect(report.victims, [bruno]);
      expect(report.attacks.map((attack) => attack.target), [anna, bruno]);
      final saved = report.attacks.first;
      expect(saved.source, AttackSource.family);
      expect(saved.outcome, AttackOutcome.healed);
      expect(saved.isFatal, isFalse);
      final shot = report.attacks.last;
      expect(shot.source, AttackSource.sniper);
      expect(shot.isFatal, isTrue);
    });

    test('chi finisce nel mirino di tutti e due conta una volta, per la famiglia', () {
      final engine = fullTable();
      final report = playNight(engine, {boss: anna, picciotto: anna, sniper: anna});
      expect(report.attacks, hasLength(1));
      expect(report.attacks.single.source, AttackSource.family);
      expect(report.victims, [anna]);
    });

    test('una notte senza agguati non lascia niente da mettere in scena', () {
      expect(playNight(fullTable()).attacks, isEmpty);
    });

    test('chi muore stanotte ha fatto in tempo ad agire', () {
      final engine = fullTable();
      final report = playNight(engine, {boss: doctor, picciotto: doctor, doctor: anna, sniper: anna});
      expect(report.victims, [doctor]);
      expect(engine.isAlive(anna), isTrue, reason: 'la protezione vale anche se il Dottore muore');
    });

    test('ognuno sceglie una volta sola e solo se è vivo', () {
      final engine = fullTable();
      engine.submitNightChoice(anna, bruno);
      expect(() => engine.submitNightChoice(anna, boss), throwsStateError);

      for (final player in engine.pendingNightPlayers) {
        engine.submitNightChoice(player, player == boss || player == picciotto ? bruno : null);
      }
      engine.resolveNight();
      engine.lynch(null);
      expect(() => engine.submitNightChoice(bruno, anna), throwsStateError);
    });

    test('la notte non si chiude finché manca qualcuno', () {
      final engine = fullTable();
      engine.submitNightChoice(boss, anna);
      expect(engine.nightComplete, isFalse);
      expect(engine.resolveNight, throwsStateError);
    });
  });

  group('voto della mafia', () {
    test('vince la maggioranza', () {
      final engine = GameEngine(GameSetup.fromRoles({
        boss: Role.mafioso,
        picciotto: Role.mafioso,
        sniper: Role.mafioso,
        anna: Role.cittadino,
        bruno: Role.cittadino,
        detective: Role.cittadino,
        doctor: Role.cittadino,
        reporter: Role.cittadino,
      }));
      final report = playNight(engine, {boss: anna, picciotto: bruno, sniper: bruno});
      expect(report.victims, [bruno]);
    });

    test('chi si astiene non conta', () {
      final engine = fullTable();
      expect(playNight(engine, {boss: null, picciotto: anna}).victims, [anna]);
    });

    test('parità con "nessuno muore"', () {
      final engine = fullTable(tieBreak: TieBreak.nobody);
      expect(playNight(engine, {boss: anna, picciotto: bruno}).victims, isEmpty);
    });

    test('parità con sorteggio: muore uno dei due votati', () {
      final victims = <Player>{};
      for (var seed = 0; seed < 30; seed++) {
        final report = playNight(fullTable(seed: seed), {boss: anna, picciotto: bruno});
        expect(report.victims, hasLength(1));
        victims.add(report.victims.single);
      }
      expect(victims, {anna, bruno});
    });

  });

  group('ruoli speciali', () {
    test('il Commissario scopre la fazione, e la scopre solo lui', () {
      final engine = fullTable();
      final finding = engine.submitNightChoice(detective, boss)!;
      expect(finding.subject, boss);
      expect(finding.team, Team.mafia);

      expect(engine.knowledgeOf(detective, boss).team, Team.mafia);
      expect(engine.knowledgeOf(detective, boss).role, isNull, reason: 'sa la fazione, non il ruolo');
      expect(engine.knowledgeOf(anna, boss).isEmpty, isTrue);
      expect(engine.knowledgeOf(null, boss).isEmpty, isTrue);
    });

    test('indagare su un onesto lo scagiona', () {
      final engine = fullTable();
      expect(engine.submitNightChoice(detective, doctor)!.team, Team.citizens);
    });

    test('le altre mosse non danno nessuna risposta', () {
      final engine = fullTable();
      expect(engine.submitNightChoice(boss, anna), isNull);
      expect(engine.submitNightChoice(doctor, anna), isNull);
      expect(engine.submitNightChoice(anna, bruno), isNull);
    });

    test('il Cecchino ha un colpo solo', () {
      final engine = fullTable();
      expect(engine.taskFor(sniper).kind, NightTaskKind.snipe);
      expect(playNight(engine, {sniper: picciotto}).victims, [picciotto]);
      engine.lynch(null);

      expect(engine.taskFor(sniper).kind, NightTaskKind.decoy);
      expect(playNight(engine, {sniper: boss}).victims, isEmpty);
    });

    test('se il Cecchino passa, il colpo gli resta', () {
      final engine = fullTable();
      playNight(engine);
      engine.lynch(null);
      expect(engine.taskFor(sniper).kind, NightTaskKind.snipe);
    });

    test('il Dottore ferma anche il Cecchino', () {
      final engine = fullTable();
      expect(playNight(engine, {sniper: anna, doctor: anna}).victims, isEmpty);
    });

    test('mafia e Cecchino possono fare due morti nella stessa notte', () {
      final engine = fullTable();
      final report = playNight(engine, {boss: anna, picciotto: anna, sniper: bruno});
      expect(report.victims, [anna, bruno]);
    });

    test('lo scoop del Cronista diventa pubblico all\'alba', () {
      final engine = fullTable();
      final report = playNight(engine, {reporter: boss});
      expect(report.scoop!.subject, boss);
      expect(report.scoop!.team, Team.mafia);
      expect(engine.knowledgeOf(null, boss).team, Team.mafia);
      expect(engine.knowledgeOf(anna, boss).role, isNull);

      engine.lynch(null);
      expect(engine.taskFor(reporter).kind, NightTaskKind.decoy);
    });

    test('se il Cronista muore quella notte, lo scoop non esce', () {
      final engine = fullTable();
      final report = playNight(engine, {reporter: boss, boss: reporter, picciotto: reporter});
      expect(report.victims, [reporter]);
      expect(report.scoop, isNull);
      expect(engine.knowledgeOf(null, boss).isEmpty, isTrue);
    });
  });

  group('il Padrino', () {
    test('vota l\'agguato come un Picciotto', () {
      final engine = grandTable();
      expect(engine.taskFor(don).kind, NightTaskKind.kill);
      expect(engine.taskFor(don).targets, isNot(contains(don)));
      expect(playNight(engine, {don: anna, picciotto: anna}).victims, [anna]);
    });

    test('al Commissario risulta innocente', () {
      final engine = grandTable();
      final finding = engine.submitNightChoice(detective, don)!;
      expect(finding.team, Team.citizens);
      expect(finding.role, isNull);
      expect(engine.knowledgeOf(detective, don).team, Team.citizens);
      expect(engine.knowledgeOf(detective, don).role, isNull);
    });

    test('il giornale invece scrive la verità', () {
      final engine = grandTable();
      final report = playNight(engine, {detective: don, reporter: don});
      expect(report.scoop!.team, Team.mafia);
      expect(engine.knowledgeOf(null, don).team, Team.mafia);
      expect(engine.knowledgeOf(detective, don).team, Team.mafia,
          reason: 'lo scoop smentisce l\'indagine, anche per chi l\'ha fatta');
    });

    test('un\'indagine fatta dopo lo scoop non cancella quello che è pubblico', () {
      final engine = grandTable();
      playNight(engine, {reporter: don});
      engine.lynch(null);

      expect(engine.submitNightChoice(detective, don)!.team, Team.citizens,
          reason: 'le carte del Padrino restano in regola');
      expect(engine.knowledgeOf(detective, don).team, Team.mafia);
    });

    test('il patibolo lo smaschera per tutti', () {
      final engine = grandTable();
      playNight(engine, {detective: don});
      final report = engine.lynch(don);
      expect(report.role, Role.padrino);
      expect(engine.knowledgeOf(detective, don).role, Role.padrino);
      expect(engine.knowledgeOf(detective, don).team, Team.mafia);
    });

    test('la famiglia lo riconosce', () {
      final engine = grandTable();
      expect(engine.knowledgeOf(picciotto, don).role, Role.padrino);
      expect(engine.knowledgeOf(tailor, don).role, Role.padrino);
      expect(engine.knowledgeOf(don, tailor).role, Role.sarto);
      expect(engine.knowledgeOf(anna, don).isEmpty, isTrue);
    });

    test('nessun voto vale doppio: il Padrino conta come tutti', () {
      final victims = <Player>{};
      for (var seed = 0; seed < 30; seed++) {
        final engine = GameEngine(
          GameSetup.fromRoles({
            picciotto: Role.mafioso,
            don: Role.padrino,
            anna: Role.cittadino,
            bruno: Role.cittadino,
            detective: Role.detective,
            doctor: Role.medico,
          }),
          random: Random(seed),
        );
        final report = playNight(engine, {picciotto: anna, don: bruno});
        expect(report.victims, hasLength(1));
        victims.add(report.victims.single);
      }
      expect(victims, {anna, bruno}, reason: 'pari: si sorteggia, il Padrino non decide');
    });
  });

  group('il Sarto', () {
    test('vota l\'agguato come un Picciotto, e una volta può cucire invece', () {
      final engine = grandTable();
      final task = engine.taskFor(tailor);
      expect(task.kind, NightTaskKind.kill);
      expect(task.alternative, NightTaskKind.silence);
      expect(task.targets, isNot(contains(tailor)));

      final report = playNight(engine, {tailor: bruno}, {tailor});
      expect(report.silenced, bruno);
      expect(report.victims, isEmpty);
      expect(engine.isAlive(bruno), isTrue, reason: 'chi tace resta in gioco, e si può votare');
      expect(engine.silenceSpent, isTrue);
      expect(engine.lynch(bruno).condemned, bruno);
    });

    test('il silenzio è uno per partita', () {
      final engine = grandTable();
      playNight(engine, {tailor: bruno}, {tailor});
      engine.lynch(null);
      expect(engine.taskFor(tailor).alternative, isNull);
      expect(() => engine.submitNightChoice(tailor, anna, alternative: true), throwsStateError);
      expect(engine.apply(NightAction(tailor.id, anna.id)), isA<IntentRejected>());
    });

    test('il silenzio resta speso anche dopo una fotografia', () {
      final engine = GameEngine(grandTable().setup, seed: 4);
      playNight(engine, {tailor: bruno}, {tailor});
      final copy = GameEngine.fromSnapshot(GameSnapshot.fromJson(engine.snapshot().toJson()));
      expect(copy.silenceSpent, isTrue);
    });

    test('il suo voto conta nell\'agguato come quello di tutti', () {
      final engine = grandTable(tieBreak: TieBreak.nobody);
      expect(playNight(engine, {don: anna, picciotto: bruno, tailor: bruno}).victims, [bruno]);
    });

    test('chi cuce non vota: l\'agguato lo decidono gli altri', () {
      final engine = grandTable();
      final report = playNight(engine, {don: anna, picciotto: anna, tailor: bruno}, {tailor});
      expect(report.victims, [anna]);
      expect(report.silenced, bruno);
    });

    test('via intenzioni: MafiaVote vota, NightAction cuce', () {
      final engine = grandTable();
      expect(engine.viewFor(tailor.id).action!.alternative, NightTaskKind.silence);
      expect(engine.apply(NightAction(tailor.id, bruno.id)).accepted, isTrue);
      for (final player in engine.pendingNightPlayers) {
        engine.apply(Pass(player.id));
      }
      expect(engine.resolveNight().silenced, bruno);
      final replay = GameEngine.replay(engine.setup, seed: 0, log: engine.log);
      expect(replay.silenceSpent, isTrue);
    });

    test('il silenziato non scrive in piazza, ma vota: lo dice la sua vista', () {
      final engine = grandTable();
      playNight(engine, {tailor: bruno}, {tailor});
      final view = engine.viewFor(bruno.id);
      expect(view.silenced, isTrue);
      expect(view.action!.type, ActionType.dayVote, reason: 'vota come tutti');
      expect(engine.viewFor(anna.id).silenced, isFalse);
      expect(PlayerView.fromJson(view.toJson()).silenced, isTrue);
      engine.lynch(null);
      expect(engine.viewFor(bruno.id).silenced, isFalse, reason: 'il silenzio dura un giorno');
    });

    test('se chi doveva tacere muore, non si annuncia niente', () {
      final engine = grandTable();
      final report = playNight(engine, {don: bruno, picciotto: bruno, tailor: bruno}, {tailor});
      expect(report.victims, [bruno]);
      expect(report.silenced, isNull);
    });

    test('chi doveva tacere e si salva, tace lo stesso', () {
      final engine = grandTable();
      final report = playNight(engine, {don: bruno, picciotto: bruno, tailor: bruno, doctor: bruno}, {tailor});
      expect(report.victims, isEmpty);
      expect(report.silenced, bruno);
    });

    test('il silenzio vale anche se il Sarto non vede l\'alba', () {
      final engine = grandTable();
      final report = playNight(engine, {tailor: bruno, sniper: tailor}, {tailor});
      expect(report.victims, [tailor]);
      expect(report.silenced, bruno);
    });

    test('può cucire la bocca anche a uno dei suoi', () {
      final engine = grandTable();
      expect(playNight(engine, {tailor: don}, {tailor}).silenced, don);
    });

    test('rimasto l\'ultimo a poter uccidere, sceglie ogni notte tra uccidere e cucire', () {
      final engine = grandTable();
      playNight(engine);
      engine.lynch(don);
      playNight(engine);
      engine.lynch(picciotto);

      final task = engine.taskFor(tailor);
      expect(task.kind, NightTaskKind.kill);
      expect(task.alternative, NightTaskKind.silence);
      expect(playNight(engine, {tailor: anna}).victims, [anna]);
    });

    test('da solo fin dall\'inizio, uccide (o cuce, una volta)', () {
      final engine = GameEngine(GameSetup.fromRoles({
        tailor: Role.sarto,
        anna: Role.cittadino,
        bruno: Role.cittadino,
        detective: Role.detective,
      }));
      expect(engine.taskFor(tailor).kind, NightTaskKind.kill);
      expect(playNight(engine, {tailor: anna}).victims, [anna]);
    });
  });

  test('i tempi di base: notte 30 s, discussione 60 s, voto 30 s; viaggiano nel JSON', () {
    const settings = GameSettings();
    expect(settings.night, const Duration(seconds: 30));
    expect(settings.discussion, const Duration(minutes: 1));
    expect(settings.vote, const Duration(seconds: 30));
    const custom = GameSettings(night: Duration(seconds: 45), discussion: Duration(minutes: 2), vote: Duration(seconds: 20));
    final back = settingsFromJson(settingsToJson(custom));
    expect([back.night, back.discussion, back.vote], [custom.night, custom.discussion, custom.vote]);
    // Una vecchia fotografia: solo la discussione, e lo spareggio "boss" tolto.
    final old = settingsFromJson({'mafiaTieBreak': 'boss', 'discussionMs': 180000});
    expect(old.mafiaTieBreak, TieBreak.random);
    expect(old.night, GameSettings.defaultNight);
  });

  group('il Compare', () {
    GameEngine table() => GameEngine(GameSetup.fromRoles({
          picciotto: Role.mafioso,
          boss: Role.compare,
          anna: Role.cittadino,
          bruno: Role.cittadino,
          detective: Role.detective,
          doctor: Role.medico,
          sniper: Role.cittadino,
        }), seed: 1);

    test('di notte vota l\'agguato con la famiglia, come dice la sua carta', () {
      final engine = table();
      expect(engine.taskFor(boss).kind, NightTaskKind.kill);
      final view = engine.viewFor(boss.id);
      expect(view.action!.type, ActionType.mafiaVote);
      expect(view.action!.kind, NightTaskKind.kill);
      expect(engine.apply(MafiaVote(boss.id, anna.id)), isNot(isA<IntentRejected>()));
      // Vede le mani della famiglia, e la famiglia vede la sua.
      expect(engine.viewFor(boss.id).familyVotes, [(voter: boss, target: anna)]);
      expect(engine.viewFor(picciotto.id).familyVotes, [(voter: boss, target: anna)]);
      expect(engine.viewFor(anna.id).familyVotes, isEmpty);
    });

    test('vota ogni notte, dalla prima all\'ultima, anche rimasto solo', () {
      final engine = table();
      expect(playNight(engine, {boss: anna, picciotto: anna}).victims, [anna]);
      engine.lynch(null);
      // Seconda notte: ancora un voto vero, non la domanda di copertura.
      expect(engine.taskFor(boss).kind, NightTaskKind.kill);
      expect(engine.viewFor(boss.id).action!.type, ActionType.mafiaVote);
      expect(playNight(engine, {boss: bruno, picciotto: bruno}).victims, [bruno]);
      engine.lynch(picciotto);
      // Morto il Picciotto, il Compare uccide da solo.
      expect(engine.taskFor(boss).kind, NightTaskKind.kill);
      expect(playNight(engine, {boss: doctor}).victims, [doctor]);
      expect(PlayerView.fromJson(engine.viewFor(boss.id).toJson()).familyChat, isTrue);
    });

    test('finché è vivo la famiglia ha la sua chat anche di giorno', () {
      final engine = table();
      expect(engine.viewFor(picciotto.id).familyChat, isTrue, reason: 'di notte, sempre');
      playNight(engine);
      expect(engine.familyDayChat, isTrue);
      expect(engine.viewFor(picciotto.id).familyChat, isTrue);
      expect(engine.viewFor(boss.id).familyChat, isTrue);
      expect(engine.viewFor(anna.id).familyChat, isFalse, reason: 'solo la famiglia');
      expect(PlayerView.fromJson(engine.viewFor(boss.id).toJson()).familyChat, isTrue);

      engine.lynch(boss);
      playNight(engine);
      expect(engine.familyDayChat, isFalse);
      expect(engine.viewFor(picciotto.id).familyChat, isFalse, reason: 'morto il Compare, di giorno niente');
    });

    test('senza Compare la famiglia di giorno tace', () {
      final engine = fullTable();
      playNight(engine);
      expect(engine.viewFor(boss.id).familyChat, isFalse);
    });
  });

  group('il Becchino', () {
    test('senza morti da riesumare ha un compito di copertura', () {
      final engine = grandTable();
      final task = engine.taskFor(digger);
      expect(task.kind, NightTaskKind.decoy);
      expect(task.targets, isNot(contains(digger)));
      expect(engine.submitNightChoice(digger, anna), isNull);
      expect(engine.suspicion, {anna: 1});
    });

    test('scava nella fossa di chi è morto di notte e scopre chi era', () {
      final engine = grandTable();
      playNight(engine, {don: doctor, picciotto: doctor});
      engine.lynch(null);

      final task = engine.taskFor(digger);
      expect(task.kind, NightTaskKind.dig);
      expect(task.targets, [doctor]);

      final finding = engine.submitNightChoice(digger, doctor)!;
      expect(finding.subject, doctor);
      expect(finding.role, Role.medico);
      expect(finding.team, Team.citizens);
      expect(engine.knowledgeOf(digger, doctor).role, Role.medico);
      expect(engine.knowledgeOf(anna, doctor).isEmpty, isTrue, reason: 'lo sa solo chi ha scavato');
      expect(engine.knowledgeOf(null, doctor).isEmpty, isTrue);
    });

    test('i vivi non si riesumano', () {
      final engine = grandTable();
      playNight(engine, {don: doctor, picciotto: doctor});
      engine.lynch(null);
      expect(() => engine.submitNightChoice(digger, anna), throwsArgumentError);
    });

    test('chi è finito sul patibolo non ha segreti: non c\'è niente da scavare', () {
      final engine = grandTable();
      playNight(engine);
      engine.lynch(anna);
      expect(engine.taskFor(digger).kind, NightTaskKind.decoy);
    });

    test('una fossa si scava una volta sola', () {
      final engine = grandTable();
      playNight(engine, {don: doctor, picciotto: doctor});
      engine.lynch(null);
      playNight(engine, {digger: doctor, don: anna, picciotto: anna});
      engine.lynch(null);

      expect(engine.taskFor(digger).targets, [anna]);
      playNight(engine, {digger: anna});
      engine.lynch(null);
      expect(engine.taskFor(digger).kind, NightTaskKind.decoy, reason: 'le fosse sono finite');
      expect(engine.knowledgeOf(digger, doctor).role, Role.medico);
      expect(engine.knowledgeOf(digger, anna).role, Role.cittadino);
    });

    test('la fossa dice sempre la verità, anche su chi inganna il Commissario', () {
      final engine = grandTable();
      playNight(engine, {sniper: convict});
      engine.lynch(null);
      final clean = engine.submitNightChoice(digger, convict)!;
      expect(clean.role, Role.pregiudicato);
      expect(clean.team, Team.citizens);

      final other = grandTable();
      playNight(other, {sniper: don});
      other.lynch(null);
      final dirty = other.submitNightChoice(digger, don)!;
      expect(dirty.role, Role.padrino);
      expect(dirty.team, Team.mafia);
    });

    test('se muore mentre scava, quello che ha scoperto non lo sa nessun altro', () {
      final engine = grandTable();
      playNight(engine, {don: doctor, picciotto: doctor});
      engine.lynch(null);
      final report = playNight(engine, {digger: doctor, don: digger, picciotto: digger});
      expect(report.victims, [digger]);
      expect(engine.knowledgeOf(null, doctor).isEmpty, isTrue);
    });
  });

  group('il Guardaspalle', () {
    test('muore al posto di chi scorta, e nessuno sa chi era il bersaglio', () {
      final engine = grandTable();
      expect(engine.taskFor(guard).kind, NightTaskKind.guard);

      final report = playNight(engine, {don: anna, picciotto: anna, guard: anna});
      expect(report.victims, [guard]);
      expect(report.attacks, hasLength(1), reason: 'in scena va un agguato solo, contro chi è caduto');
      expect(report.attacks.single.target, guard);
      expect(report.attacks.single.source, AttackSource.family);
      expect(engine.isAlive(anna), isTrue);
      expect(engine.isAlive(guard), isFalse);
      expect(engine.knowledgeOf(null, guard).isEmpty, isTrue, reason: 'una morte come le altre');
    });

    test('ferma anche il colpo del Cecchino', () {
      final engine = grandTable();
      final report = playNight(engine, {sniper: don, guard: don});
      expect(report.victims, [guard]);
      expect(report.attacks.single.source, AttackSource.sniper);
      expect(engine.isAlive(don), isTrue);
    });

    test('non può fare da scudo a se stesso', () {
      final engine = grandTable();
      expect(engine.taskFor(guard).targets, isNot(contains(guard)));
      expect(() => engine.submitNightChoice(guard, guard), throwsArgumentError);
    });

    test('se scorta qualcun altro, per lui non cambia niente', () {
      final engine = grandTable();
      final report = playNight(engine, {don: anna, picciotto: anna, guard: bruno});
      expect(report.victims, [anna]);
      expect(engine.isAlive(guard), isTrue);
    });

    test('preso di mira lui, muore come chiunque', () {
      final engine = grandTable();
      final report = playNight(engine, {don: guard, picciotto: guard, guard: anna});
      expect(report.victims, [guard]);
    });

    test('se il Dottore copre il bersaglio, il Guardaspalle non serve', () {
      final engine = grandTable();
      final report = playNight(engine, {don: anna, picciotto: anna, guard: anna, doctor: anna});
      expect(report.victims, isEmpty);
      expect(report.attacks.single.target, anna);
      expect(report.attacks.single.outcome, AttackOutcome.healed);
      expect(engine.isAlive(guard), isTrue);
    });

    test('se il Dottore copre il Guardaspalle, vivono tutti e due', () {
      final engine = grandTable();
      final report = playNight(engine, {don: anna, picciotto: anna, guard: anna, doctor: guard});
      expect(report.victims, isEmpty);
      expect(report.attacks.single.target, guard, reason: 'il colpo l\'ha preso lui');
      expect(report.attacks.single.outcome, AttackOutcome.healed);
      expect(engine.isAlive(anna), isTrue);
      expect(engine.isAlive(guard), isTrue);
    });

    test('tra due fuochi cade una volta sola', () {
      final engine = grandTable();
      final report = playNight(engine, {don: anna, picciotto: anna, guard: anna, sniper: guard});
      expect(report.attacks, hasLength(1));
      expect(report.attacks.single.target, guard);
      expect(report.attacks.single.source, AttackSource.family);
      expect(report.victims, [guard]);
      expect(engine.isAlive(anna), isTrue);
    });

    test('scorta uno, ma la notte ne colpisce due: salva solo il suo', () {
      final engine = grandTable();
      final report = playNight(engine, {don: anna, picciotto: anna, guard: anna, sniper: bruno});
      expect(report.victims.toSet(), {guard, bruno});
      expect(engine.isAlive(anna), isTrue);
    });

    test('se scorta il Reduce muore lui, e la pelle dura resta intatta', () {
      final engine = grandTable();
      final first = playNight(engine, {don: veteran, picciotto: veteran, guard: veteran});
      expect(first.victims, [guard]);
      engine.lynch(null);

      final second = playNight(engine, {don: veteran, picciotto: veteran});
      expect(second.attacks.single.outcome, AttackOutcome.shrugged);
      expect(engine.isAlive(veteran), isTrue);
    });

    test('se cade, e doveva tacere, non si annuncia niente', () {
      final engine = grandTable();
      final report = playNight(engine, {don: anna, picciotto: anna, guard: anna, tailor: guard});
      expect(report.victims, [guard]);
      expect(report.silenced, isNull);
    });
  });

  group('il Reduce', () {
    test('di notte non ha mosse: ha solo la pelle dura', () {
      expect(grandTable().taskFor(veteran).kind, NightTaskKind.decoy);
    });

    test('il primo agguato va a vuoto, il secondo no', () {
      final engine = grandTable();
      final first = playNight(engine, {don: veteran, picciotto: veteran});
      expect(first.victims, isEmpty);
      expect(first.attacks.single.target, veteran);
      expect(first.attacks.single.outcome, AttackOutcome.shrugged);
      expect(first.attacks.single.isFatal, isFalse);
      expect(engine.isAlive(veteran), isTrue);
      expect(engine.knowledgeOf(null, veteran).isEmpty, isTrue, reason: 'il tavolo può solo sospettare');
      engine.lynch(null);

      final second = playNight(engine, {don: veteran, picciotto: veteran});
      expect(second.victims, [veteran]);
      expect(second.attacks.single.outcome, AttackOutcome.killed);
    });

    test('regge anche il colpo del Cecchino, che però è speso', () {
      final engine = grandTable();
      final report = playNight(engine, {sniper: veteran});
      expect(report.victims, isEmpty);
      expect(report.attacks.single.source, AttackSource.sniper);
      expect(report.attacks.single.outcome, AttackOutcome.shrugged);
      engine.lynch(null);
      expect(engine.taskFor(sniper).kind, NightTaskKind.decoy);
    });

    test('famiglia e Cecchino la stessa notte: un agguato solo, e lo regge', () {
      final engine = grandTable();
      final report = playNight(engine, {don: veteran, picciotto: veteran, sniper: veteran});
      expect(report.attacks, hasLength(1));
      expect(report.attacks.single.outcome, AttackOutcome.shrugged);
      expect(engine.isAlive(veteran), isTrue);
    });

    test('se lo salva il Dottore, la pelle dura non si consuma', () {
      final engine = grandTable();
      final healed = playNight(engine, {don: veteran, picciotto: veteran, doctor: veteran});
      expect(healed.attacks.single.outcome, AttackOutcome.healed);
      engine.lynch(null);

      final shrugged = playNight(engine, {don: veteran, picciotto: veteran});
      expect(shrugged.attacks.single.outcome, AttackOutcome.shrugged);
      engine.lynch(null);

      final killed = playNight(engine, {don: veteran, picciotto: veteran});
      expect(killed.victims, [veteran]);
    });

    test('il patibolo non guarda la pelle', () {
      final engine = grandTable();
      playNight(engine);
      expect(engine.lynch(veteran).role, Role.reduce);
      expect(engine.isAlive(veteran), isFalse);
    });
  });

  group('il Pregiudicato', () {
    test('sta con gli onesti e di notte non ha mosse', () {
      expect(Role.pregiudicato.team, Team.citizens);
      expect(grandTable().taskFor(convict).kind, NightTaskKind.decoy);
    });

    test('al Commissario risulta della famiglia', () {
      final engine = grandTable();
      final finding = engine.submitNightChoice(detective, convict)!;
      expect(finding.team, Team.mafia);
      expect(engine.knowledgeOf(detective, convict).team, Team.mafia);
      expect(engine.knowledgeOf(don, convict).isEmpty, isTrue, reason: 'la famiglia non lo conosce');
    });

    test('il giornale lo scagiona, anche agli occhi del Commissario', () {
      final engine = grandTable();
      final report = playNight(engine, {detective: convict, reporter: convict});
      expect(report.scoop!.team, Team.citizens);
      expect(engine.knowledgeOf(null, convict).team, Team.citizens);
      expect(engine.knowledgeOf(detective, convict).team, Team.citizens);
    });

    test('sul patibolo la carta dice la verità', () {
      final engine = grandTable();
      playNight(engine, {detective: convict});
      final report = engine.lynch(convict);
      expect(report.role, Role.pregiudicato);
      expect(engine.knowledgeOf(detective, convict).team, Team.citizens);
    });

    test('per la vittoria conta come un onesto', () {
      final engine = GameEngine(GameSetup.fromRoles({
        boss: Role.mafioso,
        convict: Role.pregiudicato,
        anna: Role.cittadino,
        bruno: Role.cittadino,
      }));
      playNight(engine, {boss: anna});
      expect(engine.winner, isNull, reason: 'uno contro due: il Pregiudicato fa numero con gli onesti');
      expect(engine.lynch(boss).winner, Team.citizens);
    });
  });

  group('chi sa cosa', () {
    test('ognuno conosce il proprio ruolo', () {
      final engine = fullTable();
      expect(engine.knowledgeOf(doctor, doctor).role, Role.medico);
      expect(engine.knowledgeOf(anna, anna).role, Role.cittadino);
    });

    test('i mafiosi si conoscono tra loro, gli altri no', () {
      final engine = fullTable();
      expect(engine.knowledgeOf(boss, picciotto).role, Role.mafioso);
      expect(engine.knowledgeOf(picciotto, boss).role, Role.mafioso);
      expect(engine.knowledgeOf(anna, boss).isEmpty, isTrue);
      expect(engine.knowledgeOf(boss, detective).isEmpty, isTrue);
    });

    test('all\'inizio niente è pubblico', () {
      final engine = fullTable();
      for (final player in engine.alivePlayers) {
        expect(engine.knowledgeOf(null, player).isEmpty, isTrue, reason: player.name);
      }
    });
  });

  group('giorno', () {
    test('il linciaggio rivela il ruolo a tutti e porta alla notte dopo', () {
      final engine = fullTable();
      playNight(engine);
      final report = engine.lynch(doctor);

      expect(report.condemned, doctor);
      expect(report.role, Role.medico);
      expect(report.winner, isNull);
      expect(engine.isAlive(doctor), isFalse);
      expect(engine.knowledgeOf(null, doctor).role, Role.medico);
      expect(engine.phase, GamePhase.night);
      expect(engine.round, 2);
    });

    test('la piazza può non condannare nessuno', () {
      final engine = fullTable();
      playNight(engine);
      final report = engine.lynch(null);
      expect(report.condemned, isNull);
      expect(report.role, isNull);
      expect(engine.alivePlayers, hasLength(8));
      expect(engine.round, 2);
    });

    test('non si lincia di notte, né chi è già morto', () {
      final engine = fullTable();
      expect(() => engine.lynch(anna), throwsStateError);
      playNight(engine, {boss: anna, picciotto: anna});
      expect(() => engine.lynch(anna), throwsArgumentError);
    });

    test('di giorno non si fanno mosse notturne', () {
      final engine = fullTable();
      playNight(engine);
      expect(() => engine.submitNightChoice(boss, anna), throwsStateError);
    });
  });

  group('vittoria', () {
    test('gli onesti vincono quando cade l\'ultimo mafioso', () {
      final engine = smallTable();
      playNight(engine);
      final report = engine.lynch(boss);
      expect(report.winner, Team.citizens);
      expect(engine.winner, Team.citizens);
      expect(engine.phase, GamePhase.ended);
    });

    test('la famiglia vince quando non può più essere messa in minoranza', () {
      final engine = smallTable();
      playNight(engine, {boss: anna});
      expect(engine.winner, isNull, reason: 'uno contro due: si gioca ancora');

      final report = engine.lynch(bruno);
      expect(report.winner, Team.mafia);
      expect(engine.phase, GamePhase.ended);
    });

    test('la famiglia può vincere anche all\'alba', () {
      final engine = GameEngine(GameSetup.fromRoles({
        boss: Role.mafioso,
        anna: Role.cittadino,
        bruno: Role.cittadino,
      }));
      final report = playNight(engine, {boss: anna});
      expect(report.winner, Team.mafia);
      expect(engine.phase, GamePhase.ended);
    });

    test('Padrino e Sarto contano per la famiglia', () {
      final engine = GameEngine(GameSetup.fromRoles({
        don: Role.padrino,
        tailor: Role.sarto,
        anna: Role.cittadino,
        bruno: Role.cittadino,
        detective: Role.detective,
      }));
      final report = playNight(engine, {don: anna, tailor: bruno});
      expect(report.winner, Team.mafia, reason: 'due contro due');
    });

    test('gli onesti vincono solo quando cade tutta la famiglia, Sarto compreso', () {
      final engine = grandTable();
      playNight(engine);
      expect(engine.lynch(don).winner, isNull);
      playNight(engine);
      expect(engine.lynch(picciotto).winner, isNull);
      playNight(engine);
      expect(engine.lynch(tailor).winner, Team.citizens);
    });

    test('un colpo andato a vuoto non fa vincere nessuno', () {
      final engine = GameEngine(GameSetup.fromRoles({
        boss: Role.mafioso,
        veteran: Role.reduce,
        anna: Role.cittadino,
      }));
      final first = playNight(engine, {boss: veteran});
      expect(first.winner, isNull);
      expect(engine.phase, GamePhase.day);
      engine.lynch(null);
      expect(playNight(engine, {boss: veteran}).winner, Team.mafia);
    });

    test('a partita finita non si gioca più', () {
      final engine = smallTable();
      playNight(engine);
      engine.lynch(boss);
      expect(() => engine.taskFor(anna), throwsStateError);
      expect(() => engine.lynch(anna), throwsStateError);
    });
  });

  group('memoria della partita', () {
    test('la cronaca ricorda morti e condanne turno per turno', () {
      final engine = fullTable();
      playNight(engine, {boss: anna, picciotto: anna});
      engine.lynch(bruno);
      playNight(engine);
      engine.lynch(null);

      final history = engine.history;
      expect(history, hasLength(2));
      expect(history[0].round, 1);
      expect(history[0].nightVictims, [anna]);
      expect(history[0].lynched, bruno);
      expect(history[1].nightVictims, isEmpty);
      expect(history[1].lynched, isNull);
    });

    test('i compiti di copertura contano i sospetti, le mosse vere no', () {
      final engine = fullTable();
      playNight(engine, {anna: boss, bruno: boss, detective: boss, doctor: boss});
      expect(engine.suspicion, {boss: 2});
    });
  });

  test('partite casuali, a ogni tavolo da 3 a 12, finiscono sempre con un vincitore', () {
    final played = <Role>{};
    final tasks = <NightTaskKind>{};
    final outcomes = <AttackOutcome>{};
    for (var seed = 0; seed < 420; seed++) {
      final random = Random(seed);
      final lobby = [for (var i = 0; i < 3 + seed % 10; i++) Player(id: 'p$i', name: 'P$i')];
      final engine = GameEngine(
        GameSetup.deal(lobby: lobby, random: random),
        settings: GameSettings(mafiaTieBreak: TieBreak.values[seed % TieBreak.values.length]),
        random: random,
      );
      played.addAll(engine.setup.roles.values);

      var rounds = 0;
      while (engine.phase != GamePhase.ended) {
        expect(rounds++, lessThan(100), reason: 'seed=$seed: la partita non finisce');
        final before = engine.alivePlayers;
        for (final player in before) {
          final task = engine.taskFor(player);
          tasks.add(task.kind);
          expect(task.targets.toSet(), hasLength(task.targets.length), reason: 'seed=$seed');
          final sew = task.alternative != null && task.alternativeTargets.isNotEmpty && random.nextInt(3) == 0;
          final pool = sew ? task.alternativeTargets : task.targets;
          final skip = !sew && (pool.isEmpty || random.nextInt(5) == 0);
          final target = skip ? null : pool[random.nextInt(pool.length)];
          if (sew) tasks.add(task.alternative!);
          final finding = engine.submitNightChoice(player, target, alternative: sew);
          if (task.kind == NightTaskKind.dig && target != null) {
            expect(finding!.role, engine.setup.roleOf(target), reason: 'seed=$seed');
          }
        }
        final report = engine.resolveNight();
        outcomes.addAll(report.attacks.map((attack) => attack.outcome));
        if (!report.ignited) expect(report.attacks.length, lessThanOrEqualTo(2), reason: 'seed=$seed');
        for (final attack in report.attacks) {
          expect(before, contains(attack.target), reason: 'seed=$seed: si colpisce solo chi è vivo');
          expect(engine.isAlive(attack.target), !attack.isFatal, reason: 'seed=$seed');
        }
        expect(engine.alivePlayers.length, before.length - report.victims.length + (report.resurrected == null ? 0 : 1), reason: 'seed=$seed');
        if (report.silenced != null) {
          expect(engine.isAlive(report.silenced!), isTrue, reason: 'seed=$seed: i morti tacciono già');
        }
        if (engine.phase != GamePhase.day) break;
        final alive = engine.alivePlayers;
        engine.lynch(alive[random.nextInt(alive.length)]);
      }
      expect(engine.winner, isNotNull, reason: 'seed=$seed');
    }
    expect(played, Role.values.where((role) => role.playableIn(PlayMode.sharedPhone)).toSet(), reason: 'tutti i ruoli del telefono unico sono scesi in campo');
    // La cella e la Prostituta esistono solo online (vedi i loro test).
    expect(
      tasks,
      NightTaskKind.values.toSet().difference({NightTaskKind.jail, NightTaskKind.block}),
      reason: 'tutte le mosse sono state fatte',
    );
    expect(outcomes, AttackOutcome.values.toSet(), reason: 'tutti gli esiti si sono visti');
  });

  group('chi lascia la città', () {
    test('esce come un morto, la carta resta coperta, e le mosse su di lui si annullano', () {
      final engine = fullTable();
      engine.submitNightChoice(boss, anna);
      expect(engine.pendingNightPlayers, contains(picciotto));
      expect(engine.leaveTown(anna), isNull);
      expect(engine.isAlive(anna), isFalse);
      expect(engine.knowledgeOf(null, anna).isEmpty, isTrue, reason: 'la carta resta segreta');
      expect(engine.publicView().toJson().containsKey('recap'), isFalse);
      expect(engine.pendingNightPlayers, contains(boss), reason: 'il colpo su chi se n\'è andato si rifà');
      expect(engine.leaveTown(anna), isNull, reason: 'una volta sola');
    });

    test('se resta la sola famiglia, o nessuno della famiglia, la partita finisce subito', () {
      final engine = smallTable();
      expect(engine.leaveTown(boss), Team.citizens);
      expect(engine.phase, GamePhase.ended);
      expect(engine.winner, Team.citizens);

      final other = smallTable();
      other.leaveTown(anna);
      expect(other.leaveTown(bruno), Team.mafia);
    });
  });
}
