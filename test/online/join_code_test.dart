import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/online/join_code.dart';
import 'package:oberta/online/online_config.dart';

void main() {
  test('un codice scritto male si ripulisce', () {
    expect(JoinCode.normalize('abc234'), 'ABC234');
    expect(JoinCode.normalize(' AB-C2 34 '), 'ABC234');
  });

  test('niente lettere che si confondono, e sei caratteri esatti', () {
    for (final bad in ['ABC23O', 'ABC231', 'ABCDEI', 'ABCDEL', 'ABC23', 'ABC2345', '']) {
      expect(JoinCode.normalize(bad), isNull, reason: bad);
    }
  });

  test('il QR della stanza porta il suo codice', () {
    expect(JoinCode.fromScan(JoinCode.qrPayload('XK7P2M')), 'XK7P2M');
    expect(JoinCode.fromScan('xk7p2m'), 'XK7P2M', reason: 'anche un codice nudo');
    expect(JoinCode.fromScan('https://example.com'), isNull);
  });

  test('il link del QR, aperto dalla fotocamera, porta alla stanza', () {
    expect(JoinCode.fromLink(Uri.parse(JoinCode.qrPayload('XK7P2M'))), 'XK7P2M');
    expect(JoinCode.fromLink(Uri.parse('oberta://room/xk7p2m')), 'XK7P2M');
    expect(JoinCode.fromLink(Uri.parse('OBERTA://ROOM/XK7P2M/')), 'XK7P2M');
    expect(JoinCode.isRoomLink(Uri.parse('oberta://room/')), isTrue);
    expect(JoinCode.fromLink(Uri.parse('oberta://room/')), isNull, reason: 'una stanza senza codice');
    expect(JoinCode.fromLink(Uri.parse('oberta://room/XK7P2O')), isNull, reason: 'una O non c\'è');
    expect(JoinCode.fromLink(Uri.parse('oberta://room/XK7P2M/altro')), isNull);
    // Gli altri link che arrivano all'app non sono stanze.
    for (final other in ['oberta://friend/XK7P2M', 'https://oberta.app/room/XK7P2M', 'com.googleusercontent.apps.x:/cb']) {
      expect(JoinCode.isRoomLink(Uri.parse(other)), isFalse, reason: other);
      expect(JoinCode.fromLink(Uri.parse(other)), isNull, reason: other);
    }
  });

  test('l\'alfabeto è quello del server', () {
    expect(JoinCode.alphabet, 'ABCDEFGHJKMNPQRSTUVWXYZ23456789');
  });

  test('senza config/supabase.json l\'online non c\'è', () {
    expect(OnlineConfig.compiled.isComplete, isFalse);
    expect(OnlineConfig.compiled.hasGoogle, isFalse);
    expect(const OnlineConfig(supabaseUrl: 'https://x.supabase.co', supabaseAnonKey: 'k').isComplete, isTrue);
  });
}
