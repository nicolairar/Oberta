import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../settings/app_settings.dart';
import '../../sound/sound_stage.dart';
import '../safety.dart';
import 'livekit_voice_engine.dart';
import 'voice_engine.dart';
import 'voice_models.dart';

export 'voice_models.dart';

/// Chi è chi, per una schermata: da un'identità della voce (un posto, "s3"
/// in partita, "m3" nella stanza) al profilo (per i blocchi) e al nome (per
/// la lista di chi si sente).
typedef VoiceDirectory = ({String? Function(String identity) profileOf, String? Function(String identity) nameOf});

/// La voce di una stanza, su questo dispositivo. Una sola per stanza, divisa
/// fra le schermate che la mostrano (la stanza e la partita sopra di lei):
/// [acquire] e [release].
///
/// Il server decide tutto: a ogni cambio di fase ([phase]) si chiede il
/// permesso di nuovo, e si entra nella stanza che il server dà, con i diritti
/// che dà. Quando il server dice «fra poco» ([VoiceGrant.retryIn]) si
/// richiede allora; quando la stanza si perde (rete, server) si riprova con
/// calma. Il microfono si accende solo se il modo è [VoiceMode.mic], il
/// permesso lo concede e il tasto è tenuto premuto: si parla solo così
/// (premi per parlare, niente microfono aperto).
///
/// I bloccati ([BlockedPlayers]) non si sentono mai e non ci sentono mai:
/// il server di LiveKit non manda loro la nostra voce.
class VoiceController extends ChangeNotifier {
  final VoiceTokenSource source;
  final String roomId;
  final VoiceEngine engine;
  final AppSettings settings;

  /// La musica si abbassa mentre si è in una stanza con qualcuno.
  final void Function(bool ducked) duck;

  /// Ogni quanto, collegati, si richiede il permesso: tiene il server al
  /// corrente (chi è uscito dalla stanza perde la voce anche senza fasi).
  final Duration keepFresh;

  VoiceController({
    required this.source,
    required this.roomId,
    required this.engine,
    AppSettings? settings,
    void Function(bool ducked)? duck,
    this.keepFresh = const Duration(seconds: 150),
  }) : settings = settings ?? AppSettings.instance,
       duck = duck ?? SoundStage.instance.duckForChat {
    engine.onChanged = _engineChanged;
    engine.onLost = _lost;
    this.settings.addListener(_settingsChanged);
    BlockedPlayers.ids.addListener(_applyPrivacy);
    _mode = this.settings.voiceMode;
  }

  static final Map<String, VoiceController> _rooms = {};

  /// Il motore vero (LiveKit); i test lo sostituiscono.
  static VoiceEngine Function() engineFactory = LiveKitVoiceEngine.new;

  int _users = 0;
  final List<VoiceDirectory> _directories = [];

  /// La voce di [roomId], condivisa; [directory] dice chi è chi per chi la
  /// prende. Si rende con [release], con la stessa [directory].
  static VoiceController acquire(VoiceTokenSource source, String roomId, {VoiceDirectory? directory}) {
    final controller = _rooms[roomId] ??= VoiceController(source: source, roomId: roomId, engine: engineFactory());
    controller._users++;
    if (directory != null) controller._directories.add(directory);
    return controller;
  }

  void release({VoiceDirectory? directory}) {
    if (directory != null) _directories.remove(directory);
    if (--_users > 0) return;
    if (_rooms[roomId] == this) _rooms.remove(roomId);
    dispose();
  }

  VoiceGrant _grant = VoiceGrant.none;
  VoiceMode _mode = VoiceMode.listen;
  final Map<Object, String> _phases = {};
  bool _disposed = false;
  Future<void>? _running;
  bool _again = false;
  bool _connecting = false;

  /// Chi tiene premuto adesso: il pulsante (ogni pulsante a schermo è il
  /// suo), il tasto V ([keyboard]). Si parla finché ne resta uno; un
  /// pulsante che se ne va lascia solo la sua presa, mai quella degli altri.
  final Set<Object> _holders = {};
  bool get _held => _holders.isNotEmpty;

  /// La presa del tasto V, sul PC.
  static const Object keyboard = #voiceKeyboard;
  Future<void>? _micRun;
  int _keyUsers = 0;
  bool _offline = false;
  int _failures = 0;
  Timer? _retry;
  Timer? _fresh;
  VoiceRefusal? _refusal;
  bool _ducked = false;
  String? _privacy;
  final Set<String> _muted = {};

  VoiceGrant get grant => _grant;
  VoiceMode get mode => _mode;

  /// Il server ha detto che qui la voce non c'è (spenta, o non si è seduti).
  bool get unavailable => _refusal == VoiceRefusal.unavailable || _refusal == VoiceRefusal.notMember;

  bool get connected => engine.connected;
  bool get connecting => _connecting;

  /// Si può parlare adesso, per il server.
  bool get mayTalk => connected && _grant.canPublish;

  /// Il microfono è acceso (si sta trasmettendo).
  bool get live => engine.microphoneOn;

  bool get holding => _held;

