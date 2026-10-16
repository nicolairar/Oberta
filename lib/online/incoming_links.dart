import 'package:flutter/foundation.dart';

/// La cassetta dei link che aprono l'app da fuori: il QR di una stanza
/// inquadrato con la fotocamera, un link in un messaggio. Chi li riceve
/// dal telefono li imbuca con [deliver]; il vicolo li ritira con [take]
/// quando è pronto. Un link arrivato prima che il vicolo ci fosse (l'app
/// aperta proprio dal link) resta lì ad aspettarlo.
class IncomingLinks extends ChangeNotifier {
  Uri? _pending;

  void deliver(Uri uri) {
    _pending = uri;
    notifyListeners();
  }

  /// Il link in attesa, che da adesso non c'è più.
  Uri? take() {
    final uri = _pending;
    _pending = null;
    return uri;
  }

  static IncomingLinks instance = IncomingLinks();
}
