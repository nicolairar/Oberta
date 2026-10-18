import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/online/game/bot_brain.dart';
import 'package:oberta/online/game/game_protocol.dart';
import 'package:oberta/online/game/game_schedule.dart';
import 'package:oberta/online/game/game_server.dart';
import 'package:oberta/rules/game_engine.dart';
import 'package:oberta/rules/game_snapshot.dart';
import 'package:oberta/rules/intent.dart';
import 'package:oberta/rules/player_view.dart';
import 'package:oberta/rules/role.dart';
import 'package:oberta/table/seating.dart';

import '../../tool/edge/engine_sources.dart';
import '../rules/player_view_test.dart' show leaksIn;

/// Il server visto dal database: tiene lo stato fra un passo e l'altro, le
/// intenzioni in coda e l'ora. Tutto passa in JSON, come nella Edge Function.
class ServerHarness {
  final List<Map<String, Object?>> seats;
  final int seed;
  Map<String, Object?>? state;
  Map<String, Object?> last = const {};
  final List<Map<String, Object?>> queue = [];
  final List<String> leaks = [];
  final List<Map<String, Object?>> steps = [];
  int nextId = 1;
  int now = DateTime.utc(2026, 10, 17, 20).millisecondsSinceEpoch;
  Map<String, int>? seen;

  /// La fase in cui ogni persona ha già agito (una mossa per fase).
  final Map<String, String> actedIn = {};

  ServerHarness(this.seats, {this.seed = 1});

  Map<String, Object?> step() {
    final out = jsonDecode(jsonEncode(serverStep(jsonDecode(jsonEncode({
      'state': state,
      'seats': seats,
      'language': 'it',
      'now': now,
      'intents': queue,
      'seen': seen,
      'seed': seed + steps.length,
    })) as Map<String, Object?>))) as Map<String, Object?>;
    steps.add(out);
    state = out['state'] as Map<String, Object?>;
    final handled = out['lastIntent'] as int?;
    if (handled != null) queue.removeWhere((i) => (i['id'] as int) <= handled);
    last = out;
    _inspect(out);
    return out;
  }

  void send(String seat, Map<String, Object?> intent) => queue.add({'id': nextId++, 'seat': seat, 'intent': intent});

  Map<String, Object?> get board => last['board'] as Map<String, Object?>;
  Map<String, Object?> get schedule => board['schedule'] as Map<String, Object?>;
  Stage get stage => Stage.values.byName(schedule['stage'] as String);
  Map<String, Object?> seatView(String seat) => (last['seatViews'] as Map)[seat] as Map<String, Object?>;

  void _inspect(Map<String, Object?> out) {
    final state = out['state'] as Map<String, Object?>;
    final seating = Seating.fromJson(state['seating'] as Map<String, Object?>);
    final engine = GameEngine.fromSnapshot(GameSnapshot.fromJson(state['snapshot'] as Map<String, Object?>, seating.playerAt));
    final board = (out['board'] as Map<String, Object?>)['board'] as Map<String, Object?>;
    final version = out['version'];
    leaks.addAll(leaksIn(engine, null, board).map((l) => 'tavolo v$version: $l'));
    if (engine.phase != GamePhase.ended && (board['finalRoles'] as List).isNotEmpty) leaks.add('carte scoperte');
    for (final attack in ((board['lastDawn'] as Map?)?['attacks'] as List?) ?? const []) {
      if (attack['outcome'] != 'killed' && attack['target'] != anonymousSeat) leaks.add('chi si è salvato si vede');
    }
    for (final MapEntry(key: seat, value: payload) in (out['seatViews'] as Map<String, Object?>).entries) {
      final view = (payload as Map)['view'] as Map<String, Object?>;
      if (view['seat'] != seat) leaks.add('la vista di ${view['seat']} sotto $seat');
      if (seating.profileOf(seat) == null) leaks.add('un bot ha una vista: $seat');
      leaks.addAll(leaksIn(engine, seating.playerAt(seat), view).map((l) => '$seat v$version: $l'));
    }
  }
}

