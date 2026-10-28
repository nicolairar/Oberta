import 'package:flutter/painting.dart';

import '../rules/role.dart';

/// Le tre mani di prova, una per colore: rosso la Famiglia, oro la Città,
/// verde chi gioca da solo. [id] è quello che il server registra
/// (`tutorial_complete(faction)`): per giocare in classifica servono tutte e tre.
enum TutorialStory {
  family('family', Role.mafioso, Color(0xFFE5606A)),
  city('town', Role.detective, Color(0xFFD4AF37)),
  solo('solo', Role.fesso, Color(0xFF6FBF9A));

  final String id;
  final Role role;
  final Color color;

  const TutorialStory(this.id, this.role, this.color);

  static TutorialStory? byId(String? id) => values.where((s) => s.id == id).firstOrNull;
}

/// Chi deve sapere che una mano di prova è finita davvero (non saltata):
/// l'app online lo registra qui e lo manda al server.
abstract final class TutorialProgress {
  static void Function(TutorialStory story)? onComplete;
}
