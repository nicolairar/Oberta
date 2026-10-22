import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/l10n/app_strings.dart';
import 'package:oberta/online/app_update.dart';
import 'package:oberta/ui/widgets/app_update_gate.dart';

class _Store implements StoreReleaseSource {
  StoreRelease? release;
  Object? error;
  int calls = 0;

  _Store([this.release]);

  @override
  String get cacheKey => 'test';

  @override
  Future<StoreRelease?> latest() async {
    calls++;
    if (error case final error?) throw error;
    return release;
  }
}

class _Server implements AppRequirementsRepository {
  AppRequirements answer;
  Object? error;

  _Server([this.answer = const AppRequirements(minBuild: 0)]);

  @override
  Future<AppRequirements> requirements(String platform) async {
    if (error case final error?) throw error;
    return answer;
  }
}

void main() {
  group('versions', () {
    test('compare numerically, with or without v and build', () {
      expect(compareVersions('1.10.0', '1.9.9'), 1);
      expect(compareVersions('v1.2.0', '1.2.0'), 0);
      expect(compareVersions('1.2', '1.2.0+59'), 0);
      expect(compareVersions('1.0.0', '1.0.1'), -1);
    });
  });

  group('store lookups', () {
    test('App Store: version and trackViewUrl', () async {
      Uri? asked;
      final lookup = AppStoreLookup(fetch: (uri) async {
        asked = uri;
        return jsonEncode({
          'resultCount': 1,
          'results': [
            {'version': '1.3.0', 'trackViewUrl': 'https://apps.apple.com/it/app/oberta/id6822433258'}
          ]
        });
      });
      final release = await lookup.latest();
      expect(asked!.queryParameters['bundleId'], 'com.obertagame.oberta');
      expect(asked!.queryParameters['country'], 'it');
      expect(release!.version, '1.3.0');
      expect(release.url, contains('id6822433258'));
    });

    test('App Store without the app: nothing', () async {
      final lookup = AppStoreLookup(fetch: (_) async => '{"resultCount":0,"results":[]}');
      expect(await lookup.latest(), isNull);
    });

    test('GitHub: the tag and the zip of this platform', () async {
      final lookup = GithubReleaseLookup(
        platform: 'windows',
        fetch: (_) async => jsonEncode({
          'tag_name': 'v1.2.0',
          'html_url': 'https://github.com/nicolairar/Oberta/releases/tag/v1.2.0',
          'assets': [
            {'name': 'oberta-linux-v1.2.0.zip', 'browser_download_url': 'https://x/linux.zip'},
            {'name': 'oberta-windows-v1.2.0.zip', 'browser_download_url': 'https://x/windows.zip'},
          ],
        }),
      );
      final release = await lookup.latest();
      expect(release!.version, 'v1.2.0');
      expect(release.url, 'https://x/windows.zip');
    });
  });

  group('the gate', () {
    UpdateGate gate({StoreReleaseSource? store, AppRequirementsRepository? server, UpdateCache? cache,
            DateTime Function()? now, int? build = 59}) =>
        UpdateGate(
          version: '1.0.0',
          build: build,
          platform: 'ios',
          store: store,
          server: server,
          cache: cache,
          now: now,
        );

    test('a newer store version blocks, with the store url', () async {
      final g = gate(store: _Store(const StoreRelease('1.1.0', 'https://apps.apple.com/x')), server: _Server());
      await g.check();
      expect(g.block!.reason, UpdateReason.newerRelease);
      expect(g.block!.latestVersion, '1.1.0');
      expect(g.block!.url, 'https://apps.apple.com/x');
    });

    test('the same or an older store version lets play', () async {
      for (final version in ['1.0.0', '0.9.0']) {
        final g = gate(store: _Store(StoreRelease(version, 'https://x')), server: _Server());
        await g.check();
        expect(g.blocked, isFalse, reason: version);
      }
    });

    test('a build under the server minimum blocks', () async {
      final g = gate(server: _Server(const AppRequirements(minBuild: 60, storeUrl: 'https://apps.apple.com/y')));
      await g.check();
      expect(g.block!.reason, UpdateReason.serverMinimum);
      expect(g.block!.url, 'https://apps.apple.com/y');
    });

    test('minimum 0 (the default) blocks nobody', () async {
      final g = gate(server: _Server());
      await g.check();
      expect(g.blocked, isFalse);
    });

    test('offline: neither the store nor the server answers, nothing blocks', () async {
      final store = _Store()..error = const SocketException('offline');
      final server = _Server()..error = const SocketException('offline');
      final g = gate(store: store, server: server);
      await g.check();
      expect(g.blocked, isFalse);
    });

    test('without a build number the server minimum is not applied', () async {
      final g = gate(server: _Server(const AppRequirements(minBuild: 60)), build: null);
      await g.check();
      expect(g.blocked, isFalse);
    });

    test('update_required from any call blocks, url from the server', () async {
      final g = gate(server: _Server(const AppRequirements(minBuild: 60, storeUrl: 'https://apps.apple.com/z')));
      g.serverRejected();
      expect(g.block!.reason, UpdateReason.serverMinimum);
      expect(g.block!.url, appStoreFallbackUrl);
      await pumpEventQueue();
      expect(g.block!.url, 'https://apps.apple.com/z');
    });

    test('once blocked it stays blocked', () async {
      final store = _Store(const StoreRelease('1.1.0', 'https://x'));
      final g = gate(store: store);
      await g.check();
      store.release = null;
      await g.check();
      expect(g.blocked, isTrue);
    });

    test('the store answer is cached for an hour', () async {
      var clock = DateTime(2026, 10, 22, 12);
      final cache = MemoryUpdateCache();
      final store = _Store(const StoreRelease('1.0.0', 'https://x'));
      final g = gate(store: store, cache: cache, now: () => clock);
      await g.check();
      clock = clock.add(const Duration(minutes: 30));
      store.release = const StoreRelease('1.1.0', 'https://x');
      await g.check();
      expect(store.calls, 1);
      expect(g.blocked, isFalse);
      clock = clock.add(const Duration(minutes: 31));
      await g.check();
      expect(store.calls, 2);
      expect(g.blocked, isTrue);
    });

    test('a failed lookup is not cached', () async {
      final cache = MemoryUpdateCache();
      final store = _Store()..error = const SocketException('offline');
      final g = gate(store: store, cache: cache);
      await g.check();
      store
        ..error = null
        ..release = const StoreRelease('2.0.0', 'https://x');
      await g.check();
      expect(store.calls, 2);
      expect(g.blocked, isTrue);
    });
  });

  group('the screen', () {
    Widget app(UpdateGate gate, List<Uri> opened, {AppLanguage language = AppLanguage.it}) => MaterialApp(
          locale: language.locale,
          supportedLocales: AppLanguage.locales,
          localizationsDelegates: const [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => UpdateGateView(
            gate: gate,
            openStore: (url) async => opened.add(url),
            child: child!,
          ),
          home: const Scaffold(body: Text('home')),
        );

    testWidgets('covers the app and opens the store', (tester) async {
      final gate = UpdateGate(
        version: '1.0.0',
        build: 59,
        platform: 'ios',
        store: _Store(const StoreRelease('1.1.0', 'https://apps.apple.com/x')),
      );
      final opened = <Uri>[];
      await tester.pumpWidget(app(gate, opened));
      expect(find.text('Aggiornamento obbligatorio'), findsNothing);
      await tester.runAsync(gate.check);
      await tester.pump();
      expect(find.text('Aggiornamento obbligatorio'), findsOneWidget);
      expect(find.textContaining('1.1.0'), findsOneWidget);
      await tester.tap(find.text('AGGIORNA'));
      expect(opened, [Uri.parse('https://apps.apple.com/x')]);
      // Non si chiude: «indietro» non lo toglie.
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Aggiornamento obbligatorio'), findsOneWidget);
    });

    testWidgets('in English after update_required', (tester) async {
      final gate = UpdateGate(version: '1.0.0', build: 59, platform: 'windows');
      await tester.pumpWidget(app(gate, [], language: AppLanguage.en));
      gate.serverRejected();
      await tester.pump();
      expect(find.text('Update required'), findsOneWidget);
      expect(find.text('UPDATE'), findsOneWidget);
    });

    testWidgets('rechecks when the app comes back to the foreground', (tester) async {
      final store = _Store(const StoreRelease('1.0.0', 'https://x'));
      final gate = UpdateGate(version: '1.0.0', build: 59, platform: 'ios', store: store, cacheFor: Duration.zero);
      await tester.pumpWidget(app(gate, []));
      store.release = const StoreRelease('1.0.1', 'https://x');
      await tester.runAsync(() async {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
      expect(store.calls, 1);
      expect(find.text('Aggiornamento obbligatorio'), findsOneWidget);
    });
  });
}
