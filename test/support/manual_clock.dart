import 'package:oberta/online/game/game_clock.dart';

/// Un orologio che va avanti solo a mano: i timer dell'autorità (bot,
/// scadenze) scattano quando il test lo dice.
class ManualClock implements GameClock {
  DateTime _now = DateTime(2026, 10, 17, 21);
  final List<_ManualTimer> _timers = [];

  @override
  DateTime now() => _now;

  @override
  GameTimer schedule(Duration after, void Function() action) {
    final timer = _ManualTimer(_now.add(after), action);
    _timers.add(timer);
    return timer;
  }

  int get pending => _timers.where((timer) => !timer.cancelled).length;

  /// Va avanti fino al prossimo timer e lo fa scattare. Falso se non ce n'è.
  bool fireNext() {
    _timers.removeWhere((timer) => timer.cancelled);
    if (_timers.isEmpty) return false;
    _timers.sort((a, b) => a.due.compareTo(b.due));
    final next = _timers.removeAt(0);
    if (next.due.isAfter(_now)) _now = next.due;
    next.action();
    return true;
  }

  /// Va avanti di [duration], facendo scattare i timer che scadono intanto.
  void elapse(Duration duration) {
    final until = _now.add(duration);
    while (true) {
      _timers.removeWhere((timer) => timer.cancelled);
      final due = [for (final timer in _timers) if (!timer.due.isAfter(until)) timer]
        ..sort((a, b) => a.due.compareTo(b.due));
      if (due.isEmpty) break;
      final next = due.first;
      _timers.remove(next);
      if (next.due.isAfter(_now)) _now = next.due;
      next.action();
    }
    _now = until;
  }
}

class _ManualTimer implements GameTimer {
  final DateTime due;
  final void Function() action;
  bool cancelled = false;

  _ManualTimer(this.due, this.action);

  @override
  void cancel() => cancelled = true;
}
