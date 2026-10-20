import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// Che cosa risponde il server su questo dispositivo (vedi la migrazione
/// 20261029090000_one_active_device.sql).
class SessionAnswer {
  /// Questo dispositivo è quello che gioca.
  final bool active;

  /// Il nome del dispositivo che gioca adesso ("iPhone", "Mac", "Steam").
  final String? activeLabel;

  /// Questo dispositivo ha chiesto di giocare e aspetta: l'altro non ha
  /// ancora risposto.
  final bool waiting;

  /// Un altro dispositivo chiede di giocare (solo se questo è attivo).
  final String? contenderLabel;

  const SessionAnswer({required this.active, this.activeLabel, this.waiting = false, this.contenderLabel});

  factory SessionAnswer.fromJson(Map<String, Object?> json) => SessionAnswer(
        active: json['active'] == true,
        activeLabel: json['active_label'] as String?,
        waiting: json['waiting'] == true,
        contenderLabel: json['contender_label'] as String?,
      );
}

/// Il server delle sessioni: chiedere di giocare qui, chiedere com'è, e
/// sapere quando qualcosa cambia.
abstract class DeviceSessionRepository {
  Future<SessionAnswer> claim(String sessionId, String deviceLabel, {bool force = false});

  Future<SessionAnswer> status(String sessionId);

  /// Un colpo ogni volta che la riga delle sessioni dell'account cambia.
  Stream<void> changes();
}

enum DeviceSessionState {
  /// Non si sa ancora, o nessuno è entrato.
  idle,

  /// Si gioca qui.
  active,

  /// Due dispositivi vogliono giocare: entrambi vedono la domanda.
  contested,

  /// Gioca l'altro dispositivo: qui si può solo riprendere.
  displaced,
}

/// Un id nuovo per ogni avvio dell'app.
String newDeviceSessionId([Random? random]) {
  final r = random ?? Random.secure();
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return List.generate(24, (_) => chars[r.nextInt(chars.length)]).join();
}

/// Come si chiama questo dispositivo, per l'altro.
String deviceLabelHere() {
  if (kIsWeb) return 'Web';
  if (Platform.isIOS) return 'iPhone';
  if (Platform.isAndroid) return 'Android';
  if (Platform.isMacOS) return 'Mac';
  // Fuori dal Mac, il desktop si scarica da Steam.
  if (Platform.isWindows || Platform.isLinux) return 'Steam/PC';
  return '?';
}

/// Un solo dispositivo alla volta per account. Chiede la sessione
/// all'ingresso, batte il cuore ogni [heartbeat], ascolta i cambi e dice
/// alla UI se si gioca qui, se c'è da scegliere, o se gioca l'altro.
class DeviceSession extends ChangeNotifier {
  final DeviceSessionRepository _repository;
  final String sessionId;
  final String deviceLabel;
  final Duration heartbeat;

  DeviceSessionState _state = DeviceSessionState.idle;
  String? _otherLabel;
  Timer? _timer;
  StreamSubscription<void>? _changes;
  bool _busy = false;

  DeviceSession(
    this._repository, {
    required this.sessionId,
    required this.deviceLabel,
    this.heartbeat = const Duration(seconds: 30),
  });

  static DeviceSession? instance;

  DeviceSessionState get state => _state;

  /// L'altro dispositivo: chi gioca, o chi chiede di giocare.
  String? get otherLabel => _otherLabel;

  bool get blocked => _state == DeviceSessionState.contested || _state == DeviceSessionState.displaced;

  /// All'ingresso: chiede di giocare qui, senza scavalcare nessuno.
  Future<void> start() async {
    _changes ??= _repository.changes().listen((_) => refresh());
    _timer ??= Timer.periodic(heartbeat, (_) => refresh());
    await _run(() => _repository.claim(sessionId, deviceLabel));
  }

  /// All'uscita dall'account: si smette di ascoltare.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _changes?.cancel();
    _changes = null;
    _set(DeviceSessionState.idle, null);
  }

  /// «GIOCO QUA»: questo dispositivo prende il posto dell'altro.
  Future<void> playHere() => _run(() => _repository.claim(sessionId, deviceLabel, force: true));

  Future<void> refresh() async {
    if (_timer == null) return;
    // Senza risposta ancora (il profilo non c'era): si richiede di giocare.
    if (_state == DeviceSessionState.idle) return _run(() => _repository.claim(sessionId, deviceLabel));
    await _run(() => _repository.status(sessionId));
  }

  /// Il server ha rifiutato una scrittura con `other_device`.
  void otherDeviceRejected() {
    if (_state == DeviceSessionState.displaced) return;
    _set(DeviceSessionState.displaced, _otherLabel);
    unawaited(refresh());
  }

  Future<void> _run(Future<SessionAnswer> Function() call) async {
    if (_busy) return;
    _busy = true;
    try {
      _apply(await call());
    } catch (error) {
      debugPrint('Sessione: $error');
    } finally {
      _busy = false;
    }
  }

  void _apply(SessionAnswer answer) {
    if (answer.active) {
      if (answer.contenderLabel case final other?) {
        _set(DeviceSessionState.contested, other);
      } else {
        _set(DeviceSessionState.active, null);
      }
    } else if (answer.waiting) {
      _set(DeviceSessionState.contested, answer.activeLabel);
    } else {
      _set(DeviceSessionState.displaced, answer.activeLabel);
    }
  }

  void _set(DeviceSessionState state, String? other) {
    if (state == _state && other == _otherLabel) return;
    _state = state;
    _otherLabel = other;
    notifyListeners();
  }

  /// Segue l'account: chi entra chiede la sessione, chi esce la lascia.
  void follow(Listenable auth, bool Function() signedIn) {
    void sync() => signedIn() ? unawaited(start()) : stop();
    auth.addListener(sync);
    sync();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
