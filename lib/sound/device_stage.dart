import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../ui/widgets/death_scene.dart';
import '../ui/widgets/verdict_scene.dart';
import 'cue_sounds.dart';
import 'sample_bank.dart';
import 'scene_score.dart';
import 'sound_stage.dart';
import 'verdict_stage.dart';

/// Il palco vero: incide i nastri su un file temporaneo e li suona
/// dall'altoparlante del telefono.
class DeviceStage extends SoundStage implements VerdictStage {
  final AudioPlayer _player = AudioPlayer();
  final Map<DeathAct, Future<String>> _tapes = {};
  final Map<VerdictTake, Future<String>> _verdicts = {};

  /// I suoni brevi, incisi tutti insieme appena l'app parte, e una piccola
  /// batteria di lettori per poterli suonare uno sopra l'altro.
  late final Future<Map<Cue, String>> _cues = _recordCues();
  final List<AudioPlayer> _shortPlayers = [for (var i = 0; i < 4; i++) AudioPlayer()];
  int _nextShort = 0;
  late final Future<void> _ready = _setUp();
  late final Future<SampleBank> _bank = loadSampleBank();

  /// Cambia a ogni richiesta: un nastro che arriva tardi capisce da qui che
  /// nel frattempo la scena è finita, e non parte.
  int _ticket = 0;

  DeviceStage() {
    _ready.then<void>((_) {}, onError: _report);
    _cues.then<void>((_) {}, onError: _report);
  }

  Future<Map<Cue, String>> _recordCues() async {
    final tapes = await compute(_composeAllCues, null);
    final paths = <Cue, String>{};
    for (final cue in Cue.values) {
      final file = File('${Directory.systemTemp.path}/cue-${cue.name}.wav');
      await file.writeAsBytes(tapes[cue.index], flush: true);
      paths[cue] = file.path;
    }
    return paths;
  }

  @override
  void cue(Cue cue) {
    if (!enabled) return;
    final player = _shortPlayers[_nextShort++ % _shortPlayers.length];
    () async {
      try {
        await _ready;
        await player.stop();
        final recorded = cueRecordings[cue];
        if (recorded != null) {
          await player.play(AssetSource('sounds/${recorded[_nextShort % recorded.length]}.wav'));
        } else {
          await player.play(DeviceFileSource((await _cues)[cue]!));
        }
      } catch (error) {
        _report(error);
      }
    }();
  }

  /// Il suono fa parte della scena: deve sentirsi anche col telefono in
  /// silenzioso, e senza zittire la musica che qualcuno ha già messo su.
  Future<void> _setUp() => AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {AVAudioSessionOptions.mixWithOthers},
          ),
          android: const AudioContextAndroid(audioFocus: AndroidAudioFocus.none),
        ),
      );

  Future<String> _tape(DeathAct act) => _tapes[act] ??= _record(act);

  /// Comporre un nastro costa qualche decimo di secondo: lo si fa in un
  /// altro isolate, per non far scattare le animazioni.
  Future<String> _record(DeathAct act) async {
    final file = File('${Directory.systemTemp.path}/scene-${act.name}.wav');
    final bytes = await compute(composeSceneByIndex, (act.index, await _bank));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  @override
  void prepare(Iterable<DeathAct> acts) {
    if (!enabled) return;
    for (final act in acts) {
      _tape(act).then<void>((_) {}, onError: _report);
    }
  }

  @override
  FutureOr<void> playScene(DeathAct act) {
    final ticket = ++_ticket;
    if (!enabled) return null;
    return _play(act, ticket);
  }

  Future<void> _play(DeathAct act, int ticket) async {
    try {
      await _ready;
      final path = await _tape(act);
      if (ticket != _ticket) return;
      // Prima di cambiare nastro si riavvolge: la posizione che il film
      // chiede poco dopo deve essere quella del nastro nuovo.
      await _player.stop();
      await _player.play(DeviceFileSource(path), position: Duration.zero);
    } catch (error) {
      // Un nastro venuto male non deve fermare la partita: la scena va in
      // onda muta, e la prossima volta si riprova da capo.
      _tapes.remove(act);
      _report(error);
    }
  }

  @override
  void prepareVerdicts(Iterable<VerdictTake> takes) {
    if (!enabled) return;
    for (final take in takes) {
      (_verdicts[take] ??= recordVerdictTape(take)).then<void>((_) {}, onError: _report);
    }
  }

  @override
  FutureOr<void> playVerdict(VerdictTake take) {
    final ticket = ++_ticket;
    if (!enabled) return null;
    return _playVerdict(take, ticket);
  }

  Future<void> _playVerdict(VerdictTake take, int ticket) async {
    try {
      await _ready;
      final path = await (_verdicts[take] ??= recordVerdictTape(take));
      if (ticket != _ticket) return;
      await _player.stop();
      await _player.play(DeviceFileSource(path), position: Duration.zero);
    } catch (error) {
      _verdicts.remove(take);
      _report(error);
    }
  }

  @override
  Future<Duration?> position() async {
    try {
      return await _player.getCurrentPosition();
    } catch (error) {
      _report(error);
      return null;
    }
  }

  @override
  Future<void> stop() async {
    _ticket++;
    try {
      await _player.stop();
    } catch (error) {
      _report(error);
    }
  }

  void _report(Object error) => debugPrint('Audio: $error');
}

List<Uint8List> _composeAllCues(Object? _) => [for (final cue in Cue.values) composeCue(cue)];
