import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/ui/screens/avatar/barber_mirror_screen.dart';
import 'package:oberta/l10n/lobby_language.dart';
import 'package:oberta/main.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/incoming_links.dart';
import 'package:oberta/online/online_services.dart';

/// Il vicolo con l'online: la targhetta «Accedi», il suggerimento sul
/// manifesto, il cartellino di chi è entrato, l'accesso con email (senza
/// password) e i link delle stanze aperti dalla fotocamera.
void main() {
  late FakeOnline online;

  setUp(() {
    online = FakeOnline()..addPlayer('bruno', handle: 'bruno');
    online.auth.googleAvailable = false;
    OnlineServices.instance = online.services;
  });

  Future<void> openAlley(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(const ObertaApp());
    await tester.pumpAndSettle();
  }

  /// Il profilo nuovo, appena entrati: il nome unico, l'unico nome.
  Future<void> fillProfile(WidgetTester tester, {String handle = 'anna'}) async {
    expect(find.text('IL TUO PROFILO'), findsOneWidget);
    expect(find.byKey(const Key('online.name')), findsNothing, reason: 'niente nome da mostrare a parte');
    await tester.enterText(find.byKey(const Key('online.handle')), handle);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SALVA'));
    await tester.pumpAndSettle();
    // Poi lo specchio del barbiere (non per chi entra da un invito): la
    // faccia si può fare dopo.
    if (find.byKey(const Key('mirror.skip')).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const Key('mirror.skip')));
      await tester.pumpAndSettle();
    }
  }

  group('chi non è entrato', () {
    testWidgets('trova la targhetta «Accedi» in alto, fuori dai manifesti', (tester) async {
      await openAlley(tester);
      final plate = tester.getRect(find.byKey(const Key('home.signIn')));
      final settings = tester.getRect(find.byTooltip('Impostazioni'));
      expect(find.text('ACCEDI'), findsOneWidget);
      expect(plate.top, greaterThanOrEqualTo(59), reason: 'sotto la tacca');
      expect(plate.right, lessThanOrEqualTo(settings.left), reason: 'l\'ingranaggio resta dov\'è');
      expect(plate.height, greaterThanOrEqualTo(34), reason: 'abbastanza grande per un dito');
      expect(tester.getRect(find.text('OBERTÀ')).top, greaterThanOrEqualTo(plate.bottom - 1));
      expect(find.byKey(const Key('home.badge')), findsNothing);
    });

    testWidgets('«Gioca con amici» non porta via: spegne il vicolo e indica «Accedi»', (tester) async {
      await openAlley(tester);
      await tester.tap(find.text('GIOCA\nCON AMICI'));
      await tester.pumpAndSettle();
      expect(find.text('Accedi per giocare online'), findsOneWidget);
      expect(find.text('CHI SEI?'), findsNothing, reason: 'niente pagina online');
      expect(find.text('CREA STANZA'), findsOneWidget, reason: 'si resta nel vicolo');

      // Toccando altrove il vicolo si riaccende, e non succede altro.
      await tester.tapAt(const Offset(200, 700));
      await tester.pumpAndSettle();
      expect(find.text('Accedi per giocare online'), findsNothing);
      expect(find.text('IL TAVOLO'), findsNothing);
      expect(find.text('CHI SEI?'), findsNothing);
    });

    testWidgets('toccando la luce si entra; poi il nome unico, poi il cartellino', (tester) async {
      await openAlley(tester);
      await tester.tap(find.text('GIOCA\nCON AMICI'));
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(find.byKey(const Key('home.signIn'))));
      await tester.pumpAndSettle();
      expect(find.text('CHI SEI?'), findsOneWidget, reason: 'il foglio dell\'accesso');
      expect(find.text('Entra con Google'), findsNothing, reason: 'Google non è configurato');

      await tester.tap(find.text('Entra con Apple'));
      await tester.pumpAndSettle();
      expect(online.auth.signedIn, isTrue);

      // Il nome unico: si vede subito se è libero, e cosa non va.
      await tester.enterText(find.byKey(const Key('online.handle')), 'Bruno');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Questo nome unico è già preso.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('online.handle')), '.anna');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Non può iniziare con un punto o un trattino basso.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('online.handle')), 'str0nz0');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Nome non consentito.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('online.handle')), 'An_na 7!');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byKey(const Key('online.handle')));
      expect(field.controller!.text, 'an_na7', reason: 'sempre minuscolo; spazi e segni non entrano');
      expect(find.text('Libero: è tuo, se lo vuoi.'), findsOneWidget);
      await tester.tap(find.text('SALVA'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mirror.skip')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home.badge')), findsOneWidget);
      expect(find.text('an_na7'), findsOneWidget);
      expect(find.text('LIV. 1'), findsOneWidget);
      expect(find.text('ACCEDI'), findsNothing);
      expect(online.profileOf('me')!.handle, 'an_na7');

      // La targhetta «Il tuo look» sotto il ritratto riapre lo specchio.
      expect(find.text('IL TUO LOOK'), findsOneWidget);
      await tester.tap(find.byKey(const Key('home.mirror')));
      await tester.pumpAndSettle();
      expect(find.byType(BarberMirrorScreen), findsOneWidget);
    });

    testWidgets('se Apple non va, il messaggio gentile e sotto il motivo tecnico', (tester) async {
      await openAlley(tester);
      online.auth.failNext = const OnlineException(
        OnlineFailure.appleDisabled,
        null,
        'validation_failed · 400 · Unsupported provider: provider is not enabled',
      );
      await tester.tap(find.text('ACCEDI'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Entra con Apple'));
      await tester.pumpAndSettle();
      expect(find.text('Accesso con Apple non attivo sul server.'), findsOneWidget);
      expect(find.textContaining('Unsupported provider: provider is not enabled'), findsOneWidget);
      expect(online.auth.signedIn, isFalse);
    });

    testWidgets('chi chiude la finestra di Apple non vede errori', (tester) async {
      await openAlley(tester);
      online.auth.cancelNext = true;
      await tester.tap(find.text('ACCEDI'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Entra con Apple'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('online.failure')), findsNothing);
    });
  });

  group('entra con email, senza password', () {
    Finder said(String text) => find.textContaining(text, findRichText: true);

    /// Dal vicolo: «Accedi», «Entra con email», l'indirizzo, «Mandami il codice».
    Future<void> askCode(WidgetTester tester, {String address = 'prova@oberta.test'}) async {
      await openAlley(tester);
      await tester.tap(find.text('ACCEDI'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('online.signInEmail')));
      await tester.pumpAndSettle();
      expect(said('codice di 6 cifre e un link'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('online.email')), address);
      await tester.tap(find.byKey(const Key('online.emailSend')));
      await tester.pumpAndSettle();
    }

    String codeFor(String address) => online.auth.emailCodes[address]!;

    testWidgets('c\'è per tutti, sotto Apple, e niente password da nessuna parte', (tester) async {
      await openAlley(tester);
      await tester.tap(find.text('ACCEDI'));
      await tester.pumpAndSettle();
      expect(find.text('Entra con Apple'), findsOneWidget);
      expect(find.text('Entra con email'), findsOneWidget);
      expect(
        tester.getRect(find.byKey(const Key('online.signInEmail'))).top,
        greaterThan(tester.getRect(find.text('Entra con Apple')).top),
      );
      expect(said('assword'), findsNothing);
    });

    testWidgets('il codice della mail: sbagliato lo si dice, giusto si entra, poi il profilo', (tester) async {
      await askCode(tester);
      expect(said('Abbiamo scritto a prova@oberta.test'), findsOneWidget);
      expect(online.auth.emailLanguages['prova@oberta.test'], 'it', reason: 'le sue mail in italiano');
      expect(tester.widget<ElevatedButton>(find.byKey(const Key('online.emailVerify'))).onPressed, isNull);

      await tester.enterText(find.byKey(const Key('online.emailCodeInput')), '000000');
      await tester.pumpAndSettle();
      expect(find.text('Codice sbagliato: controlla l\'ultima mail che ti abbiamo mandato.'), findsOneWidget);
      expect(online.auth.signedIn, isFalse);

      await tester.enterText(find.byKey(const Key('online.emailCodeInput')), codeFor('prova@oberta.test'));
      await tester.pumpAndSettle();
      expect(online.auth.signedIn, isTrue, reason: 'a sei cifre entra da solo');
      await fillProfile(tester, handle: 'prova');
      expect(find.byKey(const Key('home.badge')), findsOneWidget);
    });

    testWidgets('incollato con gli spazi, o dentro una frase, il codice va lo stesso', (tester) async {
      await askCode(tester);
      final code = codeFor('prova@oberta.test');
      await tester.enterText(
        find.byKey(const Key('online.emailCodeInput')),
        'Il codice: ${code.substring(0, 3)} ${code.substring(3)}',
      );
      await tester.pumpAndSettle();
      expect(online.auth.signedIn, isTrue);
    });

    testWidgets('il link della mail apre l\'app già dentro: il foglio si chiude da solo', (tester) async {
      await askCode(tester);
      online.auth.openEmailLink('prova@oberta.test');
      await tester.pumpAndSettle();
      expect(online.auth.signedIn, isTrue);
      expect(find.byKey(const Key('online.emailCode')), findsNothing);
      await fillProfile(tester, handle: 'prova');
      expect(find.byKey(const Key('home.badge')), findsOneWidget);
    });

    testWidgets('un link scaduto lo dice, e si resta sul codice', (tester) async {
      await askCode(tester);
      online.auth.expireEmailCodes();
      online.auth.openEmailLink('prova@oberta.test');
      await tester.pumpAndSettle();
      expect(online.auth.signedIn, isFalse);
      expect(said('Il link è scaduto o è già stato usato'), findsOneWidget);
      expect(find.byKey(const Key('online.emailCode')), findsOneWidget);
    });

    testWidgets('rimandare: prima il conto alla rovescia, poi un codice nuovo, e vale solo l\'ultimo', (tester) async {
      await askCode(tester);
      final old = codeFor('prova@oberta.test');
      expect(find.text('Rimanda il codice tra 60 s'), findsOneWidget);
      expect(tester.widget<TextButton>(find.byKey(const Key('online.emailResend'))).onPressed, isNull);
      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Rimanda il codice tra 30 s'), findsOneWidget);
      await tester.pump(const Duration(seconds: 31));
      expect(find.text('Rimanda il codice'), findsOneWidget);

      await tester.tap(find.byKey(const Key('online.emailResend')));
      await tester.pumpAndSettle();
      expect(find.text('Codice nuovo in arrivo: vale solo l\'ultimo.'), findsOneWidget);
      expect(codeFor('prova@oberta.test'), isNot(old));
      await tester.enterText(find.byKey(const Key('online.emailCodeInput')), old);
      await tester.pumpAndSettle();
      expect(online.auth.signedIn, isFalse);
      expect(find.byKey(const Key('online.failure')), findsOneWidget);
      await tester.pump(const Duration(seconds: 61));
    });

    testWidgets('l\'indirizzo storto lo si dice; «Cambia indirizzo» e «Altri modi» tornano indietro', (tester) async {
      await openAlley(tester);
      await tester.tap(find.text('ACCEDI'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('online.signInEmail')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('online.email')), 'non-una-email');
      await tester.tap(find.byKey(const Key('online.emailSend')));
      await tester.pumpAndSettle();
      expect(find.text('Questa email non sembra valida.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('online.emailBack')));
      await tester.pumpAndSettle();
      expect(find.text('Entra con Apple'), findsOneWidget);

      await tester.tap(find.byKey(const Key('online.signInEmail')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('online.email')), 'prova@oberta.test');
      await tester.tap(find.byKey(const Key('online.emailSend')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('online.emailChange')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('online.email')), findsOneWidget);
      await tester.pump(const Duration(seconds: 61));
    });

    testWidgets('col provider Email spento il server lo dice chiaro', (tester) async {
      online.emailEnabled = false;
      await openAlley(tester);
      await tester.tap(find.text('ACCEDI'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('online.signInEmail')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('online.email')), 'prova@oberta.test');
      await tester.tap(find.byKey(const Key('online.emailSend')));
      await tester.pumpAndSettle();
      expect(find.text('Accesso con email non attivo sul server.'), findsOneWidget);
      expect(find.textContaining('email_provider_disabled'), findsOneWidget);
    });
  });

  group('chi è entrato', () {
    testWidgets('la locandina della classificata dice quanti sono solo quando sono tanti', (tester) async {
      online
        ..signInReady(handle: 'anna')
        ..extraOnline = 12;
      await openAlley(tester);
      expect(find.byKey(const Key('home.rankedCount')), findsNothing, reason: 'dodici in giro: meglio tacere');

      online.extraOnline = 40;
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();
      expect(find.text('40 GIOCATORI IN GIRO PER LA CITTÀ'), findsOneWidget);
    });

    testWidgets('ha il cartellino in alto a sinistra, e dal cartellino il profilo', (tester) async {
      online
        ..signInReady(handle: 'anna')
        ..award('me', level: 4, xp: 200, coins: 75);
      await openAlley(tester);
      final badge = tester.getRect(find.byKey(const Key('home.badge')));
      final settings = tester.getRect(find.byTooltip('Impostazioni'));
      expect(badge.left, lessThan(40), reason: 'in alto a sinistra');
      expect(badge.right, lessThan(settings.left), reason: 'l\'ingranaggio resta dov\'è');
      expect(find.text('LIV. 4'), findsOneWidget);
      expect(find.text('75'), findsOneWidget);
      expect(find.text('ACCEDI'), findsNothing);

      await tester.tap(find.byKey(const Key('home.badge')));
      await tester.pumpAndSettle();
      expect(find.text('anna'), findsNWidgets(2), reason: 'sul cartellino e sul profilo, sempre il nome unico');
      expect(find.byKey(const Key('profile.dossier')), findsOneWidget);
      expect(find.byType(BarberMirrorScreen), findsNothing, reason: 'il cartellino apre il profilo, non lo specchio');
      expect(find.descendant(of: find.byKey(const Key('profile.level')), matching: find.text('4')), findsOneWidget, reason: 'il sigillo del livello sul fascicolo');
      expect(find.text('200 su 250 punti esperienza'), findsOneWidget);
      expect(find.text('200 / 250 XP'), findsOneWidget);
      expect(tester.getSize(find.byKey(const Key('profile.xpFill'))).height, greaterThan(0), reason: 'la barra si vede');

      // Il server cambia il saldo: il fascicolo e il cartellino si aggiornano da soli.
      online.award('me', xp: 230, coins: 90);
      await tester.pumpAndSettle();
      expect(find.text('230 su 250 punti esperienza'), findsOneWidget);
      expect(find.text('230 / 250 XP'), findsOneWidget);
      expect(find.text('90'), findsNWidgets(2));

      await tester.scrollUntilVisible(find.text('ESCI DALL\'ACCOUNT'), 200);
      await tester.ensureVisible(find.text('ESCI DALL\'ACCOUNT'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ESCI DALL\'ACCOUNT'));
      await tester.pumpAndSettle();
      expect(online.auth.signedIn, isFalse);
      expect(find.text('ACCEDI'), findsOneWidget);
      expect(find.byKey(const Key('home.badge')), findsNothing);
    });

    testWidgets('il ritratto apre il profilo; solo «Il tuo look» apre lo specchio', (tester) async {
      online.signInReady(handle: 'anna');
      await openAlley(tester);
      await tester.tap(find.byKey(const Key('home.portrait')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('profile.dossier')), findsOneWidget);
      expect(find.byType(BarberMirrorScreen), findsNothing);
      await tester.tapAt(const Offset(200, 20));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('home.mirror')));
      await tester.pumpAndSettle();
      expect(find.byType(BarberMirrorScreen), findsOneWidget);
    });

    testWidgets('il saldo spinto dal server arriva al cartellino senza ricaricare', (tester) async {
      online.signInReady(handle: 'anna');
      await openAlley(tester);
      expect(find.text('LIV. 1'), findsOneWidget);
      online.award('me', level: 2, xp: 30, coins: 150);
      await tester.pumpAndSettle();
      expect(find.text('LIV. 2'), findsOneWidget);
      expect(find.text('150'), findsOneWidget);
    });

    testWidgets('dalle monete del cartellino si entra in bottega', (tester) async {
      online
        ..signInReady(handle: 'anna')
        ..award('me', coins: 750);
      await openAlley(tester);
      await tester.tap(find.byKey(const Key('home.shop')));
      await tester.pumpAndSettle();
      expect(find.text('LA BOTTEGA'), findsOneWidget);
      expect(find.byKey(const Key('shop.coins')), findsOneWidget);
    });

    testWidgets('«Gioca con amici» porta alla sala online', (tester) async {
      online.signInReady(handle: 'anna');
      await openAlley(tester);
      await tester.tap(find.text('GIOCA\nCON AMICI'));
      await tester.pumpAndSettle();
      expect(find.text('APRI UNA STANZA'), findsOneWidget);
    });

    testWidgets('chi aveva un nome che non vale più se lo rifà, poi il cartellino', (tester) async {
      online
        ..signInReady(handle: 'anna')
        ..forgetHandle('me');
      await openAlley(tester);
      await fillProfile(tester, handle: 'annetta');
      expect(find.byKey(const Key('home.badge')), findsOneWidget);
      expect(online.profileOf('me')!.handle, 'annetta');
    });
  });

  group('il QR di una stanza, aperto dalla fotocamera', () {
    testWidgets('chi è entrato va dritto al tavolo', (tester) async {
      online.signInReady(handle: 'anna');
      final room = online.openRoomAs('bruno', LobbyLanguage.it);
      await openAlley(tester);
      IncomingLinks.instance.deliver(Uri.parse('oberta://room/${room.code}'));
      await tester.pumpAndSettle();
      expect(find.text('LA STANZA'), findsOneWidget);
      expect(find.text('2 su 12 al tavolo'), findsOneWidget);
    });

    testWidgets('il link d\'avvio aspetta il vicolo', (tester) async {
      online.signInReady(handle: 'anna');
      final room = online.openRoomAs('bruno', LobbyLanguage.it);
      IncomingLinks.instance.deliver(Uri.parse('oberta://room/${room.code}'));
      await openAlley(tester);
      expect(find.text('LA STANZA'), findsOneWidget);
    });

    testWidgets('chi non è entrato prima entra e si fa il profilo, poi siede', (tester) async {
      final room = online.openRoomAs('bruno', LobbyLanguage.it);
      await openAlley(tester);
      IncomingLinks.instance.deliver(Uri.parse('oberta://room/${room.code.toLowerCase()}'));
      await tester.pumpAndSettle();
      expect(find.text('Accedi per entrare nella stanza ${room.code}.'), findsOneWidget);
      await tester.tap(find.text('Entra con Apple'));
      await tester.pumpAndSettle();
      await fillProfile(tester);
      expect(find.text('LA STANZA'), findsOneWidget);
      expect(find.text('2 su 12 al tavolo'), findsOneWidget);
    });

    testWidgets('chi chiude l\'accesso resta nel vicolo, e il link si dimentica', (tester) async {
      final room = online.openRoomAs('bruno', LobbyLanguage.it);
      await openAlley(tester);
      IncomingLinks.instance.deliver(Uri.parse('oberta://room/${room.code}'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(200, 100));
      await tester.pumpAndSettle();
      online.signInReady(handle: 'anna');
      await tester.pumpAndSettle();
      expect(find.text('LA STANZA'), findsNothing);
      expect(find.text('CREA STANZA'), findsOneWidget);
    });

    testWidgets('un link storto o una stanza chiusa: due parole, e si resta nel vicolo', (tester) async {
      online.signInReady(handle: 'anna');
      await openAlley(tester);
      IncomingLinks.instance.deliver(Uri.parse('oberta://room/NOPE'));
      await tester.pumpAndSettle();
      expect(find.text('Questo link non porta a nessuna stanza.'), findsOneWidget);

      final room = online.openRoomAs('bruno', LobbyLanguage.it);
      online.leaveAs('bruno', room.id);
      IncomingLinks.instance.deliver(Uri.parse('oberta://room/${room.code}'));
      await tester.pumpAndSettle();
      expect(find.text('Nessuna stanza con questo codice.'), findsOneWidget);
      expect(find.text('CREA STANZA'), findsOneWidget);
    });

    testWidgets('senza server il link lo dice, e il vicolo non ha «Accedi»', (tester) async {
      OnlineServices.instance = null;
      await openAlley(tester);
      expect(find.text('ACCEDI'), findsNothing);
      IncomingLinks.instance.deliver(Uri.parse('oberta://room/XK7P2M'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Il gioco online non è disponibile'), findsOneWidget);
    });

    testWidgets('gli altri link (gli accessi di Google) non sono affar del vicolo', (tester) async {
      online.signInReady(handle: 'anna');
      await openAlley(tester);
      IncomingLinks.instance.deliver(Uri.parse('com.googleusercontent.apps.x:/oauth2redirect?code=1'));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