List<Map<String, Object?>> table({required int humans, required int bots}) => [
      for (var i = 0; i < humans; i++) {'seat': 's${i + 1}', 'profile_id': 'p$i', 'name': 'persona$i'},
      for (var i = 0; i < bots; i++) {'seat': 's${humans + i + 1}', 'profile_id': null, 'name': botName(i)},
    ];

/// Le persone giocano come bot dalla loro vista: agiscono quando possono,
/// confermano le fasi da guardare. [lazy]: posti che non fanno mai niente.
bool humansAct(ServerHarness server, Random random, {Set<String> lazy = const {}}) {
  var acted = false;
  final schedule = server.schedule;
  for (final seat in (server.last['seatViews'] as Map).keys.cast<String>()) {
    if (lazy.contains(seat)) continue;
    final payload = server.seatView(seat);
    final view = PlayerView.fromJson(payload['view'] as Map<String, Object?>);
    if (server.queue.any((i) => i['seat'] == seat)) continue;
    if (server.stage.acceptsActions) {
      if (view.action == null || server.actedIn[seat] == schedule['key']) continue;
      server.actedIn[seat] = schedule['key'] as String;
      final intent = BotBrain(random).decide(view);
      if (intent == null) continue;
      server.send(seat, intent.toJson());
      acted = true;
    } else if (server.stage.acknowledged && payload['acked'] != true && view.alive) {
      server.send(seat, {'type': 'ack', 'seat': seat, 'stage': schedule['key']});
      acted = true;
    }
  }
  return acted;
}

/// Fino alla fine: se nessuno ha niente da fare, l'ora va avanti fino al
/// prossimo appuntamento del server.
void playToTheEnd(ServerHarness server, Random random, {Set<String> lazy = const {}, int maxSteps = 3000}) {
  server.step();
  for (var i = 0; i < maxSteps; i++) {
    if (server.last['finished'] == true) return;
    if (humansAct(server, random, lazy: lazy)) {
      server.step();
      continue;
    }
    final due = server.last['nextDue'] as int?;
    expect(due, isNotNull, reason: 'la partita non è finita ma il server non ha appuntamenti');
    server.now = max(server.now, due!);
    server.step();
  }
  fail('la partita non finisce');
}

