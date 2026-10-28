import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import 'voice_engine.dart';

/// La voce su LiveKit: solo audio, dal vivo. Niente video, niente dati,
/// niente registrazioni: il token del server non le permette nemmeno.
///
/// Ci si abbona a mano (autoSubscribe spento): si sente solo chi non è
/// zittito né bloccato. I bloccati non ricevono la nostra voce: il server di
/// LiveKit applica i permessi d'ascolto che questo dispositivo pubblica.
/// Le brevi perdite di rete le ricuce LiveKit da solo (riconnessione e
/// ripresa); se si arrende, [onLost].
///
/// Premi per parlare: la traccia del microfono si pubblica già in muto
/// appena si ha la parola ([prepareMicrophone]), così premere toglie solo il
/// muto e la voce passa dal primo istante; lasciare rimette il muto (non
/// passa niente). La traccia resta per tutta la fase e si toglie solo quando
/// la parola se ne va o si esce ([releaseMicrophone]).
class LiveKitVoiceEngine extends VoiceEngine {
  /// Il microfono: cancellazione dell'eco, niente rumore, e il muto che
  /// ferma l'invio, non la cattura (togliere il muto è immediato).
  static const _capture = lk.AudioCaptureOptions(
    echoCancellation: true,
    noiseSuppression: true,
    autoGainControl: true,
    stopAudioCaptureOnMute: false,
  );

  Future<bool>? _preparing;
  lk.Room? _room;
  lk.EventsListener<lk.RoomEvent>? _events;
  Set<String> _unheard = const {};
  Set<String> _deafTo = const {};
  bool _leaving = false;

  @override
  bool get connected => _room?.connectionState == lk.ConnectionState.connected;

  @override
  Set<String> get participants => {...?_room?.remoteParticipants.keys};

  @override
  Set<String> get speaking => {for (final p in _room?.activeSpeakers ?? const <lk.Participant>[]) p.identity};

  @override
  String? get selfIdentity => _room?.localParticipant?.identity;

  lk.LocalTrackPublication? get _mic => _room?.localParticipant?.getTrackPublicationBySource(lk.TrackSource.microphone);

  /// In onda solo se la traccia stessa non è in muto (il muto vero, quello
  /// che spegne l'invio), non solo quello annunciato al server.
  @override
  bool get microphoneOn {
    final mic = _mic;
    return mic != null && !mic.muted && !(mic.track?.muted ?? true);
  }

  @override
  bool get microphoneReady => _mic != null;

  @override
  bool get publishAllowed => _room?.localParticipant?.permissions.canPublish ?? false;

  @override
  double get level => _room?.localParticipant?.audioLevel ?? 0;

