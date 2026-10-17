import 'dart:async';

/// Un timer che si può fermare.
abstract class GameTimer {
  void cancel();
}

/// L'ora e i timer dell'autorità. In partita sono quelli veri; nei test un
/// orologio a mano, che va avanti solo quando lo si dice.
abstract class GameClock {
  DateTime now();

  GameTimer schedule(Duration after, void Function() action);
}

class SystemGameClock implements GameClock {
  const SystemGameClock();

  @override
  DateTime now() => DateTime.now();

  @override
  GameTimer schedule(Duration after, void Function() action) => _SystemTimer(Timer(after, action));
}

class _SystemTimer implements GameTimer {
  final Timer _timer;

  _SystemTimer(this._timer);

  @override
  void cancel() => _timer.cancel();
}
