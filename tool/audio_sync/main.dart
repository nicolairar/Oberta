// Quanto arriva tardi il suono dei film, misurato nell'app vera sul Mac:
//
//   lockf -t 0 /tmp/oberta_app.lock \
//     flutter run --profile -d macos -t tool/audio_sync/main.dart
//
// Mette in scena alcuni filmati della notte e del verdetto col palco vero
// ([DeviceStage]) e, per ogni suono, confronta il fotogramma in cui si vede
// la cosa (la prima volta che il film arriva al tempo del suono) con il
// momento in cui il suono si sente davvero: la posizione del lettore, letta
// più volte appena parte, dice quando è partito; si aggiunge il silenzio in
// testa alla registrazione che non si è saltato ([soundShapes]). Le righe
// `AUDIOSYNC` sono il risultato; alla fine l'app si chiude da sola.
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' show FramePhase;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:oberta/sound/device_stage.dart';
import 'package:oberta/sound/scene_cues.dart';
import 'package:oberta/sound/sound_onsets.dart';
import 'package:oberta/sound/sound_stage.dart';
import 'package:oberta/ui/widgets/death_scene.dart';
import 'package:oberta/ui/widgets/verdict_scene.dart';
import 'package:window_manager/window_manager.dart';

const _nights = [
  DeathAct.gun,
  DeathAct.lupara,
  DeathAct.knife,
  DeathAct.noose,
  DeathAct.kiss,
  DeathAct.jam,
  DeathAct.piano,
  DeathAct.burst,
];
const _verdicts = [VerdictTake.molo, VerdictTake.cannone];

int get _now => DeviceStage.clock.elapsedMicroseconds;

class _Heard {
  final SceneCue cue;
  final String asset;
  final Duration from;
  final int called;
  final bool ready;
  int? started;
  _Heard(this.cue, this.asset, this.from, this.called, this.ready);

  /// Quando si sente: la partenza del lettore più il silenzio non saltato.
  int? get audible {
    final s = started;
    if (s == null) return null;
    final onset = (soundShapes[asset]?.$1 ?? 0) * 1000;
    return s + max(0, onset - from.inMicroseconds);
  }
}

class _Take {
  final String name;
  final List<({int us, double t})> frames = [];
  final List<_Heard> heard = [];
  _Take(this.name);
}

_Take? _take;
final _rasterLag = <int>[];

/// Quando è partito [player]: ora meno quanta strada ha fatto dal punto
/// [from] in cui era fermo. Più letture, la mediana.
Future<int?> _startOf(AudioPlayer player, Duration from) async {
  final guesses = <int>[];
  final deadline = _now + 1500000;
  while (guesses.length < 5 && _now < deadline) {
    final before = _now;
    Duration? at;
    try {
      at = await player.getCurrentPosition();
    } catch (_) {
      break; // il film è finito e il lettore non c'è più
    }
    final after = _now;
    final ran = at == null ? null : at - from;
    if (ran != null && ran > const Duration(milliseconds: 3) && ran < const Duration(seconds: 2)) {
      guesses.add((before + after) ~/ 2 - ran.inMicroseconds);
    }
    await Future<void>.delayed(const Duration(milliseconds: 3));
  }
  if (guesses.isEmpty) return null;
  guesses.sort();
  return guesses[guesses.length ~/ 2];
}

