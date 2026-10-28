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
/// Premi per parlare: lasciare il tasto mette la traccia in muto (non passa
/// niente), e il microfono resta pronto per [warm]; così ripremere parla
/// subito. Passato quel tempo senza parlare la traccia si toglie e il
/// microfono del telefono si spegne del tutto.
class LiveKitVoiceEngine extends VoiceEngine {
  /// Quanto il microfono resta pronto dopo aver lasciato il tasto.
  static const warm = Duration(seconds: 20);

  Timer? _cool;
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

  @override
  bool get microphoneOn => _room?.localParticipant?.isMicrophoneEnabled() ?? false;

  @override
  double get level => _room?.localParticipant?.audioLevel ?? 0;

  @override
  Future<void> connect(String url, String token) async {
    await disconnect();
    final room = lk.Room(
      roomOptions: const lk.RoomOptions(
        adaptiveStream: false,
        dynacast: false,
        defaultAudioCaptureOptions: lk.AudioCaptureOptions(
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
          // Il muto ferma l'invio, non la cattura: ripremere è immediato
          // (la cattura si chiude dopo [warm], vedi [_coolDown]).
          stopAudioCaptureOnMute: false,
        ),
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
      ..on<lk.ParticipantPermissionsUpdatedEvent>((_) => _changed())
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
  Future<bool> setMicrophone(bool on) async {
    final local = _room?.localParticipant;
    if (local == null) return false;
    _cool?.cancel();
    try {
      await local.setMicrophoneEnabled(on);
      if (!on) _cool = Timer(warm, _coolDown);
      _changed();
      return true;
    } catch (_) {
      _changed();
      return false;
    }
  }

  /// Nessuno parla da un po': la traccia si toglie, il microfono si spegne.
  Future<void> _coolDown() async {
    final local = _room?.localParticipant;
    if (local == null || local.isMicrophoneEnabled()) return;
    final publication = local.getTrackPublicationBySource(lk.TrackSource.microphone);
    if (publication == null) return;
    try {
      await local.removePublishedTrack(publication.sid);
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
    _cool?.cancel();
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
