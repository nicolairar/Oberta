import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/rules/game_engine.dart';
import 'package:oberta/rules/game_setup.dart';
import 'package:oberta/rules/intent.dart';
import 'package:oberta/rules/player.dart';
import 'package:oberta/rules/role.dart';

// Il verdetto del voto a voce sul telefono unico: il tavolo vota ad alta
// voce, il telefono registra solo chi sale sul patibolo (o il pareggio).
// E i poteri di giorno che passano da «Usa un potere».

Player _p(String id) => Player(id: id, name: id);

final mob = _p('mob');
final mob2 = _p('mob2');
final mayor = _p('mayor');
final pacifist = _p('pacifist');
final fool = _p('fool');
final president = _p('president');
final gunner = _p('gunner');
final marksman = _p('marksman');
final cupid = _p('cupid');
final a = _p('a');
final b = _p('b');
final c = _p('c');

GameEngine _table(Map<Player, Role> roles) => GameEngine(GameSetup.fromRoles(roles), seed: 7);

GameEngine _square() => _table({
  mob: Role.mafioso,
  mob2: Role.mafioso,
  mayor: Role.sindaco,
  pacifist: Role.pacifista,
  fool: Role.fesso,
  president: Role.presidente,
  a: Role.cittadino,
  b: Role.cittadino,
  c: Role.cittadino,
});

/// Una notte in cui tutti passano.
void _quietNight(GameEngine engine) {
  for (final player in engine.alivePlayers) {
    engine.submitNightChoice(player, null);
  }
  engine.resolveNight();
}

