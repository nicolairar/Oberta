import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/l10n/app_strings.dart';
import 'package:oberta/settings/app_settings.dart';
import 'package:oberta/ui/desktop/desktop_frame.dart';
import 'package:oberta/ui/desktop/desktop_platform.dart';
import 'package:oberta/settings/display_settings.dart';
import 'package:oberta/ui/screens/home_screen.dart';
import 'package:oberta/ui/widgets/home_posters.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Al primo avvio il biglietto del tutorial sta sotto l'insegna, intero,
/// e nessun manifesto gli finisce sopra: sui telefoni piccoli, medi e grandi
/// e sul PC.
void main() {
  for (final (name, size, top, bottom, desk) in const [
    ('375×667', Size(375, 667), 20.0, 0.0, false),
    ('393×852', Size(393, 852), 59.0, 34.0, false),
    ('430×932', Size(430, 932), 59.0, 34.0, false),
    ('PC 1920×1080', Size(1920, 1080), 0.0, 0.0, true),
  ]) {
    testWidgets('il biglietto del tutorial si vede intero, $name', (tester) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      tester.view.padding = FakeViewPadding(top: top * 2, bottom: bottom * 2);
      addTearDown(tester.view.reset);
      if (desk) {
        DesktopPlatform.debugOverride = true;
        addTearDown(() => DesktopPlatform.debugOverride = null);
      }
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await tester.pumpWidget(MaterialApp(
        locale: AppLanguage.it.locale,
        supportedLocales: AppLanguage.locales,
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        builder: desk ? (context, child) => DesktopFrame(orientation: DesktopOrientation.landscape, child: child!) : null,
        home: HomeScreen(onSettings: () {}, offerTutorial: true),
      ));
      await tester.pumpAndSettle();

      final note = tester.getRect(find.byKey(const Key('tutorial.note')));
      final screen = Offset.zero & size;
      expect(screen.intersect(note), note, reason: 'il biglietto esce dallo schermo');
      final posters = [
        ...find.byType(HomeTonightPoster).evaluate(),
        ...find.byType(HomeSoonPoster).evaluate(),
      ];
      expect(posters, isNotEmpty);
      for (final poster in posters) {
        final rect = tester.getRect(find.byWidget(poster.widget));
        expect(rect.overlaps(note), isFalse, reason: 'un manifesto copre il biglietto ($rect, $note)');
      }

      // Buttato via, il biglietto non torna e i manifesti risalgono.
      await tester.tap(find.byKey(const Key('tutorial.note.dismiss')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tutorial.note')), findsNothing);
      expect(AppSettings.instance.tutorialSeen, isTrue);
    });
  }
}
