import 'dart:async';

import 'package:flutter/foundation.dart';

/// La cassetta dei link che aprono l'app da fuori: il QR di una stanza
/// inquadrato con la fotocamera, un link in un messaggio. Chi li riceve
/// dal telefono li imbuca con [deliver]; il vicolo li ritira con [take]
/// quando è pronto. Un link arrivato prima che il vicolo ci fosse (l'app
/// aperta proprio dal link) resta lì ad aspettarlo.
class IncomingLinks extends ChangeNotifier {
  Uri? _pending;

  final _steamLinks = StreamController<Uri>.broadcast();

  /// I ritorni di «Collega Steam» (`oberta://steam-link?ticket=..&state=..`):
  /// non sono link per il vicolo, li aspetta chi ha aperto il browser.
  Stream<Uri> get steamLinks => _steamLinks.stream;

  static bool isSteamLink(Uri uri) => uri.scheme == 'oberta' && uri.host == 'steam-link';

  void deliver(Uri uri) {
    if (isSteamLink(uri)) {
      _steamLinks.add(uri);
      return;
    }
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