void main() {
  test('due persone e tre bot: dalle carte alla fine, e nessuno vede quello che non deve', () {
    for (var seed = 1; seed <= 8; seed++) {
      final server = ServerHarness(table(humans: 2, bots: 3), seed: seed);
      playToTheEnd(server, Random(seed));
      expect(server.leaks, isEmpty, reason: 'partita $seed');
      expect(server.stage, Stage.ended);
      final board = server.board['board'] as Map<String, Object?>;
      expect(board['winner'], isNotNull);
      expect(board['finalRoles'], hasLength(5));
      expect((server.last['seatViews'] as Map).keys, ['s1', 's2'], reason: 'i bot non hanno viste');
      expect(server.last['nextDue'], isNull);
      final text = jsonEncode([for (final s in server.steps) [s['board'], s['seatViews']]]);
      expect(text, isNot(contains('snapshot')));
      expect(text, isNot(contains('"facts"')));
    }
  });

  test('le fasi seguono l\'orologio del server, con l\'anticipo e la tolleranza', () {
    final server = ServerHarness(table(humans: 2, bots: 2));
    final start = server.now;
    server.step();
    expect(server.stage, Stage.reveal);
    expect(server.schedule['startsAt'], start + 1500, reason: 'la fase comincia un po\' dopo essere pubblicata');
    expect(server.schedule['endsAt'], start + 1500 + 15000);
    expect(server.last['nextDue'], start + 1500 + 15000 + 2000, reason: 'si chiude dopo la tolleranza');

    // Tutti e due vedono la carta: la notte parte subito, sempre con l'anticipo.
    server.now += 4000;
    for (final seat in ['s1', 's2']) {
      server.send(seat, {'type': 'ack', 'seat': seat, 'stage': 'reveal-1'});
    }
    server.step();
    expect(server.stage, Stage.night);
    expect(server.schedule['startsAt'], server.now + 1500);
    expect(server.schedule['endsAt'], server.now + 1500 + 30000);
  });

  test('l\'ultimo voto si vede: la fase chiude solo dopo una breve attesa', () {
    final server = ServerHarness(table(humans: 5, bots: 0), seed: 2);
    final random = Random(2);
    server.step();
    final held = <Stage>{};
    for (var i = 0; i < 400 && server.last['finished'] != true && held.length < 2; i++) {
      final stage = server.stage;
      final key = server.schedule['key'];
      if (!humansAct(server, random)) {
        server.now = server.last['nextDue'] as int;
        server.step();
        continue;
      }
      server.step();
      if (stage != Stage.vote && stage != Stage.night) continue;
      final hold = server.state!['settleUntil'] as int?;
      expect(hold, server.now + 2500, reason: 'un voto accettato tiene aperta la fase');
      expect(server.schedule['key'], key, reason: 'non chiude nello stesso passo del voto');
      expect(server.last['nextDue'], lessThanOrEqualTo(hold!));
      server.now = hold - 1;
      server.step();
      expect(server.schedule['key'], key, reason: 'prima dell\'attesa resta aperta');
      server.now = hold;
      server.step();
      if (server.schedule['key'] != key) {
        held.add(stage);
        expect(server.state!['settleUntil'], isNull, reason: 'la fase nuova riparte senza attesa');
      }
    }
    expect(held, containsAll([Stage.night, Stage.vote]));
    expect(server.leaks, isEmpty);
  });

  test('i bot votano almeno 3 secondi prima della fine, e anche il loro voto si vede', () {
    final server = ServerHarness(table(humans: 1, bots: 4), seed: 5);
    server.step();
    for (var i = 0; i < 200 && server.stage != Stage.vote; i++) {
      if (!humansAct(server, Random(1))) server.now = server.last['nextDue'] as int;
      server.step();
    }
    expect(server.stage, Stage.vote);
    final endsAt = server.schedule['endsAt'] as int;
    final botDue = (server.state!['botDue'] as Map).values.cast<int>().where((d) => d != 0);
    expect(botDue, isNotEmpty);
    expect(botDue.every((d) => d <= endsAt - 3000), isTrue);
  });

  test('una conferma sola non basta, e chi non è collegato non blocca', () {
    final server = ServerHarness(table(humans: 3, bots: 1));
    server.step();
    server.send('s1', {'type': 'ack', 'seat': 's1', 'stage': 'reveal-1'});
    server.step();
    expect(server.stage, Stage.reveal);
    expect(server.seatView('s1')['acked'], isTrue);
    expect(server.seatView('s2')['acked'], isFalse);

    // Una conferma per una fase vecchia non conta.
    server.send('s2', {'type': 'ack', 'seat': 's2', 'stage': 'night-1'});
    server.step();
    expect(server.stage, Stage.reveal);

    // s3 non si fa sentire da 20 secondi: è offline, bastano s1 e s2.
    server.seen = {'s1': server.now, 's2': server.now, 's3': server.now - 20000};
    server.send('s2', {'type': 'ack', 'seat': 's2', 'stage': 'reveal-1'});
    server.step();
    expect(server.stage, Stage.night);
  });

  test('le mosse valgono solo nella loro fase: fuori tornano rifiutate', () {
    final server = ServerHarness(table(humans: 2, bots: 2));
    server.step();
    final view = server.seatView('s1')['view'] as Map<String, Object?>;
    expect(view['action'], isNull, reason: 'mentre si guarda la carta non si agisce');
    server.send('s1', {'type': 'pass', 'seat': 's1'});
    server.step();
    final receipt = server.seatView('s1')['receipt'] as Map<String, Object?>;
    expect((receipt['result'] as Map)['error'], IntentError.wrongPhase.name);

    // Allo scadere della carta si passa alla notte, e lì si agisce.
    server.now = server.last['nextDue'] as int;
    server.step();
    expect(server.stage, Stage.night);
    expect((server.seatView('s1')['view'] as Map)['action'], isNotNull);
    server.send('s1', {'type': 'pass', 'seat': 's1'});
    server.step();
    expect(((server.seatView('s1')['receipt'] as Map)['result'] as Map)['ok'], isTrue,
        reason: 'la risposta del server è la conferma della mossa');
    expect((server.seatView('s1')['view'] as Map)['action'], isNull);
  });

  test('di notte chi non sceglie passa, al voto chi non vota si astiene', () {
    final server = ServerHarness(table(humans: 2, bots: 2));
    final random = Random(3);
    server.step();
    final seen = <Stage>{};
    // s2 non tocca mai il telefono, s1 sì: la partita va avanti lo stesso.
    for (var i = 0; i < 400 && server.last['finished'] != true; i++) {
      seen.add(server.stage);
      if (!humansAct(server, random, lazy: {'s2'})) server.now = server.last['nextDue'] as int;
      server.step();
    }
    expect(server.last['finished'], isTrue);
    expect(seen, containsAll([Stage.reveal, Stage.night, Stage.dawn, Stage.discussion, Stage.vote, Stage.verdictFilm, Stage.verdict]));
    expect(server.leaks, isEmpty);
  });

  test('i film durano quanto i film, e la famiglia ha la sua chat di notte', () {
    final server = ServerHarness(table(humans: 3, bots: 3), seed: 4);
    final random = Random(4);
    server.step();
    var films = 0;
    for (var i = 0; i < 800 && server.last['finished'] != true; i++) {
      final schedule = server.schedule;
      final chat = server.last['chat'] as Map<String, Object?>;
      switch (server.stage) {
        case Stage.dawnFilms:
          final attacks = ((server.board['board'] as Map)['lastDawn'] as Map)['attacks'] as List;
          expect((schedule['endsAt'] as int) - (schedule['startsAt'] as int), 14000 * attacks.length);
          films++;
        case Stage.night:
          expect(chat['mode'], 'night');
        case Stage.discussion || Stage.vote:
          expect(chat['mode'], 'day');
        default:
          break;
      }
      if (!humansAct(server, random)) server.now = server.last['nextDue'] as int;
      server.step();
    }
    expect(films, greaterThan(0));
    final seats = (server.last['chat'] as Map)['seats'] as Map;
    expect(seats.keys, ['s1', 's2', 's3']);
  });

  test('chi va offline non blocca, e se non torna in tempo lascia la città con la carta scoperta', () {
    final server = ServerHarness(table(humans: 3, bots: 3), seed: 2);
    final start = server.now;
    server.seen = {'s1': start, 's2': start, 's3': start};
    server.step();
    expect(server.board['offline'], isEmpty);

    // s3 sparisce; gli altri due continuano a farsi sentire.
    server.now = start + 10000;
    server.seen = {'s1': server.now, 's2': server.now, 's3': start};
    server.step();
    expect(server.board['offline'], isEmpty, reason: 'un buco di rete breve non conta');
    expect(server.last['nextDue'], start + 15000, reason: 'il server torna a guardare quando scatta l\'offline');

    server.now = start + 15000;
    server.seen = {'s1': server.now, 's2': server.now, 's3': start};
    server.step();
    expect(server.board['offline'], ['s3'], reason: 'tutti vedono che s3 è offline');
    for (final seat in ['s1', 's2']) {
      server.send(seat, {'type': 'ack', 'seat': seat, 'stage': 'reveal-1'});
    }
    server.step();
    expect(server.stage, Stage.night, reason: 'chi è offline non blocca la carta');

    // Torna prima della tolleranza: niente di fatto.
    server.now = start + 40000;
    server.seen = {'s1': server.now, 's2': server.now, 's3': server.now};
    server.step();
    expect(server.board['offline'], isEmpty);

    // Sparisce di nuovo, e stavolta non torna.
    final gone = server.now;
    var away = 's3';
    while (server.now < gone + 75000 && server.last['finished'] != true) {
      final alive = ((server.board['board'] as Map)['alive'] as List).cast<String>();
      if (!alive.contains(away)) away = ['s1', 's2', 's3'].firstWhere(alive.contains, orElse: () => away);
      server.now = min(server.last['nextDue'] as int, gone + 75000);
      server.seen = {for (final seat in ['s1', 's2', 's3']) seat: seat == away ? gone : server.now};
      server.step();
    }
    if (server.last['finished'] == true && (server.board['departed'] as List).isEmpty) return;
    expect(server.board['departed'], [away]);
    expect(server.last['departed'], [away], reason: 'il database annota l\'abbandono');
    final board = server.board['board'] as Map<String, Object?>;
    expect(board['alive'], isNot(contains(away)));
    expect((board['revealed'] as List).map((k) => (k as Map)['seat']), contains(away), reason: 'la carta si scopre');
    expect(server.leaks, isEmpty);
  });

  test('una partita in cui nessuno gioca più si chiude da sola', () {
    final server = ServerHarness(table(humans: 4, bots: 0));
    server.step();
    for (var i = 0; i < 100 && server.last['finished'] != true; i++) {
      server.now = server.last['nextDue'] as int;
      server.step();
    }
    expect(server.last['finished'], isTrue);
    expect(server.board['abandoned'], isTrue);
    expect(server.last['nextDue'], isNull);
  });

  test('online i tempi sono 30 / 60 / 30, anche la prima notte, e il Compare può uscire', () {
    var compares = 0;
    for (var seed = 1; seed <= 30; seed++) {
      final server = ServerHarness(table(humans: 10, bots: 0), seed: seed);
      final random = Random(seed);
      server.step();
      final roles = [
        for (final seat in (((server.state!['snapshot'] as Map)['setup'] as Map)['seats'] as List).cast<Map>())
          seat['role'] as String,
      ];
      final compare = roles.contains('compare');
      if (compare) compares++;
      final checked = <Stage>{};
      for (var i = 0; i < 400 && server.last['finished'] != true && checked.length < 3; i++) {
        final schedule = server.schedule;
        final length = (schedule['endsAt'] as int) - (schedule['startsAt'] as int);
        final round = (server.board['board'] as Map)['round'] as int;
        switch (server.stage) {
          case Stage.night when round == 1:
            expect(length, 30000);
            checked.add(Stage.night);
          case Stage.discussion:
            expect(length, 60000);
            checked.add(Stage.discussion);
            // Il motore decide la chat: di giorno la famiglia scrive solo con
            // un Compare vivo.
            final state = server.state!;
            final seating = Seating.fromJson(state['seating'] as Map<String, Object?>);
            final engine =
                GameEngine.fromSnapshot(GameSnapshot.fromJson(state['snapshot'] as Map<String, Object?>, seating.playerAt));
            final rights = (server.last['chat'] as Map)['seats'] as Map;
            for (final MapEntry(key: seat, value: right) in rights.entries) {
              final view = engine.viewFor(seat as String);
              final open = view.alive && view.team == Team.mafia && engine.familyDayChat;
              expect((right as Map)['familyDay'], open, reason: 'seed=$seed $seat');
              expect(right['silenced'], view.silenced, reason: 'seed=$seed $seat');
            }
          case Stage.vote:
            expect(length, 30000);
            checked.add(Stage.vote);
          default:
            break;
        }
        if (!humansAct(server, random)) server.now = server.last['nextDue'] as int;
        server.step();
      }
    }
    expect(compares, greaterThan(0), reason: 'online il Compare entra nei mazzi');
  });

  test('il bundle JavaScript del server è stato ricompilato dopo l\'ultima modifica al motore', () {
    expect(bundleFingerprint('.'), engineFingerprint('.'),
        reason: 'lancia tool/edge/build.sh e committa supabase/functions/game/engine.js');
  });
}
