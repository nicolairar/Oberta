import 'package:flutter/services.dart';

import '../sound/sound_stage.dart';

export '../sound/sound_stage.dart' show Press;

/// Un tasto che si sente e si sente sotto le dita: un suono e una vibrazione
/// leggera, poi l'azione. Se l'azione è `null` il tasto resta spento.
VoidCallback? pressed(VoidCallback? action, [Press feel = Press.tap]) {
  if (action == null) return null;
  return () {
    switch (feel) {
      case Press.confirm || Press.chips || Press.shuffle:
        HapticFeedback.mediumImpact();
      case Press.back:
        HapticFeedback.lightImpact();
      case Press.tap || Press.toggle || Press.card:
        HapticFeedback.selectionClick();
    }
    SoundStage.instance.press(feel);
    action();
  };
}