/// Il tempo del film in questo fotogramma, letto dal pittore della scena.
double? _filmT() {
  double? found;
  void visit(Element element) {
    if (found != null) return;
    final render = element.renderObject;
    if (render is RenderCustomPaint) {
      final painter = render.painter;
      if (painter is DeathScenePainter) found = painter.t;
      if (painter is VerdictScenePainter) found = painter.t;
    }
    element.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(visit);
  return found;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final stage = DeviceStage();
  SoundStage.instance = stage;
  // Come in partita: la musica della notte sotto, bassa.
  stage.musicVolume = 0.1;
  stage.effectsVolume = 0.8;
  DeviceStage.probe = (cue, player, asset, from, called, ready) {
    final take = _take;
    if (take == null) return;
    final heard = _Heard(cue, asset, from, called, ready);
    take.heard.add(heard);
    _startOf(player, from).then((s) => heard.started = s);
  };
  SchedulerBinding.instance.addPersistentFrameCallback((_) {
    final take = _take;
    final t = _filmT();
    if (take != null && t != null) take.frames.add((us: _now, t: t));
  });
  SchedulerBinding.instance.addTimingsCallback((timings) {
    for (final timing in timings) {
      _rasterLag.add(timing.timestampInMicroseconds(FramePhase.rasterFinish) -
          timing.timestampInMicroseconds(FramePhase.buildFinish));
    }
  });
  final scene = ValueNotifier<Widget>(const SizedBox());
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: Colors.black,
      body: ValueListenableBuilder<Widget>(valueListenable: scene, builder: (_, child, _) => child),
    ),
  ));
  // Una finestra coperta non riceve fotogrammi: il film non andrebbe avanti.
  await windowManager.ensureInitialized();
  await windowManager.setSize(const Size(393, 852));
  await windowManager.setAlwaysOnTop(true);
  await windowManager.show();
  await windowManager.focus();
  stage.music(MusicMood.night);
  // Che i lettori e la sessione audio siano su prima di cominciare.
  await Future<void>.delayed(const Duration(seconds: 3));

  final takes = <_Take>[];
  Future<void> show(String name, Widget film, Duration length) async {
    final take = _Take(name);
    takes.add(take);
    await windowManager.show();
    await windowManager.focus();
    _say('AUDIOSYNC in onda: $name (${SchedulerBinding.instance.lifecycleState?.name}, '
        'visibile: ${await windowManager.isVisible()})');
    _take = take;
    scene.value = film;
    await Future<void>.delayed(length + const Duration(milliseconds: 600));
    scene.value = const SizedBox();
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    _take = null;
  }

  for (final act in _nights) {
    await show(
      act.name,
      DeathScene(key: ValueKey(act), act: act, victimName: 'Giulia', caption: 'Esterno, notte.', onFinished: () {}),
      DeathScene.length,
    );
  }
  for (final take in _verdicts) {
    await show(
      'verdetto ${take.name}',
      VerdictScene(key: ValueKey(take), condemnedName: 'Giulia', variant: take.name, onFinished: () {}),
      take.length,
    );
  }

  final late = <int>[];
  final fired = <int>[];
  for (final take in takes) {
    _say('AUDIOSYNC ${take.name}: ${take.frames.length} fotogrammi, ${take.heard.length} suoni');
    for (final heard in take.heard) {
      final frame = take.frames.where((f) => f.t >= heard.cue.t).firstOrNull;
      final audible = heard.audible;
      // Un suono più corto di così finisce prima che la posizione si legga bene.
      final shape = soundShapes[heard.asset];
      if (shape != null && shape.$2 - shape.$1 < 100) continue;
      if (frame == null || audible == null) {
        _say('AUDIOSYNC ${take.name} t=${heard.cue.t.toStringAsFixed(3)} ${heard.asset}: non misurato');
        continue;
      }
      late.add(audible - frame.us);
      fired.add(heard.called - frame.us);
      _say('AUDIOSYNC ${take.name.padRight(16)} t=${heard.cue.t.toStringAsFixed(3)} '
          '${heard.asset.padRight(26)} chiamato ${_ms(heard.called - frame.us)}  '
          'parte ${_ms(heard.started! - frame.us)}  si sente ${_ms(audible - frame.us)}'
          '${heard.ready ? '' : '  (a freddo)'}');
    }
  }
  if (late.isEmpty) {
    _say('AUDIOSYNC niente da misurare');
    exit(1);
  }
  _rasterLag.sort();
  _say('AUDIOSYNC fotogramma->schermo: raster ${_ms(_median(_rasterLag))} dopo il build, '
      'più fino a un giro di schermo');
  _say('AUDIOSYNC suoni ${late.length}: si sentono dopo il fotogramma di '
      '${_ms(_median(late))} (mediana), ${_ms(_pct(late, 0.9))} (90°), ${_ms(late.reduce(max))} (peggiore), '
      '${_ms(late.reduce(min))} (meglio); chiamati a ${_ms(_median(fired))}');
  await stdout.flush();
  await Future<void>.delayed(const Duration(seconds: 2));
  exit(0);
}

/// `debugPrint` va a rate e l'uscita dell'app taglierebbe le ultime righe.
void _say(String line) => stdout.writeln(line);

int _median(List<int> values) => _pct(values, 0.5);

int _pct(List<int> values, double p) {
  final sorted = [...values]..sort();
  return sorted[min(sorted.length - 1, (sorted.length * p).floor())];
}

String _ms(int us) => '${(us / 1000).toStringAsFixed(0).padLeft(4)} ms';
