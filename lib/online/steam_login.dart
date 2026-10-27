import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:url_launcher/url_launcher.dart';

import 'online_services.dart';

/// Il browser di sistema con il ritorno su una porta di loopback
/// (127.0.0.1): l'app ascolta, apre il browser e aspetta che la pagina
/// torni lì. Le password le vede solo il sito che le chiede (Steam, Apple,
/// Google). Lo usano «Accedi con Steam» e «Collega Apple / Google».
class BrowserLoopback {
  /// Quanto si aspetta chi entra nel browser.
  static const timeout = Duration(minutes: 5);

  /// Il valore casuale che lega il ritorno a questo avvio dell'app.
  static String newState([Random? random]) {
    final r = random ?? Random.secure();
    return base64Url.encode(List.generate(32, (_) => r.nextInt(256))).replaceAll('=', '');
  }

  /// Ascolta su una porta libera, apre il browser su `start(porta)` e
  /// restituisce i parametri del primo ritorno su [path] che [accept]
  /// accetta.
  static Future<Map<String, String>> wait({
    required FutureOr<Uri> Function(int port) start,
    required String path,
    required bool Function(Map<String, String> query) accept,
    Future<bool> Function(Uri url)? openBrowser,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    try {
      final url = await start(server.port);
      final opened = await (openBrowser ?? (url) => launchUrl(url, mode: LaunchMode.externalApplication))(url);
      if (!opened) throw const OnlineException(OnlineFailure.unknown, null, 'browser did not open');
      await for (final request in server.timeout(timeout)) {
        if (request.uri.path != path) {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          continue;
        }
        final query = request.uri.queryParameters;
        final ok = accept(query);
        request.response
          ..statusCode = ok ? HttpStatus.ok : HttpStatus.badRequest
          ..headers.contentType = ContentType.html
          ..write(_page(ok));
        await request.response.close();
        if (ok) return query;
      }
      throw const OnlineException(OnlineFailure.cancelled);
    } on TimeoutException {
      throw const OnlineException(OnlineFailure.cancelled);
    } finally {
      await server.close(force: true);
    }
  }

  static String _page(bool ok) => '<!doctype html><meta charset="utf-8"><title>Obertà</title>'
      '<body style="background:#07070b;color:#e8dcc0;font-family:Georgia,serif;text-align:center;padding-top:20vh">'
      '<h1 style="color:#c9a227">Obertà</h1><p>${ok ? 'Fatto: torna al gioco. / Done: go back to the game.' : 'Accesso non valido. / Invalid sign-in.'}</p>';
}

/// «Accedi con Steam» su desktop, lato app (docs/steam.md, 1.3): apre il
/// browser di sistema sulla Edge Function `steam-auth`, che porta a Steam
/// e torna qui su una porta di loopback (127.0.0.1) con un codice monouso.
/// La password Steam la vede solo il sito di Steam.
class SteamLoopback {
  static const timeout = BrowserLoopback.timeout;

  static String newState([Random? random]) => BrowserLoopback.newState(random);

  /// Apre il browser e aspetta il ritorno. Restituisce il codice monouso
  /// (da scambiare con la sessione insieme a [state]).
  static Future<String> waitForCode({
    required Uri functionUrl,
    required String state,
    Future<bool> Function(Uri url)? openBrowser,
  }) async {
    final query = await BrowserLoopback.wait(
      start: (port) => functionUrl.replace(queryParameters: {'action': 'start', 'port': '$port', 'state': state}),
      path: '/steam',
      accept: (query) => query['code'] != null && query['state'] == state,
      openBrowser: openBrowser,
    );
    return query['code']!;
  }
}
