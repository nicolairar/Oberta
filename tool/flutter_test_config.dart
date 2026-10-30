import 'dart:async';

import 'package:oberta/ui/season/season.dart';

/// I fotogrammi degli strumenti non cambiano col giorno in cui si fanno: la
/// festa si vede solo dove si chiede.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  SeasonLooks.debugCalendarOff = true;
  await testMain();
}
