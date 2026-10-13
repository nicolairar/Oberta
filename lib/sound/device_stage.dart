import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../ui/widgets/death_scene.dart';
import 'scene_score.dart';
import 'sound_stage.dart';

/// Il palco vero: incide i nastri su un file temporaneo e li suona
/// dall'altoparlante del telefono.
class DeviceStage extends SoundStage {
  final AudioPlayer _player = AudioPlayer();
  final Map<DeathAct, Future<String>> _tapes = {};
  late final Future<void> _ready = _setUp();

  /// Cambia a ogni richiesta: un nastro che arriva tardi capisce da qui che
  /// nel frattempo la scena è finita, e non parte.
  int _ticket = 0;

  DeviceStage() {
    _ready.then<void>((_) {}, onError: _report);
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
    final bytes = await compute(composeSceneByIndex, act.index);
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
      await _player.play(DeviceFileSource(path));
    } catch (error) {
      // Un nastro venuto male non deve fermare la partita: la scena va in
      // onda muta, e la prossima volta si riprova da capo.
      _tapes.remove(act);
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
