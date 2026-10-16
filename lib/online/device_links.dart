import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import 'incoming_links.dart';

/// Porta in [inbox] i link con cui il telefono apre l'app: quello che l'ha
/// avviata e quelli che arrivano mentre gira.
///
/// Il flusso di `app_links` è condiviso (lo ascolta anche Supabase), e chi
/// arriva tardi può perdersi il link d'avvio: per questo lo si chiede anche
/// a parte, e lo stesso link arrivato due volte di fila si imbuca una volta.
void listenToDeviceLinks(IncomingLinks inbox) {
  final links = AppLinks();
  Uri? last;
  DateTime? lastAt;

  void deliver(Uri? uri) {
    if (uri == null) return;
    final now = DateTime.now();
    if (uri == last && lastAt != null && now.difference(lastAt!) < const Duration(seconds: 3)) return;
    last = uri;
    lastAt = now;
    inbox.deliver(uri);
  }

  links.uriLinkStream.listen(deliver, onError: (Object error) => debugPrint('Link non letto: $error'));
  unawaited(
    links.getInitialLink().then(deliver, onError: (Object error) => debugPrint('Link d\'avvio non letto: $error')),
  );
}
