import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'roster.dart';

/// La foto di una persona e come va inquadrata.
@immutable
class PortraitPhoto {
  final ImageProvider image;

  /// Dove cade il centro dell'inquadratura dentro la foto.
  final Alignment alignment;

  const PortraitPhoto(this.image, {this.alignment = const Alignment(defaultPhotoX, defaultPhotoY)});

  @override
  bool operator ==(Object other) =>
      other is PortraitPhoto && other.image == image && other.alignment == alignment;

  @override
  int get hashCode => Object.hash(image, alignment);
}

/// Le facce vere che questo telefono conosce, per nome. Chi disegna un
/// ritratto chiede qui: se c'è una foto la usa, altrimenti disegna.
///
/// Qui dentro ci sono solo nomi e facce: niente che riguardi i ruoli. Una
/// foto dice chi è qualcuno, mai da che parte sta.
class PortraitRegistry extends ChangeNotifier {
  /// Il registro che i ritratti consultano. Lo sostituisce chi installa un
  /// elenco, prima che l'app disegni qualcosa.
  static PortraitRegistry instance = PortraitRegistry();

  Map<String, PortraitPhoto> _byName = const {};

  /// La foto di chi si chiama [name], se ne ha una.
  PortraitPhoto? photoOf(String name) => _byName.isEmpty ? null : _byName[Roster.nameKey(name)];

  /// Sostituisce tutte le facce note con [photos], da nome a foto.
  void replaceAll(Map<String, PortraitPhoto> photos) {
    final next = {for (final entry in photos.entries) Roster.nameKey(entry.key): entry.value};
    if (mapEquals(next, _byName)) return;
    for (final photo in next.values) {
      if (!_byName.containsValue(photo)) _warmUp(photo.image);
    }
    _byName = next;
    notifyListeners();
  }

  /// Decodifica la foto subito, così il primo ritratto che la mostra la
  /// trova pronta. Una foto illeggibile non è un dramma: resta il disegno.
  static void _warmUp(ImageProvider image) {
    final stream = image.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (_, _) => stream.removeListener(listener),
      onError: (_, _) => stream.removeListener(listener),
    );
    stream.addListener(listener);
  }
}
