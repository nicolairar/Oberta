import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../ui/widgets/death_scene.dart';
import '../ui/widgets/verdict_scene.dart';
import 'cue_deck.dart';
import 'cue_sounds.dart';
import 'ambience.dart';
import 'fx_groups.dart';
import 'meme_beat.dart';
import 'memes.dart';
import 'music_tracks.dart';
import 'scene_cues.dart';
import 'sound_onsets.dart';
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
  StreamSubscription<void>? _oneShotEnd;
  double _duck = 1;
  final Map<FxGroup, int> _lastTake = {};
  late final Future<void> _ready = _setUp();

  /// Per misurare (tool/audio_sync): chiamato ogni volta che parte un suono
  /// di una scena, col lettore, la registrazione, il punto da cui parte,
  /// quando (su [clock], in microsecondi) la scena l'ha chiesto e se il
  /// lettore era già pronto.
  static void Function(SceneCue cue, AudioPlayer player, String asset, Duration from, int called, bool ready)? probe;

  static final Stopwatch clock = Stopwatch()..start();

  /// Il ritardo misurato tra il play e il suono vero, che le scene anticipano.
  final LeadMeter _lead = LeadMeter();

  DeviceStage() {
    _ready.then<void>((_) {}, onError: _report);
    _cues.then<void>((_) {}, onError: _report);
    for (final player in [_player, _memePlayer, _voicePlayer, ..._shortPlayers,
      for (final deck in [..._musicDecks, ..._ambienceDecks, ..._atmosphereDecks]) deck.player]) {
      _quiet(player);
    }
    _warmUp().then<void>((_) {}, onError: _report);
  }

  /// Appena l'app parte: i passi con cui comincia ogni scena già copiati
  /// sul disco, e il ritardo del lettore già misurato, con qualche passo a
  /// volume zero (il primo, che sveglia l'audio, di solito non conta).
  /// Così anche la prima scena della sera è a tempo dal primo passo.
  Future<void> _warmUp() async {
    await _ready;
    final steps = [for (var i = 1; i <= 4; i++) 'sounds/step_$i.wav'];
    for (final asset in steps) {
      await _file(asset);
    }
    // Una tavola che scricchiola: abbastanza lunga da leggerne la posizione
    // mentre suona (un passo finisce in un decimo di secondo).
    final plank = DeviceFileSource(await _file('sounds/plank.wav'));
    const patience = Duration(seconds: 2);
    final player = _quiet(AudioPlayer());
    try {
      for (var i = 0; i < 5; i++) {
        await player.setSource(plank).timeout(patience);
        await player.setVolume(0).timeout(patience);
        final called = clock.elapsedMicroseconds;
        await player.resume().timeout(patience);
        _measure(player, Duration.zero, called);
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await player.stop().timeout(patience);
      }
    } finally {
      await player.dispose();
    }
  }

  /// Di serie un lettore chiede a che punto è a ogni fotogramma, finché
  /// suona: con la musica sempre accesa vuol dire chiedere un fotogramma
  /// nuovo dopo l'altro, e una chiamata al sistema per lettore ogni volta.
  /// Qui nessuno ascolta quella posizione: la si chiede solo quando serve.
  static AudioPlayer _quiet(AudioPlayer player) => player..positionUpdater = null;

  /// Da dove parte davvero [asset] (saltato il silenzio in testa) e quanto
  /// suona da lì.
  static ({Duration from, Duration length}) _shapeOf(String asset) {
    final shape = soundShapes[asset];
    if (shape == null) return (from: Duration.zero, length: const Duration(seconds: 2));
    return (from: Duration(milliseconds: shape.$1), length: Duration(milliseconds: shape.$2 - shape.$1));
  }

  /// Il punto in cui far partire [asset], se non è l'inizio.
  static Duration? _startOf(String asset) {
    final from = _shapeOf(asset).from;
    return from > Duration.zero ? from : null;
  }

  /// Una registrazione di [group] diversa dall'ultima, quando se ne ha la scelta.
  int _takeOf(FxGroup group) {
    var take = 1 + _random.nextInt(group.count);
    if (group.count > 1 && take == _lastTake[group]) take = take % group.count + 1;
    _lastTake[group] = take;
    return take;
  }

  /// I file dei suoni copiati dagli asset al disco, dove i lettori li
  /// leggono: una copia sola per file, anche se lo chiedono in due insieme.
  final Map<String, Future<String>> _files = {};

  Future<String> _file(String asset) => _files[asset] ??= AudioCache.instance.loadPath(asset)
    // Andata male una volta, la prossima si riprova.
    ..then<void>((_) {}, onError: (Object _) {
      _files.remove(asset);
    });

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
          final asset = 'sounds/${recorded[_nextShort % recorded.length]}.wav';
          await player.play(AssetSource(asset), volume: effectsVolume * gain, position: _startOf(asset));
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




  /// Copia sul disco, prima che servano, le registrazioni che le scene in
  /// arrivo possono suonare (tutte le varianti di ogni gruppo).
  @override
  void prepare(Iterable<DeathAct> acts) {
    final assets = <String>{
      for (final act in acts)
        for (final cue in sceneCuesFor(act, memes: memeMode)) ...[
          if (cue.fx case final fx?) for (var take = 1; take <= fx.count; take++) fx.asset(take),
          if (cue.sample case final name?) 'sounds/$name.wav',
          if (cue.meme case final meme?) meme.asset,
        ],
    };
    for (final asset in assets) {
      _file(asset).then<void>((_) {}, onError: _report);
    }
  }

  @override
  SceneSound arm(CueSheet sheet) => _SceneDeck(this, sheet);

  @override
  Duration get cueLead => _lead.lead;

  /// Un suono di una scena già deciso: quale registrazione, da dove parte,
  /// quanto suona, quanto forte rispetto al volume degli effetti.
  _Resolved _resolve(SceneCue cue) {
    final asset = switch (cue) {
      SceneCue(meme: final meme?) => meme.asset,
      SceneCue(fx: final fx?) => fx.asset(_takeOf(fx)),
      _ => 'sounds/${cue.sample}.wav',
    };
    final shape = _shapeOf(asset);
    // I meme sono fatti per farsi sentire: sopra a tutto il resto.
    final gain = cue.meme != null ? 1.15 : cue.gain * mix.scene;
    return _Resolved(cue, asset, shape.from, shape.length, gain);
  }

  double _volumeOf(_Resolved take) => (effectsVolume * take.gain).clamp(0.0, 1.0);

  /// Se [take] può suonare adesso. Un meme mentre ne suona un altro non
  /// suona: quelli brevi si mettono in coda (a freddo), quelli lunghi no.
  bool _mayPlay(_Resolved take) {
    if (!enabled || effectsVolume <= 0) return false;
    final meme = take.cue.meme;
    if (meme == null) return true;
    if (!memeMode) return false;
    if (_memeUntil.isAfter(DateTime.now())) {
      if (!meme.isLong) this.meme(meme);
      return false;
    }
    _memeStarts(meme);
    return true;
  }

  /// Fa partire un suono di scena su un lettore già pronto: resta solo il play.
  void _fire(AudioPlayer player, _Resolved take, double armed) {
    final volume = _volumeOf(take);
    // Le chiamate al lettore arrivano in ordine: niente attesa tra le due.
    if (volume != armed) player.setVolume(volume).then<void>((_) {}, onError: _report);
    final called = clock.elapsedMicroseconds;
    player.resume().then<void>((_) {}, onError: _report);
    probe?.call(take.cue, player, take.asset, take.from, called, true);
    _measure(player, take.from, called);
  }

  /// Un suono di scena che non ha un lettore pronto: parte come gli altri,
  /// su uno dei lettori dei suoni brevi.
  void _fireCold(_Resolved take) {
    final player = _shortPlayers[_nextShort++ % _shortPlayers.length];
    final called = clock.elapsedMicroseconds;
    () async {
      try {
        await player.stop();
        await player.play(
          DeviceFileSource(await _file(take.asset)),
          volume: _volumeOf(take),
          position: take.from > Duration.zero ? take.from : null,
        );
        probe?.call(take.cue, player, take.asset, take.from, called, false);
      } catch (error) {
        _report(error);
      }
    }();
  }

  /// Quanto ci ha messo il suono a partire davvero, da quando si è premuto
  /// play ([called]): la posizione del lettore dice da quanto sta suonando.
  void _measure(AudioPlayer player, Duration from, int called) {
    var tries = 0;
    Future<void> look() async {
      try {
        final before = clock.elapsedMicroseconds;
        final at = await player.getCurrentPosition();
        final after = clock.elapsedMicroseconds;
        final ran = at == null ? Duration.zero : at - from;
        if (ran > const Duration(milliseconds: 5)) {
          _lead.heard(Duration(microseconds: (before + after) ~/ 2 - ran.inMicroseconds - called));
        } else if (++tries < 8) {
          Timer(const Duration(milliseconds: 40), look);
        }
      } catch (_) {}
    }

    Timer(const Duration(milliseconds: 60), look);
  }


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
    final asset = 'sounds/$name.wav';
    () async {
      try {
        await player.stop();
        await player.play(AssetSource(asset), volume: (effectsVolume * volume).clamp(0.0, 1.0), position: _startOf(asset));
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
        final asset = group.asset(_takeOf(group));
        final player = _shortPlayers[_nextShort++ % _shortPlayers.length];
        await player.stop();
        await player.play(AssetSource(asset), volume: (effectsVolume * volume).clamp(0.0, 1.0), position: _startOf(asset));
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
    _oneShotEnd?.cancel();
    _oneShotEnd = null;
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
        await deck.player.setReleaseMode(mood.oneShot ? ReleaseMode.release : ReleaseMode.loop);
        // Finita la vittoria non resta il silenzio: riparte il loop della
        // schermata in vista.
        if (mood.oneShot && _mood == mood) {
          _oneShotEnd?.cancel();
          _oneShotEnd = deck.player.onPlayerComplete.listen((_) {
            if (_musicDeck == deck && _mood == mood) musicEnded(mood);
          });
        }
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
        _memeStarts(meme);
        await _memePlayer.stop();
        // I meme sono fatti per farsi sentire: sopra a tutto il resto.
        await _memePlayer.play(
          AssetSource(meme.asset),
          volume: (effectsVolume * 1.15).clamp(0.0, 1.0),
          position: _startOf(meme.asset),
        );
      } catch (error) {
        _report(error);
      }
    }();
  }

  /// Parte un meme: fino alla sua fine gli altri aspettano.
  void _memeStarts(Meme meme) {
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

  double _chatDuck = 1;

  @override
  void duckForChat(bool ducked) {
    final duck = ducked ? 0.35 : 1.0;
    if (duck == _chatDuck) return;
    _chatDuck = duck;
    _musicDeck.fadeTo(_musicTarget, Duration(milliseconds: ducked ? 500 : 1500));
  }

  double get _musicTarget =>
      enabled ? (musicVolume * _duck * _memeDuck * _voiceDuck * _chatDuck).clamp(0.0, 1.0) : 0;

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

class _Resolved {
  final SceneCue cue;
  final String asset;
  final Duration from;
  final Duration length;
  final double gain;

  const _Resolved(this.cue, this.asset, this.from, this.length, this.gain);
}

/// Un lettore della scena e i suoni che gli toccano, in ordine.
class _Seat {
  AudioPlayer player;
  final List<int> queue = [];
  int next = 0;

  /// Il suono che ha caricato ed è pronto a partire, se ce n'è uno.
  int? ready;
  double volume = 0;
  bool used = false;
  Timer? later;

  _Seat(this.player);
}

/// I suoni di una scena, ognuno già caricato su un lettore suo prima del
/// suo fotogramma (il piano è [planDeck]): al momento giusto resta solo il
/// play. Un lettore che ha finito il suo si ricarica col prossimo. Quello che
/// non ha fatto in tempo a essere pronto parte a freddo, come prima.
class _SceneDeck implements SceneSound {
  final DeviceStage stage;
  final List<SceneCue> cues;
  final Map<int, _Resolved> _takes = {};
  final Map<int, _Seat> _seatOf = {};
  final List<_Seat> _seats = [];
  final Set<int> _fired = {};
  bool _closed = false;

  /// I lettori si caricano uno alla volta, nell'ordine in cui serviranno:
  /// tutti insieme si rubano il tempo a vicenda, e il primo passo
  /// arriverebbe tardi.
  Future<void> _line = Future<void>.value();

  void _queue(_Seat seat) => _line = _line.then((_) => _arm(seat));

  _SceneDeck(this.stage, CueSheet sheet) : cues = sheet.cues {
    final times = sheet.times;
    final coming = [for (var i = sheet.next; i < cues.length; i++) i];
    for (final i in coming) {
      _takes[i] = stage._resolve(cues[i]);
    }
    final plan = planDeck([for (final i in coming) (at: times[i], length: _takes[i]!.length)]);
    for (var p = 0; p < plan.players; p++) {
      _seats.add(_Seat(DeviceStage._quiet(AudioPlayer())));
    }
    for (var k = 0; k < coming.length; k++) {
      final seat = plan.seats[k];
      if (seat == null) continue;
      _seatOf[coming[k]] = _seats[seat];
      _seats[seat].queue.add(coming[k]);
    }
    if (!stage.enabled || stage.effectsVolume <= 0) return;
    // Il piano dà i lettori in ordine di primo suono.
    for (final seat in _seats) {
      _queue(seat);
    }
  }

  /// Carica sul lettore il prossimo dei suoi suoni che non è ancora partito.
  Future<void> _arm(_Seat seat) async {
    while (!_closed) {
      while (seat.next < seat.queue.length && _fired.contains(seat.queue[seat.next])) {
        seat.next++;
      }
      if (seat.next >= seat.queue.length) return;
      final index = seat.queue[seat.next];
      final take = _takes[index]!;
      try {
        // Ogni tanto un lettore non dice mai di essere pronto: non può
        // fermare tutti gli altri, che si caricano dopo di lui.
        const patience = Duration(seconds: 2);
        if (seat.used) await seat.player.stop().timeout(patience);
        seat.used = true;
        await seat.player.setSource(DeviceFileSource(await stage._file(take.asset))).timeout(patience);
        if (take.from > Duration.zero) await seat.player.seek(take.from).timeout(patience);
        seat.volume = stage._volumeOf(take);
        await seat.player.setVolume(seat.volume).timeout(patience);
      } catch (error) {
        if (_closed) return;
        stage._report(error);
        // Questo suono partirà a freddo; per i prossimi, un lettore nuovo.
        seat.player.dispose().then<void>((_) {}, onError: (Object _) {});
        seat.player = DeviceStage._quiet(AudioPlayer());
        seat.used = false;
        seat.next++;
        continue;
      }
      if (_closed) return;
      if (!_fired.contains(index)) {
        seat.ready = index;
        return;
      }
    }
  }

  @override
  void fire(int index) {
    if (_closed || !_fired.add(index)) return;
    final take = _takes[index] ?? stage._resolve(cues[index]);
    final seat = _seatOf[index];
    if (!stage._mayPlay(take)) {
      if (seat != null && seat.ready == index) {
        seat.ready = null;
        _queue(seat);
      }
      return;
    }
    if (seat != null && seat.ready == index) {
      seat.ready = null;
      stage._fire(seat.player, take, seat.volume);
      // Finito questo, il lettore si prepara per il prossimo.
      seat.later = Timer(take.length + const Duration(milliseconds: 40), () => _queue(seat));
    } else {
      stage._fireCold(take);
    }
  }

  @override
  void release() {
    if (_closed) return;
    _closed = true;
    for (final seat in _seats) {
      seat.later?.cancel();
      seat.player.dispose().then<void>((_) {}, onError: stage._report);
    }
  }
}

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
