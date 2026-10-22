import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Aggiornamento obbligatorio. Due controlli:
///
/// * i negozi: su iOS la ricerca dell'App Store, sul desktop l'ultima
///   release di GitHub. Se lì c'è una versione più alta di questa, si
///   aggiorna. Il risultato resta in cache per un'ora;
/// * il server: `app_requirements(platform)` dà la build minima
///   (`min_build_<platform>`, vedi 20261103090000_mandatory_update.sql) e
///   ogni chiamata di una build più vecchia torna `update_required`.
///
/// Se un controllo non risponde (niente rete, limite di GitHub) non blocca
/// nulla: il gioco su un telefono solo resta giocabile offline.

const appStoreFallbackUrl = 'https://apps.apple.com/app/id6822433258';
const desktopFallbackUrl = 'https://github.com/nicolairar/Oberta/releases/latest';
const playStoreFallbackUrl = 'https://play.google.com/store/apps/details?id=com.obertagame.oberta';

/// La piattaforma come la chiama il server (`x-app-platform`).
String? appPlatformHere() {
  if (kIsWeb) return null;
  if (Platform.isIOS) return 'ios';
  if (Platform.isAndroid) return 'android';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isWindows) return 'windows';
  if (Platform.isLinux) return 'linux';
  return null;
}

String fallbackStoreUrl(String? platform) => switch (platform) {
      'ios' => appStoreFallbackUrl,
      'android' => playStoreFallbackUrl,
      _ => desktopFallbackUrl,
    };

/// Confronta due versioni "1.2.0" (anche "v1.2.0", "1.2.0+59"): negativo se
/// [a] è più vecchia, zero se uguali, positivo se più nuova.
int compareVersions(String a, String b) {
  List<int> parts(String v) {
    final core = v.trim().replaceFirst(RegExp('^[vV]'), '').split(RegExp('[+-]')).first;
    return [for (final p in core.split('.')) int.tryParse(p) ?? 0];
  }

  final x = parts(a);
  final y = parts(b);
  for (var i = 0; i < x.length || i < y.length; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d.sign;
  }
  return 0;
}

/// L'ultima versione pubblicata e dove scaricarla.
class StoreRelease {
  final String version;
  final String url;

  const StoreRelease(this.version, this.url);

  Map<String, Object?> toJson() => {'version': version, 'url': url};

  static StoreRelease? fromJson(Object? json) {
    if (json is! Map) return null;
    final version = json['version'];
    final url = json['url'];
    if (version is! String || url is! String || version.isEmpty || url.isEmpty) return null;
    return StoreRelease(version, url);
  }
}

/// Chiede al negozio l'ultima versione. Null se non ce n'è nessuna.
abstract class StoreReleaseSource {
  /// Distingue le cache di negozi diversi.
  String get cacheKey;

  Future<StoreRelease?> latest();
}

/// Scarica un testo: `dart:io` in produzione, una funzione nei test.
typedef FetchText = Future<String> Function(Uri uri);

Future<String> fetchTextWithHttp(Uri uri) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final request = await client.getUrl(uri).timeout(const Duration(seconds: 8));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(HttpHeaders.userAgentHeader, 'oberta-app');
    final response = await request.close().timeout(const Duration(seconds: 8));
    final body = await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) throw HttpException('HTTP ${response.statusCode}', uri: uri);
    return body;
  } finally {
    client.close(force: true);
  }
}

/// iOS: la ricerca dell'App Store (`version`, `trackViewUrl`).
class AppStoreLookup implements StoreReleaseSource {
  final String bundleId;
  final String country;
  final FetchText fetch;

  const AppStoreLookup({this.bundleId = 'com.obertagame.oberta', this.country = 'it', this.fetch = fetchTextWithHttp});

  @override
  String get cacheKey => 'appstore';

  @override
  Future<StoreRelease?> latest() async {
    final uri = Uri.https('itunes.apple.com', '/lookup', {'bundleId': bundleId, 'country': country});
    final json = jsonDecode(await fetch(uri));
    final results = json is Map ? json['results'] : null;
    if (results is! List || results.isEmpty || results.first is! Map) return null;
    final app = results.first as Map;
    final version = app['version'];
    if (version is! String) return null;
    final url = app['trackViewUrl'];
    return StoreRelease(version, url is String && url.isNotEmpty ? url : appStoreFallbackUrl);
  }
}

/// Desktop: l'ultima release di GitHub (tag "v1.2.0"). Porta dritti allo
/// zip di questa piattaforma, se c'è, altrimenti alla pagina della release.
class GithubReleaseLookup implements StoreReleaseSource {
  final String repository;
  final String platform;
  final FetchText fetch;

  const GithubReleaseLookup({
    this.repository = 'nicolairar/Oberta',
    required this.platform,
    this.fetch = fetchTextWithHttp,
  });

  @override
  String get cacheKey => 'github.$platform';

  @override
  Future<StoreRelease?> latest() async {
    final json = jsonDecode(await fetch(Uri.https('api.github.com', '/repos/$repository/releases/latest')));
    if (json is! Map) return null;
    final tag = json['tag_name'];
    if (tag is! String || tag.isEmpty) return null;
    var url = json['html_url'] is String ? json['html_url'] as String : desktopFallbackUrl;
    final assets = json['assets'];
    if (assets is List) {
      for (final asset in assets) {
        if (asset is Map &&
            asset['name'] is String &&
            (asset['name'] as String).startsWith('oberta-$platform') &&
            asset['browser_download_url'] is String) {
          url = asset['browser_download_url'] as String;
          break;
        }
      }
    }
    return StoreRelease(tag, url);
  }
}

