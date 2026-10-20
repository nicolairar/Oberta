import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/l10n/app_strings.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/ui/widgets/device_session_gate.dart';

void main() {
  late FakeDeviceSessions server;
  late DeviceSession phone;
  late DeviceSession mac;

  setUp(() {
    server = FakeDeviceSessions(() => 'me');
    phone = DeviceSession(server, sessionId: 'phone-session-1', deviceLabel: 'iPhone');
    mac = DeviceSession(server.withAccount(() => 'me'), sessionId: 'mac-session-1', deviceLabel: 'Mac');
  });

  tearDown(() {
    phone.dispose();
    mac.dispose();
  });

  test('the first device plays, the second one makes both ask', () async {
    await phone.start();
    expect(phone.state, DeviceSessionState.active);
    await mac.start();
    await pumpEventQueue();
    expect(mac.state, DeviceSessionState.contested);
    expect(mac.otherLabel, 'iPhone');
    expect(phone.state, DeviceSessionState.contested);
    expect(phone.otherLabel, 'Mac');
  });

  test('whoever taps play here wins, the other is pushed out', () async {
    await phone.start();
    await mac.start();
    await pumpEventQueue();
    await mac.playHere();
    await pumpEventQueue();
    expect(mac.state, DeviceSessionState.active);
    expect(phone.state, DeviceSessionState.displaced);
    expect(phone.otherLabel, 'Mac');
    expect(() => server.checkWrite('phone-session-1'), throwsA(isA<OnlineException>()));

    await phone.playHere();
    await pumpEventQueue();
    expect(phone.state, DeviceSessionState.active);
    expect(mac.state, DeviceSessionState.displaced);
  });

  test('the active device keeping its seat sends the other away', () async {
    await phone.start();
    await mac.start();
    await pumpEventQueue();
    await phone.playHere();
    await pumpEventQueue();
    expect(phone.state, DeviceSessionState.active);
    expect(mac.state, DeviceSessionState.displaced);
  });

  test('an other_device rejection shows the displaced screen', () async {
    await phone.start();
    phone.otherDeviceRejected();
    expect(phone.state, DeviceSessionState.displaced);
  });

  testWidgets('the gate shows the question and play here takes over', (tester) async {
    await tester.runAsync(() async {
      await phone.start();
      await mac.start();
      await pumpEventQueue();
    });
    await tester.pumpWidget(MaterialApp(
      locale: AppLanguage.it.locale,
      supportedLocales: AppLanguage.locales,
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: DeviceSessionGate(session: phone, child: const Text('tavolo')),
    ));
    await tester.pump();
    expect(find.text('Puoi giocare su un solo dispositivo alla volta'), findsOneWidget);
    expect(find.textContaining('Mac'), findsOneWidget);

    await tester.runAsync(() async {
      await mac.playHere();
      await pumpEventQueue();
    });
    await tester.pump();
    expect(find.text('Sei connesso su un altro dispositivo'), findsOneWidget);

    await tester.tap(find.text('GIOCO QUA'));
    await tester.runAsync(pumpEventQueue);
    await tester.pump();
    expect(find.text('GIOCO QUA'), findsNothing);
    expect(find.text('tavolo'), findsOneWidget);
    expect(phone.state, DeviceSessionState.active);
  });
}
