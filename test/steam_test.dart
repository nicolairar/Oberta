import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/steam/steam.dart';

void main() {
  test('without --dart-define=STEAM=true there is no Steam at all', () async {
    expect(SteamClient.enabled, isFalse);
    await SteamClient.start();
    final steam = SteamClient.instance;
    expect(steam, isA<NoSteam>());
    expect(steam.running, isFalse);
    expect(steam.steamId, isNull);
    expect(await steam.webApiTicket(SteamClient.webApiIdentity), isNull);
    expect(steam.unlock(spacewarAchievements.first), isFalse);
  });

  test('tickets travel as lowercase hex', () {
    expect(ticketHex(Uint8List.fromList([0, 1, 0xab, 0xff])), '0001abff');
  });
}
