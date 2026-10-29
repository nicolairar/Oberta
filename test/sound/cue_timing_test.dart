import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/sound/cue_deck.dart';
import 'package:oberta/sound/scene_cues.dart';
import 'package:oberta/sound/sound_onsets.dart';
import 'package:oberta/sound/verdict_cues.dart';
import 'package:oberta/ui/widgets/death_scene.dart';
import 'package:oberta/ui/widgets/verdict_scene.dart';

Duration ms(int value) => Duration(milliseconds: value);

/// Tutti i file che una scena può suonare, per ogni suono.
List<String> assetsOf(SceneCue cue) => [
      if (cue.fx case final fx?) for (var take = 1; take <= fx.count; take++) fx.asset(take),
      if (cue.sample case final name?) 'sounds/$name.wav',
      if (cue.meme case final meme?) meme.asset,
    ];

/// Quanto suona il più lungo dei file che [cue] può pescare, dal suo inizio vero.
Duration longest(SceneCue cue) {
  var most = Duration.zero;
  for (final asset in assetsOf(cue)) {
    final (from, length) = soundShapes[asset]!;
    final rest = ms(length - from);
    if (rest > most) most = rest;
  }
  return most;
}

void main() {
  const frame = 1 / (14 * 60); // un fotogramma a 60 Hz, nel tempo vero del film

  group('il foglio dei suoni', () {
    test('senza anticipo suona dove suonava prima: al primo fotogramma che arriva al suono', () {
      for (final act in DeathAct.values) {
        final cues = sceneCuesFor(act);
        final sheet = CueSheet(cues, length: DeathScene.length, clock: filmClock);
        var old = 0;
        // I fotogrammi cadono dove capita, non proprio sui suoni.
        for (var n = 0; (n + 0.37) * frame <= 1; n++) {
          final x = (n + 0.37) * frame;
          final before = <int>[];
          while (old < cues.length && filmTime(x) >= cues[old].t) {
            before.add(old++);
          }
          expect(sheet.due(x), before, reason: '${act.name} a x=$x');
        }
      }
    });

    test('con l\'anticipo ogni suono parte una volta, in ordine, entro un fotogramma da [suo tempo − anticipo]', () {
      const lead = Duration(milliseconds: 70);
      for (final act in DeathAct.values) {
        final sheet = CueSheet(sceneCuesFor(act), length: DeathScene.length, clock: filmClock);
        final times = sheet.times;
        final fired = <int>[];
        for (var n = 0; n * frame <= 1 + frame; n++) {
          final x = n * frame;
          for (final i in sheet.due(x, lead: lead)) {
            fired.add(i);
            final firedAt = DeathScene.length * x;
            expect(firedAt, greaterThanOrEqualTo(times[i] - lead - ms(1)), reason: '${act.name} #$i');
            expect(firedAt, lessThan(times[i] - lead + DeathScene.length * frame + ms(1)), reason: '${act.name} #$i');
          }
        }
        expect(fired, [for (var i = 0; i < sheet.cues.length; i++) i], reason: act.name);
      }
    });

    test('i tempi veri dei suoni seguono il tempo del film', () {
      final sheet = CueSheet(sceneCuesFor(DeathAct.gun), length: DeathScene.length, clock: filmClock);
      for (var i = 0; i < sheet.cues.length; i++) {
        expect(sheet.times[i], DeathScene.length * filmClock(sheet.cues[i].t));
      }
      // Il verdetto non rallenta: tempo del film e tempo vero coincidono.
      final verdict = CueSheet(verdictCuesFor(VerdictTake.molo), length: VerdictTake.molo.length);
      expect(verdict.times.first, VerdictTake.molo.length * verdict.cues.first.t);
    });

    test('chi entra a film cominciato non sente i suoni di prima, chi salta non sente più niente', () {
      final sheet = CueSheet(sceneCuesFor(DeathAct.lupara), length: DeathScene.length, clock: filmClock);
      final strike = filmClock(DeathScenePainter.strike);
      sheet.skipTo(strike);
      final first = sheet.next;
      expect(sheet.cues[first].t, greaterThanOrEqualTo(DeathScenePainter.strike - 1e-9));
      expect(sheet.cues[first - 1].t, lessThan(DeathScenePainter.strike));
      expect(sheet.due(strike), contains(first));
      sheet.skipAll();
      expect(sheet.due(1), isEmpty);
    });
  });

  group('il piano dei lettori', () {
    test('un lettore si riprende solo quando il suo suono è finito e c\'è il tempo di ricaricarlo', () {
      final plan = planDeck([
        (at: ms(0), length: ms(500)),
        (at: ms(600), length: ms(200)), // il primo finisce a 500: a 600 non c'è tempo
        (at: ms(900), length: ms(200)), // il primo è libero da 500, +300 = 800
      ]);
      expect(plan.seats, [0, 1, 0]);
      expect(plan.players, 2);
    });

    test('oltre il massimo dei lettori i suoni restano senza, e partono a freddo', () {
      final plan = planDeck([for (var i = 0; i < 5; i++) (at: ms(i * 10), length: ms(1000))], maxPlayers: 3);
      expect(plan.seats, [0, 1, 2, null, null]);
      expect(plan.players, 3);
    });

    test('ogni suono di ogni scena trova il suo lettore pronto, anche con le registrazioni più lunghe', () {
      void check(List<SceneCue> cues, List<Duration> times, String name) {
        final plan = planDeck([for (var i = 0; i < cues.length; i++) (at: times[i], length: longest(cues[i]))]);
        expect(plan.seats, isNot(contains(null)), reason: name);
      }

      for (final act in DeathAct.values) {
        for (final save in [null, DeathAct.rescue, DeathAct.defibrillator, DeathAct.jam, DeathAct.lucky]) {
          if (save != null && act.survives) continue;
          for (final memes in [false, true]) {
            final sheet = CueSheet(sceneCuesFor(act, save: save, memes: memes), length: DeathScene.length, clock: filmClock);
            check(sheet.cues, sheet.times, '${act.name}+${save?.name} memes=$memes');
          }
        }
      }
      for (final take in VerdictTake.values) {
        final sheet = CueSheet(verdictCuesFor(take, memes: true), length: take.length);
        check(sheet.cues, sheet.times, take.name);
      }
    });
  });

  group('l\'anticipo misurato', () {
    test('finché non ci sono tre misure non si anticipa niente', () {
      final meter = LeadMeter();
      meter.heard(ms(90));
      meter.heard(ms(90));
      expect(meter.lead, Duration.zero);
      meter.heard(ms(90));
      expect(meter.lead, ms(90 - 16));
    });

    test('la mediana, meno un fotogramma, mai negativa, mai troppa', () {
      final meter = LeadMeter();
      for (final late in [40, 45, 300, 42, 41]) {
        meter.heard(ms(late));
      }
      expect(meter.lead, ms(42 - 16));

      final quick = LeadMeter();
      for (var i = 0; i < 5; i++) {
        quick.heard(ms(8));
      }
      expect(quick.lead, Duration.zero, reason: 'un suono che arriva prima dell\'immagine si nota di più');

      final slow = LeadMeter();
      for (var i = 0; i < 5; i++) {
        slow.heard(ms(400));
      }
      expect(slow.lead, ms(150));
    });

    test('le letture assurde non contano, e contano solo le ultime', () {
      final meter = LeadMeter(window: 3);
      meter.heard(ms(-500));
      meter.heard(ms(5000));
      meter.heard(ms(60));
      meter.heard(ms(60));
      expect(meter.lead, Duration.zero, reason: 'solo due misure buone');
      meter.heard(ms(60));
      meter.heard(ms(120));
      meter.heard(ms(120));
      meter.heard(ms(120));
      expect(meter.lead, ms(120 - 16));
    });
  });
}