  @override
  Future<void> connect(String url, String token) async {
    await disconnect();
    final room = lk.Room(
      roomOptions: const lk.RoomOptions(
        adaptiveStream: false,
        dynacast: false,
        defaultAudioCaptureOptions: _capture,
        defaultAudioPublishOptions: lk.AudioPublishOptions(dtx: true),
      ),
    );
    _room = room;
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS)) {
      // Muto e voce in silenzio (niente suono di sistema a ogni pressione),
      // senza riavviare il motore audio.
      try {
        await lk.AudioManager.instance.setMicrophoneMuteMode(lk.MicrophoneMuteMode.inputMixer);
      } catch (_) {}
    }
    final events = room.createListener();
    _events = events;
    events
      ..on<lk.ParticipantConnectedEvent>((_) => _sync())
      ..on<lk.ParticipantDisconnectedEvent>((_) => _changed())
      ..on<lk.TrackPublishedEvent>((_) => _subscribe())
      ..on<lk.TrackUnpublishedEvent>((_) => _changed())
      ..on<lk.ActiveSpeakersChangedEvent>((_) => _changed())
      ..on<lk.LocalTrackPublishedEvent>((_) => _changed())
      ..on<lk.LocalTrackUnpublishedEvent>((_) => _changed())
      ..on<lk.TrackMutedEvent>((_) => _changed())
      ..on<lk.TrackUnmutedEvent>((_) => _changed())
      ..on<lk.ParticipantPermissionsUpdatedEvent>((event) {
        // La parola tolta dal server (un morto, il voto): la traccia se ne
        // va subito, senza aspettare il controller.
        if (event.participant is lk.LocalParticipant && !event.permissions.canPublish) {
          unawaited(releaseMicrophone());
        }
        _changed();
      })
      ..on<lk.RoomReconnectedEvent>((_) => _sync())
      ..on<lk.RoomDisconnectedEvent>((event) {
        if (_leaving || _room != room) return;
        _changed();
        onLost?.call();
      });
    await room.connect(url, token, connectOptions: const lk.ConnectOptions(autoSubscribe: false));
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android)) {
      // Il telefono sta sul tavolo: la voce esce dall'altoparlante.
      try {
        await lk.AudioManager.instance.setSpeakerOutputPreferred(true);
      } catch (_) {}
    }
    await _sync();
  }

  void _changed() => onChanged?.call();

  Future<void> _sync() async {
    await _subscribe();
    _sendPermissions();
    _changed();
  }

  Future<void> _subscribe() async {
    final room = _room;
    if (room == null) return;
    for (final participant in room.remoteParticipants.values) {
      final heard = !_unheard.contains(participant.identity);
      for (final publication in participant.audioTrackPublications) {
        try {
          if (heard && !publication.subscribed) {
            await publication.subscribe();
          } else if (!heard && publication.subscribed) {
            await publication.unsubscribe();
          }
        } catch (_) {}
      }
    }
    _changed();
  }

  void _sendPermissions() {
    final room = _room;
    final local = room?.localParticipant;
    if (room == null || local == null) return;
    if (_deafTo.isEmpty) {
      local.setTrackSubscriptionPermissions(allParticipantsAllowed: true);
      return;
    }
    // Solo chi non è bloccato riceve la nostra voce.
    local.setTrackSubscriptionPermissions(
      allParticipantsAllowed: false,
      trackPermissions: [
        for (final identity in room.remoteParticipants.keys)
          if (!_deafTo.contains(identity)) lk.ParticipantTrackPermission(identity, true, null),
      ],
    );
  }

  @override
  Future<bool> prepareMicrophone() => _preparing ??= _prepare().whenComplete(() => _preparing = null);

  Future<bool> _prepare() async {
    final room = _room;
    final local = room?.localParticipant;
    if (room == null || local == null) return false;
    if (_mic != null) return true;
    lk.LocalAudioTrack? track;
    try {
      track = await lk.LocalAudioTrack.create(_capture);
      // In muto prima di pubblicarla: la traccia spenta (enabled falso)
      // manda solo silenzio, e il server la sa muta fin dall'inizio. Sui
      // telefoni Apple la sessione audio passa adesso a playAndRecord, una
      // volta per fase, invece che alla prima pressione.
      await track.start();
      await track.mute(stopOnMute: false);
      if (_room != room) throw StateError('left');
      await local.publishAudioTrack(track);
      _changed();
      return true;
    } catch (_) {
      if (track != null && _mic?.track != track) {
        try {
          await track.stop();
        } catch (_) {}
      }
      _changed();
      return false;
    }
  }

  @override
  Future<bool> setMicrophone(bool on) async {
    if (_room?.localParticipant == null) return false;
    try {
      var mic = _mic;
      if (mic == null) {
        if (!on) return true;
        if (!await prepareMicrophone()) return false;
        mic = _mic;
        if (mic == null) return false;
      }
      if (on) {
        await mic.unmute(stopOnMute: false);
      } else {
        await mic.mute(stopOnMute: false);
      }
      _changed();
      return true;
    } catch (_) {
      _changed();
      return false;
    }
  }

  @override
  Future<void> releaseMicrophone() async {
    await _preparing;
    final local = _room?.localParticipant;
    final mic = _mic;
    if (local == null || mic == null) return;
    try {
      await mic.mute(stopOnMute: false);
      await local.removePublishedTrack(mic.sid);
    } catch (_) {}
    _changed();
  }

  @override
  Future<void> setPrivacy({required Set<String> unheard, required Set<String> deafTo}) async {
    _unheard = unheard;
    _deafTo = deafTo;
    await _subscribe();
    _sendPermissions();
  }

  @override
  Future<void> disconnect() async {
    final room = _room;
    if (room == null) return;
    _leaving = true;
    try {
      await _events?.dispose();
      await room.disconnect();
      await room.dispose();
    } catch (_) {
    } finally {
      _events = null;
      _room = null;
      _leaving = false;
      _changed();
    }
  }

  @override
  Future<void> dispose() => disconnect();
}
