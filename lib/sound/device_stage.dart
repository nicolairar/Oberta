import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../ui/widgets/death_scene.dart';
import '../ui/widgets/verdict_scene.dart';
import 'cue_sounds.dart';
import 'ambience.dart';
import 'fx_groups.dart';
import 'memes.dart';
import 'music_tracks.dart';
import 'sound_stage.dart';
import 'verdict_stage.dart';

/// Il palco vero: incide i nastri su un file temporaneo e li suona
/// dall'altoparlante del telefono.
class DeviceStage extends SoundStage implements VerdictStage {
  final AudioPlayer _player = AudioPlayer();

  /// I suoni brevi, incisi tutti insieme appena l'app parte, e una piccola
  /// batteria di lettori per poterli suonare uno sopra l'altro.
  late final Future<Map<Cue, String>> _cues = _recordCues();
  final List<AudioPlayer> _shortPlayers = [for (var i = 0; i < 8; i++) AudioPlayer()];
  int _nextShort = 0;

  final AudioPlayer _music = AudioPlayer();
  final AudioPlayer _ambience = AudioPlayer();
  FxGroup? _ambienceGroup;
  final _random = Random();
  MusicMood? _mood;
  double _duck = 1;
  Timer? _fade;
  final Map<FxGroup, int> _lastTake = {};
  late final Future<void> _ready = _setUp();


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
        final gain = cueGains[cue] ?? 0.6;
        final fx = cueEffects[cue];
        if (fx != null) {
          effect(fx, volume: gain);
          return;
        }
        final recorded = cueRecordings[cue];
        if (recorded != null) {
          await player.play(AssetSource('sounds/${recorded[_nextShort % recorded.length]}.wav'), volume: effectsVolume * gain);
        } else {
          await player.play(DeviceFileSource((await _cues)[cue]!), volume: effectsVolume * gain);
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




  @override
  void prepare(Iterable<DeathAct> acts) {}


  /// Le scene non hanno più un nastro: ogni suono parte da solo al suo
  /// fotogramma (vedi `scene_cues.dart`). Il film parte subito.
  @override
  FutureOr<void> playScene(DeathAct act) {
    return null;
  }

  @override
  void sample(String name, {double volume = 1}) {
    if (!enabled || effectsVolume <= 0) return;
    final player = _shortPlayers[_nextShort++ % _shortPlayers.length];
    () async {
      try {
        await player.stop();
        await player.play(AssetSource('sounds/$name.wav'), volume: (effectsVolume * volume).clamp(0.0, 1.0));
      } catch (error) {
        _report(error);
      }
    }();
  }



  @override
  void prepareVerdicts(Iterable<VerdictTake> takes) {}


  /// Anche i verdetti suonano a battute (vedi `verdict_cues.dart`), senza nastro.
  @override
  FutureOr<void> playVerdict(VerdictTake take) {
    return null;
  }




  @override
  void effect(FxGroup group, {Duration after = Duration.zero, double volume = 1}) {
    if (!enabled || effectsVolume <= 0) return;
    () async {
      try {
        if (after > Duration.zero) await Future<void>.delayed(after);
        if (!enabled) return;
        await _ready;
        // Una registrazione diversa dall'ultima, quando se ne ha la scelta.
        var take = 1 + _random.nextInt(group.count);
        if (group.count > 1 && take == _lastTake[group]) take = take % group.count + 1;
        _lastTake[group] = take;
        final player = _shortPlayers[_nextShort++ % _shortPlayers.length];
        await player.stop();
        await player.play(AssetSource(group.asset(take)), volume: (effectsVolume * volume).clamp(0.0, 1.0));
      } catch (error) {
        _report(error);
      }
    }();
  }

  @override
  void music(MusicMood? mood) {
    _wanted = mood;
    if (!enabled) return;
    if (mood == _mood) return;
    _mood = mood;
    _fadeTo(0, const Duration(milliseconds: 700), then: () async {
      await _music.stop();
      if (mood == null || !enabled || _mood != mood) return;
      final tracks = musicTracks[mood]!;
      final track = tracks[_random.nextInt(tracks.length)];
      await _music.setReleaseMode(mood == MusicMood.winTown || mood == MusicMood.winFamily ? ReleaseMode.release : ReleaseMode.loop);
      await _music.play(AssetSource('music/$track.m4a'), volume: 0);
      _fadeTo(_musicTarget, const Duration(milliseconds: 2200));
    });
  }

  /// Il nastro delle scene è inciso a volume pieno: va tenuto sotto gli effetti.
  double get _sceneVolume => (effectsVolume * 0.6).clamp(0.0, 1.0);

  /// Il sottofondo (pioggia, grilli) sta sotto a tutto.
  double get _ambienceVolume => (effectsVolume * 0.45).clamp(0.0, 1.0);

  bool _enabled = true;
  MusicMood? _wanted;

  @override
  bool get enabled => _enabled;

  /// Spento vuol dire silenzio, subito: musica, sottofondo, scene ed effetti.
  /// Riacceso, riparte la musica del momento in cui si è.
  @override
  set enabled(bool on) {
    if (on == _enabled) return;
    _enabled = on;
    if (!on) {
      _fade?.cancel();
      for (final player in [_player, _music, _ambience, ..._shortPlayers]) {
        player.stop().then<void>((_) {}, onError: _report);
      }
      _mood = null;
      final ambience = _ambienceGroup;
      _ambienceGroup = null;
      _resumeAmbience = ambience;
    } else {
      final mood = _wanted;
      if (mood != null) music(mood);
      final ambience = _resumeAmbience;
      if (ambience != null) this.ambience(ambience);
    }
  }

  FxGroup? _resumeAmbience;

  double _musicVolume = 0.5;
  double _effectsVolume = 0.8;

  @override
  double get musicVolume => _musicVolume;

  @override
  set musicVolume(double volume) {
    _musicVolume = volume;
    _fadeTo(_musicTarget, const Duration(milliseconds: 250));
  }

  @override
  double get effectsVolume => _effectsVolume;

  @override
  set effectsVolume(double volume) {
    _effectsVolume = volume;
    // Anche quello che sta già suonando si adegua.
    _ambience.setVolume(_ambienceVolume).then<void>((_) {}, onError: _report);
    _player.setVolume(_sceneVolume).then<void>((_) {}, onError: _report);
  }

  @override
  void meme(Meme meme, {Duration after = Duration.zero}) {
    if (!enabled || !memeMode || effectsVolume <= 0) return;
    () async {
      try {
        if (after > Duration.zero) await Future<void>.delayed(after);
        if (!memeMode) return;
        await _ready;
        final player = _shortPlayers[_nextShort++ % _shortPlayers.length];
        await player.stop();
        await player.play(AssetSource(meme.asset), volume: effectsVolume * 0.7);
      } catch (error) {
        _report(error);
      }
    }();
  }

  @override
  void ambience(FxGroup? group) {
    if (!enabled) {
      _resumeAmbience = group;
      return;
    }
    if (group == _ambienceGroup) return;
    _ambienceGroup = group;
    () async {
      try {
        // Via quello di prima, piano.
        for (var v = _ambience.volume; v > 0.01; v -= 0.08) {
          await _ambience.setVolume(v);
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        await _ambience.stop();
        if (group == null || !enabled || _ambienceGroup != group) return;
        await _ambience.setReleaseMode(ReleaseMode.loop);
        await _ambience.play(AssetSource(group.asset(ambienceTake[group] ?? 1)), volume: 0);
        final target = _ambienceVolume;
        for (var v = 0.0; v < target; v += 0.05) {
          if (_ambienceGroup != group) return;
          await _ambience.setVolume(v);
          await Future<void>.delayed(const Duration(milliseconds: 60));
        }
        await _ambience.setVolume(target);
      } catch (error) {
        _report(error);
      }
    }();
  }

  @override
  void duckMusic(bool ducked) {
    _duck = ducked ? 0.3 : 1;
    _fadeTo(_musicTarget, const Duration(milliseconds: 600));
  }

  double get _musicTarget => enabled ? (musicVolume * _duck).clamp(0.0, 1.0) : 0;

  /// Porta la musica al volume [target] a piccoli passi, ogni 40 ms.
  void _fadeTo(double target, Duration length, {Future<void> Function()? then}) {
    _fade?.cancel();
    final steps = max(1, length.inMilliseconds ~/ 40);
    var step = 0;
    final start = _music.volume;
    _fade = Timer.periodic(const Duration(milliseconds: 40), (timer) async {
      step++;
      final t = (step / steps).clamp(0.0, 1.0);
      await _music.setVolume(start + (target - start) * t);
      if (step >= steps) {
        timer.cancel();
        await then?.call();
      }
    });
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
    try {
      await _player.stop();
    } catch (error) {
      _report(error);
    }
  }

  void _report(Object error) => debugPrint('Audio: $error');
}

List<Uint8List> _composeAllCues(Object? _) => [for (final cue in Cue.values) composeCue(cue)];
