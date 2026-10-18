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
import 'meme_beat.dart';
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

  /// Due lettori per la musica e due per il sottofondo, per passare
  /// dall'uno all'altro in dissolvenza incrociata.
  final List<_Deck> _musicDecks = [_Deck(), _Deck()];
  late _Deck _musicDeck = _musicDecks.first;
  final List<_Deck> _ambienceDecks = [_Deck(), _Deck()];
  late _Deck _ambienceDeck = _ambienceDecks.first;

  /// I rumori di fondo (il gallo, gli uccelli, il treno lontano), che si
  /// sovrappongono in dissolvenza.
  final List<_Deck> _atmosphereDecks = [for (var i = 0; i < 5; i++) _Deck()];
  int _nextAtmosphere = 0;

  FxGroup? _ambienceGroup;
  final _random = Random();
  MusicMood? _mood;
  double _duck = 1;
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
        final gain = (cueGains[cue] ?? 0.6) * mix.cue;
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
    // Dissolvenza incrociata: la traccia nuova sale mentre la vecchia scende,
    // senza un secondo di silenzio in mezzo.
    final old = _musicDeck;
    _musicDeck = _musicDecks.firstWhere((deck) => deck != old);
    old.fadeTo(0, const Duration(milliseconds: 1800), then: old.stop);
    if (mood == null) return;
    final deck = _musicDeck;
    () async {
      try {
        final tracks = musicTracks[mood]!;
        final track = tracks[_random.nextInt(tracks.length)];
        await deck.player.stop();
        await deck.player.setReleaseMode(mood == MusicMood.winTown || mood == MusicMood.winFamily ? ReleaseMode.release : ReleaseMode.loop);
        await deck.player.play(AssetSource('music/$track.m4a'), volume: 0);
        deck.volume = 0;
        if (_musicDeck == deck) deck.fadeTo(_musicTarget, const Duration(milliseconds: 2500));
      } catch (error) {
        _report(error);
      }
    }();
  }

  /// Il nastro delle scene è inciso a volume pieno: va tenuto sotto gli effetti.
  double get _sceneVolume => (effectsVolume * 0.6).clamp(0.0, 1.0);

  /// Il sottofondo (pioggia, grilli) sta sotto a tutto.
  double get _ambienceVolume => (effectsVolume * mix.ambience * (_voiceDuck < 1 ? 0.4 : 1)).clamp(0.0, 1.0);

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
      for (final deck in [..._musicDecks, ..._ambienceDecks, ..._atmosphereDecks]) {
        deck.cancel();
      }
      _memeTimer?.cancel();
      _memeDuck = 1;
      for (final player in [_player, _memePlayer, _voicePlayer, ..._shortPlayers, for (final deck in [..._musicDecks, ..._ambienceDecks, ..._atmosphereDecks]) deck.player]) {
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
    _musicDeck.fadeTo(_musicTarget, const Duration(milliseconds: 250));
  }

  @override
  double get effectsVolume => _effectsVolume;

  @override
  set effectsVolume(double volume) {
    _effectsVolume = volume;
    // Anche quello che sta già suonando si adegua.
    _ambienceDeck.fadeTo(_ambienceGroup == null ? 0 : _ambienceVolume, const Duration(milliseconds: 250));
    _player.setVolume(_sceneVolume).then<void>((_) {}, onError: _report);
    _voicePlayer.setVolume(_voiceVolume).then<void>((_) {}, onError: _report);
  }

  @override
  void meme(Meme meme, {Duration after = Duration.zero}) {
    if (!enabled || !memeMode || effectsVolume <= 0) return;
    () async {
      try {
        if (after > Duration.zero) await Future<void>.delayed(after);
        if (!memeMode || !enabled) return;
        await _ready;
        // Mentre suona una canzoncina, i meme brevi aspettano il loro turno:
        // due meme uno sopra l'altro non fanno ridere nessuno.
        final now = DateTime.now();
        if (_memeUntil.isAfter(now)) {
          if (meme.isLong) return;
          await Future<void>.delayed(_memeUntil.difference(now));
          if (!memeMode || !enabled) return;
        }
        _memeUntil = DateTime.now().add(Duration(milliseconds: meme.millis));
        MemeBeat.instance.heard(meme);
        // Il meme è la battuta: la musica si fa da parte. Quelli lunghi la
        // zittiscono del tutto (e il sottofondo con lei), quelli brevi la
        // abbassano per un attimo.
        _memeDuck = meme.isLong ? 0 : 0.35;
        _musicDeck.fadeTo(_musicTarget, const Duration(milliseconds: 150));
        if (meme.isLong) _ambienceDeck.fadeTo(0, const Duration(milliseconds: 300));
        _memeTimer?.cancel();
        _memeTimer = Timer(Duration(milliseconds: meme.millis + 200), () {
          _memeDuck = 1;
          _musicDeck.fadeTo(_musicTarget, const Duration(milliseconds: 1200));
          if (_ambienceGroup != null) _ambienceDeck.fadeTo(_ambienceVolume, const Duration(milliseconds: 1500));
        });
        await _memePlayer.stop();
        // I meme sono fatti per farsi sentire: sopra a tutto il resto.
        await _memePlayer.play(AssetSource(meme.asset), volume: (effectsVolume * 1.15).clamp(0.0, 1.0));
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
    // Anche qui una dissolvenza incrociata lunga: la pioggia che diventa
    // grilli non deve mai "staccare".
    final old = _ambienceDeck;
    _ambienceDeck = _ambienceDecks.firstWhere((deck) => deck != old);
    old.fadeTo(0, const Duration(milliseconds: 3000), then: old.stop);
    if (group == null) return;
    final deck = _ambienceDeck;
    () async {
      try {
        await deck.player.stop();
        await deck.player.setReleaseMode(ReleaseMode.loop);
        await deck.player.play(AssetSource(group.asset(ambienceTake[group] ?? 1)), volume: 0);
        deck.volume = 0;
        if (_ambienceDeck == deck) deck.fadeTo(_ambienceVolume, const Duration(milliseconds: 3500));
      } catch (error) {
        _report(error);
      }
    }();
  }

  /// Un rumore di fondo che entra piano, resta sotto la musica e se ne va
  /// in dissolvenza prima di finire: niente attacchi secchi, niente stacchi.
  /// Più di uno può suonare insieme.
  @override
  void atmosphere(FxGroup group, {Duration after = Duration.zero, double volume = 1}) {
    if (!enabled || effectsVolume <= 0) return;
    () async {
      try {
        if (after > Duration.zero) await Future<void>.delayed(after);
        if (!enabled) return;
        await _ready;
        final deck = _atmosphereDecks[_nextAtmosphere++ % _atmosphereDecks.length];
        deck.cancel();
        await deck.player.stop();
        var take = 1 + _random.nextInt(group.count);
        if (group.count > 1 && take == _lastTake[group]) take = take % group.count + 1;
        _lastTake[group] = take;
        await deck.player.setReleaseMode(ReleaseMode.stop);
        await deck.player.play(AssetSource(group.asset(take)), volume: 0);
        deck.volume = 0;
        final target = (effectsVolume * mix.atmosphere * volume).clamp(0.0, 1.0);
        deck.fadeTo(target, const Duration(milliseconds: 900));
        final length = await deck.player.getDuration();
        if (length == null) return;
        final tail = Duration(milliseconds: min(2500, length.inMilliseconds ~/ 3));
        deck.later(length - tail, () => deck.fadeTo(0, tail));
      } catch (error) {
        _report(error);
      }
    }();
  }

  @override
  void press(Press press) {
    if (!enabled || effectsVolume <= 0) return;
    final (name, gain) = switch (press) {
      Press.tap => ('ui_tap', 1.0),
      Press.confirm => ('ui_confirm', 0.9),
      Press.back => ('ui_back', 0.9),
      Press.toggle => ('ui_toggle', 1.0),
      Press.chips => ('chips_${1 + _random.nextInt(3)}', 1.0),
      Press.card => ('card_place_${1 + _random.nextInt(3)}', 1.0),
      Press.shuffle => ('shuffle', 0.8),
    };
    sample(name, volume: mix.press * gain);
  }

  @override
  void duckMusic(bool ducked) {
    _duck = ducked ? 0.3 : 1;
    _musicDeck.fadeTo(_musicTarget, const Duration(milliseconds: 600));
  }

  /// Il lettore del narratore automatico: una clip alla volta.
  final AudioPlayer _voicePlayer = AudioPlayer();
  double _voiceDuck = 1;

  // La voce è il gioco: sta sopra a tutto, anche con gli effetti bassi.
  double get _voiceVolume => (0.35 + effectsVolume * mix.voice).clamp(0.0, 1.0);

  @override
  void voice(String asset) {
    if (!enabled || effectsVolume <= 0) return;
    () async {
      try {
        await _ready;
        await _voicePlayer.stop();
        await _voicePlayer.play(AssetSource(asset), volume: _voiceVolume);
      } catch (error) {
        _report(error);
      }
    }();
  }

  @override
  void stopVoice() {
    _voicePlayer.stop().then<void>((_) {}, onError: _report);
  }

  /// La voce scende veloce sotto la musica e la riporta su piano: tra una
  /// battuta e l'altra il sottofondo torna a respirare da solo.
  @override
  void duckForVoice(bool ducked) {
    final duck = ducked ? 0.2 : 1.0;
    if (duck == _voiceDuck) return;
    _voiceDuck = duck;
    final fade = Duration(milliseconds: ducked ? 400 : 1400);
    _musicDeck.fadeTo(_musicTarget, fade);
    if (_ambienceGroup != null) _ambienceDeck.fadeTo(_ambienceVolume, fade);
  }

  double get _musicTarget => enabled ? (musicVolume * _duck * _memeDuck * _voiceDuck).clamp(0.0, 1.0) : 0;

  final AudioPlayer _memePlayer = AudioPlayer();
  DateTime _memeUntil = DateTime(0);
  double _memeDuck = 1;
  Timer? _memeTimer;

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

/// Un lettore con il suo volume, che sa salire e scendere piano.
class _Deck {
  final AudioPlayer player = AudioPlayer();
  double volume = 0;
  Timer? _fade;
  Timer? _later;

  void cancel() {
    _fade?.cancel();
    _later?.cancel();
  }

  /// Più tardi, se nel frattempo nessuno ha cambiato idea.
  void later(Duration after, void Function() action) {
    _later?.cancel();
    _later = Timer(after, action);
  }

  /// Porta il volume a [target] a piccoli passi, ogni 40 ms.
  void fadeTo(double target, Duration length, {Future<void> Function()? then}) {
    _fade?.cancel();
    final steps = max(1, length.inMilliseconds ~/ 40);
    var step = 0;
    final start = volume;
    _fade = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      step++;
      final t = (step / steps).clamp(0.0, 1.0);
      volume = start + (target - start) * t;
      player.setVolume(volume).then<void>((_) {}, onError: (Object e) => debugPrint('Audio: $e'));
      if (step >= steps) {
        timer.cancel();
        then?.call().then<void>((_) {}, onError: (Object e) => debugPrint('Audio: $e'));
      }
    });
  }

  Future<void> stop() => player.stop();
}