  /// La voce dovrebbe esserci ma la rete o il server non rispondono: si
  /// riprova da soli.
  bool get offline => _offline;

  /// Il server ha detto che la voce si apre fra poco (la fase sta partendo).
  bool get opensSoon => !connected && _grant.retryIn != null;

  /// Quanto forte arriva la propria voce, da 0 a 1 (mentre si parla).
  double get level => live ? engine.level.clamp(0.0, 1.0) : 0;

  Set<String> get participants => engine.participants;

  bool isSpeaking(String identity) => connected && engine.speaking.contains(identity);

  bool isMuted(String identity) => _muted.contains(identity);

  String? profileOf(String identity) {
    for (final d in _directories.reversed) {
      final profile = d.profileOf(identity);
      if (profile != null) return profile;
    }
    return null;
  }

  String nameOf(String identity) {
    for (final d in _directories.reversed) {
      final name = d.nameOf(identity);
      if (name != null) return name;
    }
    return identity;
  }

  /// La fase della partita (o della stanza) è cambiata: si chiede di nuovo.
  /// Ogni schermata ([from]) ha la sua chiave: cambia solo quando cambia lei.
  void phase(String key, {Object from = VoiceController}) {
    if (_phases[from] == key) return;
    _phases[from] = key;
    if (unavailable) return;
    refresh();
  }

  /// Chiede il permesso di nuovo ed entra (o esce) di conseguenza. Una
  /// richiesta alla volta: quelle che arrivano nel mentre ne fanno una sola,
  /// subito dopo, e aspettano quella.
  Future<void> refresh() {
    if (_disposed) return Future.value();
    if (_running case final running?) {
      _again = true;
      return running;
    }
    return _running = _run().whenComplete(() => _running = null);
  }

  Future<void> _run() async {
    do {
      _again = false;
      await _refreshOnce();
    } while (_again && !_disposed);
  }

  Future<void> _refreshOnce() async {
    _retry?.cancel();
    _fresh?.cancel();
    if (_mode == VoiceMode.off) {
      _refusal = null;
      await _leave();
      return;
    }
    final VoiceGrant next;
    try {
      next = await source.grant(roomId);
    } on VoiceRefused catch (refused) {
      _refusal = refused.reason;
      if (refused.reason == VoiceRefusal.network) {
        _offline = true;
        _backoff();
      } else {
        await _leave();
      }
      _notify();
      return;
    } catch (_) {
      _refusal = VoiceRefusal.network;
      _offline = true;
      _backoff();
      _notify();
      return;
    }
    if (_disposed) return;
    _refusal = null;
    _offline = false;
    if (!next.connects) {
      await _leave();
      _grant = next;
      if (next.retryIn case final wait?) {
        // Un filo dopo l'ora del server: è lui a dire se è aperto.
        _retry = Timer(wait + Duration(milliseconds: 80 + Random().nextInt(220)), refresh);
      }
      _notify();
      return;
    }
    final same =
        engine.connected &&
        next.room == _grant.room &&
        next.identity == _grant.identity &&
        next.canPublish == _grant.canPublish &&
        next.canSubscribe == _grant.canSubscribe;
    _grant = next;
    if (!next.canPublish) _holders.clear();
    if (!same) {
      _connecting = true;
      _notify();
      try {
        await engine.disconnect();
        await engine.connect(next.url!, next.token!);
        _failures = 0;
        _privacy = null;
      } catch (_) {
        _connecting = false;
        _offline = true;
        _backoff();
        _notify();
        return;
      } finally {
        _connecting = false;
      }
    }
    if (_disposed) return;
    _fresh = Timer(keepFresh, refresh);
    await _applyMic();
    await _applyPrivacy();
    _notify();
  }

  /// Dopo un errore: 2, 4, 8… secondi, al più 30.
  void _backoff() {
    _retry?.cancel();
    final wait = Duration(seconds: min(30, 2 << min(_failures, 4)));
    _failures++;
    _retry = Timer(wait, refresh);
  }

  /// La stanza si è chiusa da sola (rete, o il server che ci ha tolto):
  /// si richiede subito, la prima volta, e chi tiene ancora premuto torna a
  /// parlare appena si rientra (se il server lo permette ancora).
  void _lost() {
    if (_disposed) return;
    _grant = VoiceGrant.none;
    _offline = true;
    if (_failures == 0) {
      _retry?.cancel();
      _failures++;
      _retry = Timer(Duration(milliseconds: 300 + Random().nextInt(300)), refresh);
    } else {
      _backoff();
    }
    _notify();
  }

  Future<void> _leave() async {
    _grant = VoiceGrant.none;
    _holders.clear();
    if (engine.connected) await engine.disconnect();
    _privacy = null;
    _applyDuck();
  }

  bool get _wantMic => _mode == VoiceMode.mic && mayTalk && _held;

  /// Porta il microfono dove deve essere: una sola operazione alla volta,
  /// e dopo ognuna si guarda di nuovo (si può aver lasciato il tasto mentre
  /// il microfono si accendeva, o il contrario).
  Future<void> _applyMic() {
    if (_micRun case final running?) return running;
    return _micRun = _syncMic().whenComplete(() => _micRun = null);
  }