void main() {
  group('il verdetto a voce', () {
    test('il condannato sale sul patibolo, la carta si gira, e si va alla notte', () {
      final engine = _square();
      _quietNight(engine);
      final report = engine.lynch(mob);
      expect(report.condemned, mob);
      expect(report.role, Role.mafioso);
      expect(engine.isAlive(mob), isFalse);
      expect(engine.knowledgeOf(null, mob).role, Role.mafioso);
      expect(engine.phase, GamePhase.night);
      expect(engine.log.last, isA<LynchCommand>());
      expect(engine.dayVotes, isEmpty, reason: 'nessun voto finto');
    });

    test('il pareggio: nessuno sale sul patibolo, e torna la notte', () {
      final engine = _square();
      _quietNight(engine);
      final alive = engine.alivePlayers.length;
      final report = engine.lynch(null);
      expect(report.condemned, isNull);
      expect(report.truce, isFalse);
      expect(engine.alivePlayers, hasLength(alive));
      expect(engine.phase, GamePhase.night);
      expect(engine.round, 2);
    });

    test('chi si può condannare: i vivi, non il Presidente; con la tregua nessuno', () {
      final engine = _square();
      expect(engine.lynchable, isEmpty, reason: 'di notte no');
      _quietNight(engine);
      expect(engine.lynchable, isNot(contains(president)));
      expect(engine.lynchable, containsAll([mob, mayor, pacifist, fool, a]));
      expect(() => engine.lynch(president), throwsArgumentError);
      engine.pacify(pacifist, mob);
      expect(engine.lynchable, isEmpty);
    });

    test('il Sindaco rivelato: il doppio lo conta il tavolo, il verdetto è uno solo', () {
      final engine = _square();
      _quietNight(engine);
      expect(engine.apply(RevealMayor(mayor.id)).accepted, isTrue);
      expect(engine.mayor, mayor);
      final report = engine.lynch(mob2);
      expect(report.condemned, mob2);
      expect(engine.knowledgeOf(null, mayor).role, Role.sindaco, reason: 'il suo posto porta la carta');
    });

    test('la tregua del Pacifista: niente condanna, e il verdetto lo dice', () {
      final engine = _square();
      _quietNight(engine);
      engine.pacify(pacifist, a);
      expect(() => engine.lynch(mob), throwsStateError, reason: 'con la tregua non si condanna');
      final report = engine.lynch(null);
      expect(report.truce, isTrue);
      expect(report.condemned, isNull);
      expect(engine.knowledgeOf(null, pacifist).role, Role.pacifista);
      expect(engine.knowledgeOf(null, a).role, Role.cittadino);
    });

    test('il Fesso condannato a voce vince da solo, e la partita va avanti', () {
      final engine = _square();
      _quietNight(engine);
      final report = engine.lynch(fool);
      expect(report.personalWin, isTrue);
      expect(engine.personalWins, contains(fool));
      expect(report.winner, isNull);
      expect(engine.phase, GamePhase.night);
    });

    test('l\'innamorato del condannato muore di crepacuore', () {
      final engine = _table({mob: Role.mafioso, cupid: Role.cupido, a: Role.cittadino, b: Role.cittadino, c: Role.cittadino});
      expect(engine.apply(Link(cupid.id, a.id, b.id)).accepted, isTrue);
      for (final player in engine.alivePlayers) {
        if (player != cupid) engine.submitNightChoice(player, null);
      }
      engine.resolveNight();
      final report = engine.lynch(a);
      expect(report.heartbroken, b);
      expect(engine.isAlive(b), isFalse);
    });

    test('il resoconto rigioca il verdetto a voce, senza voti inventati', () {
      final engine = _table({mob: Role.mafioso, a: Role.cittadino, b: Role.cittadino, c: Role.cittadino});
      _quietNight(engine);
      engine.lynch(mob);
      final recap = engine.recap!;
      expect(recap.days.single.lynch.condemned, mob);
      expect(recap.days.single.votes, isEmpty);
    });
  });

  group('il voto segreto', () {
    test('il pareggio si riconosce prima di chiudere, col Sindaco che vale doppio', () {
      final engine = _square();
      _quietNight(engine);
      engine
        ..apply(DayVote(a.id, mob.id))
        ..apply(DayVote(b.id, mob2.id));
      expect(engine.dayVoteTied, isTrue);
      engine.apply(RevealMayor(mayor.id));
      engine.apply(DayVote(mayor.id, mob2.id));
      expect(engine.dayVoteTied, isFalse, reason: 'il Sindaco vale doppio: tre a uno');
      expect(engine.closeDayVote().condemned, mob2);
    });

    test('tutti astenuti non è un pareggio', () {
      final engine = _square();
      _quietNight(engine);
      engine.apply(Pass(a.id));
      expect(engine.dayVoteTied, isFalse);
    });

    test('a fine partita il resoconto può tacere chi ha votato chi', () {
      final engine = _table({mob: Role.mafioso, a: Role.cittadino, b: Role.cittadino, c: Role.cittadino});
      _quietNight(engine);
      engine
        ..apply(DayVote(a.id, mob.id))
        ..apply(DayVote(b.id, mob.id))
        ..apply(DayVote(mob.id, a.id));
      engine.closeDayVote();
      final recap = engine.recap!;
      expect(recap.days.single.votes, hasLength(3));
      final secret = recap.withoutBallots();
      expect(secret.days.single.votes, isEmpty);
      expect(secret.days.single.lynch.condemned, mob);
      expect(secret.roles, recap.roles);
      expect(secret.nights, hasLength(recap.nights.length));
    });
  });

  group('i poteri di giorno', () {
    test('solo i quattro ruoli di giorno ne hanno uno', () {
      expect({for (final role in Role.values) role: role.dayPower}..removeWhere((_, power) => power == null), {
        Role.pacifista: DayPower.truce,
        Role.artigliere: DayPower.cannon,
        Role.tiratoreScelto: DayPower.marksman,
        Role.sindaco: DayPower.mayor,
      });
    });

    test('chi non ha un potere, di notte, o da morto: niente', () {
      final engine = _square();
      expect(engine.dayPowerOf(mayor), isNull, reason: 'di notte no');
      _quietNight(engine);
      expect(engine.dayPowerOf(a), isNull);
      expect(engine.dayPowerOf(mob), isNull);
      expect(engine.dayPowerOf(president), isNull);
      expect(engine.dayPowerOf(mayor), DayPower.mayor);
      expect(engine.dayPowerOf(pacifist), DayPower.truce);
      engine.lynch(mayor);
      _quietNight(engine);
      expect(engine.dayPowerOf(mayor), isNull, reason: 'i morti non usano poteri');
    });

    test('il Sindaco si rivela una volta; la tregua è una per partita e ferma Sindaco e Tiratore', () {
      final engine = _table({
        mob: Role.mafioso,
        mob2: Role.mafioso,
        mayor: Role.sindaco,
        pacifist: Role.pacifista,
        marksman: Role.tiratoreScelto,
        a: Role.cittadino,
        b: Role.cittadino,
        c: Role.cittadino,
      });
      _quietNight(engine);
      engine.apply(RevealMayor(mayor.id));
      expect(engine.dayPowerOf(mayor), isNull, reason: 'una volta per partita');
      expect(engine.dayPowerOf(marksman), DayPower.marksman, reason: 'con i colpi, anche senza mira');
      expect(engine.canShoot(marksman), isFalse, reason: 'nessuno nel mirino');
      engine.pacify(pacifist, a);
      expect(engine.dayPowerOf(pacifist), isNull);
      expect(engine.dayPowerOf(marksman), isNull, reason: 'con la tregua non si spara');
    });

    test('l\'Artigliere dal secondo giorno, uno al giorno; dopo il primo colpo tutti sanno chi è', () {
      final engine = _table({mob: Role.mafioso, mob2: Role.mafioso, gunner: Role.artigliere, a: Role.cittadino, b: Role.cittadino, c: Role.cittadino});
      _quietNight(engine);
      expect(engine.dayPowerOf(gunner), isNull, reason: 'il primo giorno il cannone tace');
      engine.lynch(null);
      _quietNight(engine);
      expect(engine.dayPowerOf(gunner), DayPower.cannon);
      expect(engine.knowledgeOf(null, gunner).role, isNull);
      engine.fire(gunner, mob);
      expect(engine.knowledgeOf(null, gunner).role, Role.artigliere, reason: 'il suo posto porta la carta');
      expect(engine.dayPowerOf(gunner), isNull, reason: 'uno al giorno');
    });
  });
}