/// Quel che il server chiede a questa piattaforma.
class AppRequirements {
  final int minBuild;
  final String? storeUrl;

  const AppRequirements({required this.minBuild, this.storeUrl});

  factory AppRequirements.fromJson(Map<String, Object?> json) => AppRequirements(
        minBuild: (json['min_build'] as num?)?.toInt() ?? 0,
        storeUrl: json['store_url'] as String?,
      );
}

abstract class AppRequirementsRepository {
  Future<AppRequirements> requirements(String platform);
}

/// Dove resta l'ultima risposta del negozio, con l'ora.
abstract class UpdateCache {
  Future<String?> read(String key);

  Future<void> write(String key, String value);
}

class MemoryUpdateCache implements UpdateCache {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class PrefsUpdateCache implements UpdateCache {
  final _prefs = SharedPreferencesAsync();

  @override
  Future<String?> read(String key) async {
    try {
      return await _prefs.getString('update.$key');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _prefs.setString('update.$key', value);
    } catch (_) {}
  }
}

/// Perché si deve aggiornare.
enum UpdateReason {
  /// Il negozio ha una versione più nuova.
  newerRelease,

  /// Il server non accetta più questa build.
  serverMinimum,
}

class UpdateBlock {
  final UpdateReason reason;
  final String url;

  /// La versione del negozio, per [UpdateReason.newerRelease].
  final String? latestVersion;

  const UpdateBlock(this.reason, this.url, {this.latestVersion});
}

/// Decide se questa build deve aggiornarsi. Una volta bloccata, resta
/// bloccata: il programma non diventa più nuovo da solo.
class UpdateGate extends ChangeNotifier {
  final String version;
  final int? build;
  final String? platform;
  final StoreReleaseSource? store;
  final AppRequirementsRepository? server;
  final UpdateCache cache;
  final Duration cacheFor;
  final DateTime Function() now;

  UpdateBlock? _block;
  Future<void>? _checking;

  UpdateGate({
    required this.version,
    required this.build,
    required this.platform,
    this.store,
    this.server,
    UpdateCache? cache,
    this.cacheFor = const Duration(hours: 1),
    DateTime Function()? now,
  })  : cache = cache ?? MemoryUpdateCache(),
        now = now ?? DateTime.now;

  static UpdateGate? instance;

  UpdateBlock? get block => _block;

  bool get blocked => _block != null;

  /// All'avvio e al ritorno in primo piano.
  Future<void> check() => _checking ??= _check().whenComplete(() => _checking = null);

  /// Una chiamata è tornata `update_required`.
  void serverRejected() {
    if (_block != null) return;
    _set(UpdateBlock(UpdateReason.serverMinimum, fallbackStoreUrl(platform)));
    unawaited(_serverUrl().then((url) {
      if (url != null && _block?.reason == UpdateReason.serverMinimum) {
        _set(UpdateBlock(UpdateReason.serverMinimum, url));
      }
    }));
  }

  Future<void> _check() async {
    if (_block != null) return;
    final release = await _latestRelease();
    if (release != null && compareVersions(release.version, version) > 0) {
      _set(UpdateBlock(UpdateReason.newerRelease, release.url, latestVersion: release.version));
      return;
    }
    final build = this.build;
    final platform = this.platform;
    final server = this.server;
    if (build == null || platform == null || server == null) return;
    try {
      final needs = await server.requirements(platform);
      if (build < needs.minBuild && _block == null) {
        _set(UpdateBlock(UpdateReason.serverMinimum, _usable(needs.storeUrl) ?? fallbackStoreUrl(platform)));
      }
    } catch (error) {
      debugPrint('Aggiornamento: server muto ($error)');
    }
  }

  Future<String?> _serverUrl() async {
    final platform = this.platform;
    final server = this.server;
    if (platform == null || server == null) return null;
    try {
      return _usable((await server.requirements(platform)).storeUrl);
    } catch (_) {
      return null;
    }
  }

  String? _usable(String? url) => url != null && url.startsWith('https://') ? url : null;

  Future<StoreRelease?> _latestRelease() async {
    final store = this.store;
    if (store == null) return null;
    final key = 'latest.${store.cacheKey}';
    final cached = await cache.read(key);
    if (cached != null) {
      try {
        final json = jsonDecode(cached) as Map;
        final at = DateTime.fromMillisecondsSinceEpoch((json['at'] as num).toInt());
        final age = now().difference(at);
        if (!age.isNegative && age < cacheFor) {
          return json['none'] == true ? null : StoreRelease.fromJson(json['release']);
        }
      } catch (_) {}
    }
    try {
      final release = await store.latest();
      await cache.write(
        key,
        jsonEncode({
          'at': now().millisecondsSinceEpoch,
          if (release == null) 'none': true else 'release': release.toJson(),
        }),
      );
      return release;
    } catch (error) {
      // Offline o limite raggiunto: non si blocca nessuno.
      debugPrint('Aggiornamento: negozio muto ($error)');
      return null;
    }
  }

  void _set(UpdateBlock block) {
    _block = block;
    notifyListeners();
  }
}
