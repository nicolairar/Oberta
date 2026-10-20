import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:url_launcher/url_launcher.dart';

import 'online_services.dart';

/// «Accedi con Steam» su desktop, lato app (docs/steam.md, 1.3): apre il
/// browser di sistema sulla Edge Function `steam-auth`, che porta a Steam
/// e torna qui su una porta di loopback (127.0.0.1) con un codice monouso.
/// La password Steam la vede solo il sito di Steam.
class SteamLoopback {
  /// Quanto si aspetta chi entra su Steam nel browser.
  static const timeout = Duration(minutes: 5);

  /// Il valore casuale che lega il ritorno a questo avvio dell'app.
  static String newState([Random? random]) {
    final r = random ?? Random.secure();
    return base64Url.encode(List.generate(32, (_) => r.nextInt(256))).replaceAll('=', '');
  }

  /// Apre il browser e aspetta il ritorno. Restituisce il codice monouso
  /// (da scambiare con la sessione insieme a [state]).
  static Future<String> waitForCode({
    required Uri functionUrl,
    required String state,
    Future<bool> Function(Uri url)? openBrowser,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    try {
      final start = functionUrl.replace(queryParameters: {
        'action': 'start',
        'port': '${server.port}',
        'state': state,
      });
      final opened = await (openBrowser ?? (url) => launchUrl(url, mode: LaunchMode.externalApplication))(start);
      if (!opened) throw const OnlineException(OnlineFailure.unknown, null, 'steam · browser did not open');
      await for (final request in server.timeout(timeout)) {
        if (request.uri.path != '/steam') {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          continue;
        }
        final code = request.uri.queryParameters['code'];
        final ok = code != null && request.uri.queryParameters['state'] == state;
        request.response
          ..statusCode = ok ? HttpStatus.ok : HttpStatus.badRequest
          ..headers.contentType = ContentType.html
          ..write(_page(ok));
        await request.response.close();
        if (ok) return code;
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
