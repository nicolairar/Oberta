import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/online_account.dart';
import 'package:oberta/online/online_models.dart';
import 'package:oberta/online/ranked_models.dart';
import 'package:oberta/settings/app_settings.dart';
import 'package:oberta/settings/settings_store.dart';
import 'package:oberta/ui/screens/online/profile_sheet.dart';
import 'package:oberta/ui/screens/settings_screen.dart';
import 'package:oberta/ui/widgets/platform_marks.dart';

import '../../support/desktop_shots.dart';

FakeOnline _online() {
  final online = FakeOnline()..signInReady(handle: 'anna', level: 7, xp: 140, coins: 1250);
  online.history['me'] = [
    const MatchResult(gameId: 'g1', won: true, role: 'detective', xpGained: 60, levelBefore: 7, levelAfter: 7),
    const MatchResult(gameId: 'g2', won: false, role: 'mafioso', xpGained: 20, levelBefore: 6, levelAfter: 7),
    const MatchResult(gameId: 'g3', won: true, role: 'cittadino', xpGained: 45, levelBefore: 6, levelAfter: 6),
    const MatchResult(
      gameId: 'g4',
      won: false,
      abandoned: true,
      role: 'medico',
      xpGained: 0,
      levelBefore: 6,
      levelAfter: 6,
    ),
  ];
  online.ratings[('me', AppLanguage.it)] = const Rating(30, 2);
  return online;
}

void main() {
  for (final MapEntry(key: label, value: size) in desktopSizes.entries) {
    testWidgets('il fascicolo su desktop $label', (tester) async {
      await useDesktop(tester, size);
      final online = _online();
      final account = OnlineAccount(online.services);
      await tester.pumpWidget(
        desktopApp(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showProfileSheet(context, account: account, onShop: () {}, onSettings: () {}),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await desktopFrames(tester);
      expect(find.byKey(const Key('profile.dossier')), findsOneWidget);
      expect(find.byKey(const Key('profile.coins')), findsOneWidget);
      await saveDesktopShot(tester, 'profile_$label');

      await tester.tap(find.byKey(const Key('profile.close')));
      await desktopFrames(tester, 5);
      expect(find.byKey(const Key('profile.dossier')), findsNothing);
    });

    testWidgets('le impostazioni su desktop $label', (tester) async {
      await useDesktop(tester, size);
      final online = _online();
      final settings = AppSettings(MemorySettingsStore());
      await shootDesktopPage(
        tester,
        'settings_$label',
        (_) => SettingsScreen(settings: settings, online: online.services, versionLabel: '1.0.0 (40)'),
      );
      await tester.tap(find.byKey(const Key('settings.category.screen')));
      await desktopFrames(tester, 5);
      await saveDesktopShot(tester, 'settings_screen_$label');
      await tester.tap(find.byKey(const Key('settings.window.Schermo intero')));
      await desktopFrames(tester, 2);
      expect(settings.windowMode.name, 'fullscreen');
      await tester.tap(find.byKey(const Key('settings.category.account')));
      await desktopFrames(tester, 5);
      await saveDesktopShot(tester, 'settings_account_$label');
      // Su Steam e sul desktop l'account non si elimina da qui; si collega
      // Apple o Google, senza codici.
      expect(find.byKey(const Key('settings.delete')), findsNothing);
      expect(find.byKey(const Key('settings.link')), findsOneWidget);
    });
  }

  testWidgets('il fascicolo di chi gioca con Steam: nome Steam, logo, immagine del profilo', (tester) async {
    await useDesktop(tester, desktopSizes['1080p']!);
    final online = _online()..linkSteam('me', persona: 'Don Vito ☕', avatar: 'https://avatars.steamstatic.com/abc_full.jpg');
    final account = OnlineAccount(online.services);
    await tester.pumpWidget(
      desktopApp(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showProfileSheet(context, account: account, onShop: () {}, onSettings: () {}),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await desktopFrames(tester);
    expect(find.byKey(const Key('profile.steamPersona')), findsOneWidget);
    expect(find.text('Su Steam: Don Vito ☕'), findsOneWidget);
    expect(find.byKey(const Key('mark.steam')), findsNothing, reason: 'no platform logo next to names');
    await saveDesktopShot(tester, 'profile_steam');
    expect(account.profile!.pictureUrl, isNull);
    await tester.tap(find.byKey(const Key('profile.picture.steam')));
    await desktopFrames(tester, 4);
    expect(account.profile!.picture, ProfilePicture.steam);
    expect(account.profile!.pictureUrl, 'https://avatars.steamstatic.com/abc_full.jpg');
    // L'immagine non arriva (niente rete nei test): resta il ritratto.
    expect(find.byType(SteamPicture), findsWidgets);
    await tester.tap(find.byKey(const Key('profile.picture.game')));
    await desktopFrames(tester, 4);
    expect(account.profile!.pictureUrl, isNull);
  });
}