  Future<void> _syncMic() async {
    for (var tries = 0; tries < 4; tries++) {
      if (_disposed || !engine.connected) return;
      final want = _wantMic;
      if (want == engine.microphoneOn) return;
      final ok = await engine.setMicrophone(want);
      if (!ok) {
        if (want && _held) {
          // Il microfono non si accende (il sistema lo nega): non si resta
          // a «parlare» nel vuoto.
          _holders.clear();
          _notify();
        }
        return;
      }
    }
  }

  Future<void> _applyPrivacy() async {
    if (_disposed || !engine.connected) return;
    final blocked = BlockedPlayers.ids.value;
    final deaf = {
      for (final identity in engine.participants)
        if (profileOf(identity) case final profile? when blocked.contains(profile)) identity,
    };
    final unheard = {...deaf, ..._muted};
    final key = '${[...unheard]..sort()}|${[...deaf]..sort()}|${[...engine.participants]..sort()}';
    if (key == _privacy) return;
    _privacy = key;
    await engine.setPrivacy(unheard: unheard, deafTo: deaf);
  }

  void _applyDuck() {
    final ducked = engine.connected && engine.participants.isNotEmpty;
    if (ducked == _ducked) return;
    _ducked = ducked;
    duck(ducked);
  }

  void _engineChanged() {
    if (_disposed) return;
    // Rientrati (o il motore che ha cambiato da solo il microfono): chi
    // tiene premuto parla di nuovo, chi non lo tiene resta muto.
    if (engine.connected && _wantMic != engine.microphoneOn) _applyMic();
    _applyPrivacy();
    _notify();
  }

  void _settingsChanged() {
    if (_disposed) return;
    final mode = settings.voiceMode;
    if (mode != _mode) {
      final wasOff = _mode == VoiceMode.off;
      _mode = mode;
      if (mode != VoiceMode.mic) _holders.clear();
      if (mode == VoiceMode.off || wasOff) {
        refresh();
        return;
      }
    }
    _applyMic();
    _notify();
  }

  /// Cambia il modo (e lo ricorda sul dispositivo).
  void setMode(VoiceMode mode) => settings.voiceMode = mode;

  /// Si può tenere premuto adesso: col microfono scelto e la parola data.
  bool get canHold => _mode == VoiceMode.mic && mayTalk;

  /// Se [by] tiene premuto adesso.
  bool holdingBy(Object by) => _holders.contains(by);

  /// Premi per parlare: il pulsante (o il tasto) [by] giù e su. Si parla
  /// finché almeno uno è giù; i rinnovi del permesso e i cambi di fase con
  /// la stessa parola non lo interrompono.
  void hold(bool down, {Object by = VoiceController}) {
    if (down) {
      if (!canHold || !_holders.add(by)) return;
    } else if (!_holders.remove(by)) {
      return;
    }
    _applyMic();
    _notify();
  }

  /// Sul PC: chi mostra la voce ascolta anche il tasto V. Un solo ascolto
  /// per la stanza, finché c'è almeno uno schermo che lo vuole.
  void attachKeyboard() {
    if (_keyUsers++ == 0) HardwareKeyboard.instance.addHandler(handleKey);
  }

  void detachKeyboard() {
    if (_keyUsers == 0 || --_keyUsers > 0) return;
    HardwareKeyboard.instance.removeHandler(handleKey);
    hold(false, by: keyboard);
  }

  /// Non sentire più [identity] (o sentirlo di nuovo), solo qui.
  void toggleMute(String identity) {
    if (!_muted.remove(identity)) _muted.add(identity);
    _applyPrivacy();
    _notify();
  }

  /// Sul PC: V tenuto premuto parla (fuori dai campi di testo). Vero se il
  /// tasto è della voce.
  bool handleKey(KeyEvent event) {
    if (event.logicalKey != LogicalKeyboardKey.keyV) return false;
    if (!canHold) {
      if (event is KeyUpEvent && holdingBy(keyboard)) {
        hold(false, by: keyboard);
        return true;
      }
      return false;
    }
    final focus = FocusManager.instance.primaryFocus?.context;
    if (event is KeyDownEvent && focus != null && focus.findAncestorWidgetOfExactType<EditableText>() != null) {
      return false;
    }
    if (event is KeyDownEvent) {
      hold(true, by: keyboard);
      return true;
    }
    if (event is KeyUpEvent) {
      final was = holdingBy(keyboard);
      hold(false, by: keyboard);
      return was;
    }
    return holdingBy(keyboard);
  }

  void _notify() {
    if (_disposed) return;
    _applyDuck();
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _retry?.cancel();
    _fresh?.cancel();
    if (_keyUsers > 0) HardwareKeyboard.instance.removeHandler(handleKey);
    settings.removeListener(_settingsChanged);
    BlockedPlayers.ids.removeListener(_applyPrivacy);
    if (_ducked == true) duck(false);
    engine.onChanged = null;
    engine.onLost = null;
    engine.dispose();
    super.dispose();
  }
}
