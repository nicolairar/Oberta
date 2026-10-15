import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../ui/widgets/verdict_scene.dart';
import 'sound_stage.dart';
import 'verdict_score.dart';

/// Un palco che sa suonare anche i verdetti. Il palco muto non lo è: chi lo
/// chiede a lui non sente niente, e il film parte subito.
abstract interface class VerdictStage {
  /// Avvisa che questi verdetti potrebbero andare in onda a breve.
  void prepareVerdicts(Iterable<VerdictTake> takes);

  /// Fa partire la musica di un verdetto. Come per le scene della notte, il
  /// `Future` si chiude quando la musica è partita.
  FutureOr<void> playVerdict(VerdictTake take);
}

/// Il verdetto chiesto a qualunque palco: chi non sa suonarlo resta muto.
extension SoundStageVerdict on SoundStage {
  void prepareVerdicts([Iterable<VerdictTake> takes = VerdictTake.values]) {
    final stage = this;
    if (stage is VerdictStage) (stage as VerdictStage).prepareVerdicts(takes);
  }

  FutureOr<void> playVerdict(VerdictTake take) {
    final stage = this;
    if (stage is VerdictStage) return (stage as VerdictStage).playVerdict(take);
    return null;
  }
}

/// Incide il nastro di un verdetto in un altro isolate e lo salva in un file
/// temporaneo: restituisce dove.
Future<String> recordVerdictTape(VerdictTake take) async {
  final file = File('${Directory.systemTemp.path}/verdict-${take.name}.wav');
  final bytes = await compute(composeVerdictByIndex, take.index);
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
